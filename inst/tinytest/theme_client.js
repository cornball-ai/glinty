// The client's theme CSS builder, driven under node.
//
// theme_css() paints the served page; themeCssText() repaints it on
// welcome. The two must produce byte-identical CSS from the same wire
// tokens, or the first paint and the hydrated state diverge -- the
// invariant both files state. R can only assert its own half, so the
// builder is sliced out of the SHIPPED glinty.js -- not a copy -- and
// fed the same wire theme the server serialized.
//
// The slice runs from THEME_COLOR_NAMES up to applyTheme, which is
// where the pure builders end and the DOM begins; the harness
// supplies nothing else, so a builder that starts reaching for the
// document fails here rather than being quietly stubbed.
//
// Usage: node theme_client.js <glinty.js> <theme.json> <expected.css>
// Prints "ok 1" and exits 0, or prints both strings and exits 1.

'use strict';
var fs = require('fs');

var src = fs.readFileSync(process.argv[2], 'utf8');
var from = src.indexOf('var THEME_COLOR_NAMES');
var to = src.indexOf('function applyTheme(');
if (from < 0 || to < 0 || to <= from) {
  console.error('could not find the theme block in glinty.js');
  process.exit(1);
}
var make = new Function(
  src.slice(from, to) + '\nreturn themeCssText;'
);
var themeCssText = make();

var theme = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
var expected = fs.readFileSync(process.argv[4], 'utf8');
var got = themeCssText(theme);
if (got === expected) {
  console.log('ok 1');
  process.exit(0);
}
console.error('client CSS differs from server CSS');
console.error('server: ' + expected);
console.error('client: ' + got);
process.exit(1);
