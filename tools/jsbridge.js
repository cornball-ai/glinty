/* Runtime checks of glinty.js without a browser.

   A hand-rolled mini-DOM (below) is stubbed into a fresh vm context
   per scenario, and the real client is driven through the protocol 3
   paths that matter: the hello/welcome bootstrap, all four hydration
   invariants, component rendering against the shared fixture file,
   and the transcript replays that the R and Dart suites also run.

   This is the browser half of the stage 2 gate: "one press is one
   frame across adoption" and "adoption emits nothing" can only be
   proven here, because only the browser adopts pre-rendered markup.

   Usage: node tools/jsbridge.js inst/www/glinty.js */

"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const CLIENT_PATH = process.argv[2] ||
    path.join(__dirname, "..", "inst", "www", "glinty.js");
const FIXTURES = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "inst", "fixtures", "components.json"),
    "utf8"));
const TRANSCRIPTS = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "inst", "fixtures", "transcripts.json"),
    "utf8"));
const CLIENT_SRC = fs.readFileSync(CLIENT_PATH, "utf8");

let failures = 0;
let current = "";
function section(name) {
    current = name;
    console.log(name);
}
function check(name, cond) {
    if (cond) {
        console.log("  ok   " + name);
    } else {
        failures++;
        console.log("  FAIL " + name);
    }
}

function transcript(name) {
    const hit = TRANSCRIPTS.transcripts.find((t) => t.name === name);
    if (!hit) throw new Error("no transcript named " + name);
    return hit;
}
function frames(t, dir) {
    return t.frames.filter((f) => f.dir === dir).map((f) => f.message);
}

/* ---------- mini-DOM ---------- */

function decamel(k) {
    return k.replace(/[A-Z]/g, (m) => "-" + m.toLowerCase());
}

function parseSelector(sel) {
    const spec = { tag: null, id: null, classes: [], attrs: [], pseudos: [] };
    let rest = sel.trim();
    const tagMatch = rest.match(/^[a-zA-Z][\w-]*/);
    if (tagMatch) {
        spec.tag = tagMatch[0].toUpperCase();
        rest = rest.slice(tagMatch[0].length);
    }
    const token = /^(#[\w-]+|\.[\w-]+|\[[^\]]+\]|:[\w-]+)/;
    while (rest.length) {
        const m = rest.match(token);
        if (!m) throw new Error("unsupported selector: " + sel);
        const t = m[0];
        if (t[0] === "#") spec.id = t.slice(1);
        else if (t[0] === ".") spec.classes.push(t.slice(1));
        else if (t[0] === ":") spec.pseudos.push(t.slice(1));
        else {
            const inner = t.slice(1, -1);
            const eq = inner.indexOf("=");
            if (eq === -1) spec.attrs.push({ name: inner });
            else {
                spec.attrs.push({
                    name: inner.slice(0, eq),
                    value: inner.slice(eq + 1).replace(/^"|"$/g, "")
                });
            }
        }
        rest = rest.slice(t.length);
    }
    return spec;
}

function matches(el, sel) {
    if (!el || !el.getAttribute) return false;
    const spec = typeof sel === "string" ? parseSelector(sel) : sel;
    if (spec.tag && el.tagName !== spec.tag) return false;
    if (spec.id && el.attrs.id !== spec.id) return false;
    for (const c of spec.classes) {
        if (!el.classList.contains(c)) return false;
    }
    for (const a of spec.attrs) {
        if (!(a.name in el.attrs)) return false;
        if (a.value !== undefined && String(el.attrs[a.name]) !== a.value) {
            return false;
        }
    }
    for (const p of spec.pseudos) {
        if (p === "checked") {
            if (!el.checked) return false;
        } else {
            throw new Error("unsupported pseudo: " + p);
        }
    }
    return true;
}

function walk(node, fn) {
    if (!node) return;
    for (const child of node.children || []) {
        if (child.getAttribute) {
            fn(child);
            walk(child, fn);
        }
    }
}

function makeTextNode(text) {
    return { nodeType: 3, textContent: text };
}

function makeEl(doc, tag) {
    const style = {
        props: {},
        setProperty(k, v) { this.props[k] = String(v); },
        getPropertyValue(k) { return this.props[k] || ""; }
    };
    const elx = {
        nodeType: 1,
        tagName: String(tag).toUpperCase(),
        attrs: {},
        children: [],
        parentNode: null,
        style,
        _listeners: {},
        ownerDocument: doc,

        setAttribute(k, v) { this.attrs[k] = String(v); },
        getAttribute(k) {
            return k in this.attrs ? this.attrs[k] : null;
        },
        hasAttribute(k) { return k in this.attrs; },
        removeAttribute(k) { delete this.attrs[k]; },

        appendChild(c) {
            if (c.parentNode) c.remove && c.remove();
            this.children.push(c);
            if (c.nodeType === 1) c.parentNode = this;
            return c;
        },
        insertBefore(c, ref) {
            if (c.parentNode) c.remove && c.remove();
            const i = ref ? this.children.indexOf(ref) : -1;
            if (i === -1) this.children.push(c);
            else this.children.splice(i, 0, c);
            if (c.nodeType === 1) c.parentNode = this;
            return c;
        },
        get nextSibling() {
            if (!this.parentNode) return null;
            const sib = this.parentNode.children;
            const i = sib.indexOf(this);
            return i >= 0 && i + 1 < sib.length ? sib[i + 1] : null;
        },
        remove() {
            if (!this.parentNode) return;
            const sib = this.parentNode.children;
            const i = sib.indexOf(this);
            if (i >= 0) sib.splice(i, 1);
            this.parentNode = null;
        },

        addEventListener(type, fn) {
            (this._listeners[type] = this._listeners[type] || []).push(fn);
        },

        querySelector(sel) {
            const spec = parseSelector(sel);
            let hit = null;
            walk(this, (n) => { if (!hit && matches(n, spec)) hit = n; });
            return hit;
        },
        querySelectorAll(sel) {
            const spec = parseSelector(sel);
            const hits = [];
            walk(this, (n) => { if (matches(n, spec)) hits.push(n); });
            return hits;
        },
        closest(sel) {
            const spec = parseSelector(sel);
            let n = this;
            while (n && n.getAttribute) {
                if (matches(n, spec)) return n;
                n = n.parentNode;
            }
            return null;
        },

        get id() { return this.attrs.id || ""; },
        set id(v) { this.attrs.id = String(v); },
        get className() { return this.attrs.class || ""; },
        set className(v) { this.attrs.class = String(v); },
        get type() { return this.attrs.type || ""; },
        set type(v) { this.attrs.type = String(v); },
        get name() { return this.attrs.name || ""; },
        set name(v) { this.attrs.name = String(v); },
        set htmlFor(v) { this.attrs.for = String(v); },

        get value() {
            if (this._value !== undefined) return this._value;
            return "value" in this.attrs ? this.attrs.value : "";
        },
        set value(v) { this._value = v; },
        /* src reflects the attribute, as it does on real media
           elements, so removeAttribute("src") is observable */
        get src() { return this.attrs.src || ""; },
        set src(v) { this.attrs.src = String(v); },
        get checked() {
            if (this._checked !== undefined) return this._checked;
            return "checked" in this.attrs;
        },
        set checked(v) { this._checked = !!v; },
        get selected() {
            if (this._selected !== undefined) return this._selected;
            return "selected" in this.attrs;
        },
        set selected(v) { this._selected = !!v; },
        get multiple() { return "multiple" in this.attrs; },
        get selectedOptions() {
            return this.children.filter(
                (c) => c.tagName === "OPTION" && c.selected);
        },

        get textContent() {
            return (this.children || [])
                .map((c) => c.textContent || "")
                .join("");
        },
        set textContent(v) {
            this.children = v === "" ? [] : [makeTextNode(String(v))];
        },
        get innerHTML() { return this._innerHTML || ""; },
        set innerHTML(v) {
            this._innerHTML = String(v);
            this.children = [];
        },

        clientWidth: 0,
        clientHeight: 0
    };
    elx.classList = {
        contains(c) {
            return (elx.attrs.class || "").split(/\s+/).includes(c);
        },
        add(c) {
            const cs = (elx.attrs.class || "").split(/\s+/).filter(Boolean);
            if (!cs.includes(c)) cs.push(c);
            elx.attrs.class = cs.join(" ");
        },
        remove(c) {
            elx.attrs.class = (elx.attrs.class || "").split(/\s+/)
                .filter((x) => x && x !== c).join(" ");
        },
        toggle(c, force) {
            const has = elx.classList.contains(c);
            const want = force === undefined ? !has : !!force;
            if (want) elx.classList.add(c);
            else elx.classList.remove(c);
        }
    };
    elx.dataset = new Proxy({}, {
        get(t, k) {
            if (typeof k !== "string") return undefined;
            const a = "data-" + decamel(k);
            return a in elx.attrs ? elx.attrs[a] : undefined;
        },
        set(t, k, v) {
            elx.attrs["data-" + decamel(k)] = String(v);
            return true;
        },
        has(t, k) { return ("data-" + decamel(k)) in elx.attrs; }
    });
    return elx;
}

function makeDocument() {
    const doc = {};
    const bag = {};
    doc.documentElement = makeEl(doc, "html");
    doc.head = makeEl(doc, "head");
    doc.body = makeEl(doc, "body");
    doc.documentElement.appendChild(doc.head);
    doc.documentElement.appendChild(doc.body);
    doc.activeElement = null;
    doc.dispatched = [];
    doc.createElement = (tag) => makeEl(doc, tag);
    doc.createElementNS = (ns, tag) => makeEl(doc, tag);
    doc.createTextNode = (t) => makeTextNode(t);
    doc.addEventListener = (type, fn) => {
        (bag[type] = bag[type] || []).push(fn);
    };
    doc.fire = (type, ev) => (bag[type] || []).forEach((fn) => fn(ev));
    doc.dispatchEvent = (ev) => doc.dispatched.push(ev);
    doc.getElementById = (id) => {
        let hit = null;
        walk(doc.documentElement, (n) => {
            if (!hit && n.attrs.id === id) hit = n;
        });
        return hit;
    };
    doc.querySelector = (sel) => doc.documentElement.querySelector(sel);
    doc.querySelectorAll = (sel) => doc.documentElement.querySelectorAll(sel);
    return doc;
}

/* ---------- a fresh page running the real client ---------- */

class FakeWebSocket {
    constructor(url, page) {
        this.url = url;
        this.readyState = 0;
        this._listeners = {};
        this.page = page;
        page.sockets.push(this);
    }
    addEventListener(type, fn) {
        (this._listeners[type] = this._listeners[type] || []).push(fn);
    }
    send(txt) { this.page.sent.push(JSON.parse(txt)); }
    open() {
        this.readyState = 1;
        (this._listeners.open || []).forEach((fn) => fn({}));
    }
    deliver(obj) {
        (this._listeners.message || []).forEach(
            (fn) => fn({ data: JSON.stringify(obj) }));
    }
    close() {
        this.readyState = 3;
        (this._listeners.close || []).forEach((fn) => fn({}));
    }
}
FakeWebSocket.OPEN = 1;

/* Boot glinty.js against a fresh document. setup(document, root) may
   populate the pre-rendered DOM; metaRevision writes the g-ui-revision
   meta tag the server would have embedded. */
function freshPage(opts) {
    const page = {
        sent: [],
        sockets: [],
        warnings: [],
        reloads: 0
    };
    const doc = makeDocument();
    page.document = doc;
    const root = makeEl(doc, "div");
    root.setAttribute("id", "glinty-root");
    doc.body.appendChild(root);
    page.root = root;

    if (opts && opts.metaRevision) {
        const meta = makeEl(doc, "meta");
        meta.setAttribute("name", "g-ui-revision");
        meta.setAttribute("content", opts.metaRevision);
        doc.head.appendChild(meta);
    }
    if (opts && opts.setup) opts.setup(doc, root);

    const sandbox = {
        console: {
            log: () => {},
            warn: (...a) => page.warnings.push(a.join(" ")),
            error: (...a) => page.warnings.push(a.join(" "))
        },
        setTimeout,
        clearTimeout,
        Map,
        Object,
        Array,
        String,
        Number,
        Boolean,
        JSON,
        Math,
        Proxy,
        WebSocket: function (url) { return new FakeWebSocket(url, page); },
        location: {
            protocol: "http:",
            host: "localhost:8099",
            reload() { page.reloads++; }
        },
        CustomEvent: class CustomEvent {
            constructor(type, init) {
                this.type = type;
                this.detail = (init || {}).detail;
            }
        },
        document: doc
    };
    sandbox.WebSocket.OPEN = 1;
    sandbox.window = sandbox;
    sandbox.window.addEventListener = () => {};
    if (opts && opts.dpr) sandbox.devicePixelRatio = opts.dpr;
    /* Off by default so every other scenario exercises the fallback
       (manual triggers); one scenario opts in to prove the wiring. */
    if (opts && opts.resizeObserver) {
        page.observers = [];
        sandbox.ResizeObserver = class ResizeObserver {
            constructor(cb) {
                this.cb = cb;
                this.targets = [];
                page.observers.push(this);
            }
            observe(el) {
                if (!this.targets.includes(el)) this.targets.push(el);
            }
            disconnect() { this.targets = []; }
        };
    }

    vm.createContext(sandbox);
    vm.runInContext(CLIENT_SRC, sandbox);

    page.sandbox = sandbox;
    page.G = sandbox.window.Glinty;
    doc.fire("DOMContentLoaded", {});
    page.ws = () => page.sockets[page.sockets.length - 1];

    page.fire = (type, target) => {
        (root._listeners[type] || []).forEach(
            (fn) => fn({ target, preventDefault() {} }));
    };
    page.frames = (type) => page.sent.filter((m) => m.type === type);
    return page;
}

/* The pre-rendered DOM a served counter-ish page would carry: the
   attribute contract here (data-g-target, data-g-message,
   data-g-event) is pinned on the R side by the lowering tests, so
   hand-building it does not drift from what the server emits. */
function prerenderDemo(doc, root) {
    const marker = makeEl(doc, "div");
    marker.setAttribute("id", "marker");
    root.appendChild(marker);

    const btn = makeEl(doc, "button");
    btn.setAttribute("id", "go");
    btn.setAttribute("type", "button");
    btn.setAttribute("class", "g-btn g-btn-primary");
    btn.setAttribute("data-g-target", "go");
    btn.setAttribute("data-g-message", "event");
    root.appendChild(btn);

    const input = makeEl(doc, "input");
    input.setAttribute("id", "name");
    input.setAttribute("type", "text");
    input.setAttribute("value", "");
    input.setAttribute("data-g-target", "name");
    input.setAttribute("data-g-message", "input");
    input.setAttribute("data-g-event", "input");
    root.appendChild(input);

    const out = makeEl(doc, "span");
    out.setAttribute("id", "greeting");
    out.setAttribute("data-g-output", "greeting");
    out.setAttribute("data-g-kind", "text");
    root.appendChild(out);

    const host = makeEl(doc, "div");
    host.setAttribute("id", "panel");
    host.setAttribute("data-g-output", "panel");
    host.setAttribute("data-g-kind", "ui");
    root.appendChild(host);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async function main() {

    /* ---------------------------------------------------------- */
    section("the opening frame");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const page = freshPage({ metaRevision: rev, setup: prerenderDemo });

        check("a socket was created", page.sockets.length === 1);
        page.ws().open();
        check("exactly one frame left on open", page.sent.length === 1);
        const hello = page.sent[0];
        check("and it is hello", hello.type === "hello");
        check("hello speaks protocol 3", hello.protocol === 3);
        check("hello names the client",
              typeof hello.client === "string" && hello.client.length > 0);
        check("hello declares components",
              Array.isArray(hello.components) &&
              hello.components.includes("page"));
        check("hello declares kinds and features",
              Array.isArray(hello.kinds) && Array.isArray(hello.features));
        check("hello carries the served revision", hello.prerendered === rev);
        check("hello carries NO input values -- the server seeded itself",
              !("inputs" in hello));
    }

    /* ---------------------------------------------------------- */
    section("invariant 2: adoption emits nothing");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const welcome = frames(hyd, "out")[0];
        const page = freshPage({ metaRevision: rev, setup: prerenderDemo });
        page.ws().open();

        page.ws().deliver(welcome);
        check("session id adopted", page.G.sessionId() === welcome.session);
        check("the pre-rendered DOM was kept, not rebuilt",
              page.document.getElementById("marker") !== null);
        check("nothing was sent beyond hello", page.sent.length === 1);
        check("glinty:connected fired once",
              page.document.dispatched.filter(
                  (e) => e.type === "glinty:connected").length === 1);
    }

    /* ---------------------------------------------------------- */
    section("invariant 1: one press is one frame, across adoption");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const welcome = frames(hyd, "out")[0];
        const evShape = frames(transcript("button-event"), "in")[0];
        const page = freshPage({ metaRevision: rev, setup: prerenderDemo });
        page.ws().open();
        page.ws().deliver(welcome);

        const btn = page.document.getElementById("go");
        page.fire("click", btn);
        check("one press, one event frame", page.frames("event").length === 1);
        check("shaped exactly as the transcript's event frame",
              JSON.stringify({ ...page.frames("event")[0], id: "go" }) ===
              JSON.stringify({ ...evShape, id: "go" }) &&
              page.frames("event")[0].id === "go");
        page.fire("click", btn);
        check("two presses, two frames", page.frames("event").length === 2);

        /* Cut the socket and let the real reconnect path run: the
           client resumes, the server welcomes with resumed=true, and
           the press after all that must still be exactly one frame.
           A duplicated handler would make it two. */
        page.ws().close();
        await sleep(650);
        check("a second socket reconnected", page.sockets.length === 2);
        page.ws().open();
        const resumeHello = page.sent[page.sent.length - 1];
        check("the reconnect hello carries resume",
              resumeHello.type === "hello" &&
              resumeHello.resume === welcome.session);
        page.ws().deliver({
            type: "welcome",
            session: welcome.session,
            protocol: 3,
            ui_revision: welcome.ui_revision,
            ui: welcome.ui,
            resumed: true
        });
        check("resume kept the DOM",
              page.document.getElementById("marker") !== null);
        check("resume did not re-fire glinty:connected",
              page.document.dispatched.filter(
                  (e) => e.type === "glinty:connected").length === 1);

        page.fire("click", btn);
        check("one press after resume is still one frame",
              page.frames("event").length === 3);
    }

    /* ---------------------------------------------------------- */
    section("invariant 3: a revision mismatch rebuilds");
    {
        const mis = transcript("revision-mismatch");
        const staleRev = frames(mis, "in")[0].prerendered;
        const welcome = frames(mis, "out")[0];
        const page = freshPage({ metaRevision: staleRev,
                                 setup: prerenderDemo });
        page.ws().open();
        page.ws().deliver(welcome);

        check("the stale markup was discarded",
              page.document.getElementById("marker") === null);
        const built = page.root.children[0];
        check("the root was rebuilt from welcome.ui",
              built && built.classList.contains("g-page"));
        check("the rebuilt tree is the transcript's tree",
              page.document.getElementById("name") !== null &&
              page.document.getElementById("greeting") !== null);
        const input = page.document.getElementById("name");
        check("rebuilt inputs carry their bindings",
              input.getAttribute("data-g-target") === "name" &&
              input.getAttribute("data-g-message") === "input");

        /* delegation lives on the root, so rebuilt nodes are live */
        input._value = "Troy";
        page.fire("change", input);
        /* text inputs report on their emit event; this one is
           emit=live in the tree, so change does nothing... */
        const inputFrames = page.frames("input");
        page.fire("input", input);
        await sleep(250); /* debounce */
        check("rebuilt inputs still report through delegation",
              page.frames("input").length === inputFrames.length + 1 &&
              page.frames("input").pop().value === "Troy");
    }

    /* ---------------------------------------------------------- */
    section("a document with no revision meta rebuilds too");
    {
        const hw = transcript("hello-welcome");
        const welcome = frames(hw, "out")[0];
        const page = freshPage({ setup: prerenderDemo });
        page.ws().open();
        check("hello omits prerendered when there is nothing to claim",
              !("prerendered" in page.sent[0]));
        page.ws().deliver(welcome);
        check("unverifiable markup is discarded",
              page.document.getElementById("marker") === null);
        check("and the tree comes from welcome",
              page.root.children[0] &&
              page.root.children[0].classList.contains("g-page"));
    }

    /* ---------------------------------------------------------- */
    section("invariant 4: a protocol mismatch is refused, visibly");
    {
        const pm = transcript("protocol-mismatch");
        const welcome = frames(pm, "out")[0];
        const page = freshPage({ metaRevision: "irrelevant",
                                 setup: prerenderDemo });
        page.ws().open();
        page.ws().deliver(welcome);

        const err = page.document.getElementById("g-protocol-error");
        check("the refusal is on screen", err !== null);
        check("it names both versions",
              err.textContent.includes("protocol 3") &&
              err.textContent.includes("protocol " + welcome.protocol));
        check("it says what to do", err.textContent.includes("Update the app"));
        check("the refused tree was not rendered",
              page.document.getElementById("name") === null);
        check("no session was adopted", page.G.sessionId() === null);

        const before = page.sent.length;
        page.ws().deliver({ type: "output", id: "panel",
                            kind: "text", value: "late" });
        check("messages after a refusal are ignored",
              page.document.getElementById("panel") === null &&
              page.sent.length === before);

        page.ws().close();
        await sleep(650);
        check("a refused session does not reconnect",
              page.sockets.length === 1);
        check("and does not stack a disconnect overlay",
              page.document.getElementById("g-disconnected") === null);
        check("and never reloads the page", page.reloads === 0);
    }

    /* ---------------------------------------------------------- */
    section("theme tokens live in the g-theme style block");
    {
        const hw = transcript("hello-welcome");
        const welcome = frames(hw, "out")[0];

        /* No served block (cached themeless page, themed server):
           the client creates one, right after the stylesheet link so
           app stylesheets that follow still win. */
        const page = freshPage({
            setup: (doc, root) => {
                prerenderDemo(doc, root);
                const link = makeEl(doc, "link");
                link.setAttribute("rel", "stylesheet");
                link.setAttribute("href", "/glinty/glinty.css");
                doc.head.appendChild(link);
                const appCss = makeEl(doc, "link");
                appCss.setAttribute("rel", "stylesheet");
                appCss.setAttribute("href", "/static/app.css");
                doc.head.appendChild(appCss);
            }
        });
        page.ws().open();
        page.ws().deliver(welcome);

        const node = page.document.getElementById("g-theme");
        check("the block exists and carries the tokens",
              node !== null &&
              node.textContent.includes(
                  "--g-primary:" + welcome.theme.colors.primary) &&
              node.textContent.includes(
                  "--g-space:" + welcome.theme.spacing + "px") &&
              node.textContent.includes(
                  "--g-font-mono:" + welcome.theme.font.mono));
        const head = page.document.head.children;
        check("it sits after glinty.css and before app stylesheets, so"
              + " app CSS keeps winning after connect",
              head.indexOf(node) >
                  head.findIndex((n) => String(n.getAttribute("href"))
                      .includes("glinty.css")) &&
              head.indexOf(node) <
                  head.findIndex((n) => String(n.getAttribute("href"))
                      .includes("app.css")));

        /* A served block is updated in place: same node, same
           position, fresh tokens -- the cascade never moves. */
        const served = freshPage({
            setup: (doc, root) => {
                prerenderDemo(doc, root);
                const style = makeEl(doc, "style");
                style.setAttribute("id", "g-theme");
                style.textContent = ":root{--g-primary:#stale}";
                doc.head.appendChild(style);
            }
        });
        served.ws().open();
        const before = served.document.getElementById("g-theme");
        served.ws().deliver(welcome);
        const after = served.document.getElementById("g-theme");
        check("a served block is rewritten in place",
              before === after &&
              after.textContent.includes("--g-primary:#2456d6") &&
              !after.textContent.includes("#stale"));

        /* A themeless welcome touches nothing. */
        const bare = freshPage({ setup: prerenderDemo });
        bare.ws().open();
        bare.ws().deliver({ type: "welcome", session: "s0", protocol: 3 });
        check("no theme, no block",
              bare.document.getElementById("g-theme") === null);

        /* Each token is held to the same rule app_theme() enforces:
           hex colors, one plain family name -- so a value the server
           admitted is a value this client writes, and vice versa. */
        const hostile = freshPage({ setup: prerenderDemo });
        hostile.ws().open();
        hostile.ws().deliver({
            type: "welcome", session: "sx", protocol: 3,
            theme: { colors: { primary: "red;}body{display:none",
                               danger: "#b3261e" },
                     font: { mono: "x;--g-primary:#ff0000",
                             body: "JetBrains Mono" },
                     spacing: 4 }
        });
        const hnode = hostile.document.getElementById("g-theme");
        check("values outside the shared server rule are refused",
              hnode !== null &&
              !hnode.textContent.includes("display:none") &&
              !hnode.textContent.includes("#ff0000") &&
              hnode.textContent.includes("--g-danger:#b3261e") &&
              hnode.textContent.includes("--g-font-body:JetBrains Mono"));
    }

    /* ---------------------------------------------------------- */
    section("unknown variants fall back, visibly in the console");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const page = freshPage({ metaRevision: rev, setup: prerenderDemo });
        page.ws().open();
        page.ws().deliver(frames(hyd, "out")[0]);

        const before = page.warnings.length;
        page.ws().deliver({
            type: "output", id: "panel", kind: "ui",
            value: { component: "text", value: "hi", variant: "sparkly" }
        });
        const host = page.document.getElementById("panel");
        check("an unknown text variant renders as the first listed",
              host.children[0].classList.contains("g-text") &&
              !host.children[0].className.includes("sparkly"));
        check("and warns rather than erroring",
              page.warnings.length === before + 1 &&
              page.warnings[before].includes("sparkly"));

        /* the same rule holds for every variant-bearing component,
           not just the class-mapped text ones */
        page.ws().deliver({
            type: "output", id: "panel", kind: "ui",
            value: { component: "button", id: "b1", label: "Go",
                     variant: "explosive" }
        });
        check("an unknown button variant falls back to default",
              host.children[0].classList.contains("g-btn-default") &&
              page.warnings.some((w) => w.includes("explosive")));
        page.ws().deliver({
            type: "output", id: "panel", kind: "ui",
            value: { component: "panel", variant: "drawer",
                     children: [] }
        });
        check("an unknown panel variant falls back to plain",
              host.children[0].classList.contains("g-panel-plain") &&
              page.warnings.some((w) => w.includes("drawer")));
    }

    /* ---------------------------------------------------------- */
    section("measure: logical pixels, dpr, dedup, and staleness");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const shape = frames(transcript("measure-then-image"), "in")[0];
        const page = freshPage({
            metaRevision: rev,
            dpr: 2,
            setup: (doc, root) => {
                prerenderDemo(doc, root);
                const img = makeEl(doc, "img");
                img.setAttribute("id", "scatter");
                img.setAttribute("class", "g-plot-output");
                img.setAttribute("data-g-output", "scatter");
                img.setAttribute("data-g-kind", "image");
                img.clientWidth = 640;
                img.clientHeight = 480;
                root.appendChild(img);
                /* a hidden plot: zero box, must never be reported */
                const ghost = makeEl(doc, "img");
                ghost.setAttribute("id", "ghost");
                ghost.setAttribute("class", "g-plot-output");
                root.appendChild(ghost);
            }
        });
        page.ws().open();
        page.ws().deliver(frames(hyd, "out")[0]);

        const measures = () => page.frames("measure");
        check("a visible plot reports one measure after adoption",
              measures().length === 1);
        check("shaped exactly as the transcript's measure frame",
              JSON.stringify(measures()[0]) === JSON.stringify(shape));
        check("dimensions are the logical box, dpr rides alongside",
              measures()[0].width === 640 && measures()[0].dpr === 2);
        check("a zero-size box is never reported",
              !measures().some((m) => m.id === "ghost"));

        /* Any input change schedules a re-measure pass (a panel may
           have toggled); unchanged dims must dedup to silence. */
        page.G.setInputValue("nudge", 1);
        await sleep(300);
        check("an unchanged box is not re-reported",
              measures().length === 1);

        /* ...but a real size change reports once. */
        page.document.getElementById("scatter").clientWidth = 800;
        page.G.setInputValue("nudge", 2);
        await sleep(300);
        check("a resized box reports the new size",
              measures().length === 2 &&
              measures()[1].width === 800 && measures()[1].dpr === 2);

        /* Dragging a window to a monitor with a different density
           changes dpr with the box unchanged; the raster is now
           wrong, so dpr belongs in the dedup key. */
        page.sandbox.devicePixelRatio = 1;
        page.G.setInputValue("nudge", 3);
        await sleep(300);
        check("a dpr change alone re-reports",
              measures().length === 3 && measures()[2].dpr === 1 &&
              measures()[2].width === 800);

        /* An image output answers in logical pixels; the client sets
           the display size from the value, never the raster. */
        page.ws().deliver(frames(transcript("measure-then-image"),
                                 "out")[0]);
        const img = page.document.getElementById("scatter");
        check("the image lands with its logical size",
              img.getAttribute("width") === "640" &&
              img.getAttribute("height") === "480" &&
              String(img.src).indexOf("data:image/png") === 0);

        /* Dynamic UI can deliver a plot that has never had a box. */
        page.ws().deliver({
            type: "output", id: "panel", kind: "ui",
            value: { component: "plot_output", id: "late_plot" }
        });
        const late = page.document.getElementById("late_plot");
        late.clientWidth = 320;
        late.clientHeight = 240;
        await sleep(300);
        check("a plot arriving via dynamic UI reports its box",
              measures().some((m) => m.id === "late_plot" &&
                  m.width === 320 && m.height === 240));

        /* An output kind this client cannot display is a version gap
           the user should see -- same rule as an unknown component.
           The notice is a sibling node, because slots are not all
           containers: an <img> shows no textContent, and plots are
           exactly where kinds will grow. */
        const gapFor = (id) => page.document.querySelector(
            '[data-g-kind-gap="' + id + '"]');
        page.ws().deliver({ type: "output", id: "greeting",
                            kind: "hologram", value: 1 });
        const slot = page.document.getElementById("greeting");
        check("an unknown output kind is visible and named, never silent",
              gapFor("greeting") !== null &&
              gapFor("greeting").textContent.includes(
                  "[unsupported output kind: hologram]") &&
              slot.classList.contains("g-unsupported"));

        page.ws().deliver({ type: "output", id: "scatter",
                            kind: "sculpture", value: 1 });
        const img2 = page.document.getElementById("scatter");
        check("the refusal is visible beside an img slot too",
              gapFor("scatter") !== null &&
              img2.getAttribute("src") === null && img2.src === "");

        /* A recognised value arriving later closes the gap. */
        page.ws().deliver(frames(transcript("measure-then-image"),
                                 "out")[0]);
        check("a recognised kind clears the notice and the marker",
              gapFor("scatter") === null &&
              !img2.classList.contains("g-unsupported") &&
              String(img2.src).indexOf("data:image/png") === 0);
        page.ws().deliver({ type: "output", id: "greeting",
                            kind: "text", value: "back" });
        check("text slots recover the same way",
              gapFor("greeting") === null &&
              slot.textContent === "back" &&
              !slot.classList.contains("g-unsupported"));

        /* Output ids are app-chosen text; one carrying quote or
           bracket characters must not break the gap machinery, which
           is why the notice is held by reference rather than found
           by selector. */
        const hostileId = 'x"]y[z';
        const hostile = makeEl(page.document, "span");
        hostile.setAttribute("id", hostileId);
        hostile.setAttribute("data-g-output", hostileId);
        page.root.appendChild(hostile);
        const gaps = () => page.document.querySelectorAll(".g-kind-gap");
        let threw = null;
        try {
            page.ws().deliver({ type: "output", id: hostileId,
                                kind: "hologram", value: 1 });
            page.ws().deliver({ type: "output", id: hostileId,
                                kind: "text", value: "fine" });
        } catch (e) {
            threw = e;
        }
        check("a hostile output id cannot break the gap machinery",
              threw === null && gaps().length === 0 &&
              hostile.textContent === "fine" &&
              !hostile.classList.contains("g-unsupported"));
    }

    /* ---------------------------------------------------------- */
    section("ResizeObserver watches what manual triggers cannot");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const page = freshPage({
            metaRevision: rev,
            dpr: 1,
            resizeObserver: true,
            setup: (doc, root) => {
                prerenderDemo(doc, root);
                const img = makeEl(doc, "img");
                img.setAttribute("id", "scatter");
                img.setAttribute("class", "g-plot-output");
                img.clientWidth = 640;
                img.clientHeight = 480;
                root.appendChild(img);
            }
        });
        page.ws().open();
        page.ws().deliver(frames(hyd, "out")[0]);

        const ro = page.observers[0];
        check("hydration puts the plot under observation",
              !!ro && ro.targets.some((t) => t.id === "scatter"));

        /* A sibling grew and squeezed the plot: no window resize, no
           glinty state change, only the observer fires. */
        page.document.getElementById("scatter").clientWidth = 500;
        ro.cb();
        await sleep(300);
        check("an observer callback alone re-measures",
              page.frames("measure").some((m) => m.width === 500));

        /* Dynamic UI re-establishes observation for new plots. */
        page.ws().deliver({
            type: "output", id: "panel", kind: "ui",
            value: { component: "plot_output", id: "late_plot" }
        });
        check("plots arriving later are observed too",
              ro.targets.some((t) => t.id === "late_plot"));

        /* A modal can carry a plot; closing it must not leave the
           observer holding the discarded tree. */
        page.ws().deliver({
            type: "modal", action: "show", title: "Plot",
            body: [{ component: "plot_output", id: "modal_plot" }],
            easy_close: false
        });
        check("a plot inside a modal is observed",
              ro.targets.some((t) => t.id === "modal_plot"));
        page.ws().deliver({ type: "modal", action: "hide" });
        check("closing the modal drops its plots from observation",
              !ro.targets.some((t) => t.id === "modal_plot") &&
              ro.targets.some((t) => t.id === "scatter"));
    }

    /* ---------------------------------------------------------- */
    section("an expired resume reloads for fresh markup");
    {
        const page = freshPage({ metaRevision: "whatever",
                                 setup: prerenderDemo });
        page.ws().open();
        page.ws().deliver({ type: "welcome", session: "s-new", protocol: 3,
                            resumed: false });
        check("resumed=false reloads", page.reloads === 1);
    }

    /* ---------------------------------------------------------- */
    section("every fixture renders through the runtime ui path");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        for (const f of FIXTURES.fixtures) {
            const page = freshPage({ metaRevision: rev,
                                     setup: prerenderDemo });
            page.ws().open();
            page.ws().deliver(frames(hyd, "out")[0]);
            let threw = null;
            try {
                page.ws().deliver({ type: "output", id: "panel",
                                    kind: "ui", value: f.component });
            } catch (e) {
                threw = e;
            }
            const host = page.document.getElementById("panel");
            check("renders fixture: " + f.name,
                  threw === null && host.children.length === 1);
        }
    }

    /* ---------------------------------------------------------- */
    section("renderer parity spot checks");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const page = freshPage({ metaRevision: rev, setup: prerenderDemo });
        page.ws().open();
        page.ws().deliver(frames(hyd, "out")[0]);
        const host = page.document.getElementById("panel");
        const build = (component) => {
            page.ws().deliver({ type: "output", id: "panel",
                                kind: "ui", value: component });
            return host.children[0];
        };
        const byName = (name) =>
            FIXTURES.fixtures.find((f) => f.name === name).component;

        let node = build(byName("text-input"));
        let ctl = node.querySelector("[data-g-target]");
        check("text_input binds target, message and event",
              ctl.getAttribute("data-g-target") !== null &&
              ctl.getAttribute("data-g-message") === "input" &&
              ctl.getAttribute("data-g-event") === "input");

        node = build(byName("password-input"));
        ctl = node.querySelector("[data-g-target]");
        check("password_input is a password box with an empty value",
              ctl.getAttribute("type") === "password" &&
              ctl.getAttribute("value") === "");

        node = build(byName("select-input"));
        ctl = node.querySelector("select");
        const fixture = byName("select-input");
        check("select_input renders one option per choice",
              ctl !== null &&
              ctl.children.length === fixture.choices.length);

        node = build(byName("button-primary"));
        check("button is an event emitter with its variant class",
              node.getAttribute("data-g-message") === "event" &&
              node.classList.contains("g-btn-primary") &&
              node.getAttribute("data-g-event") === null);

        node = build(byName("slider-input"));
        ctl = node.querySelector("[data-g-target]");
        check("slider carries its bounds and position",
              ctl.getAttribute("type") === "range" &&
              ctl.getAttribute("min") !== null &&
              ctl.getAttribute("value") !== null);

        node = build(byName("tabset"));
        check("tabset shows exactly one active tab",
              node.querySelectorAll(".g-tab-btn.g-tab-active").length === 1 &&
              node.querySelectorAll(".g-tab-body").length ===
                  node.querySelectorAll(".g-tab-btn").length);
        const tabBtn = node.querySelector(".g-tab-btn");
        check("tab buttons are input emitters carrying their panel",
              tabBtn.getAttribute("data-g-message") === "input" &&
              tabBtn.getAttribute("data-g-value") !== null);

        node = build(byName("conditional-panel"));
        let cond = null;
        try { cond = JSON.parse(node.getAttribute("data-g-cond")); }
        catch (e) { cond = null; }
        check("conditional_panel carries a parseable condition",
              cond !== null && typeof cond.op === "string");

        node = build(byName("raw_html"));
        check("raw_html lands as trusted markup",
              node.innerHTML === byName("raw_html").html);

        node = build(byName("text-output"));
        check("outputs are slots naming their id and kind",
              node.getAttribute("data-g-output") !== null &&
              node.getAttribute("data-g-kind") === "text");

        node = build(byName("plot-output-responsive"));
        check("a dimensionless plot fills its container",
              String(node.getAttribute("style")).includes("aspect-ratio"));

        node = build({ component: "holo_deck", id: "h1" });
        check("an unknown component is visible and named, never silent",
              node.classList.contains("g-unsupported") &&
              node.getAttribute("data-g-component") === "holo_deck" &&
              node.textContent.includes("holo_deck"));
    }

    /* ---------------------------------------------------------- */
    section("dynamic UI inside a live page (the stage 1 regression)");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const page = freshPage({ metaRevision: rev, setup: prerenderDemo });
        page.ws().open();
        page.ws().deliver(frames(hyd, "out")[0]);

        /* render_ui() sends a component tree; before stage 2 the
           client only knew the retired tag-tree format and built
           nothing from it. */
        page.ws().deliver({
            type: "output", id: "panel", kind: "ui",
            value: {
                component: "column",
                children: [
                    { component: "heading", value: "Details", level: 4 },
                    { component: "text_input", id: "extra",
                      label: "Extra:", value: "", emit: "live" },
                    { component: "button", id: "go2", label: "Run",
                      variant: "primary" }
                ]
            }
        });
        const host = page.document.getElementById("panel");
        check("the subtree was built",
              host.children.length === 1 &&
              host.children[0].classList.contains("g-layout-col"));
        check("its input is bound",
              page.document.getElementById("extra")
                  .getAttribute("data-g-target") === "extra");
        page.fire("click", page.document.getElementById("go2"));
        check("its button reports through root delegation",
              page.frames("event").some((m) => m.id === "go2"));
    }

    /* ---------------------------------------------------------- */
    section("modal bodies are components too");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const page = freshPage({ metaRevision: rev, setup: prerenderDemo });
        page.ws().open();
        page.ws().deliver(frames(hyd, "out")[0]);

        page.ws().deliver({
            type: "modal", action: "show", title: "Confirm",
            body: [{ component: "text", value: "Proceed?",
                     variant: "normal" }],
            footer: { component: "button", id: "confirm", label: "Yes",
                      variant: "danger" },
            easy_close: false
        });
        const modal = page.document.getElementById("g-modal");
        check("the modal mounted inside the root",
              modal !== null && modal.closest("#glinty-root") !== null);
        check("its body rendered as components",
              modal.textContent.includes("Proceed?"));
        page.fire("click", page.document.getElementById("confirm"));
        check("its button reaches the server as an event",
              page.frames("event").some((m) => m.id === "confirm"));
    }

    /* ---------------------------------------------------------- */
    section("transfer tickets replace session ids in URLs");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const grantShape = frames(transcript("ticket-grant"), "out")[0];
        const page = freshPage({ metaRevision: rev, setup: prerenderDemo });
        page.sandbox.fetch = (url) => {
            page.fetches = page.fetches || [];
            page.fetches.push(String(url));
            return Promise.resolve({ ok: true });
        };
        page.sandbox.FormData = class FormData { append() {} };
        page.ws().open();
        page.ws().deliver(frames(hyd, "out")[0]);

        /* downloads: a press asks for a ticket, not an event */
        page.ws().deliver({
            type: "output", id: "panel", kind: "ui",
            value: { component: "download_button", id: "report",
                     label: "Save" }
        });
        const dl = page.document.getElementById("report");
        check("download buttons carry their download id",
              dl.getAttribute("data-g-download") === "report");
        const eventsBefore = page.frames("event").length;
        page.fire("click", dl);
        const reqs = page.frames("ticket");
        check("a press requests a download ticket, and only that",
              reqs.length === 1 &&
              reqs[0].purpose === "download" && reqs[0].id === "report" &&
              page.frames("event").length === eventsBefore);
        page.ws().deliver({ type: "ticket", id: "report",
                            purpose: "download",
                            token: grantShape.token, expires: 30 });
        check("the grant becomes the navigation target",
              String(page.sandbox.location.href)
                  .includes("/download?ticket=" + grantShape.token));
        check("and no session id appears in the URL",
              !String(page.sandbox.location.href).includes("session"));

        /* uploads: the POST goes to the ticket, nothing else */
        page.ws().deliver({
            type: "output", id: "panel", kind: "ui",
            value: { component: "file_input", id: "dataset",
                     label: "CSV:" }
        });
        const up = page.document.getElementById("dataset");
        up.files = [{ name: "a.bin" }];
        page.fire("change", up);
        const upReq = page.frames("ticket").filter(
            (m) => m.purpose === "upload");
        check("a chosen file requests an upload ticket",
              upReq.length === 1 && upReq[0].id === "dataset");
        page.ws().deliver({ type: "ticket", id: "dataset",
                            purpose: "upload", token: "tk_up1",
                            expires: 30 });
        check("the POST goes to the ticket URL",
              (page.fetches || []).some((u) =>
                  u.includes("/upload?ticket=tk_up1") &&
                  !u.includes("session")));
    }

    /* ---------------------------------------------------------- */
    section("authentication: token out, refusal visible");
    {
        const withToken = freshPage({ setup: prerenderDemo });
        withToken.sandbox.GLINTY_AUTH = "eyJhb.example.token";
        /* GLINTY_AUTH is read at connect; boot again via a manual
           reconnect path: close before any session, then... simplest
           honest check is a fresh page whose sandbox carries the
           token before DOMContentLoaded -- but freshPage already
           fired it. So fire open on the socket it made: hello was
           built at open time, after the token existed. */
        withToken.ws().open();
        check("hello carries the app-provided token",
              withToken.sent[0].token === "eyJhb.example.token");

        const bare = freshPage({ setup: prerenderDemo });
        bare.ws().open();
        check("no token, no field", !("token" in bare.sent[0]));

        /* a refused connection says so on screen and goes quiet --
           replayed from the shared transcript, same as Dart */
        bare.ws().deliver(frames(transcript("hello-refused"), "out")[0]);
        const box = bare.document.getElementById("g-protocol-error");
        check("the refusal is visible",
              box !== null &&
              box.textContent.includes("Connection refused") &&
              box.textContent.includes("authentication failed"));
        bare.ws().deliver(frames(transcript("hello-welcome"), "out")[0]);
        check("nothing after the refusal is processed",
              bare.G.sessionId() === null);
        bare.ws().close();
        await sleep(650);
        check("a refused connection does not reconnect",
              bare.sockets.length === 1);

        /* The token that worked an hour ago has expired. A client
           keying "is this a refusal?" on having never connected would
           read this as an ordinary error and retry forever. */
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const live = freshPage({ metaRevision: rev, setup: prerenderDemo });
        live.ws().open();
        live.ws().deliver(frames(hyd, "out")[0]);
        check("a normal session is not refused", live.G.sessionId() !== null);
        /* an output error mid-session is NOT a refusal */
        live.ws().deliver({ type: "error", id: "greeting",
                            message: "render failed" });
        check("an output error after welcome is an output error",
              live.document.getElementById("g-protocol-error") === null);

        live.ws().close();
        await sleep(650);
        check("it reconnected", live.sockets.length === 2);
        live.ws().open();
        live.ws().deliver(frames(transcript("hello-refused"), "out")[0]);
        const box2 = live.document.getElementById("g-protocol-error");
        check("a refusal on reconnect is visible",
              box2 !== null &&
              box2.textContent.includes("Connection refused"));
        live.ws().close();
        await sleep(900);
        check("and it stops retrying", live.sockets.length === 2);
    }

    /* ---------------------------------------------------------- */
    section("a refused ticket gives the control back");
    {
        const hyd = transcript("hello-welcome-hydrated");
        const rev = frames(hyd, "in")[0].prerendered;
        const page = freshPage({ metaRevision: rev, setup: prerenderDemo });
        page.sandbox.FormData = class FormData { append() {} };
        page.ws().open();
        page.ws().deliver(frames(hyd, "out")[0]);

        page.ws().deliver({
            type: "output", id: "panel", kind: "ui",
            value: { component: "file_input", id: "dataset", label: "CSV:" }
        });
        const up = page.document.getElementById("dataset");
        up.files = [{ name: "a.bin" }];
        page.fire("change", up);
        check("the control is disabled while it waits", up.disabled === true);

        /* the server is at its live-ticket cap and says so */
        page.ws().deliver({ type: "error", id: "dataset",
                            message: "too many pending transfers" });
        check("a refused grant re-enables the control rather than "
              + "leaving it dead", up.disabled === false);
    }

    /* ---------------------------------------------------------- */
    section("public surface");
    {
        const page = freshPage({ setup: prerenderDemo });
        const G = page.G;
        check("window.Glinty is defined", typeof G === "object" && G !== null);
        check("sessionId is null before welcome", G.sessionId() === null);

        /* App JS firing before the socket is open must not be
           dropped, and must not jump ahead of hello. */
        G.setInputValue("early", "value-1");
        check("nothing sent while closed", page.sent.length === 0);
        page.ws().open();
        check("hello still goes first", page.sent[0].type === "hello");
        page.ws().deliver({ type: "welcome", session: "s1", protocol: 3 });
        const early = page.sent.find((m) => m.id === "early");
        check("queued input flushed after welcome",
              !!early && early.value === "value-1");
        check("sessionId now readable", G.sessionId() === "s1");

        let got = null;
        G.addCustomMessageHandler("set_mode", (v) => { got = v; });
        page.ws().deliver({ type: "custom", handler: "set_mode",
                            value: { n: 3 } });
        check("custom handler received an object", got && got.n === 3);
        const before = page.warnings.length;
        page.ws().deliver({ type: "custom", handler: "never_registered",
                            value: 1 });
        check("unknown handler warns instead of throwing",
              page.warnings.length === before + 1);
        let poisoned = false;
        try {
            page.ws().deliver({ type: "custom", handler: "toString",
                                value: 1 });
        } catch (e) { poisoned = true; }
        check("inherited property is not treated as a handler", !poisoned);

        G.setInputValue("evt", "x", { priority: "event" });
        check("opts argument is accepted and ignored",
              page.sent.filter((m) => m.id === "evt").length === 1);
    }

    console.log("");
    if (failures > 0) {
        console.log(failures + " check(s) FAILED");
        process.exit(1);
    }
    console.log("all checks passed");
})().catch((e) => {
    console.error("jsbridge crashed in section: " + current);
    console.error(e);
    process.exit(1);
});
