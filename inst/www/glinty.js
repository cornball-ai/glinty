/* glinty client: WebSocket transport + DOM patching. No dependencies. */
(function () {
    "use strict";

    var ws = null;
    var sessionId = null;
    var debounceTimers = new Map();
    var DEBOUNCE_MS = 200;
    var customHandlers = {};
    var pending = [];
    var connectedFired = false;
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

    function harvestInputs() {
        var inputs = {};
        document.querySelectorAll("[data-g-target]").forEach(function (el) {
            if (el.dataset.gEvent === "click") {
                /* Clicks are events, not state -- except the open tab
                   of a tabset, which is state the server should know
                   from the start. */
                if (el.classList.contains("g-tab-active")) {
                    inputs[el.dataset.gTarget] = el.dataset.gValue;
                }
                return;
            }
            /* radios: one value per group, from the checked member */
            if (el.type === "radio" && !el.checked) return;
            inputs[el.dataset.gTarget] = extractValue(el);
        });
        Object.keys(inputs).forEach(function (id) {
            inputValues[id] = inputs[id];
        });
        measurePlots(function (id, dim, value) {
            inputs["..clientdata_output_" + id + "_" + dim] = value;
        });
        return inputs;
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
    }

    /* ---------- client-sized plots ---------- */

    var plotDims = {};

    function measurePlots(report) {
        document.querySelectorAll("img.g-plot-output").forEach(function (el) {
            if (!el.id) return;
            var w = Math.round(el.clientWidth);
            var h = Math.round(el.clientHeight);
            if (w < 1 || h < 1) return;
            var key = el.id + ":" + w + "x" + h;
            if (plotDims[el.id] === key) return;
            plotDims[el.id] = key;
            report(el.id, "width", w);
            report(el.id, "height", h);
        });
    }

    var resizeTimer = null;
    window.addEventListener("resize", function () {
        if (resizeTimer) clearTimeout(resizeTimer);
        resizeTimer = setTimeout(function () {
            measurePlots(function (id, dim, value) {
                send({
                    type: "input",
                    id: "..clientdata_output_" + id + "_" + dim,
                    value: value
                });
            });
        }, 250);
    });

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

    function bindEvents(root) {
        root.addEventListener("click", function (ev) {
            var el = ev.target.closest('[data-g-event="click"]');
            if (!el) return;
            /* A bind carrying a value is an event input (which item
               was clicked), not an action-button counter. */
            if (el.dataset.gValue !== undefined) {
                noteInput(el.dataset.gTarget, el.dataset.gValue);
                send({
                    type: "input",
                    id: el.dataset.gTarget,
                    value: el.dataset.gValue
                });
            } else {
                send({ type: "click", id: el.dataset.gTarget });
            }
        });

        root.addEventListener("click", function (ev) {
            var btn = ev.target.closest(".g-tab-btn");
            if (btn) activateTab(btn);
        });

        root.addEventListener("input", function (ev) {
            var el = ev.target;
            if (el.dataset.gEvent !== "input") return;
            if (el.type === "range") {
                var echo = document.getElementById(el.id + "_val");
                if (echo) echo.textContent = el.value;
            }
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

    /* ---------- file uploads (plain POST, not the WS) ---------- */

    function uploadFiles(el) {
        if (!sessionId || !el.files || el.files.length === 0) return;
        var fd = new FormData();
        Array.from(el.files).forEach(function (f) {
            fd.append("file", f, f.name);
        });
        el.disabled = true;
        fetch(
            "/upload?session=" + encodeURIComponent(sessionId) +
                "&id=" + encodeURIComponent(el.dataset.gUpload),
            { method: "POST", body: fd }
        ).then(function (resp) {
            if (!resp.ok) throw new Error("upload failed: " + resp.status);
            el.classList.remove("g-error");
        }).catch(function () {
            el.classList.add("g-error");
        }).finally(function () {
            el.disabled = false;
        });
    }

    /* ---------- incoming ---------- */

    function clearError(el) {
        el.classList.remove("g-error");
        el.removeAttribute("title");
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

    function buildTagNode(node) {
        if (node === null || node === undefined) return null;
        if (typeof node === "string") {
            return document.createTextNode(node);
        }
        var el = document.createElement(node.tag);
        var attrs = node.attrs || {};
        Object.keys(attrs).forEach(function (k) {
            el.setAttribute(k, attrs[k]);
        });
        if (node.bind) {
            el.setAttribute("data-g-event", node.bind.event);
            el.setAttribute("data-g-target", node.bind.target);
            if (node.bind.value !== null && node.bind.value !== undefined) {
                el.setAttribute("data-g-value", node.bind.value);
            }
        }
        if (node.text !== null && node.text !== undefined) {
            el.textContent = node.text;
        } else {
            (node.children || []).forEach(function (c) {
                var child = buildTagNode(c);
                if (child) el.appendChild(child);
            });
        }
        return el;
    }

    function applyUpdate(msg) {
        var el = document.getElementById(msg.id);
        if (!el) return;
        clearError(el);
        if (msg.property === "table") {
            buildTable(el, msg.value || {});
            return;
        }
        if (msg.property === "ui") {
            el.textContent = "";
            var node = buildTagNode(msg.value);
            if (node) el.appendChild(node);
            /* the new subtree may contain conditional panels that
               have never been evaluated */
            refreshConditionals();
            return;
        }
        el[msg.property] = msg.value;
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
            if (el !== document.activeElement) el.value = msg.selected;
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
                    if (el.type === "range") {
                        var echo = document.getElementById(el.id + "_val");
                        if (echo) echo.textContent = el.value;
                    }
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

    function onMessage(ev) {
        var msg;
        try {
            msg = JSON.parse(ev.data);
        } catch (e) {
            console.error("glinty: bad frame", ev.data);
            return;
        }
        switch (msg.type) {
        case "config":
            if (msg.resumed === false) {
                /* session expired server-side; our DOM is stale */
                location.reload();
                return;
            }
            sessionId = msg.session_id;
            retries = 0;
            hideBanner();
            flushPending();
            /* Once per page load, not once per socket: a successful
               resume keeps the DOM and the app's JS state, and a
               failed one reloads above. Re-firing would make apps
               double-register their listeners. */
            if (!connectedFired) {
                connectedFired = true;
                document.dispatchEvent(new CustomEvent("glinty:connected", {
                    detail: { sessionId: sessionId }
                }));
            }
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
        case "update":
            applyUpdate(msg);
            break;
        case "update_input":
            applyInputUpdate(msg);
            break;
        case "error":
            applyError(msg);
            break;
        default:
            console.warn("glinty: unknown message type", msg.type);
        }
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
            if (sessionId) {
                send({ type: "resume", session_id: sessionId });
            } else {
                send({ type: "init", inputs: harvestInputs() });
            }
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
        /* Current session id, or null before the first config. */
        sessionId: function () {
            return sessionId;
        }
    };

    document.addEventListener("DOMContentLoaded", function () {
        var root = document.getElementById("glinty-root");
        if (!root) return;
        bindEvents(root);
        /* Seed inputValues and settle conditional panels before the
           socket work starts, so the page never flashes content that
           its condition says to hide. */
        harvestInputs();
        refreshConditionals();
        connect();
    });
})();
