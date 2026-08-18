// The tree-swap draft guard (#79), driven under node.
//
// captureFocusedDraft/restoreFocusedDraft are how the browser spares
// the focused field's draft when a ui frame (or a replacing modal)
// rebuilds the subtree around it. Sliced out of the SHIPPED glinty.js
// -- not a copy -- and run against element stubs small enough to
// read; the pair touches only activeElement, contains, querySelector
// and the field's own value/selection/focus surface.
//
// Usage: node swap_client.js <path to glinty.js>
// Prints "ok <n>" and exits 0, or prints the failures and exits 1.

'use strict';
var fs = require('fs');

var src = fs.readFileSync(process.argv[2], 'utf8');
var from = src.indexOf(
  '/* The never-stomp contract extends to tree swaps (#79).');
var to = src.indexOf('/* Apply an output message');
if (from < 0 || to < 0 || to <= from) {
  console.error('could not find the swap-draft block in glinty.js');
  process.exit(1);
}
var block = src.slice(from, to);

var activeElement = null;
var documentStub = {
  get activeElement() {
    return activeElement;
  }
};

var load = new Function('document',
  block + '\nreturn { capture: captureFocusedDraft,' +
  ' restore: restoreFocusedDraft };');
var api = load(documentStub);

var failures = [];
var checks = 0;
function eq(actual, expected, what) {
  checks++;
  var a = JSON.stringify(actual);
  var e = JSON.stringify(expected);
  if (a !== e) failures.push(what + ': expected ' + e + ', got ' + a);
}

function field(tag, target, value, opts) {
  opts = opts || {};
  var el = {
    tagName: tag,
    type: opts.type,
    dataset: target === null ? {} : { gTarget: target },
    value: value,
    selectionStart: 'start' in opts ? opts.start : value.length,
    selectionEnd: 'end' in opts ? opts.end : value.length,
    calls: [],
    focus: function () { el.calls.push('focus'); },
    setSelectionRange: function (s, e) {
      el.calls.push('select:' + s + ':' + e);
    }
  };
  return el;
}

function container(fields) {
  return {
    contains: function (el) { return fields.indexOf(el) !== -1; },
    querySelector: function (sel) {
      var m = /^\[data-g-target="(.*)"\]$/.exec(sel);
      if (!m) return null;
      for (var i = 0; i < fields.length; i++) {
        if (fields[i].dataset.gTarget === m[1]) return fields[i];
      }
      return null;
    }
  };
}

// --- capture: the focused text-ish field inside the container ---

var ta = field('TEXTAREA', 'draft', 'half a thought', { start: 4, end: 4 });
var old = container([ta]);
activeElement = ta;
eq(api.capture(old),
   { target: 'draft', value: 'half a thought', start: 4, end: 4 },
   'a focused textarea is captured with value and caret');

activeElement = null;
eq(api.capture(old), null, 'nothing focused, nothing captured');

var outside = field('TEXTAREA', 'other', 'elsewhere');
activeElement = outside;
eq(api.capture(old), null, 'focus outside the container is not its draft');

var unbound = field('TEXTAREA', null, 'loose');
activeElement = unbound;
eq(api.capture(container([unbound])), null,
   'an element with no target id has no store entry to guard');

var check = field('INPUT', 'save', 'on', { type: 'checkbox' });
activeElement = check;
eq(api.capture(container([check])), null,
   'a checkbox holds click-state, not a draft');

var pw = field('INPUT', 'secret', 'hunter2', { type: 'password' });
activeElement = pw;
eq(api.capture(container([pw])) !== null, true,
   'a password field is a draft like any other text field');

// --- restore: into the rebuilt subtree ---

var rebuilt = field('TEXTAREA', 'draft', 'declared');
var neu = container([rebuilt]);
api.restore(neu, { target: 'draft', value: 'half a thought',
                   start: 4, end: 4 });
eq(rebuilt.value, 'half a thought', 'the draft replaces the declared value');
eq(rebuilt.calls, ['select:4:4', 'focus'],
   'caret restored, then focus, in that order');

var without = container([field('TEXTAREA', 'other', 'x')]);
api.restore(without, { target: 'draft', value: 'gone', start: 0, end: 0 });
eq(true, true, 'a tree without the field restores nothing and throws nothing');

// a date input reports a null selection; value and focus still land
var dateEl = field('INPUT', 'when', '', { type: 'date', start: null,
                                          end: null });
activeElement = dateEl;
var kept = api.capture(container([dateEl]));
eq(kept.start, null, 'a date field captures without a caret');
var dateNew = field('INPUT', 'when', '', { type: 'date', start: null,
                                           end: null });
api.restore(container([dateNew]), kept);
eq(dateNew.calls, ['focus'], 'restore skips the caret it never had');

api.restore(neu, null);
eq(true, true, 'restore(null) is the no-capture no-op');

if (failures.length) {
  failures.forEach(function (f) { console.error('FAIL ' + f); });
  process.exit(1);
}
console.log('ok ' + checks);
