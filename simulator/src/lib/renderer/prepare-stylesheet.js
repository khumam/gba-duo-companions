// Matches the Thor's companion display: 369dpi / 160 = 2.30625x, the same
// multiplier render-widget.js's `px()` and WidgetRenderer.kt's `px()` use.
const DEVICE_DENSITY = 2.30625;

// Widget type names a pack's CSS can target with a bare type selector (e.g. `box { ... }`),
// mirroring CompanionTree.kt's typeName, plus the parts it generates (bar > fill,
// bar > label, tabs > tab-bar > tab, tabs > tab-content, list > empty). Real DOM elements
// don't carry these as tag names (to avoid HTML parser quirks like `<image>` auto-aliasing
// to `<img>`), so every element gets a `data-type` attribute instead, and bare type
// selectors are rewritten to attribute selectors before the browser ever sees them.
const WIDGET_TYPES = [
	'box', 'text', 'row', 'column', 'tabs', 'pages', 'button', 'list', 'image', 'bar', 'spacer',
	'fill', 'label', 'tab-bar', 'tab', 'tab-content', 'empty',
];

/**
 * Prepares raw `style.css` text (already combined across a pack's declared files, in order)
 * for injection into a real `<style>` element scoped to a Shadow DOM root: prepends
 * [baseCssText] (the engine's real `default.css`, read live from the sibling `gbaduo` repo —
 * see routes/api/default-css), rescales every `px` length by [DEVICE_DENSITY], rewrites bare
 * widget-type selectors to `[data-type="..."]` attribute selectors, translates `:root` to
 * `:host` (`:root` never matches inside a shadow tree), translates the interaction
 * pseudo-classes `:active`/`:pressed`/`:disabled` to real toggled classes (a plain `<div>`
 * never genuinely matches these the way a native control would — render-widget.js toggles
 * `.active`/`.pressed`/`.disabled` to match), rewrites `display: stack` to a `display: grid`
 * + marker custom property (see [translateStackDisplay]), and resolves relative `url(...)`
 * references against the pack's served asset base path.
 *
 * `@font-face` blocks are stripped out of this output — Chromium does not register fonts
 * declared inside a shadow tree's stylesheet (verified: `document.fonts` never lists them,
 * and the font visibly never applies), so they have to be injected into `document.head`
 * instead. Use [extractFontFaceCss] for that, on the same raw `cssText`.
 *
 * Known limitation: type-selector translation only looks at each top-level block's own
 * selector text, not selectors nested inside `@media`/`@supports` bodies. Not an issue for
 * Android's current CSS support (it doesn't implement `@media` either), but worth revisiting
 * if the simulator ever needs to preview a responsive pack ahead of Android catching up.
 */
export function prepareStylesheetCss(cssText, packBaseUrl, baseCssText = '') {
	const blocks = splitIntoBlocks(stripComments(`${baseCssText}\n${cssText}`));
	// The real engine's box model is always border-box (width/height include padding+border —
	// see ComputedStyle/BoxStyle.kt). The browser default is content-box, where padding adds
	// to the declared width instead of being subtracted from it: a 1080px-wide element with
	// 16px (37px scaled) padding renders 74px too wide, and that excess cascades through every
	// nested box. --gbaduo-stack gets the same universal-rule treatment for the same reason
	// custom properties inherit (see translateStackDisplay/applyStackChildPlacement): without
	// it, every descendant of a real stack container would also report --gbaduo-stack: 1 via
	// inheritance, not just the container itself. A directly-specified value always beats an
	// inherited one, so only elements translateStackDisplay actually touches end up with 1.
	// `[data-gbaduo-hidden]` is how render-widget.js hides a `pages` widget's unselected pages
	// (CompanionNode.hiddenBySwitch). It has to beat any pack/default `display` rule, and stay
	// separate from `visibleIf`'s inline display:none so the two never fight each other.
	// `min-width/min-height: 0`: LayoutEngine.kt documents that `auto` is 0, not min-content,
	// so flex items (e.g. tabs in a full tab strip) shrink below their longest word instead
	// of overflowing the screen. `overflow-wrap: anywhere` then lets a word that no longer
	// fits break mid-word, as Compose's text layout does — otherwise the browser would keep
	// the word whole and let it spill out of its shrunken box.
	const resetRule =
		'*{ box-sizing: border-box; --gbaduo-stack: 0; min-width: 0; min-height: 0; overflow-wrap: anywhere; }\n' +
		'[data-gbaduo-hidden]{ display: none !important; }\n';
	const translated = blocks
		.filter(({ selector }) => !selector.trim().startsWith('@font-face'))
		.map(({ selector, body }) => {
			const trimmedSelector = selector.trim();
			// `:root` means the companion tree's root widget node (CompanionTree's root is the
			// stylesheet's "document"), not the shadow DOM host. `:host` styles the outer host
			// <div> (one DOM level above the rendered tree) — `width`/`height`/other
			// non-inherited properties set there never reach the actual root widget element,
			// which is what needs to actually fill the canvas. The caller tags the real root
			// element with `data-gbaduo-root` (see +page.svelte) so this targets it directly.
			const rootTranslated = trimmedSelector === ':root' ? '[data-gbaduo-root]' : trimmedSelector;
			const typeTranslated = rootTranslated === '' ? rootTranslated : translateTypeSelectors(rootTranslated);
			const translatedSelector = translatePseudoStates(typeTranslated);
			const stackTranslatedBody = translateStackDisplay(body);
			const rescaledBody = rescalePxLengths(stackTranslatedBody);
			const rewrittenBody = rewriteUrls(rescaledBody, packBaseUrl);
			return `${translatedSelector}{${rewrittenBody}}`;
		})
		.join('\n');
	return resetRule + translated;
}

/**
 * Extracts just the `@font-face` blocks from raw pack CSS, with `url(...)` resolved against the
 * pack's asset base path, for injection into `document.head` (global — see [prepareStylesheetCss]
 * for why these can't live in the shadow-scoped stylesheet). No px-rescaling: `@font-face` bodies
 * don't carry the kind of length values that convention applies to.
 */
export function extractFontFaceCss(cssText, packBaseUrl) {
	const blocks = splitIntoBlocks(stripComments(cssText));
	return blocks
		.filter(({ selector }) => selector.trim().startsWith('@font-face'))
		.map(({ selector, body }) => `${selector.trim()}{${rewriteUrls(body, packBaseUrl)}}`)
		.join('\n');
}

function stripComments(cssText) {
	return cssText.replace(/\/\*[\s\S]*?\*\//g, '');
}

/** Splits `selector { body } selector2 { body2 }` into `{selector, body}` pairs, brace-depth aware. */
function splitIntoBlocks(cssText) {
	const blocks = [];
	let depth = 0;
	let selectorStart = 0;
	let bodyStart = -1;
	for (let i = 0; i < cssText.length; i++) {
		const ch = cssText[i];
		if (ch === '{') {
			if (depth === 0) bodyStart = i + 1;
			depth++;
		} else if (ch === '}') {
			depth--;
			if (depth === 0) {
				blocks.push({
					selector: cssText.slice(selectorStart, bodyStart - 1),
					body: cssText.slice(bodyStart, i),
				});
				selectorStart = i + 1;
			}
		}
	}
	return blocks;
}

function translateTypeSelectors(selector) {
	const pattern = new RegExp(`(^|[\\s,>])(${WIDGET_TYPES.join('|')})(?=[\\s.#:,>{]|$)`, 'g');
	return selector.replace(pattern, (_match, boundary, type) => `${boundary}[data-type="${type}"]`);
}

/**
 * The real engine supports `:active`/`:pressed`/`:disabled` as live state (`StyleNode.states`
 * in Selector.kt), but a plain `<div>` never genuinely matches these the way a native form
 * control does in a browser. render-widget.js toggles `.active`/`.pressed`/`.disabled`
 * classes to match instead.
 */
function translatePseudoStates(selector) {
	return selector
		.replace(/:active\b/g, '.active')
		.replace(/:pressed\b/g, '.pressed')
		.replace(/:disabled\b/g, '.disabled');
}

/**
 * `display: stack` is CompanionTree.kt's Compose-`Box`-style overlay layout (every
 * non-absolutely-positioned child occupies the same area, aligned by `place-items`) —
 * browsers have no such keyword. Rewritten to `display: grid` plus a `--gbaduo-stack: 1`
 * marker; render-widget.js's `applyStackChildPlacement` reads that marker via
 * `getComputedStyle` once the tree is attached to the DOM and places each
 * non-absolutely-positioned direct child into the same grid cell, reproducing the overlay
 * with only standard grid placement. `position: relative` is added so `position: absolute`
 * children (e.g. `bar > fill`) anchor against this element, matching `default.css`'s intent.
 */
function translateStackDisplay(body) {
	return body.replace(/display\s*:\s*stack\s*;?/g, 'display: grid; position: relative; --gbaduo-stack: 1;');
}

function rescalePxLengths(body) {
	return body.replace(/(-?\d*\.?\d+)px/g, (_match, numberText) => {
		const scaled = Math.round(parseFloat(numberText) * DEVICE_DENSITY);
		return `${scaled}px`;
	});
}

function rewriteUrls(body, packBaseUrl) {
	return body.replace(/url\(\s*(['"]?)([^'")]+)\1\s*\)/g, (_match, quote, path) => {
		if (/^(https?:|data:|\/)/.test(path)) return `url(${quote}${path}${quote})`;
		// The real engine resolves a stylesheet's url() relative to the pack's root directory
		// (CssParser.resolveUrl), so an author writes "assets/fonts/x.ttf" meaning exactly that
		// path under the pack root. The simulator serves assets at /packs/{id}/assets/..., so
		// strip a leading "assets/" before appending — otherwise an already-"assets/"-prefixed
		// path doubles up into .../assets/assets/fonts/x.ttf and 404s.
		const relativePath = path.startsWith('assets/') ? path.slice('assets/'.length) : path;
		return `url("${packBaseUrl}/assets/${relativePath}")`;
	});
}
