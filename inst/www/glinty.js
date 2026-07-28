/* glinty client: WebSocket transport + component rendering + DOM
   patching. No dependencies. Speaks protocol 3: it opens with hello,
   receives the canonical component tree in welcome, and hydrates
   against the pre-rendered markup by comparing ui_revision. */
(function () {
    "use strict";

    var PROTOCOL = 3;
    var CLIENT_ID = "glinty-js/0.5.0";

    /* What this client declares in hello. A declaration, not a
       negotiation: the server sends the whole tree regardless, and a
       component missing from this list still renders here -- the list
       exists so the server can log what a lesser client will show as
       a placeholder. The browser renders the full set. */
    var SUPPORTED_COMPONENTS = [
        "audio_output", "button", "checkbox_input", "column",
        "conditional_panel", "date_input", "divider", "download_button",
        "file_input", "heading", "html_output", "icon", "image_output",
        "link", "number_input", "page", "panel", "password_input",
        "plot_output", "radio_buttons", "raw_html", "row", "select_input",
        "slider_input", "spacer", "tabset", "text", "text_input",
        "text_output", "textarea_input", "ui_output", "verbatim_output"
    ];
    var SUPPORTED_KINDS = ["text", "html", "table", "image", "audio", "ui"];
    var SUPPORTED_FEATURES = ["upload", "download", "modal", "progress"];

    /* The one reserved component id: a button carrying it closes the
       open dialog locally and reports nothing. Reserved rather than
       app-chosen because ".." ids are refused on the input path, so
       an app cannot collide with it. */
    var MODAL_CLOSE_ID = "..modal_close";

    var ws = null;
    var sessionId = null;
    var debounceTimers = new Map();
    var DEBOUNCE_MS = 200;
    var customHandlers = {};
    var pending = [];
    var connectedFired = false;
    /* Revision of the markup this page was served with, read from the
       meta tag before connecting. Null when the document carries no
       revision, in which case welcome's tree is built from scratch. */
    var prerendered = null;
    /* Set once the server speaks a protocol this client cannot read.
       A refused session ignores everything and never reconnects: no
       message after the refusal is meaningful. */
    var refused = false;
    /* True from the moment a socket sends hello until that socket's
       welcome arrives. An id-less error in that window is a refusal
       of this connection -- and refusals happen on reconnects too,
       where a token has expired since the first hello. Keyed to the
       socket rather than to "have we ever connected", or a reconnect
       refusal reads as an ordinary session error and the client
       retries forever against a server that will never let it in. */
    var awaitingWelcome = false;
    /* The client's view of every input it knows about. Conditional
       panels are evaluated against this rather than re-read from the
       DOM, so server-pushed updates and Glinty.setInputValue() count
       the same as user edits. */
    var inputValues = {};

    /* ---------- value extraction ---------- */

    function extractValue(el) {
        if (el.type === "checkbox") return el.checked;
        if (el.type === "radio") {
            var checked = document.querySelector(
                'input[name="' + el.name + '"]:checked'
            );
            return checked ? checked.value : null;
        }
        if (el.tagName === "SELECT" && el.multiple) {
            return Array.from(el.selectedOptions).map(function (o) {
                return o.value;
            });
        }
        if (el.type === "range" || el.type === "number") {
            return el.value === "" ? null : Number(el.value);
        }
        return el.value;
    }

    /* Seed inputValues from the DOM so conditional panels can settle
       before (and without) any server round trip. Local state only:
       nothing here is sent. Protocol 2 shipped this harvest to the
       server at init; under v3 the server seeds itself from the tree
       it built, and a client that echoed the form back would write
       every default on every reload. */
    function harvestLocal() {
        document.querySelectorAll("[data-g-target]").forEach(function (el) {
            if (el.dataset.gMessage === "event") return; /* buttons: no state */
            if (el.dataset.gValue !== undefined) {
                /* click-selected state (tab buttons): the active one
                   holds the group's value */
                if (el.classList.contains("g-tab-active")) {
                    inputValues[el.dataset.gTarget] = el.dataset.gValue;
                }
                return;
            }
            if (el.type === "radio" && !el.checked) return;
            inputValues[el.dataset.gTarget] = extractValue(el);
        });
    }

    /* ---------- conditional panels ---------- */

    function noteInput(id, value) {
        inputValues[id] = value;
        refreshConditionals();
    }

    function condMatches(actual, wanted) {
        return wanted.some(function (w) {
            if (typeof w === "boolean" || typeof actual === "boolean") {
                return Boolean(actual) === Boolean(w);
            }
            if (actual === null || actual === undefined) return false;
            return String(actual) === String(w);
        });
    }

    function evalCondition(c) {
        if (!c || typeof c !== "object") return false;
        switch (c.op) {
        case "is":
            if (!Object.prototype.hasOwnProperty.call(inputValues, c.id)) {
                return false;
            }
            return condMatches(inputValues[c.id], [].concat(c.values));
        case "and":
            return (c.args || []).every(evalCondition);
        case "or":
            return (c.args || []).some(evalCondition);
        case "not":
            return !evalCondition(c.arg);
        default:
            console.warn("glinty: unknown condition op", c.op);
            return false;
        }
    }

    function refreshConditionals() {
        document.querySelectorAll("[data-g-cond]").forEach(function (el) {
            var cond = el._gCond;
            if (cond === undefined) {
                try {
                    cond = JSON.parse(el.dataset.gCond);
                } catch (e) {
                    console.error("glinty: bad condition", el.dataset.gCond);
                    cond = null;
                }
                el._gCond = cond;
            }
            el.classList.toggle("g-hidden", !evalCondition(cond));
        });
        /* a panel toggling can reveal a plot that has never had a
           real box to report */
        scheduleMeasure();
    }

    /* ---------- tabsets ---------- */

    function activateTab(btn) {
        var set = btn.closest(".g-tabset");
        if (!set) return;
        var name = btn.dataset.gTabPanel;
        /* closest() re-check keeps a nested tabset from being driven
           by its parent's buttons. */
        set.querySelectorAll(".g-tab-btn").forEach(function (b) {
            if (b.closest(".g-tabset") !== set) return;
            b.classList.toggle("g-tab-active",
                               b.dataset.gTabPanel === name);
        });
        set.querySelectorAll(".g-tab-body").forEach(function (p) {
            if (p.closest(".g-tabset") !== set) return;
            p.classList.toggle("g-hidden", p.dataset.gTabPanel !== name);
        });
        /* the newly shown panel may hold a plot that was 0x0 while
           hidden and has never reported a real box */
        scheduleMeasure();
    }

    /* ---------- client-sized plots ---------- */

    /* Last (width x height @ dpr) sent per output id. Dedup is per
       id and client-side: an element that is rebuilt at the same size
       stays silent, because the measurement is session state on the
       server and survives anything that happens to the element. */
    var plotDims = {};

    /* A rendered box is the one thing the server cannot know from the
       tree, so it is the one thing a client still reports after
       adopting. Dimensions are logical (CSS) pixels; dpr says how
       many physical pixels back each one, so the server can render a
       raster that is sharp on this screen. A box that cannot be seen
       (hidden, detached: zero size) is never reported -- zero is not
       a size, and the server keeps the last real one. */
    function reportPlotDims() {
        var dpr = window.devicePixelRatio || 1;
        document.querySelectorAll("img.g-plot-output").forEach(function (el) {
            if (!el.id) return;
            var w = Math.round(el.clientWidth);
            var h = Math.round(el.clientHeight);
            if (w < 1 || h < 1) return;
            var key = w + "x" + h + "@" + dpr;
            if (plotDims[el.id] === key) return;
            plotDims[el.id] = key;
            send({ type: "measure", id: el.id, width: w, height: h,
                   dpr: dpr });
        });
    }

    /* One debounced entry point for everything that can change a
       measured element's box or visibility: window resize, a tab
       switch, a conditional panel toggling, dynamic UI arriving. The
       dedup above makes spurious calls free. */
    var measureTimer = null;
    function scheduleMeasure() {
        if (measureTimer) clearTimeout(measureTimer);
        measureTimer = setTimeout(reportPlotDims, 250);
    }
    window.addEventListener("resize", scheduleMeasure);

    /* ResizeObserver catches what the manual triggers cannot: a box
       changed by a sibling growing, a font loading, or CSS -- none of
       which fire a window resize or pass through glinty. Observation
       is re-established from scratch whenever the set of measured
       elements can have changed; disconnect-and-reobserve is cheap at
       plot counts and never leaks an observer into a discarded tree.
       Everything still funnels through the deduped reporter, so the
       manual triggers staying live costs nothing, and clients without
       ResizeObserver keep working on them alone. */
    var resizeObserver = null;
    function observeMeasured() {
        if (typeof ResizeObserver === "undefined") return;
        if (!resizeObserver) {
            resizeObserver = new ResizeObserver(scheduleMeasure);
        }
        resizeObserver.disconnect();
        document.querySelectorAll("img.g-plot-output").forEach(function (el) {
            resizeObserver.observe(el);
        });
    }

    /* ---------- outgoing ---------- */

    /* Queue rather than drop: app scripts can fire before the socket
       is open, and a silently lost input is a miserable bug. */
    function send(msg) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(msg));
        } else {
            pending.push(msg);
        }
    }

    function flushPending() {
        var queued = pending;
        pending = [];
        queued.forEach(send);
    }

    function sendInput(el) {
        var value = extractValue(el);
        noteInput(el.dataset.gTarget, value);
        send({
            type: "input",
            id: el.dataset.gTarget,
            value: value
        });
    }

    function sendInputDebounced(el) {
        var id = el.dataset.gTarget;
        if (debounceTimers.has(id)) clearTimeout(debounceTimers.get(id));
        debounceTimers.set(id, setTimeout(function () {
            debounceTimers.delete(id);
            sendInput(el);
        }, DEBOUNCE_MS));
    }

    /* ---------- event delegation ---------- */

    /* Listeners attach to the root exactly once, at page load. That
       is what makes "adopting pre-rendered markup never duplicates
       handlers" structural: hydration touches the DOM, never the
       listeners, so there is no second registration to forget to
       skip. */
    function bindEvents(root) {
        root.addEventListener("click", function (ev) {
            var el = ev.target.closest("[data-g-target]");
            if (!el) return;
            /* data-g-message says what the element emits. Buttons are
               events: no value, just the fact of the press. A download
               button's press IS the download -- the ticket listener
               below handles it, and doubling it with an event frame
               would make one press two actions. An element carrying
               data-g-value is click-selected state (a tab): that is
               an input. Anything else reports through its own
               input/change events, not through clicks. */
            if (el.dataset.gMessage === "event") {
                if (el.dataset.gDownload === undefined) {
                    send({ type: "event", id: el.dataset.gTarget });
                }
                return;
            }
            if (el.dataset.gValue !== undefined) {
                noteInput(el.dataset.gTarget, el.dataset.gValue);
                send({
                    type: "input",
                    id: el.dataset.gTarget,
                    value: el.dataset.gValue
                });
            }
        });

        root.addEventListener("click", function (ev) {
            var btn = ev.target.closest(".g-tab-btn");
            if (btn) activateTab(btn);
        });

        root.addEventListener("click", function (ev) {
            if (ev.target.closest("[data-g-modal-close]")) {
                closeModal();
                return;
            }
            var dl = ev.target.closest("[data-g-download]");
            if (dl) {
                ev.preventDefault();
                startDownload(dl);
            }
        });

        root.addEventListener("input", function (ev) {
            var el = ev.target;
            if (el.dataset.gEvent !== "input") return;
            sendInputDebounced(el);
        });

        root.addEventListener("change", function (ev) {
            var el = ev.target;
            if (el.dataset.gUpload) {
                uploadFiles(el);
                return;
            }
            if (el.dataset.gEvent !== "change") return;
            sendInput(el);
        });
    }

    /* ---------- transfer tickets ---------- */

    /* Uploads and downloads run over plain HTTP, so they cannot ride
       the socket's authentication. Each transfer asks the server for
       a short-lived single-use ticket over the socket and puts only
       that in the URL: no session credential in browser history or
       server logs, and a leaked URL expires in seconds. */
    var ticketWaiters = {};

    function requestTicket(id, purpose, cb, onRefused) {
        var key = purpose + ":" + id;
        (ticketWaiters[key] = ticketWaiters[key] || []).push({
            grant: cb,
            refused: onRefused
        });
        send({ type: "ticket", id: id, purpose: purpose });
    }

    function deliverTicket(msg) {
        var key = msg.purpose + ":" + msg.id;
        var queue = ticketWaiters[key];
        if (queue && queue.length) {
            queue.shift().grant(msg);
        }
    }

    /* The server can refuse a grant (too many pending transfers).
       Waiters have to hear about it: a control disabled while it
       waits for a grant that never comes stays disabled forever. */
    function refuseTickets(id, message) {
        ["upload", "download"].forEach(function (purpose) {
            var queue = ticketWaiters[purpose + ":" + id];
            while (queue && queue.length) {
                var waiter = queue.shift();
                if (waiter.refused) waiter.refused(message);
            }
        });
    }

    /* ---------- file uploads (plain POST, not the WS) ---------- */

    function uploadFiles(el) {
        if (!sessionId || !el.files || el.files.length === 0) return;
        var fd = new FormData();
        Array.from(el.files).forEach(function (f) {
            fd.append("file", f, f.name);
        });
        el.disabled = true;
        requestTicket(el.dataset.gUpload, "upload", function (ticket) {
            fetch(
                "/upload?ticket=" + encodeURIComponent(ticket.token),
                { method: "POST", body: fd }
            ).then(function (resp) {
                if (!resp.ok) throw new Error("upload failed: " + resp.status);
                el.classList.remove("g-error");
            }).catch(function () {
                el.classList.add("g-error");
            }).finally(function () {
                el.disabled = false;
            });
        }, function () {
            /* refused: give the control back rather than leaving it
               dead while the user wonders what happened */
            el.disabled = false;
            el.classList.add("g-error");
        });
    }

    /* ---------- component rendering ---------- */

    /* The JS twin of R's component_to_html(). The server renders the
       initial page; this builds the same DOM for everything that
       arrives at runtime: welcome.ui on a revision mismatch,
       render_ui() output, modal bodies. The two lowerings must agree,
       and the shared fixtures pin this one the same way the R tests
       pin that one. Anything reached for here that the tree does not
       supply is a schema finding, not a workaround. */

    var TEXT_CLASSES = {
        normal: "g-text",
        muted: "g-text g-muted",
        strong: "g-text g-strong",
        heading: "g-text g-text-heading"
    };
    var OUTPUT_CLASSES = {
        normal: "g-output",
        muted: "g-output g-muted",
        strong: "g-output g-strong"
    };
    var OUTPUT_KIND_OF = {
        text_output: "text",
        verbatim_output: "text",
        table_output: "table",
        plot_output: "image",
        image_output: "image",
        audio_output: "audio",
        html_output: "html",
        ui_output: "ui"
    };

    function el(tag, attrs) {
        var node = document.createElement(tag);
        Object.keys(attrs || {}).forEach(function (k) {
            var v = attrs[k];
            if (v !== null && v !== undefined) node.setAttribute(k, v);
        });
        return node;
    }

    /* The spec's fallback rule, applied to every variant-bearing
       component: unknown variants take the first listed, with a
       warning rather than an error, because a same-protocol server
       one release newer may know variants this client does not. */
    var KNOWN_VARIANTS = {
        text: ["normal", "muted", "strong", "heading"],
        text_output: ["normal", "muted", "strong"],
        button: ["default", "primary", "secondary", "danger", "ghost"],
        download_button: ["default", "primary", "secondary", "danger",
                          "ghost"],
        panel: ["plain", "card", "sidebar"],
        divider: ["line", "labelled"]
    };

    function checkVariant(component, variant) {
        var known = KNOWN_VARIANTS[component];
        if (!known) return variant;
        if (variant === null || variant === undefined) return known[0];
        if (known.indexOf(variant) !== -1) return variant;
        console.warn("glinty: unknown", component, "variant", variant,
                     "- falling back to", known[0]);
        return known[0];
    }

    /* emit becomes a DOM event name here and nowhere else. */
    function emitEvent(emit) {
        return emit === "live" ? "input" : "change";
    }

    function bindAttrs(c, message) {
        var attrs = { id: c.id };
        attrs["data-g-target"] = c.id;
        attrs["data-g-message"] = message;
        if (c.emit) attrs["data-g-event"] = emitEvent(c.emit);
        return attrs;
    }

    function slotAttrs(c) {
        var attrs = { id: c.id };
        attrs["data-g-output"] = c.id;
        attrs["data-g-kind"] = OUTPUT_KIND_OF[c.component];
        return attrs;
    }

    function assign(target, extra) {
        Object.keys(extra || {}).forEach(function (k) {
            target[k] = extra[k];
        });
        return target;
    }

    function fieldGroup(c, control) {
        var wrap = el("div", { "class": "g-field" });
        if (c.label) {
            var lab = el("label", { "for": c.id });
            lab.textContent = c.label;
            wrap.appendChild(lab);
        }
        wrap.appendChild(control);
        return wrap;
    }

    function appendChildren(node, children) {
        (children || []).forEach(function (ch) {
            var built = buildComponent(ch);
            if (built) node.appendChild(built);
        });
    }

    function buildLayout(c, cls) {
        var style = [];
        if (c.gap !== null && c.gap !== undefined) {
            style.push("gap:" + c.gap + "px");
        }
        if (c.align) {
            var map = { start: "flex-start", center: "center",
                        end: "flex-end" };
            style.push("align-items:" + map[c.align]);
        }
        var node = el("div", {
            "class": cls,
            id: c.id,
            style: style.length ? style.join(";") : null
        });
        appendChildren(node, c.children);
        return node;
    }

    function buildTextLike(c, type) {
        var attrs = assign(bindAttrs(c, "input"), {
            type: type,
            "class": "g-input",
            value: c.value === null || c.value === undefined ? "" : c.value,
            placeholder: c.placeholder
        });
        return fieldGroup(c, el("input", attrs));
    }

    function buildSelect(c) {
        var attrs = assign(bindAttrs(c, "input"), { "class": "g-select" });
        if (c.multiple) attrs.multiple = "multiple";
        var sel = el("select", attrs);
        /* A multiple select carries a list, so membership rather than
           equality: === against an array never matches, which drew
           every option unselected however many the app had chosen. */
        var chosen = Array.isArray(c.selected)
            ? c.selected.map(String)
            : c.selected === null || c.selected === undefined
              ? []
              : [String(c.selected)];
        (c.choices || []).forEach(function (ch) {
            var opt = el("option", {
                value: ch.value,
                selected: chosen.indexOf(String(ch.value)) !== -1
                    ? "selected"
                    : null
            });
            opt.textContent = ch.label;
            sel.appendChild(opt);
        });
        return fieldGroup(c, sel);
    }

    function buildCheckbox(c) {
        var attrs = assign(bindAttrs(c, "input"), {
            type: "checkbox",
            "class": "g-checkbox",
            checked: c.value === true ? "checked" : null
        });
        var wrap = el("div", { "class": "g-check" });
        wrap.appendChild(el("input", attrs));
        var lab = el("label", { "for": c.id });
        lab.textContent = c.label || "";
        wrap.appendChild(lab);
        return wrap;
    }

    function buildRadio(c) {
        var group = el("div", { id: c.id, "class": "g-radio-group" });
        var glab = el("label", { "class": "g-radio-group-label" });
        glab.textContent = c.label || "";
        group.appendChild(glab);
        (c.choices || []).forEach(function (ch, i) {
            var item = el("div", { "class": "g-radio-item" });
            var itemId = c.id + "_" + (i + 1);
            var attrs = {
                id: itemId,
                type: "radio",
                name: c.id,
                value: ch.value,
                "class": "g-radio",
                checked: ch.value === c.selected ? "checked" : null
            };
            attrs["data-g-target"] = c.id;
            attrs["data-g-message"] = "input";
            attrs["data-g-event"] = emitEvent(c.emit);
            item.appendChild(el("input", attrs));
            var lab = el("label", { "for": itemId });
            lab.textContent = ch.label;
            item.appendChild(lab);
            group.appendChild(item);
        });
        return group;
    }

    function buildFile(c) {
        var attrs = assign(bindAttrs(c, "input"), {
            type: "file",
            "class": "g-file"
        });
        if (c.multiple) attrs.multiple = "multiple";
        attrs["data-g-upload"] = c.id;
        if (c.accept) {
            attrs.accept = [].concat(c.accept).join(",");
        }
        return fieldGroup(c, el("input", attrs));
    }

    function buildButton(c, extraClass) {
        /* MODAL_CLOSE_ID dismisses the dialog and tells nobody, which
           is what modal_button() is for. It carries no event binding:
           a Cancel that also reported would make dismissing a dialog
           news, and the server has no observer for it anyway. The
           delegated handler below has always looked for the mark; for
           a while nothing set it, so the button rendered and did
           nothing at all. */
        var closes = c.id === MODAL_CLOSE_ID;
        var attrs = assign(
            closes ? {} : bindAttrs(c, "event"),
            {
                type: "button",
                "class": ["g-btn",
                          "g-btn-" + checkVariant(c.component, c.variant)]
                    .concat(extraClass || []).join(" ")
            }
        );
        if (closes) {
            attrs["data-g-modal-close"] = "1";
        }
        if (c.component === "download_button") {
            attrs["data-g-download"] = c.id;
        }
        var btn = el("button", attrs);
        if (c.icon) {
            btn.appendChild(buildComponent({
                component: "icon", name: c.icon, size: 18
            }));
        }
        btn.appendChild(document.createTextNode(c.label || ""));
        return btn;
    }

    function buildTabset(c) {
        var titles = (c.panels || []).map(function (p) { return p.title; });
        var selected = c.selected;
        if (selected === null || selected === undefined ||
                titles.indexOf(selected) === -1) {
            selected = titles[0];
        }
        var set = el("div", { id: c.id, "class": "g-tabset" });
        var nav = el("div", { "class": "g-tab-nav" });
        (c.panels || []).forEach(function (p) {
            var attrs = {
                type: "button",
                "class": "g-tab-btn" +
                    (p.title === selected ? " g-tab-active" : "")
            };
            attrs["data-g-tab-panel"] = p.title;
            attrs["data-g-target"] = c.id;
            attrs["data-g-message"] = "input";
            attrs["data-g-value"] = p.title;
            var btn = el("button", attrs);
            btn.textContent = p.title;
            nav.appendChild(btn);
        });
        set.appendChild(nav);
        var bodies = el("div", { "class": "g-tab-bodies" });
        (c.panels || []).forEach(function (p) {
            var attrs = {
                "class": "g-tab-body" +
                    (p.title === selected ? "" : " g-hidden")
            };
            attrs["data-g-tab-panel"] = p.title;
            var body = el("div", attrs);
            appendChildren(body, p.children);
            bodies.appendChild(body);
        });
        set.appendChild(bodies);
        return set;
    }

    function buildComponent(c) {
        if (c === null || c === undefined) return null;
        var node;
        switch (c.component) {
        case "text":
            node = el("span", {
                "class": TEXT_CLASSES[checkVariant("text", c.variant)],
                id: c.id
            });
            node.textContent = c.value;
            return node;
        case "heading":
            node = el("h" + (c.level || 2), { id: c.id });
            node.textContent = c.value;
            return node;
        case "link":
            node = el("a", {
                href: c.href,
                "class": "g-link",
                target: c.external ? "_blank" : null,
                rel: c.external ? "noopener noreferrer" : null
            });
            node.textContent = c.value;
            return node;
        case "icon":
            node = el("span", {
                "class": "g-icon g-icon-" + c.name,
                style: "width:" + c.size + "px;height:" + c.size + "px"
            });
            node.setAttribute("data-g-icon", c.name);
            node.setAttribute("aria-hidden", "true");
            return node;
        case "divider":
            if (checkVariant("divider", c.variant) === "labelled" && c.label) {
                node = el("div", {
                    "class": "g-divider g-divider-labelled"
                });
                var dl = el("span", { "class": "g-divider-label" });
                dl.textContent = c.label;
                node.appendChild(dl);
                return node;
            }
            return el("hr", { "class": "g-divider" });
        case "spacer":
            node = el("div", {
                "class": "g-spacer",
                style: "height:calc(var(--g-space) * " + c.size + ")"
            });
            node.setAttribute("data-g-size", c.size);
            return node;
        case "page":
            node = el("div", { "class": "g-page", id: c.id });
            appendChildren(node, c.children);
            return node;
        case "row":
            return buildLayout(c, "g-layout-row");
        case "column":
            return buildLayout(c, "g-layout-col");
        case "panel":
            node = el("div", {
                "class": "g-panel g-panel-" + checkVariant("panel", c.variant),
                id: c.id
            });
            if (c.title) {
                var pt = el("div", { "class": "g-panel-title" });
                pt.textContent = c.title;
                node.appendChild(pt);
            }
            appendChildren(node, c.children);
            return node;
        case "text_input":
            return buildTextLike(c, "text");
        case "password_input":
            return buildTextLike(c, "password");
        case "date_input":
            return buildTextLike(c, "date");
        case "textarea_input":
            node = el("textarea", assign(bindAttrs(c, "input"), {
                "class": "g-textarea",
                rows: c.rows,
                placeholder: c.placeholder
            }));
            node.textContent =
                c.value === null || c.value === undefined ? "" : c.value;
            return fieldGroup(c, node);
        case "number_input":
            return fieldGroup(c, el("input", assign(bindAttrs(c, "input"), {
                type: "number",
                "class": "g-input",
                value: c.value,
                min: c.min,
                max: c.max,
                step: c.step
            })));
        case "select_input":
            return buildSelect(c);
        case "checkbox_input":
            return buildCheckbox(c);
        case "radio_buttons":
            return buildRadio(c);
        case "slider_input":
            return fieldGroup(c, el("input", assign(bindAttrs(c, "input"), {
                type: "range",
                "class": "g-slider",
                min: c.min,
                max: c.max,
                value: c.value,
                step: c.step
            })));
        case "file_input":
            return buildFile(c);
        case "button":
            return buildButton(c);
        case "download_button":
            return buildButton(c, ["g-download"]);
        case "text_output":
            return el("span", assign(slotAttrs(c), {
                "class": OUTPUT_CLASSES[checkVariant("text_output", c.variant)]
            }));
        case "verbatim_output":
            return el("pre", assign(slotAttrs(c), {
                "class": "g-verbatim-output"
            }));
        case "table_output":
            return el("div", assign(slotAttrs(c), {
                "class": "g-table-output"
            }));
        case "plot_output":
            return el("img", assign(slotAttrs(c), {
                "class": "g-plot-output",
                alt: c.alt,
                width: c.width,
                height: c.height,
                style: (c.width === null || c.width === undefined) &&
                    (c.height === null || c.height === undefined)
                    ? "width:100%;aspect-ratio:4 / 3" : null
            }));
        case "image_output":
            return el("img", assign(slotAttrs(c), {
                "class": "g-image-output",
                alt: c.alt
            }));
        case "audio_output":
            return el("audio", assign(slotAttrs(c), {
                "class": "g-audio-output",
                controls: c.controls ? "controls" : null,
                autoplay: c.autoplay ? "autoplay" : null
            }));
        case "html_output":
            return el("div", assign(slotAttrs(c), {
                "class": "g-html-output"
            }));
        case "ui_output":
            return el("div", assign(slotAttrs(c), {
                "class": "g-ui-output"
            }));
        case "tabset":
            return buildTabset(c);
        case "conditional_panel":
            node = el("div", { "class": "g-conditional" });
            node.setAttribute("data-g-cond", JSON.stringify(c.condition));
            appendChildren(node, c.children);
            return node;
        case "raw_html": {
            /* The browser-only escape hatch: trusted markup, inserted
               as-is. A template splices its children inline, keeping
               the structure identical to the server-rendered page. */
            var t = document.createElement("template");
            if (t.content) {
                t.innerHTML = c.html;
                return t.content;
            }
            node = document.createElement("div");
            node.innerHTML = c.html;
            return node;
        }
        default:
            /* Visible and named, never silent. */
            node = el("div", { "class": "g-unsupported" });
            node.setAttribute("data-g-component", String(c.component));
            node.textContent =
                "[unsupported component: " + c.component + "]";
            return node;
        }
    }

    /* ---------- incoming ---------- */

    function clearError(el) {
        el.classList.remove("g-error");
        el.removeAttribute("title");
        clearKindGap(el);
    }

    /* The visible refusal for an output kind this client cannot
       display. Slot elements are not all containers -- an <img>
       shows no textContent -- so the notice is a sibling node,
       visible next to anything. The slot holds a direct reference to
       its notice: no selector, so no id can break one (an output id
       is app-chosen text, not something to interpolate into query
       syntax). The data attribute is set for inspection only. */
    function showKindGap(el, kind) {
        clearKindGap(el);
        el.classList.add("g-unsupported");
        var note = document.createElement("div");
        note.className = "g-unsupported g-kind-gap";
        note.setAttribute("data-g-kind-gap", el.id);
        note.textContent = "[unsupported output kind: " + kind + "]";
        if (el.parentNode) {
            el.parentNode.insertBefore(note, el.nextSibling);
            el._gKindGap = note;
        }
    }

    /* A recognised value arriving later means the gap closed; the
       notice and the marker class go with it. A rebuilt slot starts
       clean by construction: the old notice died with the old
       subtree, and the new element carries no reference. */
    function clearKindGap(el) {
        el.classList.remove("g-unsupported");
        if (el._gKindGap) {
            el._gKindGap.remove();
            el._gKindGap = null;
        }
    }

    function buildTable(el, data) {
        el.textContent = "";
        var tbl = document.createElement("table");
        tbl.className = "g-table";
        var thead = document.createElement("thead");
        var hr = document.createElement("tr");
        (data.header || []).forEach(function (h) {
            var th = document.createElement("th");
            th.textContent = h;
            hr.appendChild(th);
        });
        thead.appendChild(hr);
        tbl.appendChild(thead);
        var tbody = document.createElement("tbody");
        (data.rows || []).forEach(function (r) {
            var tr = document.createElement("tr");
            r.forEach(function (c) {
                var td = document.createElement("td");
                td.textContent = c; /* structural escaping */
                tr.appendChild(td);
            });
            tbody.appendChild(tr);
        });
        tbl.appendChild(tbody);
        el.appendChild(tbl);
    }

    /* Apply an output message: the value is typed by kind (what the
       renderer produced), and the receiving element decides how to
       show it. The DOM property names of protocol 2 are gone from
       the wire; this is the only place that knows text means
       textContent here. */
    function applyOutput(msg) {
        var el = document.getElementById(msg.id);
        if (!el) return;
        clearError(el);
        switch (msg.kind) {
        case "text":
            el.textContent = msg.value === null ? "" : msg.value;
            break;
        case "html":
            el.innerHTML = msg.value === null ? "" : msg.value;
            break;
        case "table":
            buildTable(el, msg.value || {});
            break;
        case "image": {
            var v = msg.value || {};
            el.src = v.src || "";
            /* logical pixels: the raster behind src may be denser */
            if (v.width) el.setAttribute("width", v.width);
            if (v.height) el.setAttribute("height", v.height);
            break;
        }
        case "audio":
            el.src = (msg.value || {}).src || "";
            break;
        case "ui": {
            el.textContent = "";
            var node = buildComponent(msg.value);
            if (node) el.appendChild(node);
            /* the new subtree may contain conditional panels that
               have never been evaluated, and plots that have never
               reported a box (refreshConditionals also schedules a
               measure pass) */
            refreshConditionals();
            observeMeasured();
            break;
        }
        default:
            /* Visible and named, never silent -- the same rule as an
               unknown component. A kind this client cannot display is
               a version gap the user should see, not a console line
               nobody reads. The slot empties (stale content shown as
               current would be a quieter lie) and the notice stands
               beside it. */
            el.textContent = "";
            el.removeAttribute("src");
            showKindGap(el, msg.kind);
            console.warn("glinty: unknown output kind", msg.kind);
        }
    }

    function applyRadioUpdate(group, msg) {
        if (msg.label !== undefined) {
            var lab = group.querySelector(".g-radio-group-label");
            if (lab) lab.textContent = msg.label;
        }
        if (msg.choices !== undefined) {
            group.querySelectorAll(".g-radio-item").forEach(function (n) {
                n.remove();
            });
            msg.choices.forEach(function (c, i) {
                var item = document.createElement("div");
                item.className = "g-radio-item";
                var inp = document.createElement("input");
                inp.type = "radio";
                inp.name = msg.id;
                inp.id = msg.id + "_" + (i + 1);
                inp.value = c.value;
                inp.className = "g-radio";
                inp.dataset.gEvent = "change";
                inp.dataset.gTarget = msg.id;
                var lab = document.createElement("label");
                lab.htmlFor = inp.id;
                lab.textContent = c.label;
                item.appendChild(inp);
                item.appendChild(lab);
                group.appendChild(item);
            });
        }
        if (msg.selected !== undefined) {
            var target = group.querySelector(
                'input[name="' + msg.id + '"][value="' + msg.selected + '"]'
            );
            if (target) target.checked = true;
        }
    }

    function applyInputUpdate(msg) {
        var el = document.getElementById(msg.id);
        if (!el) return;

        /* A server-driven update is a value change like any other, so
           conditional panels keyed on this input must see it. The
           server already synced its own copy. */
        if (msg.selected !== undefined) {
            noteInput(msg.id, msg.selected);
        } else if (msg.value !== undefined) {
            noteInput(msg.id, el.type === "checkbox" ? !!msg.value : msg.value);
        }

        if (el.classList && el.classList.contains("g-radio-group")) {
            applyRadioUpdate(el, msg);
            return;
        }

        if (msg.label !== undefined) {
            var lab = document.querySelector('label[for="' + msg.id + '"]');
            if (lab) lab.textContent = msg.label;
        }
        if (msg.choices !== undefined && el.tagName === "SELECT") {
            el.textContent = "";
            msg.choices.forEach(function (c) {
                var opt = document.createElement("option");
                opt.value = c.value;
                opt.textContent = c.label;
                el.appendChild(opt);
            });
        }
        if (msg.selected !== undefined && el.tagName === "SELECT") {
            /* never stomp an open dropdown */
            if (el !== document.activeElement) {
                if (el.multiple) {
                    /* el.value takes one string, so assigning an array
                       to a multiple select selected nothing at all --
                       the server pushed a selection and the control
                       silently cleared. Set each option instead. */
                    var want = Array.isArray(msg.selected)
                        ? msg.selected.map(String)
                        : [String(msg.selected)];
                    Array.prototype.forEach.call(el.options, function (o) {
                        o.selected = want.indexOf(o.value) !== -1;
                    });
                } else {
                    el.value = msg.selected;
                }
            }
        }
        if (msg.min !== undefined) el.min = msg.min;
        if (msg.max !== undefined) el.max = msg.max;
        if (msg.step !== undefined) el.step = msg.step;
        if (msg.value !== undefined && el.tagName !== "SELECT") {
            /* never stomp live typing */
            if (el !== document.activeElement) {
                if (el.type === "checkbox") {
                    el.checked = !!msg.value;
                } else {
                    el.value = msg.value;
                }
            }
        }
        /* deliberately no synthetic events: the server already knows */
    }

    function applyError(msg) {
        if (!msg.id) {
            console.error("glinty:", msg.message);
            return;
        }
        var el = document.getElementById(msg.id);
        if (!el) return;
        el.classList.add("g-error");
        el.textContent = "Error: " + msg.message;
        el.title = msg.message;
    }

    /* ---------- hydration ---------- */

    /* Replace the pre-rendered markup with DOM built from welcome.ui.
       The mismatch path: whatever this page was served describes a
       different tree, and patching a stale DOM is how a hydration bug
       becomes a data bug. Delegated listeners live on the root and
       survive; local input state re-seeds from the new DOM. */
    function rebuildRoot(ui) {
        var root = document.getElementById("glinty-root");
        if (!root) return;
        root.textContent = "";
        var built = buildComponent(ui);
        if (built) root.appendChild(built);
        inputValues = {};
        harvestLocal();
        refreshConditionals();
        observeMeasured();
    }

    /* A fatal refusal, drawn. It replaces the content rather than
       sitting on top of it, because there is no content this client
       can be trusted to show. Styled inline so it renders even if the
       stylesheet never loaded. */
    function showFatal(title, text) {
        var root = document.getElementById("glinty-root") || document.body;
        root.textContent = "";
        var box = document.createElement("div");
        box.id = "g-protocol-error";
        box.setAttribute("style",
            "margin:24px;padding:20px 24px;border:2px solid #b3261e;" +
            "border-radius:8px;background:#fdecea;color:#4a1210;" +
            "font-family:system-ui,sans-serif");
        var h = document.createElement("h2");
        h.textContent = title;
        var p = document.createElement("p");
        p.textContent = text;
        box.appendChild(h);
        box.appendChild(p);
        root.appendChild(box);
    }

    function showProtocolError(got) {
        var advice = got > PROTOCOL ? "Update the app." : "Update the server.";
        showFatal("Incompatible glinty server",
                  "This app speaks glinty protocol " + PROTOCOL +
                  ", but the server sent protocol " + got + ". " + advice);
    }

    /* Theme tokens land in the #g-theme style element -- the same
       one the served page carried -- never as inline properties on
       the root. Precedence is the point: the block sits after
       glinty.css (tokens beat the defaults and the dark-mode block)
       and before any app stylesheet (apps beat tokens), and writing
       the element keeps that order identical before and after the
       socket connects. Inline root properties would beat app CSS and
       flip the cascade mid-session. On a fresh page this write is a
       no-op; on a cached page it heals the palette without a
       reload. */
    var THEME_COLOR_NAMES = ["primary", "on_primary", "surface",
                             "background", "text", "muted", "border",
                             "danger"];

    /* Token values are interpolated into CSS text, so each field is
       held to the same rule app_theme() enforces server-side --
       "#rrggbb(aa)" colors, one plain family name per font token.
       Identical rules on both sides is the point: a value the server
       admitted is a value this client writes, so the first paint and
       the hydrated state cannot diverge. */
    var HEX_COLOR = /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/;
    var FONT_FAMILY = /^[A-Za-z0-9][A-Za-z0-9 _-]*$/;

    function themeCssText(theme) {
        var parts = [];
        var colors = theme.colors || {};
        THEME_COLOR_NAMES.forEach(function (name) {
            if (typeof colors[name] === "string" &&
                    HEX_COLOR.test(colors[name])) {
                parts.push("--g-" + name.replace(/_/g, "-") + ":" +
                           colors[name]);
            }
        });
        if (typeof theme.spacing === "number" && isFinite(theme.spacing)) {
            parts.push("--g-space:" + theme.spacing + "px");
        }
        if (typeof theme.radius === "number" && isFinite(theme.radius)) {
            parts.push("--g-radius:" + theme.radius + "px");
        }
        var font = theme.font || {};
        if (typeof font.body === "string" && FONT_FAMILY.test(font.body)) {
            parts.push("--g-font-body:" + font.body);
        }
        if (typeof font.mono === "string" && FONT_FAMILY.test(font.mono)) {
            parts.push("--g-font-mono:" + font.mono);
        }
        if (typeof font.size === "number" && isFinite(font.size)) {
            parts.push("--g-font-size:" + font.size + "px");
        }
        return ":root{" + parts.join(";") + "}";
    }

    function applyTheme(theme) {
        if (!theme || typeof theme !== "object") return;
        var node = document.getElementById("g-theme");
        if (!node) {
            node = document.createElement("style");
            node.id = "g-theme";
            /* after the first stylesheet link (glinty.css), so app
               stylesheets that follow still win */
            var link = document.querySelector("link");
            if (link && link.parentNode) {
                link.parentNode.insertBefore(node, link.nextSibling);
            } else if (document.head) {
                document.head.appendChild(node);
            }
        }
        node.textContent = themeCssText(theme);
    }

    function handleWelcome(msg) {
        awaitingWelcome = false;
        if (msg.protocol !== PROTOCOL) {
            /* Refuse before touching the DOM state: a mismatched
               server must not get a half-rendered tree on screen. */
            refused = true;
            showProtocolError(msg.protocol);
            return;
        }
        if (msg.resumed === false) {
            /* session expired server-side; our DOM holds dead state */
            location.reload();
            return;
        }
        applyTheme(msg.theme);
        var resumedNow = msg.resumed === true;
        sessionId = msg.session;
        retries = 0;
        hideBanner();
        if (!resumedNow) {
            if (prerendered && msg.ui_revision &&
                    msg.ui_revision === prerendered) {
                /* Adopt: the markup we were served describes exactly
                   this tree. Nothing to build, nothing to send -- the
                   server built the tree and knows every default. */
            } else if (msg.ui) {
                rebuildRoot(msg.ui);
            }
            reportPlotDims();
            observeMeasured();
        }
        /* On resume the DOM is live client state, not the initial
           tree; the welcome's ui rides along and is ignored. */
        flushPending();
        /* Once per page load, not once per socket: a successful
           resume keeps the DOM and the app's JS state, and a failed
           one reloads above. Re-firing would make apps
           double-register their listeners. */
        if (!connectedFired) {
            connectedFired = true;
            document.dispatchEvent(new CustomEvent("glinty:connected", {
                detail: { sessionId: sessionId }
            }));
        }
    }

    function onMessage(ev) {
        if (refused) return;
        var msg;
        try {
            msg = JSON.parse(ev.data);
        } catch (e) {
            console.error("glinty: bad frame", ev.data);
            return;
        }
        switch (msg.type) {
        case "welcome":
            handleWelcome(msg);
            break;
        case "custom":
            if (Object.prototype.hasOwnProperty.call(
                customHandlers, msg.handler
            )) {
                customHandlers[msg.handler](msg.value);
            } else {
                console.warn("glinty: no handler for custom message",
                             msg.handler);
            }
            break;
        case "output":
            applyOutput(msg);
            break;
        case "input_update":
            applyInputUpdate(msg);
            break;
        case "modal":
            if (msg.action === "hide") {
                closeModal();
            } else {
                showModal(msg);
            }
            break;
        case "progress":
            applyProgress(msg);
            break;
        case "ticket":
            deliverTicket(msg);
            break;
        case "error":
            /* An id-less error while this socket is still waiting for
               its welcome is a refused connection (authentication,
               most likely): the server says why once and closes.
               Visible, like every other refusal -- including on a
               reconnect, where the token that worked an hour ago has
               expired. */
            if (!msg.id && awaitingWelcome) {
                refused = true;
                awaitingWelcome = false;
                showFatal("Connection refused",
                          msg.message || "The server refused this connection.");
                break;
            }
            /* an error naming a resource someone is waiting on is
               that wait's answer */
            if (msg.id) refuseTickets(msg.id, msg.message);
            applyError(msg);
            break;
        default:
            console.warn("glinty: unknown message type", msg.type);
        }
    }

    /* ---------- modals ---------- */

    /* Mounted inside #glinty-root, not document.body, so the existing
       event delegation reaches buttons and inputs in the dialog. */
    function closeModal() {
        var open = document.getElementById("g-modal");
        if (open) {
            open.remove();
            /* the body may have held plots; re-establish observation
               from the DOM that remains, or the observer keeps refs
               into the discarded tree */
            observeMeasured();
        }
    }

    function showModal(msg) {
        closeModal();
        var root = document.getElementById("glinty-root");
        if (!root) return;

        var overlay = document.createElement("div");
        overlay.id = "g-modal";
        overlay.className = "g-modal-overlay";

        var box = document.createElement("div");
        box.className = "g-modal-box";

        if (msg.title !== null && msg.title !== undefined) {
            var h = document.createElement("h3");
            h.className = "g-modal-title";
            h.textContent = msg.title;
            box.appendChild(h);
        }

        var body = document.createElement("div");
        body.className = "g-modal-body";
        (msg.body || []).forEach(function (node) {
            var el = buildComponent(node);
            if (el) body.appendChild(el);
        });
        box.appendChild(body);

        if (msg.footer) {
            var foot = document.createElement("div");
            foot.className = "g-modal-footer";
            var f = buildComponent(msg.footer);
            if (f) foot.appendChild(f);
            box.appendChild(foot);
        }

        if (msg.easy_close) {
            overlay.addEventListener("click", function (ev) {
                if (ev.target === overlay) closeModal();
            });
        }
        overlay.dataset.gEasyClose = msg.easy_close ? "1" : "0";

        overlay.appendChild(box);
        root.appendChild(overlay);
        refreshConditionals();
        /* a modal body can hold a plot too */
        observeMeasured();
    }

    document.addEventListener("keydown", function (ev) {
        if (ev.key !== "Escape") return;
        var open = document.getElementById("g-modal");
        if (open && open.dataset.gEasyClose === "1") closeModal();
    });

    /* ---------- progress ---------- */

    function progressContainer() {
        var el = document.getElementById("g-progress");
        if (!el) {
            el = document.createElement("div");
            el.id = "g-progress";
            el.className = "g-progress-stack";
            document.body.appendChild(el);
        }
        return el;
    }

    function applyProgress(msg) {
        if (msg.action === "hide") {
            var gone = document.getElementById(msg.id);
            if (gone) gone.remove();
            var stack = document.getElementById("g-progress");
            if (stack && stack.children.length === 0) stack.remove();
            return;
        }
        var bar = document.getElementById(msg.id);
        if (!bar) {
            bar = document.createElement("div");
            bar.id = msg.id;
            bar.className = "g-progress";
            bar.innerHTML =
                '<div class="g-progress-message"></div>' +
                '<div class="g-progress-track">' +
                '<div class="g-progress-fill"></div></div>' +
                '<div class="g-progress-detail"></div>';
            progressContainer().appendChild(bar);
        }
        bar.querySelector(".g-progress-message").textContent =
            msg.message || "";
        bar.querySelector(".g-progress-detail").textContent =
            msg.detail || "";
        bar.querySelector(".g-progress-fill").style.width =
            Math.round((msg.value || 0) * 100) + "%";
    }

    /* ---------- downloads ---------- */

    /* The page HTML is built once and served to every session, so
       nothing session-specific can be baked into an href at render
       time. A press asks for a ticket and navigates to it. */
    function startDownload(el) {
        if (!sessionId) return;
        requestTicket(el.dataset.gDownload, "download", function (ticket) {
            window.location.href =
                "/download?ticket=" + encodeURIComponent(ticket.token);
        });
    }

    /* ---------- disconnect overlay ---------- */

    function showDisconnected() {
        if (document.getElementById("g-disconnected")) return;
        var root = document.getElementById("glinty-root");
        if (root) root.classList.add("g-disconnected-root");

        var overlay = document.createElement("div");
        overlay.id = "g-disconnected";
        overlay.className = "g-disconnected-overlay";

        var box = document.createElement("div");
        box.className = "g-disconnected-box";

        var text = document.createElement("p");
        text.textContent = "Connection lost.";

        var btn = document.createElement("button");
        btn.className = "g-btn";
        btn.textContent = "Reload";
        btn.addEventListener("click", function () {
            location.reload();
        });

        box.appendChild(text);
        box.appendChild(btn);
        overlay.appendChild(box);
        document.body.appendChild(overlay);
    }

    /* ---------- reconnect with resume ---------- */

    var retries = 0;
    var MAX_RETRIES = 12;

    function showBanner() {
        if (document.getElementById("g-reconnect")) return;
        var banner = document.createElement("div");
        banner.id = "g-reconnect";
        banner.className = "g-reconnect-banner";
        banner.textContent = "Reconnecting…";
        document.body.appendChild(banner);
    }

    function hideBanner() {
        var banner = document.getElementById("g-reconnect");
        if (banner) banner.remove();
    }

    function handleClose() {
        if (refused) return; /* a refused session has nothing to resume */
        if (!sessionId) {
            /* never had a session: nothing to resume */
            showDisconnected();
            return;
        }
        if (retries >= MAX_RETRIES) {
            hideBanner();
            showDisconnected();
            return;
        }
        showBanner();
        var delay = Math.min(500 * Math.pow(2, retries), 5000);
        retries += 1;
        setTimeout(connect, delay);
    }

    /* ---------- boot ---------- */

    function connect() {
        var proto = location.protocol === "https:" ? "wss://" : "ws://";
        ws = new WebSocket(proto + location.host + "/ws");
        ws.addEventListener("open", function () {
            /* hello goes out directly, ahead of anything queued: it
               must be the first frame the server sees. It carries no
               input values -- the server seeded itself from the tree
               it built. */
            var hello = {
                type: "hello",
                protocol: PROTOCOL,
                client: CLIENT_ID,
                components: SUPPORTED_COMPONENTS,
                kinds: SUPPORTED_KINDS,
                features: SUPPORTED_FEATURES
            };
            /* The auth seam, browser side: an app script (loaded
               after glinty.js, before DOMContentLoaded) sets
               window.GLINTY_AUTH to the opaque token its login flow
               produced, and hello carries it. glinty never parses
               it. */
            if (typeof window.GLINTY_AUTH === "string" &&
                    window.GLINTY_AUTH) {
                hello.token = window.GLINTY_AUTH;
            }
            if (sessionId) {
                hello.resume = sessionId;
            } else if (prerendered) {
                hello.prerendered = prerendered;
            }
            awaitingWelcome = true;
            ws.send(JSON.stringify(hello));
        });
        ws.addEventListener("message", onMessage);
        ws.addEventListener("close", handleClose);
    }

    /* ---------- public API ---------- */

    /* The contract for app-supplied scripts. Loaded after this file,
       so window.Glinty is always defined when they run. */
    window.Glinty = {
        /* Set an input from JavaScript. Every call invalidates
           dependents, so there is no priority concept; opts is
           accepted and ignored so Shiny-shaped code ports as-is. */
        setInputValue: function (id, value, opts) {
            void opts;
            noteInput(id, value);
            send({ type: "input", id: id, value: value });
        },
        /* Register a handler for send_custom_message(). Registering
           the same name twice replaces the first handler. */
        addCustomMessageHandler: function (name, fn) {
            if (typeof fn !== "function") {
                console.error("glinty: handler for", name, "is not a function");
                return;
            }
            customHandlers[name] = fn;
        },
        /* Current session id, or null before the first welcome. */
        sessionId: function () {
            return sessionId;
        }
    };

    document.addEventListener("DOMContentLoaded", function () {
        var root = document.getElementById("glinty-root");
        if (!root) return;
        var meta = document.querySelector('meta[name="g-ui-revision"]');
        prerendered = meta ? meta.getAttribute("content") : null;
        bindEvents(root);
        /* Seed inputValues and settle conditional panels before the
           socket work starts, so the page never flashes content that
           its condition says to hide. Local only; nothing is sent. */
        harvestLocal();
        refreshConditionals();
        connect();
    });
})();
