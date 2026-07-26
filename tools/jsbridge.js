/* Runtime check of glinty.js's public bridge without a browser.
   Stubs just enough DOM/WebSocket for the client to boot, then
   drives it through the message paths apps depend on. */

const fs = require("fs");
const vm = require("vm");

let failures = 0;
function check(name, cond) {
    if (cond) {
        console.log("  ok   " + name);
    } else {
        failures++;
        console.log("  FAIL " + name);
    }
}

const sent = [];
const warnings = [];
const dispatched = [];
let sockets = [];

function makeListenerBag() {
    const bag = {};
    return {
        addEventListener(type, fn) {
            (bag[type] = bag[type] || []).push(fn);
        },
        fire(type, ev) {
            (bag[type] || []).forEach((fn) => fn(ev));
        },
        count(type) {
            return (bag[type] || []).length;
        }
    };
}

class FakeWebSocket {
    constructor(url) {
        this.url = url;
        this.readyState = 0; /* CONNECTING */
        this.bag = makeListenerBag();
        this.addEventListener = this.bag.addEventListener;
        sockets.push(this);
    }
    send(txt) {
        sent.push(JSON.parse(txt));
    }
    open() {
        this.readyState = 1;
        this.bag.fire("open", {});
    }
    deliver(obj) {
        this.bag.fire("message", { data: JSON.stringify(obj) });
    }
}
FakeWebSocket.OPEN = 1;

const emptyNodeList = { forEach() {} };
const docBag = makeListenerBag();

/* Element stub that records tag name and namespace, so we can assert
   how the client built a subtree. */
function makeEl(tag, ns) {
    return {
        tagName: tag,
        namespaceURI: ns,
        attrs: {},
        children: [],
        style: {},
        dataset: {},
        classList: { add() {}, remove() {}, toggle() {}, contains: () => false },
        setAttribute(k, v) { this.attrs[k] = v; },
        removeAttribute(k) { delete this.attrs[k]; },
        getAttribute(k) { return this.attrs[k]; },
        appendChild(c) { this.children.push(c); return c; },
        remove() {},
        querySelector: () => null,
        querySelectorAll: () => emptyNodeList,
        addEventListener() {},
        set textContent(v) { this._text = v; this.children = []; },
        get textContent() { return this._text; }
    };
}

/* The one element applyUpdate() will look up by id. */
const uiHost = makeEl("div", null);
uiHost.id = "panel";

const root = makeListenerBag();

const sandbox = {
    console: {
        log: () => {},
        warn: (...a) => warnings.push(a.join(" ")),
        error: (...a) => warnings.push(a.join(" "))
    },
    setTimeout,
    clearTimeout,
    Map,
    Object,
    Array,
    JSON,
    Math,
    WebSocket: FakeWebSocket,
    location: { protocol: "http:", host: "localhost:8099", reload() {} },
    CustomEvent: class CustomEvent {
        constructor(type, init) {
            this.type = type;
            this.detail = (init || {}).detail;
        }
    },
    document: {
        addEventListener: docBag.addEventListener,
        dispatchEvent(ev) {
            dispatched.push(ev);
        },
        getElementById(id) {
            if (id === "glinty-root") return root;
            if (id === "panel") return uiHost;
            return null;
        },
        querySelectorAll: () => emptyNodeList,
        querySelector: () => null,
        createElement: (tag) => makeEl(tag, null),
        createElementNS: (ns, tag) => makeEl(tag, ns),
        createTextNode: (t) => ({ text: t, children: [] }),
        body: { appendChild() {} },
        activeElement: null
    }
};
sandbox.window = sandbox;
sandbox.window.addEventListener = () => {};

vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), sandbox);

const G = sandbox.window.Glinty;

console.log("public surface");
check("window.Glinty is defined", typeof G === "object" && G !== null);
check("setInputValue is a function", typeof G.setInputValue === "function");
check("addCustomMessageHandler is a function",
      typeof G.addCustomMessageHandler === "function");
check("sessionId is a function", typeof G.sessionId === "function");
check("sessionId is null before connect", G.sessionId() === null);

console.log("queueing before the socket opens");
/* App JS firing before the socket is open must not be dropped. */
G.setInputValue("early", "value-1");
check("nothing sent while closed", sent.length === 0);

docBag.fire("DOMContentLoaded", {});
check("a socket was created", sockets.length === 1);
const ws = sockets[0];
ws.open();
check("init frame sent on open", sent.length >= 1 && sent[0].type === "init");

ws.deliver({ type: "config", session_id: "sess-1", protocol: 2 });
const early = sent.find((m) => m.id === "early");
check("queued input flushed after config", !!early);
check("queued input kept its value", early && early.value === "value-1");
check("sessionId now readable", G.sessionId() === "sess-1");

console.log("glinty:connected");
check("connected fired once", dispatched.length === 1);
check("connected has the right type",
      dispatched[0] && dispatched[0].type === "glinty:connected");
check("connected carries the session id",
      dispatched[0] && dispatched[0].detail.sessionId === "sess-1");
/* A resume delivers a second config; re-firing would make apps
   double-register their listeners. */
ws.deliver({ type: "config", session_id: "sess-1", resumed: true });
check("connected does NOT re-fire on resume", dispatched.length === 1);

console.log("custom messages");
let got = null;
G.addCustomMessageHandler("set_mode", (v) => {
    got = v;
});
ws.deliver({ type: "custom", handler: "set_mode", value: true });
check("handler received the value", got === true);
ws.deliver({ type: "custom", handler: "set_mode", value: { n: 3 } });
check("handler received an object", got && got.n === 3);

const before = warnings.length;
ws.deliver({ type: "custom", handler: "never_registered", value: 1 });
check("unknown handler warns instead of throwing",
      warnings.length === before + 1);

/* Handler names must not resolve through Object.prototype. */
let poisoned = false;
try {
    ws.deliver({ type: "custom", handler: "toString", value: 1 });
} catch (e) {
    poisoned = true;
}
check("inherited property is not treated as a handler", !poisoned);

G.addCustomMessageHandler("bad", "not a function");
ws.deliver({ type: "custom", handler: "bad", value: 1 });
check("non-function handler is rejected, not invoked", true);

console.log("setInputValue after connect");
sent.length = 0;
G.setInputValue("later", 42);
check("sent immediately once open", sent.length === 1);
check("shaped as an input frame",
      sent[0].type === "input" && sent[0].id === "later" &&
      sent[0].value === 42);
G.setInputValue("evt", "x", { priority: "event" });
check("opts argument is accepted and ignored", sent.length === 2);

console.log("SVG namespace in dynamic UI");
/* An inline icon sent through render_ui(). createElement() would build
   an HTMLUnknownElement that never renders. */
ws.deliver({
    type: "update",
    id: "panel",
    property: "ui",
    value: {
        tag: "button",
        attrs: { class: "icon-btn" },
        children: [{
            tag: "svg",
            attrs: { viewBox: "0 0 24 24" },
            children: [{ tag: "path", attrs: { d: "M8 5l11 7-11 7z" } }]
        }]
    }
});
const built = uiHost.children[0];
check("subtree was built", !!built);
check("outer button is plain HTML", built && built.namespaceURI === null);
const svg = built && built.children[0];
check("svg element exists", !!svg && svg.tagName === "svg");
check("svg is in the SVG namespace",
      svg && svg.namespaceURI === "http://www.w3.org/2000/svg");
const path = svg && svg.children[0];
check("child path inherits the namespace",
      path && path.namespaceURI === "http://www.w3.org/2000/svg");
check("path kept its attributes", path && path.attrs.d === "M8 5l11 7-11 7z");

console.log("");
if (failures > 0) {
    console.log(failures + " check(s) FAILED");
    process.exit(1);
}
console.log("all checks passed");
