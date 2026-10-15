import { describe, it, expect } from 'vitest';
import { parseLayout, parseLayoutWithWarnings, InvalidLayoutError } from './parse-layout.js';

describe('parseLayout', () => {
	it('parses text with no legacy keys present', () => {
		const widget = parseLayout('{"type":"text","text":"Money: {money}"}');
		expect(widget.type).toBe('text');
		expect(widget.text).toBe('Money: {money}');
		expect(widget.legacy).toEqual({});
	});

	it('parses text legacy keys only when present in the source JSON', () => {
		const widget = parseLayout('{"type":"text","text":"hi","size":16,"bold":true}');
		expect(widget.legacy).toEqual({ size: 16, bold: true });
		expect('color' in widget.legacy).toBe(false);
		expect('font' in widget.legacy).toBe(false);
	});

	it('parses column with children', () => {
		const widget = parseLayout(
			'{"type":"column","gap":8,"children":[{"type":"text","text":"a"},{"type":"spacer","size":4}]}',
		);
		expect(widget.gap).toBe(8);
		expect(widget.children).toHaveLength(2);
		expect(widget.children[0].type).toBe('text');
		expect(widget.children[1].type).toBe('spacer');
	});

	it('parses row, tabs, bar, image', () => {
		const row = parseLayout('{"type":"row","children":[]}');
		expect(row.children).toHaveLength(0);

		const tabs = parseLayout('{"type":"tabs","tabs":[{"title":"Info","child":{"type":"text","text":"x"}}]}');
		expect(tabs.tabs[0].title).toBe('Info');

		const bar = parseLayout('{"type":"bar","value":"$hp","max":100,"height":12,"label":"{hp} HP"}');
		expect(bar.valueKey).toBe('hp');
		expect(bar.max).toBe(100);
		expect(bar.label).toBe('{hp} HP');

		const image = parseLayout('{"type":"image","src":"asset:icon.png"}');
		expect(image.src).toBe('asset:icon.png');
	});

	it('bar without a label defaults to null (no label part generated)', () => {
		const bar = parseLayout('{"type":"bar","value":"$hp","max":100}');
		expect(bar.label).toBeNull();
	});

	it('parses visibleIf and defaults', () => {
		const widget = parseLayout('{"type":"spacer","size":4,"visibleIf":"$hasItem"}');
		expect(widget.visibleIf).toBe('hasItem');
	});

	it('no visibleIf means always visible', () => {
		const widget = parseLayout('{"type":"spacer","size":4}');
		expect(widget.visibleIf).toBeNull();
	});

	it('rejects unknown type', () => {
		expect(() => parseLayout('{"type":"nonsense"}')).toThrow(InvalidLayoutError);
	});

	it('parses list', () => {
		const widget = parseLayout(
			'{"type":"list","items":"$party","empty":"No Pokemon","template":{"type":"text","text":"{name}"}}',
		);
		expect(widget.itemsPath).toBe('party');
		expect(widget.emptyText).toBe('No Pokemon');
		expect(widget.template.type).toBe('text');
	});

	it('list without template is rejected', () => {
		expect(() => parseLayout('{"type":"list","items":"$party"}')).toThrow(InvalidLayoutError);
	});

	it('parses box legacy keys only when present in the source JSON', () => {
		const widget = parseLayout(
			'{"type":"box","width":340,"height":160,"background":"#192134","cornerRadius":16,"borderColor":"#DC2626","borderWidth":2,"padding":12,"child":{"type":"text","text":"hi"}}',
		);
		expect(widget.legacy).toEqual({
			width: 340,
			height: 160,
			background: '#192134',
			cornerRadius: 16,
			borderColor: '#DC2626',
			borderWidth: 2,
			padding: 12,
		});
		expect(widget.children).toHaveLength(1);
		expect(widget.children[0].type).toBe('text');
	});

	it('box with only child and no legacy keys has an empty legacy map', () => {
		const widget = parseLayout('{"type":"box","child":{"type":"spacer","size":4}}');
		expect(widget.legacy).toEqual({});
	});

	it('parses box with children array', () => {
		const widget = parseLayout('{"type":"box","children":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}');
		expect(widget.children).toHaveLength(2);
		expect(widget.children[0].type).toBe('text');
		expect(widget.children[1].type).toBe('text');
	});

	it('box with both child and children is rejected', () => {
		expect(() =>
			parseLayout('{"type":"box","child":{"type":"spacer","size":4},"children":[{"type":"spacer","size":4}]}'),
		).toThrow(InvalidLayoutError);
	});

	it('box without child is rejected', () => {
		expect(() => parseLayout('{"type":"box","background":"#000000"}')).toThrow(InvalidLayoutError);
	});

	it('parses text with a font legacy key', () => {
		const widget = parseLayout('{"type":"text","text":"hi","font":"fonts/PressStart2P.ttf"}');
		expect(widget.legacy.font).toBe('fonts/PressStart2P.ttf');
	});

	it('parses id, class, and inline style', () => {
		const widget = parseLayout(
			'{"type":"text","text":"hi","id":"hp-label","class":"card mon","style":{"padding":"8px","color":"red"}}',
		);
		expect(widget.meta.id).toBe('hp-label');
		expect(widget.meta.classes).toEqual(['card', 'mon']);
		expect(widget.meta.inlineStyle).toEqual({ padding: '8px', color: 'red' });
	});

	it('missing style meta defaults to empty', () => {
		const widget = parseLayout('{"type":"spacer","size":4}');
		expect(widget.meta.id).toBeNull();
		expect(widget.meta.classes).toEqual([]);
		expect(widget.meta.inlineStyle).toEqual({});
		expect(widget.meta.classIf).toEqual({});
		expect(widget.meta.bindStyle).toEqual({});
	});

	it('parses classIf and bindStyle as binding maps', () => {
		const widget = parseLayout(
			'{"type":"box","child":{"type":"spacer","size":4},' +
				'"classIf":{"low":"$hpLow","fainted":"$fainted"},' +
				'"bindStyle":{"width":"{hpPct}%","--accent":"{typeColor}"}}',
		);
		expect(widget.meta.classIf).toEqual({ low: 'hpLow', fainted: 'fainted' });
		expect(widget.meta.bindStyle).toEqual({ width: '{hpPct}%', '--accent': '{typeColor}' });
	});
});

// ---- pages, button, onClick — ported from gbaduo's LayoutTest.kt ----------------------

describe('pages, button and onClick', () => {
	it('parses pages and buttons', () => {
		const pages = parseLayout(
			JSON.stringify({
				type: 'pages',
				state: 'screen',
				initial: 'b',
				pages: [
					{ name: 'a', child: { type: 'text', text: 'A' } },
					{
						name: 'b',
						child: {
							type: 'button',
							text: 'Go {x}',
							onClick: { navigate: 'a', state: 'screen' },
							children: [{ type: 'spacer' }],
						},
					},
				],
			}),
		);
		expect(pages.state).toBe('screen');
		expect(pages.initial).toBe('b');
		expect(pages.pages.map((p) => p.name)).toEqual(['a', 'b']);
		const button = pages.pages[1].child;
		expect(button.type).toBe('button');
		expect(button.meta.onClick).toEqual([{ kind: 'navigate', page: 'a', state: 'screen' }]);
		expect(button.children[0].type).toBe('text');
		expect(button.children[0].text).toBe('Go {x}');
		expect(button.children[0].meta.classes).toEqual(['label']);
		expect(button.children[1].type).toBe('spacer');
	});

	it('pages default to the first page and the page key', () => {
		const pages = parseLayout('{"type":"pages","pages":[{"name":"main","child":{"type":"spacer"}}]}');
		expect(pages.state).toBe('page');
		expect(pages.initial).toBe('main');
	});

	it('invalid pages are rejected', () => {
		const bad = [
			'{"type":"pages","pages":[]}',
			'{"type":"pages"}',
			'{"type":"pages","initial":"nope","pages":[{"name":"a","child":{"type":"spacer"}}]}',
			'{"type":"pages","pages":[{"name":"a","child":{"type":"spacer"}},{"name":"a","child":{"type":"spacer"}}]}',
			'{"type":"pages","state":"a.b","pages":[{"name":"a","child":{"type":"spacer"}}]}',
		];
		for (const json of bad) expect(() => parseLayout(json), json).toThrow(InvalidLayoutError);
	});

	it('onClick works on any widget and bad actions warn', () => {
		const parsed = parseLayoutWithWarnings(
			JSON.stringify({
				type: 'row',
				onClick: [{ set: { selected: '{@index}' } }, { navigate: 'detail' }],
				children: [{ type: 'text', text: 'x', onClick: 'sideways' }],
			}),
		);
		expect(parsed.root.meta.onClick).toEqual([
			{ kind: 'set', values: { selected: '{@index}' } },
			{ kind: 'navigate', page: 'detail', state: 'page' },
		]);
		expect(parsed.root.children[0].meta.onClick).toEqual([]);
		expect(parsed.warnings).toHaveLength(1);
		expect(parsed.warnings[0]).toContain('onClick');
	});
});
