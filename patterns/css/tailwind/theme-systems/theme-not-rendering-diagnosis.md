---
id: "pattern-css-tailwind-theme-systems-not-rendering-diagnosis"
title: "Theme Not Rendering: Two-Stage Diagnosis (Pipeline + Values + Overrides)"
type: troubleshooting
status: draft
confidence: medium
revision: 1
languages:
  - language: css
    versions: "*"
  - language: javascript
    versions: ">=14.0"
frameworks:
  - name: tailwind
    versions: ">=4.0"
domain: theme-systems
tags:
  - theme-rendering
  - css-variables
  - tailwind-v4
  - json-driven-themes
  - debugging
  - oklch-colors
introduced: 2026-01-11
last_verified: 2026-01-11
review_by: 2026-04-11
sanitized: true
related: []
---

# Theme Not Rendering: Two-Stage Diagnosis (Pipeline + Values + Overrides)

## Context

**When this occurs:**

You're using a JSON-driven theme system with Tailwind v4 CSS-first approach where:
- Theme tokens defined in JSON (colors, fonts, spacing, etc.)
- Build-time compiler transforms JSON → CSS variables
- CSS variables consumed via Tailwind's `@theme inline` directive
- Browser shows **default theme** instead of custom theme despite:
  - ✅ JSON file exists and contains custom values
  - ✅ Compiler runs successfully
  - ✅ No build errors

**Technology stack:**
- Tailwind CSS v4 (CSS-first architecture)
- JSON-based theme configuration
- Build-time compilation (Node.js script, Vite plugin, etc.)
- CSS custom properties (CSS variables)
- Modern color spaces (OKLCH, P3, etc.)

**Preconditions:**
- Theme system was working previously OR is newly implemented
- Compiler output appears successful (no errors in logs)
- Generated CSS files exist on disk
- Application loads without JavaScript errors

---

## Symptoms

**Visual symptoms:**
- ❌ Browser shows **default theme colors** (e.g., blue #3B82F6) instead of custom brand colors
- ❌ Wrong font family renders (system default instead of custom font)
- ❌ Incorrect spacing/radius values
- ❌ Theme appears partially broken (some elements correct, others default)

**Inspection symptoms:**
- ✅ Compiled CSS file exists at expected path (e.g., `dist/theme.css`)
- ✅ File size looks reasonable (not empty)
- ❌ Browser DevTools show wrong computed values:
  ```css
  /* Expected */
  background-color: oklch(0.9789 0.0082 121.6272);
  
  /* Actual */
  background-color: oklch(0.98 0.01 240); /* Default blue theme */
  ```

**Build output symptoms:**
- ✅ Theme compiler reports success (e.g., "Generated 5312 bytes")
- ✅ Vite/Webpack reports successful build
- ❌ No obvious errors or warnings
- ❌ Build appears to complete normally

---

## Root Cause

This is a **three-layer problem** where each layer can independently cause theme rendering failures:

### Layer 1: Pipeline Issues (CSS Import Order)

**Problem:** Custom theme CSS is **loaded in wrong order** relative to other stylesheets.

**Why this fails:**
```css
/* ❌ WRONG ORDER - Default overrides custom */
@import "theme-packs/custom-theme/_generated.css";  /* Custom theme */
@import "vendor/animations.css";                     /* Has default theme */
/* Result: Default theme wins (last import takes precedence) */

/* ✅ CORRECT ORDER - Custom overrides default */
@import "theme-packs/custom-theme/_generated.css";  /* Custom theme LAST */
```

**CSS specificity rules:**
- When multiple stylesheets define same CSS variable, **last definition wins**
- Import order matters in CSS (unlike JavaScript modules)
- Tailwind v4 uses CSS variables as source of truth, so import order is critical

### Layer 2: Value Issues (Wrong Source Values)

**Problem:** Theme JSON contains **approximated/wrong values** that don't match reference design.

**Why this fails:**
```json
// ❌ APPROXIMATED VALUES (wrong hue, wrong lightness)
{
  "--background": "oklch(0.98 0.01 240)",  // Cool blue tint
  "--primary": "oklch(0.55 0.25 275)",     // Purple
  "--border": "oklch(0.88 0.02 260)"       // Light purple
}

// ✅ ACTUAL REFERENCE VALUES
{
  "--background": "oklch(0.9789 0.0082 121.6272)",  // Warm cream
  "--primary": "oklch(0.6232 0.1858 308.6424)",     // Correct purple hue
  "--border": "oklch(0 0 0)"                        // Black
}
```

**Common sources of wrong values:**
- Manual conversion from RGB/hex without reference
- Eyeballing colors instead of using design system tokens
- Copy-pasted from similar theme with different color palette
- Using color picker on screenshot (lossy, inaccurate)

### Layer 3: Override Issues (Hardcoded Utility Classes)

**Problem:** View templates contain **hardcoded utility classes** that bypass theme system.

**Why this fails:**
```html
<!-- ❌ HARDCODED - Ignores theme variables -->
<button class="bg-blue-600 text-white hover:bg-blue-700">
  Save
</button>

<!-- ✅ SEMANTIC - Uses theme variables -->
<button class="bg-primary text-primary-foreground hover:bg-primary/90">
  Save
</button>
```

**Common hardcoded patterns:**
- `bg-blue-*`, `text-gray-*`, `border-slate-*` (color utilities)
- `text-zinc-500 dark:text-zinc-400` (explicit dark mode overrides)
- Inline styles: `style="background: #3B82F6"`
- Component library defaults (if not configured to use theme)

---

## Fix

### Phase 1: Verify Pipeline (CSS Import Order)

**Step 1: Check CSS entry point**

```css
/* app/assets/application.css or app/frontend/entrypoints/application.css */

/* Find this pattern: */
@import "theme-packs/custom-theme/_generated.css";
@import "vendor/animations.css";
@import "components/*.css";

/* ❌ If custom theme is imported BEFORE vendor CSS, reorder: */
```

**Step 2: Fix import order**

```css
/* ✅ Custom theme MUST be imported LAST (or late enough to override defaults) */

@import "vendor/animations.css";
@import "components/*.css";
@import "theme-packs/custom-theme/_generated.css";  /* LAST */
```

**Step 3: Rebuild**

```bash
# Rebuild CSS (exact command depends on your build system)
npm run build:css
# or
bundle exec rails assets:precompile
# or
vite build
```

**Step 4: Verify compiled output**

```bash
# Check that generated CSS exists and is recent
ls -lh dist/assets/application-*.css
# or
ls -lh public/vite/assets/application-*.css

# Verify it contains your custom theme values
grep "oklch" dist/assets/application-*.css | head -5
```

**If Phase 1 fixes it:** Theme now renders. Done.  
**If Phase 1 doesn't fix it:** Proceed to Phase 2.

---

### Phase 2: Verify Values (JSON Source Correctness)

**Step 1: Get reference values**

```bash
# If you have a design system reference (Figma, design tokens, etc.)
# Extract EXACT values, don't approximate

# Example reference:
# Background: oklch(0.9789 0.0082 121.6272)
# Primary: oklch(0.6232 0.1858 308.6424)
# Border: oklch(0 0 0)
```

**Step 2: Compare JSON to reference**

```json
// theme-packs/custom-theme/theme.json

{
  "light": {
    "--background": "oklch(0.98 0.01 240)",  // ❌ WRONG - Cool blue vs warm cream
    "--primary": "oklch(0.55 0.25 275)",     // ❌ WRONG - Different hue
    "--border": "oklch(0.88 0.02 260)"       // ❌ WRONG - Light purple vs black
  }
}
```

**Step 3: Update JSON with exact reference values**

```json
// ✅ Use EXACT values from design system
{
  "light": {
    "--background": "oklch(0.9789 0.0082 121.6272)",
    "--primary": "oklch(0.6232 0.1858 308.6424)",
    "--border": "oklch(0 0 0)",
    "--accent": "oklch(0.8024 0.1608 151.7117)",
    "--radius": "1rem",
    "--font-sans": "\"Custom Font\", ui-sans-serif, system-ui, sans-serif"
  }
}
```

**Step 4: Recompile theme**

```bash
# Run your theme compiler (exact command varies)
node scripts/theme-compiler.js
# or
npm run compile:theme

# Example output:
# ✅ Successfully generated theme-packs/custom-theme/_generated.css
# Output size: 5312 bytes
```

**Step 5: Rebuild application**

```bash
npm run build
# or
bundle exec rails assets:precompile
```

**Step 6: Hard refresh browser**

```
Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
```

**If Phase 2 fixes it:** Theme now renders correctly. Done.  
**If Phase 2 doesn't fix it:** Proceed to Phase 3.

---

### Phase 3: Find Overrides (Hardcoded Classes)

**Step 1: Search for hardcoded color classes**

```bash
# Find hardcoded utility classes in templates
grep -r "bg-blue\|bg-gray\|bg-slate\|bg-zinc\|text-gray\|border-blue" app/views/
grep -r "bg-blue\|bg-gray\|bg-slate\|bg-zinc\|text-gray\|border-blue" app/components/

# Example output:
# app/views/documents/show.html.erb:9:  <button class="bg-blue-600 text-white">
# app/components/ui/_status.html.erb:26:  <div class="bg-gray-200 dark:bg-gray-700">
```

**Step 2: Replace hardcoded classes with semantic tokens**

```diff
<!-- app/views/documents/show.html.erb -->

- <button class="bg-blue-600 text-white hover:bg-blue-700">
+ <button class="bg-primary text-primary-foreground hover:bg-primary/90">
    Save
  </button>

- <div class="bg-gray-200 dark:bg-gray-700">
+ <div class="bg-muted">
    Content
  </div>

- <span class="text-gray-500 dark:text-gray-400">
+ <span class="text-muted-foreground">
    Metadata
  </span>

- <div class="border-l-blue-500 bg-blue-50">
+ <div class="border-l-primary bg-primary/10">
    Highlight
  </div>
```

**Step 3: Rebuild (if using Tailwind JIT)**

```bash
npm run build
# or just refresh if using dev server with watch mode
```

**Step 4: Verify in browser**

Hard refresh (Cmd+Shift+R / Ctrl+Shift+R) and check elements that were previously wrong.

**If Phase 3 fixes it:** All hardcoded overrides removed. Done.

---

### Phase 4: Runtime Verification

**Step 1: Open browser DevTools console**

**Step 2: Run verification script**

```javascript
// Paste this into browser console

const root = document.documentElement;
const computedStyle = getComputedStyle(root);

const expectedValues = {
  '--background': 'oklch(0.9789 0.0082 121.6272)',
  '--border': 'oklch(0 0 0)',
  '--primary': 'oklch(0.6232 0.1858 308.6424)',
  '--accent': 'oklch(0.8024 0.1608 151.7117)',
  '--radius': '1rem',
  '--font-sans': '"Custom Font", ui-sans-serif, system-ui, sans-serif'
};

const results = {};
for (const [key, expected] of Object.entries(expectedValues)) {
  const actual = computedStyle.getPropertyValue(key).trim();
  const match = actual === expected;
  results[key] = { expected, actual, match };
  console.log(`${match ? '✅' : '❌'} ${key}`);
  console.log(`   Expected: ${expected}`);
  console.log(`   Actual:   ${actual}`);
}

const allMatch = Object.values(results).every(r => r.match);
console.log(`\n${allMatch ? '✅ ALL VALUES MATCH' : '❌ SOME VALUES DO NOT MATCH'}`);
```

**Step 3: Verify specific elements**

```javascript
// Check a specific button element
const button = document.querySelector('button.bg-primary');
const buttonStyle = getComputedStyle(button);
console.log('Button background:', buttonStyle.backgroundColor);
// Should show: oklch(0.6232 0.1858 308.6424)

// Check background color on body
const bodyStyle = getComputedStyle(document.body);
console.log('Body background:', bodyStyle.backgroundColor);
// Should show: oklch(0.9789 0.0082 121.6272)
```

---

## Verification Checklist

**Phase 1 - Pipeline:**
- [ ] Custom theme CSS imported in correct order (after vendor CSS or last)
- [ ] Rebuild completed successfully
- [ ] Generated CSS file timestamp is recent
- [ ] No CSS import errors in browser console

**Phase 2 - Values:**
- [ ] JSON values match design system reference exactly
- [ ] Color hues match (hue component in OKLCH: 0-360°)
- [ ] Lightness/chroma match (not approximated)
- [ ] Font names match exactly (quotes, fallbacks)
- [ ] Spacing/radius values match
- [ ] Theme compiler ran successfully
- [ ] Generated CSS contains new values (grep check)

**Phase 3 - Overrides:**
- [ ] No hardcoded color utilities in templates (`bg-blue-*`, `text-gray-*`, etc.)
- [ ] All color classes use semantic tokens (`bg-primary`, `bg-muted`, etc.)
- [ ] No inline styles with hardcoded colors
- [ ] Component library configured to use theme variables

**Phase 4 - Runtime:**
- [ ] Browser console verification script shows all ✅
- [ ] Computed styles match expected OKLCH values exactly
- [ ] Visual inspection: theme looks correct in browser
- [ ] Test in different color schemes (light/dark if supported)
- [ ] Test edge cases (hover states, disabled states, etc.)

---

## Common Pitfalls

### 1. Approximating Color Values

**❌ Wrong approach:**
```json
// "Close enough" mentality
"--primary": "oklch(0.55 0.25 275)"  // Eyeballed from screenshot
```

**✅ Correct approach:**
```json
// Exact values from design system
"--primary": "oklch(0.6232 0.1858 308.6424)"  // From Figma tokens
```

**Why it matters:** Small differences in hue (275° vs 308°) or chroma (0.25 vs 0.1858) result in visually different colors.

### 2. Checking Generated CSS Without Rebuilding

**❌ Wrong approach:**
```bash
# Check file, see it exists, assume it's up to date
ls theme.css  # ✅ File exists
# Don't rebuild, deploy to production
```

**✅ Correct approach:**
```bash
# Always rebuild after JSON changes
npm run compile:theme
npm run build
# Verify file timestamp
ls -l theme.css  # Check modified time
```

### 3. Using Color Picker on Screenshot

**❌ Wrong approach:**
```
1. Screenshot of design system
2. Use color picker to sample
3. Convert to OKLCH
4. Put in JSON
# Result: Lossy, compressed, wrong color space
```

**✅ Correct approach:**
```
1. Export design tokens from Figma/design tool
2. Use exact OKLCH values from tokens
3. If no tokens, ask designer for exact values
```

### 4. Forgetting CSS Cascade Rules

**❌ Wrong assumption:**
```css
/* "My theme is more specific, it should win" */
.my-theme { --background: oklch(...); }  /* Defined first */
:root { --background: oklch(...); }      /* Default, defined later */
/* Result: Default wins (later definition) */
```

**✅ Correct understanding:**
```css
/* Import order and cascade both matter */
@import "defaults.css";  /* Defines :root vars */
@import "my-theme.css";  /* Must override :root vars with equal/higher specificity */
/* Or ensure my-theme imports AFTER defaults */
```

---

## Related Patterns

- `pattern-css-tailwind-import-order-debugging` (when to check)
- `pattern-css-oklch-color-space-precision` (color value accuracy)
- `pattern-css-semantic-tokens-migration` (removing hardcoded classes)

---

## Additional Context

**Why this pattern is common:**

1. **JSON-driven themes are new** - Tailwind v4's CSS-first approach is relatively new (2024)
2. **Multiple compilation steps** - JSON → CSS → bundler → browser adds complexity
3. **Eyeballing colors fails** - Human perception is poor at judging OKLCH precision
4. **Import order is subtle** - CSS cascade rules are well-known but easy to miss

**When to suspect this pattern:**

- Theme worked before, broke after dependency update
- New theme system just implemented, "almost works"
- Tests pass but visual QA fails
- Some elements themed correctly, others wrong (mixed overrides)

**Prevention strategies:**

- **Version control theme JSON** - Track exact values in git
- **E2E visual regression tests** - Catch theme changes automatically
- **CI check for hardcoded classes** - Lint rules for `bg-blue-*`, etc.
- **Design token source of truth** - Export from Figma, don't manually type

---

**Pattern confidence:** Medium (tested on one production project, pattern logic is sound, needs validation across more projects)

**Last verified:** 2026-01-11  
**Technology versions:** Tailwind CSS 4.0, Rails 8.1.1, Vite 5.4.21
