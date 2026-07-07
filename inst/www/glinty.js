/* glinty client: WebSocket transport + DOM patching. No dependencies. */
(function () {
    "use strict";

    var ws = null;
    var sessionId = null;
    var debounceTimers = new Map();
    var DEBOUNCE_MS = 200;

    /* ---------- value extraction ---------- */

    function extractValue(el) {
        if (el.type === "checkbox") return el.checked;
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
            if (el.dataset.gEvent === "click") return;
            inputs[el.dataset.gTarget] = extractValue(el);
        });
        return inputs;
    }

    /* ---------- outgoing ---------- */

    function send(msg) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(msg));
        }
    }

    function sendInput(el) {
        send({
            type: "input",
            id: el.dataset.gTarget,
            value: extractValue(el)
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
            if (el) send({ type: "click", id: el.dataset.gTarget });
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
            if (el.dataset.gEvent !== "change") return;
            sendInput(el);
        });
    }

    /* ---------- incoming ---------- */

    function clearError(el) {
        el.classList.remove("g-error");
        el.removeAttribute("title");
    }

    function applyUpdate(msg) {
        var el = document.getElementById(msg.id);
        if (!el) return;
        clearError(el);
        el[msg.property] = msg.value;
    }

    function applyInputUpdate(msg) {
        var el = document.getElementById(msg.id);
        if (!el) return;

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
            sessionId = msg.session_id;
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

    /* ---------- boot ---------- */

    function connect() {
        var proto = location.protocol === "https:" ? "wss://" : "ws://";
        ws = new WebSocket(proto + location.host + "/ws");
        ws.addEventListener("open", function () {
            send({ type: "init", inputs: harvestInputs() });
        });
        ws.addEventListener("message", onMessage);
        ws.addEventListener("close", showDisconnected);
        ws.addEventListener("error", showDisconnected);
    }

    document.addEventListener("DOMContentLoaded", function () {
        var root = document.getElementById("glinty-root");
        if (!root) return;
        bindEvents(root);
        connect();
    });
})();
