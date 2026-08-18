// The browser client's keyboard block, driven under node.
//
// This is the first component whose whole behaviour is client-side:
// R can assert what goes on the wire, and nothing in R can assert that
// pressing a key produces it. So the block is sliced out of the SHIPPED
// glinty.js -- not a copy -- and run against a DOM stub small enough to
// read, with `send` captured.
//
// Slicing rather than loading the whole file keeps the stub honest: the
// harness supplies exactly the two things the block reaches for, so
// anything else it starts reaching for fails here rather than being
// quietly satisfied by a stub that grew to meet it.
//
// Usage: node keyboard_client.js <path to glinty.js>
// Prints "ok <n>" and exits 0, or prints the failures and exits 1.

'use strict';
var fs = require('fs');

var src = fs.readFileSync(process.argv[2], 'utf8');
var from = src.indexOf('/* ---------- keyboard ---------- */');
var to = src.indexOf('/* ---------- event delegation ---------- */');
if (from < 0 || to < 0 || to <= from) {
  console.error('could not find the keyboard block in glinty.js');
  process.exit(1);
}
var block = src.slice(from, to);

// --- the DOM stub ---

var sent = [];
var keyHandler = null;
var activeElement = null;

// Fields registered with a data-g-clear-on declaration, for
// emitEventFrame's document-wide query. Everything the block reads
// off a field: its value, its target, its clear-on event.
var clearOnFields = [];

var document = {
  addEventListener: function (type, fn) {
    if (type === 'keydown') keyHandler = fn;
  },
  get activeElement() {
    return activeElement;
  },
  querySelectorAll: function (sel) {
    var m = /^\[data-g-clear-on="(.*)"\]$/.exec(sel);
    if (!m) return [];
    return clearOnFields.filter(function (el) {
      return el.dataset.gClearOn === m[1];
    });
  }
};

function send(frame) {
  sent.push(frame);
}

// The real sendInput lives outside the sliced block (it leans on
// extractValue and the whole binding zoo); for a text field it
// reduces to "report el.value under el's target", which is what the
// block's clear path needs and what this supplies.
var debounceTimers = new Map();
function sendInput(el) {
  sent.push({ type: 'input', id: el.dataset.gTarget, value: el.value });
}

// A shortcut element, as the lowering builds it: flags present mean
// true and absent means false, which is the contract the R side is
// asserted against.
function shortcutEl(spec) {
  var d = { gTarget: spec.id, gKey: spec.key };
  if (spec.value !== undefined) d.gValue = spec.value;
  if (spec.ctrl) d.gCtrl = '1';
  if (spec.shift) d.gShift = '1';
  if (spec.alt) d.gAlt = '1';
  if (spec.typing) d.gTyping = '1';
  if (spec.hold) d.gHold = '1';
  return { dataset: d };
}

var bound = [];
var root = {
  querySelectorAll: function (sel) {
    var m = /^\[data-g-key="(.*)"\]$/.exec(sel);
    if (!m) return [];
    return bound.filter(function (el) {
      return el.dataset.gKey === m[1];
    });
  }
};

// --- load the block ---

var load = new Function('document', 'send', 'sendInput', 'debounceTimers',
  block + '\nreturn {' +
  'bindKeys: bindKeys, keyToken: keyToken, isTyping: isTyping};');
var api = load(document, send, sendInput, debounceTimers);
api.bindKeys(root);

// --- assertions ---

var failures = [];
var checks = 0;
function eq(actual, expected, what) {
  checks++;
  var a = JSON.stringify(actual);
  var e = JSON.stringify(expected);
  if (a !== e) failures.push(what + ': expected ' + e + ', got ' + a);
}

var lastEvent = null;
function press(code, mods) {
  mods = mods || {};
  sent = [];
  lastEvent = {
    code: code,
    ctrlKey: !!mods.ctrl,
    metaKey: !!mods.meta,
    shiftKey: !!mods.shift,
    altKey: !!mods.alt,
    repeat: !!mods.repeat,
    prevented: false,
    preventDefault: function () { this.prevented = true; }
  };
  keyHandler(lastEvent);
  return sent;
}

// --- tokens: the physical key, not the character it would type ---
eq(api.keyToken({ code: 'KeyJ' }), 'j', 'letter');
eq(api.keyToken({ code: 'Digit4' }), '4', 'digit');
eq(api.keyToken({ code: 'F11' }), 'f11', 'function key');
eq(api.keyToken({ code: 'Space' }), 'space', 'space');
eq(api.keyToken({ code: 'ArrowLeft' }), 'left', 'arrow');
eq(api.keyToken({ code: 'BracketRight' }), 'bracketright', 'punctuation');
// Shift+1 is the "1" key, never "exclam": that is why code beats key.
eq(api.keyToken({ code: 'Digit1' }), '1', 'shifted digit is the digit');
// Keys no shortcut can name report nothing rather than guessing.
eq(api.keyToken({ code: 'ShiftLeft' }), null, 'a modifier alone');
eq(api.keyToken({ code: 'F13' }), null, 'a key outside the set');
eq(api.keyToken({}), null, 'an event with no code');

// --- a bare binding fires, and takes the keypress ---
bound = [shortcutEl({ id: 'play', key: 'space' })];
var out = press('Space');
eq(out, [{ type: 'event', id: 'play' }], 'bare key emits an event frame');

// A declared shortcut takes the keypress: bind ctrl+s and it saves the
// project rather than also offering to save the page.
eq(lastEvent.prevented, true, 'a match prevents the browser default');

// A key nothing binds is left entirely alone -- including its default,
// so binding "k" somewhere must not stop ctrl+f finding on the page.
eq(press('KeyQ'), [], 'unbound key sends nothing');
eq(lastEvent.prevented, false, 'an unbound key keeps its default');
press('Space', { ctrl: true });
eq(lastEvent.prevented, false,
  'a bound key with the wrong modifiers keeps its default');

// --- modifiers must match exactly, both ways ---
bound = [shortcutEl({ id: 'save', key: 's', ctrl: true })];
eq(press('KeyS', { ctrl: true }), [{ type: 'event', id: 'save' }],
  'ctrl+s fires');
eq(press('KeyS'), [], 'plain s does not fire a ctrl binding');
eq(press('KeyS', { ctrl: true, shift: true }), [],
  'ctrl+shift+s does not fire a ctrl binding');
// Cmd is Ctrl, as the R constructor promises.
eq(press('KeyS', { meta: true }), [{ type: 'event', id: 'save' }],
  'cmd+s fires a ctrl binding');

bound = [shortcutEl({ id: 'plain', key: 's' })];
eq(press('KeyS', { ctrl: true }), [],
  'a plain binding does not fire on ctrl+s');

// --- typing ---
bound = [
  shortcutEl({ id: 'del', key: 'd' }),
  shortcutEl({ id: 'esc', key: 'escape', typing: true })
];
activeElement = { tagName: 'INPUT', type: 'text' };
eq(api.isTyping(), true, 'a text input is typing');
eq(press('KeyD'), [], 'a bare letter waits while typing');
eq(press('Escape'), [{ type: 'event', id: 'esc' }],
  'typing:true still fires while typing');

activeElement = { tagName: 'TEXTAREA' };
eq(api.isTyping(), true, 'a textarea is typing');
eq(press('KeyD'), [], 'a bare letter waits in a textarea');

activeElement = { isContentEditable: true, tagName: 'DIV' };
eq(api.isTyping(), true, 'contenteditable is typing');

// Focusable controls that type nothing do not suppress shortcuts.
activeElement = { tagName: 'INPUT', type: 'checkbox' };
eq(api.isTyping(), false, 'a checkbox is not typing');
eq(press('KeyD'), [{ type: 'event', id: 'del' }],
  'a letter fires with a checkbox focused');
activeElement = { tagName: 'INPUT', type: 'range' };
eq(api.isTyping(), false, 'a slider is not typing');
activeElement = { tagName: 'BUTTON' };
eq(api.isTyping(), false, 'a button is not typing');
activeElement = null;
eq(api.isTyping(), false, 'nothing focused is not typing');

// --- autorepeat ---
bound = [
  shortcutEl({ id: 'play', key: 'space' }),
  shortcutEl({ id: 'nudge', key: 'left', value: '-1', hold: true })
];
eq(press('Space', { repeat: true }), [],
  'a held key does not repeat a binding that did not ask');
eq(press('ArrowLeft', { repeat: true }),
  [{ type: 'event', id: 'nudge', value: '-1' }],
  'hold:true repeats, and carries its value');
eq(press('ArrowLeft'), [{ type: 'event', id: 'nudge', value: '-1' }],
  'the first press fires too');

// --- two bindings on one key, told apart by their modifiers ---
bound = [
  shortcutEl({ id: 'zoom_in', key: 'equal', ctrl: true }),
  shortcutEl({ id: 'next', key: 'equal' })
];
eq(press('Equal', { ctrl: true }), [{ type: 'event', id: 'zoom_in' }],
  'the modified binding wins its own combination');
eq(press('Equal'), [{ type: 'event', id: 'next' }],
  'the bare binding wins its own');

// --- one key, two ids: both hear it, as two buttons sharing one id do ---
bound = [
  shortcutEl({ id: 'a', key: 'k' }),
  shortcutEl({ id: 'b', key: 'k' })
];
eq(press('KeyK'), [{ type: 'event', id: 'a' }, { type: 'event', id: 'b' }],
  'every matching binding fires');

// --- clear_on: the composer shape (#60) ---
// A live textarea declaring clear_on="send", enter bound to send with
// typing:true. The contract is the frame ORDER: the event goes out
// first, so the server handler reads the full draft, and the cleared
// "" follows it.
bound = [shortcutEl({ id: 'send', key: 'enter', typing: true })];
var composer = {
  value: 'hello world',
  dataset: { gTarget: 'draft', gClearOn: 'send' }
};
clearOnFields = [composer];
activeElement = { tagName: 'TEXTAREA' };

eq(press('Enter'),
  [{ type: 'event', id: 'send' }, { type: 'input', id: 'draft', value: '' }],
  'send clears the composer: event first, then the emptied report');
eq(composer.value, '', 'the field itself is emptied');

// Enter within the debounce window: the tail of the draft is still
// queued, so it flushes BEFORE the event -- the handler must read
// what the user saw when they pressed enter, not 200ms behind it.
composer.value = 'hello wor';
debounceTimers.set('draft', setTimeout(function () {}, 1000));
eq(press('Enter'),
  [{ type: 'input', id: 'draft', value: 'hello wor' },
   { type: 'event', id: 'send' },
   { type: 'input', id: 'draft', value: '' }],
  'a pending debounce flushes ahead of the event');
eq(debounceTimers.has('draft'), false, 'the flushed timer is gone');

// Only the named event clears: another shortcut leaves the draft be.
composer.value = 'kept';
bound = [shortcutEl({ id: 'other', key: 'escape', typing: true })];
eq(press('Escape'), [{ type: 'event', id: 'other' }],
  'an unrelated event does not touch a clear_on field');
eq(composer.value, 'kept', 'the draft survives unrelated events');
clearOnFields = [];
activeElement = null;

if (failures.length) {
  failures.forEach(function (f) { console.error('FAIL ' + f); });
  process.exit(1);
}
console.log('ok ' + checks);
