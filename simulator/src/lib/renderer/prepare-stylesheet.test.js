import { describe, it, expect } from 'vitest';
import { prepareStylesheetCss, extractFontFaceCss } from './prepare-stylesheet.js';

describe('prepareStylesheetCss', () => {
	it('always prepends a universal border-box reset, matching the real engine\'s box model', () => {
		const out = prepareStylesheetCss('.card { width: 100px; }', '/packs/x');
		expect(out).toMatch(/^\*\{ box-sizing: border-box; --gbaduo-stack: 0;/);
	});

	it('treats min-width/min-height auto as 0 like LayoutEngine.kt, so flex items can shrink below a word', () => {
		const out = prepareStylesheetCss('', '/packs/x');
		expect(out).toMatch(/^\*\{[^}]*min-width: 0; min-height: 0; overflow-wrap: anywhere; \}/);
	});

	it('rescales px lengths by the device density', () => {
		const out = prepareStylesheetCss('.card { width: 440px; padding: 12px; }', '/packs/x');
		expect(out).toContain('width: 1015px');
		expect(out).toContain('padding: 28px');
	});

	it('leaves non-px values untouched', () => {
		const out = prepareStylesheetCss('.card { color: red; opacity: 0.5; }', '/packs/x');
		expect(out).toContain('color: red');
		expect(out).toContain('opacity: 0.5');
	});

	it('translates bare type selectors to data-type attribute selectors', () => {
		const out = prepareStylesheetCss('box { color: red; }', '/packs/x');
		expect(out).toContain('[data-type="box"]{');
	});

	it('translates the generated-part type names (fill, tab-bar, tab, tab-content, empty, label)', () => {
		const out = prepareStylesheetCss(
			'bar > fill { color: red; } tabs > tab-bar > tab { color: red; } tab-content { color: red; } list > empty { color: red; } bar > label { color: red; }',
			'/packs/x',
		);
		expect(out).toContain('[data-type="bar"] > [data-type="fill"]{');
		expect(out).toContain('[data-type="tabs"] > [data-type="tab-bar"] > [data-type="tab"]{');
		expect(out).toContain('[data-type="tab-content"]{');
		expect(out).toContain('[data-type="list"] > [data-type="empty"]{');
		expect(out).toContain('[data-type="bar"] > [data-type="label"]{');
	});

	it('translates type selectors inside compound and descendant selectors', () => {
		const out = prepareStylesheetCss('.party text { color: red; }', '/packs/x');
		expect(out).toContain('.party [data-type="text"]{');
	});

	it('does not translate a class that happens to share a type name', () => {
		const out = prepareStylesheetCss('.box { color: red; }', '/packs/x');
		expect(out).toContain('.box{ color: red; }');
	});

	it('leaves id and structural pseudo-class selectors untouched', () => {
		const out = prepareStylesheetCss('#screen:first-child { color: red; }', '/packs/x');
		expect(out).toContain('#screen:first-child{');
	});

	it('translates :active, :pressed, :disabled to real toggled classes', () => {
		const out = prepareStylesheetCss(
			'tab:active { color: red; } .card:pressed { color: blue; } .card:disabled { opacity: 0.5; }',
			'/packs/x',
		);
		expect(out).toContain('[data-type="tab"].active{');
		expect(out).toContain('.card.pressed{');
		expect(out).toContain('.card.disabled{');
	});

	it('strips @font-face blocks out of the shadow-scoped output', () => {
		const out = prepareStylesheetCss(
			'@font-face { font-family: "Pixel"; src: url("fonts/Pixel.ttf"); } .card { color: red; }',
			'/packs/demo',
		);
		expect(out).not.toContain('@font-face');
		expect(out).toContain('.card{ color: red; }');
	});

	it('does not double the assets/ prefix when a url() already starts with it', () => {
		const out = prepareStylesheetCss('.card { background: url(assets/images/bg.png); }', '/packs/x');
		expect(out).toContain('url("/packs/x/assets/images/bg.png")');
		expect(out).not.toContain('assets/assets');
	});

	it('leaves absolute and data urls untouched', () => {
		const out = prepareStylesheetCss('.a { background: url(https://example.com/x.png); }', '/packs/x');
		expect(out).toContain('url(https://example.com/x.png)');
	});

	it('translates :root to a data-gbaduo-root marker so it targets the actual root widget, not the shadow host', () => {
		const out = prepareStylesheetCss(':root { --accent: red; width: 100px; }', '/packs/x');
		expect(out).toContain('[data-gbaduo-root]{ --accent: red; width: 231px; }');
		expect(out).not.toContain(':root');
		expect(out).not.toContain(':host');
	});

	it('translates display: stack to display: grid plus the stack marker', () => {
		const out = prepareStylesheetCss('bar { display: stack; height: 12px; }', '/packs/x');
		expect(out).toContain('display: grid; position: relative; --gbaduo-stack: 1;');
		expect(out).not.toContain('display: stack');
	});

	it('prepends baseCssText (the real default.css) and translates it the same way', () => {
		const out = prepareStylesheetCss('.card { color: red; }', '/packs/x', 'bar { display: stack; }');
		expect(out).toContain('[data-type="bar"]{ display: grid; position: relative; --gbaduo-stack: 1; }');
		expect(out).toContain('.card{ color: red; }');
	});
});

describe('extractFontFaceCss', () => {
	it('extracts only @font-face blocks with urls rewritten', () => {
		const css = `
			:root { --accent: red; }
			@font-face { font-family: "Pixel"; src: url("fonts/Pixel.ttf"); }
			.card { color: red; }
		`;
		const out = extractFontFaceCss(css, '/packs/demo');
		expect(out).toContain('@font-face{ font-family: "Pixel"; src: url("/packs/demo/assets/fonts/Pixel.ttf"); }');
		expect(out).not.toContain(':root');
		expect(out).not.toContain('.card');
	});

	it('does not double the assets/ prefix for a real-pack-style @font-face src', () => {
		const css = '@font-face { font-family: "Baloo2"; src: url("assets/fonts/Baloo2.ttf"); }';
		const out = extractFontFaceCss(css, '/packs/harvest-moon-fomt-companion');
		expect(out).toContain('url("/packs/harvest-moon-fomt-companion/assets/fonts/Baloo2.ttf")');
		expect(out).not.toContain('assets/assets');
	});

	it('returns an empty string when there are no @font-face blocks', () => {
		const out = extractFontFaceCss('.card { color: red; }', '/packs/x');
		expect(out).toBe('');
	});

	it('extracts multiple @font-face blocks', () => {
		const css = `
			@font-face { font-family: "A"; src: url("a.ttf"); }
			@font-face { font-family: "B"; src: url("b.ttf"); }
		`;
		const out = extractFontFaceCss(css, '/packs/x');
		expect(out).toContain('"A"');
		expect(out).toContain('"B"');
	});

	it('ignores @font-face mentioned inside a comment', () => {
		const out = extractFontFaceCss('/* @font-face { not real } */ .card { color: red; }', '/packs/x');
		expect(out).toBe('');
	});
});

describe('prepareStylesheetCss with comments', () => {
	it('strips a leading block comment before parsing, so :root still translates correctly', () => {
		const css = `/*\n * Design notes spanning\n * multiple lines\n */\n:root { --accent: red; }`;
		const out = prepareStylesheetCss(css, '/packs/x');
		expect(out).toContain('[data-gbaduo-root]{ --accent: red; }');
	});

	it('strips inline comments inside a rule body', () => {
		const out = prepareStylesheetCss('.card { color: red; /* note */ padding: 4px; }', '/packs/x');
		expect(out).toContain('color: red;');
		expect(out).toContain('padding: 9px;');
		expect(out).not.toContain('note');
	});
});
