// The browser builder's binding attributes, driven under node.
//
// bindAttrs is the JS mirror of R's html_bind: the same component must
// get the same data-g-* binding whether the server lowered it to HTML
// or the client built it from a `ui` frame. test_lowerings.R asserts
// the static half; nothing in R can assert the dynamic half, so the
// function is sliced out of the SHIPPED glinty.js -- not a copy -- and
// called directly. It is pure, so no DOM stub is needed.
//
// This exists because the two sides drifted once: html_bind wrote
// data-g-clear-on and bindAttrs did not, so a composer inside a
// rendered slot silently never cleared (#80). The next attribute
// html_bind grows should fail here until bindAttrs answers for it.
//
// Usage: node builder_client.js <path to glinty.js>
// Prints "ok <n>" and exits 0, or prints the failures and exits 1.

'use strict';
var fs = require('fs');

var src = fs.readFileSync(process.argv[2], 'utf8');
var from = src.indexOf(
  '/* emit becomes a DOM event name here and nowhere else. */');
var to = src.indexOf('function slotAttrs');
if (from < 0 || to < 0 || to <= from) {
  console.error('could not find emitEvent/bindAttrs in glinty.js');
  process.exit(1);
}
var block = src.slice(from, to);

var load = new Function(block + '\nreturn { bindAttrs: bindAttrs };');
var api = load();

var failures = [];
var checks = 0;
function eq(actual, expected, what) {
  checks++;
  var a = JSON.stringify(actual);
  var e = JSON.stringify(expected);
  if (a !== e) failures.push(what + ': expected ' + e + ', got ' + a);
}

// The composer shape (#60): a live textarea declaring clear_on. The
// full map is asserted, not just the one attribute, so the mirror is
// locked key for key against what html_bind writes for the same
// component.
eq(api.bindAttrs({ id: 'draft', emit: 'live', clear_on: 'send' }, 'input'),
   { id: 'draft',
     'data-g-target': 'draft',
     'data-g-message': 'input',
     'data-g-event': 'input',
     'data-g-clear-on': 'send' },
   'a dynamically built clear_on composer carries the binding');

// Absent means absent: no clear_on, no attribute -- emitEventFrame's
// query must not catch bystanders.
eq(api.bindAttrs({ id: 'name', emit: 'settle' }, 'input'),
   { id: 'name',
     'data-g-target': 'name',
     'data-g-message': 'input',
     'data-g-event': 'change' },
   'a field without clear_on gets no data-g-clear-on');

// The event shape: no DOM id (nothing makes a button id unique), and
// the value rides the event.
eq(api.bindAttrs({ id: 'pick', value: 'row-3' }, 'event'),
   { 'data-g-target': 'pick',
     'data-g-message': 'event',
     'data-g-value': 'row-3' },
   'an event binding stays id-less and valued');

if (failures.length) {
  failures.forEach(function (f) { console.error('FAIL ' + f); });
  process.exit(1);
}
console.log('ok ' + checks);
