// Runs inside the probe page, under a headless browser. `plan` is
// injected above this by css_computed_conflicts(): one entry per
// variant family, naming its variants and the properties glinty's own
// stylesheet sets on them.
//
// The answer is deliberately small -- how many distinct values a
// family's variants have for each property, in each state -- because
// the finding is a comparison between two runs of this page, and R
// does that comparison. Everything here is a measurement; nothing
// here is a judgement.

const STATES = ["", "hover", "focus", "active"];

const asArray = (x) => (Array.isArray(x) ? x : [x]);

const measurements = {};

for (const family of asArray(plan)) {
  const variants = asArray(family.variants);
  const properties = asArray(family.properties);

  for (const state of STATES) {
    for (const property of properties) {
      const values = [];

      for (const variant of variants) {
        const el = document.querySelector(
          `[data-probe="${family.base}|${variant}|${state}"]`
        );
        // A family whose probe is missing measures nothing rather
        // than measuring the empty set and calling it agreement.
        if (!el) continue;
        values.push(getComputedStyle(el).getPropertyValue(property));
      }

      if (values.length === 0) continue;
      const distinct = [...new Set(values)];
      measurements[`${family.base}|${state}|${property}`] = {
        distinct: distinct.length,
        values: distinct,
      };
    }
  }
}

document.getElementById("glinty-computed").textContent =
  JSON.stringify(measurements);
