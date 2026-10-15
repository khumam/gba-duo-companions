import { describe, it, expect, afterEach } from 'vitest';
import { parseLayout } from './parse-layout.js';
import { createRenderer, applyStackChildPlacement, applyBarAccentColors, applyScrollContainers } from './render-widget.js';

const packBaseUrl = '/packs/test-pack';

afterEach(() => {
	document.body.innerHTML = '';
	document.head.querySelectorAll('style[data-test]').forEach((el) => el.remove());
});

function injectTestStyle(cssText) {
	const style = document.createElement('style');
	style.setAttribute('data-test', '');
	style.textContent = cssText;
	document.head.appendChild(style);
	return style;
}

describe('createRenderer', () => {
	it('renders text and updates on interpolated bindings', () => {
		const widget = parseLayout('{"type":"text","text":"Money: {trainer.money}"}');
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		renderer.update({ trainer: { money: 3000 } });
		expect(el.textContent).toBe('Money: 3000');
	});

	it('turns a legacy column gap into a CSS gap, like Layout.kt legacyPx', () => {
		const widget = parseLayout(
			'{"type":"column","gap":8,"children":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}',
		);
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		expect(el.children).toHaveLength(2);
		expect(el.style.gap).toBe('18px');
		// display/flex-direction come from default.css, so pack CSS can override them.
		expect(el.style.display).toBe('');
	});

	it('only sizes an image/spacer inline when `size` is written', () => {
		const sized = createRenderer(packBaseUrl).build(parseLayout('{"type":"image","src":"asset:a.png","size":16}'));
		expect(sized.style.width).toBe('37px');
		const unsized = createRenderer(packBaseUrl).build(parseLayout('{"type":"image","src":"asset:a.png"}'));
		expect(unsized.style.width).toBe('');
		expect(unsized.getAttribute('src')).toBe('/packs/test-pack/assets/a.png');
	});

	it('resolves a $-bound image source on update', () => {
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(parseLayout('{"type":"image","src":"$detail.icon"}'));
		expect(el.getAttribute('src')).toMatch(/^data:image\/gif/);
		renderer.update({ detail: { icon: 'asset:mon-fire.png' } });
		expect(el.getAttribute('src')).toBe('/packs/test-pack/assets/mon-fire.png');
		renderer.update({ detail: { icon: 'gfx:party0' } });
		expect(el.getAttribute('src')).toMatch(/^data:image\/gif/);
	});

	it('applies box legacy keys only when present, regardless of a stylesheet existing', () => {
		const widget = parseLayout('{"type":"box","width":340,"background":"#192134","child":{"type":"text","text":"hi"}}');
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		expect(el.style.width).toBe('784px');
		expect(el.style.backgroundColor).toBe('rgb(25, 33, 52)');
		expect(el.style.height).toBe('');
		expect(el.style.borderWidth).toBe('');
	});

	it('applies text legacy keys only when present', () => {
		const widget = parseLayout('{"type":"text","text":"hi","size":20,"color":"#ff0000","bold":true}');
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		expect(el.style.fontSize).toBe('46px');
		expect(el.style.color).toBe('rgb(255, 0, 0)');
		expect(el.style.fontWeight).toBe('bold');
	});

	it('applies visibleIf visibility', () => {
		const widget = parseLayout('{"type":"text","text":"x","visibleIf":"$hasItem"}');
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		renderer.update({ hasItem: false });
		expect(el.style.display).toBe('none');
		renderer.update({ hasItem: true });
		expect(el.style.display).not.toBe('none');
	});

	it('generates a bar > fill part, sized by value/max', () => {
		const widget = parseLayout('{"type":"bar","value":"$hp","max":100}');
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		renderer.update({ hp: 50 });
		const fill = el.querySelector(':scope > [data-type="fill"]');
		expect(fill.className).toBe('fill');
		expect(fill.style.width).toBe('50%');
	});

	it('only generates a bar > label part when the widget declares a label', () => {
		const withLabel = createRenderer(packBaseUrl).build(parseLayout('{"type":"bar","value":"$hp","max":100,"label":"{hp} HP"}'));
		expect(withLabel.querySelector(':scope > [data-type="label"]')).not.toBeNull();

		const withoutLabel = createRenderer(packBaseUrl).build(parseLayout('{"type":"bar","value":"$hp","max":100}'));
		expect(withoutLabel.querySelector(':scope > [data-type="label"]')).toBeNull();
	});

	it('generates tab-bar > tab and tab-content parts, and toggles .active on the selected tab', () => {
		const widget = parseLayout(
			'{"type":"tabs","tabs":[{"title":"A","child":{"type":"text","text":"a"}},{"title":"B","child":{"type":"text","text":"b"}}]}',
		);
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		const tabBar = el.querySelector(':scope > [data-type="tab-bar"]');
		const tabs = tabBar.querySelectorAll('[data-type="tab"]');
		const content = el.querySelector(':scope > [data-type="tab-content"]');

		expect(tabs).toHaveLength(2);
		expect(tabs[0].classList.contains('active')).toBe(true);
		expect(tabs[1].classList.contains('active')).toBe(false);
		expect(content.textContent).toBe('a');

		tabs[1].dispatchEvent(new Event('click', { bubbles: true }));
		expect(tabs[0].classList.contains('active')).toBe(false);
		expect(tabs[1].classList.contains('active')).toBe(true);
		expect(content.textContent).toBe('b');
	});

	it('resolves a bar\'s accent-color correctly in a non-default tab once selected, even though it sat detached until the click', () => {
		injectTestStyle('[data-type="bar"] { accent-color: rgb(232, 113, 143); }');
		const widget = parseLayout(
			'{"type":"tabs","tabs":[' +
				'{"title":"A","child":{"type":"text","text":"a"}},' +
				'{"title":"B","child":{"type":"bar","value":"$hp","max":100}}' +
				']}',
		);
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		document.body.appendChild(el);
		renderer.update({ hp: 50 });

		const tabs = el.querySelectorAll('[data-type="tab"]');
		tabs[1].dispatchEvent(new Event('click', { bubbles: true }));

		const fill = el.querySelector('[data-type="bar"] > [data-type="fill"]');
		expect(fill.style.backgroundColor).toBe('rgb(232, 113, 143)');
	});

	it('renders a list, rebuilding only when item count changes, with a renamed empty part', () => {
		const widget = parseLayout(
			'{"type":"list","items":"$party","empty":"No Pokemon","template":{"type":"text","text":"{name}"}}',
		);
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		renderer.update({ party: [{ name: 'BULBASAUR' }, { name: 'CHARMANDER' }] });
		const items = el.querySelectorAll('[data-list-item]');
		expect(items).toHaveLength(2);
		expect(items[0].textContent).toBe('BULBASAUR');

		const empty = el.querySelector(':scope > [data-type="empty"]');
		expect(empty.className).toBe('empty');
		expect(empty.style.display).toBe('none');

		renderer.update({ party: [] });
		expect(empty.style.display).not.toBe('none');
		expect(empty.textContent).toBe('No Pokemon');
	});

	it('sets data-type, id, class, and inline style from widget meta on every element', () => {
		const widget = parseLayout('{"type":"text","text":"hi","id":"hp-label","class":"card mon","style":{"padding":"8px"}}');
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		expect(el.dataset.type).toBe('text');
		expect(el.id).toBe('hp-label');
		expect(el.className).toBe('card mon');
		expect(el.style.padding).toBe('8px');
	});

	it('toggles classIf classes and applies bindStyle on update', () => {
		const widget = parseLayout(
			'{"type":"text","text":"HP","classIf":{"low":"$hpLow"},"bindStyle":{"width":"{hpPct}%"}}',
		);
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		renderer.update({ hpLow: true, hpPct: 30 });
		expect(el.classList.contains('low')).toBe(true);
		expect(el.style.width).toBe('30%');
		renderer.update({ hpLow: false, hpPct: 90 });
		expect(el.classList.contains('low')).toBe(false);
		expect(el.style.width).toBe('90%');
	});
});

describe('applyBarAccentColors', () => {
	it("colors a bar fill from the bar element's own resolved accent-color", () => {
		injectTestStyle('[data-type="bar"] { accent-color: rgb(74, 222, 128); }');
		const widget = parseLayout('{"type":"bar","value":"$hp","max":100}');
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		document.body.appendChild(el);
		renderer.update({ hp: 50 });

		applyBarAccentColors(el);

		const fill = el.querySelector(':scope > [data-type="fill"]');
		expect(fill.style.backgroundColor).toBe('rgb(74, 222, 128)');
	});
});

describe('applyBarAccentColors keeps a fill that has its own background', () => {
	it('like CompanionScreen.boxPaint, accent-color is only the fallback', () => {
		injectTestStyle(`
			[data-type="bar"] { accent-color: rgb(1, 2, 3); }
			.styled > [data-type="fill"] { background-color: rgb(240, 128, 48); }
		`);
		const styled = createRenderer(packBaseUrl).build(parseLayout('{"type":"bar","class":"styled","value":"$v","max":10}'));
		const plain = createRenderer(packBaseUrl).build(parseLayout('{"type":"bar","value":"$v","max":10}'));
		document.body.append(styled, plain);
		applyBarAccentColors(document.body);
		applyBarAccentColors(document.body); // re-running must not get stuck on its own inline value
		expect(styled.querySelector('[data-type="fill"]').style.backgroundColor).toBe('');
		expect(plain.querySelector('[data-type="fill"]').style.backgroundColor).toBe('rgb(1, 2, 3)');
	});
});

describe('applyStackChildPlacement', () => {
	it('places non-absolute children of a --gbaduo-stack element into the same grid cell', () => {
		injectTestStyle(`
			.stack-container { display: grid; --gbaduo-stack: 1; }
			.fill-child { position: absolute; }
		`);
		const container = document.createElement('div');
		container.className = 'stack-container';
		const overlay = document.createElement('div');
		overlay.className = 'overlay-child';
		const fill = document.createElement('div');
		fill.className = 'fill-child';
		container.appendChild(overlay);
		container.appendChild(fill);
		document.body.appendChild(container);

		applyStackChildPlacement(container);

		expect(overlay.style.gridRow).toBe('1');
		expect(overlay.style.gridColumn).toBe('1');
		expect(fill.style.gridRow).toBe('');
	});
});

// ---- onClick, pages and UI state — ported from gbaduo's CompanionTreeTest.kt ----------

const partyWithDetail = JSON.stringify({
	type: 'pages',
	pages: [
		{
			name: 'party',
			child: {
				type: 'list',
				items: '$party',
				template: {
					type: 'row',
					class: 'mon',
					onClick: [{ set: { selected: '{@index}', name: '{name}' } }, { navigate: 'detail' }],
					children: [{ type: 'text', text: '{name}' }],
				},
			},
		},
		{
			name: 'detail',
			child: {
				type: 'column',
				children: [
					{ type: 'button', text: 'Back', onClick: 'back' },
					{ type: 'text', text: '{detail.name} #{ui.selected}' },
					{ type: 'button', text: 'Heal', onClick: { call: 'heal', args: ['{ui.selected}', '{detail.name}'] } },
				],
			},
		},
	],
});

const isHidden = (el) => el.hasAttribute('data-gbaduo-hidden');
const tap = (el) => el.dispatchEvent(new Event('click', { bubbles: true }));

describe('onClick, pages and UI state', () => {
	it('tapping a list item navigates to its detail page', () => {
		const uiChanges = [];
		const renderer = createRenderer(packBaseUrl, { onUiChange: (ui) => uiChanges.push(ui) });
		const el = renderer.build(parseLayout(partyWithDetail));
		renderer.update({ party: [{ name: 'Bulba' }, { name: 'Pika' }], detail: { name: '?' } });
		const [partyPage, detailPage] = el.children;
		expect(renderer.ui).toEqual({ page: 'party' });
		expect(isHidden(partyPage)).toBe(false);
		expect(isHidden(detailPage)).toBe(true);

		tap(partyPage.children[2]); // "Pika" (children[0] is the list's empty part)
		expect(renderer.ui).toEqual({ page: 'detail', selected: 1, name: 'Pika' });
		expect(uiChanges).toEqual([renderer.ui]);
		expect(isHidden(partyPage)).toBe(true);
		expect(isHidden(detailPage)).toBe(false);
		expect(detailPage.children[1].textContent).toBe('? #1'); // bindings re-ran with the new ui at once

		renderer.update({ party: [], detail: { name: 'Pika' } });
		expect(detailPage.children[1].textContent).toBe('Pika #1');

		tap(detailPage.children[0]); // Back
		expect(renderer.ui.page).toBe('party');
		expect(isHidden(partyPage)).toBe(false);
		expect(renderer.ui.selected).toBe(1); // other ui state stays
	});

	it('a call runs after the UI change from the same tap', () => {
		const events = [];
		const renderer = createRenderer(packBaseUrl, {
			onUiChange: (ui) => events.push(`ui ${ui.selected}`),
			onCall: (name, args) => events.push(`call ${name} ${JSON.stringify(args)}`),
		});
		const el = renderer.build(
			parseLayout(
				JSON.stringify({
					type: 'list',
					items: '$party',
					template: {
						type: 'box',
						onClick: [{ call: 'open', args: ['{@index}', '{name}', 'Lv {level}', true] }, { set: { selected: '{@index}' } }],
						children: [],
					},
				}),
			),
		);
		renderer.update({ party: [{ name: 'A', level: 5 }, { name: 'B', level: 7 }] });
		tap(el.children[2]);
		expect(events).toEqual(['ui 1', 'call open [1,"B","Lv 7",true]']);
	});

	it('back without history returns to the initial page, and history nests', () => {
		const renderer = createRenderer(packBaseUrl);
		renderer.build(
			parseLayout(
				JSON.stringify({
					type: 'pages',
					initial: 'a',
					pages: ['a', 'b', 'c'].map((name) => ({ name, child: { type: 'spacer' } })),
				}),
			),
		);
		renderer.update({});
		renderer.perform([
			{ kind: 'navigate', page: 'b', state: 'page' },
			{ kind: 'navigate', page: 'c', state: 'page' },
		]);
		expect(renderer.ui.page).toBe('c');
		renderer.perform([{ kind: 'back', state: 'page' }]);
		expect(renderer.ui.page).toBe('b');
		renderer.perform([{ kind: 'back', state: 'page' }]);
		expect(renderer.ui.page).toBe('a');
		renderer.perform([{ kind: 'set', values: { page: 'b' } }]);
		renderer.perform([{ kind: 'back', state: 'page' }]); // a plain `set` leaves no history
		expect(renderer.ui.page).toBe('a');
	});

	it('an unknown page shows the initial one, and no change reports nothing', () => {
		let changes = 0;
		const renderer = createRenderer(packBaseUrl, { onUiChange: () => changes++ });
		const el = renderer.build(
			parseLayout(
				JSON.stringify({ type: 'pages', pages: ['a', 'b'].map((name) => ({ name, child: { type: 'spacer' } })) }),
			),
		);
		renderer.update({});
		renderer.perform([{ kind: 'set', values: { page: 'typo' } }]);
		expect(isHidden(el.children[0])).toBe(false);
		expect(isHidden(el.children[1])).toBe(true);
		renderer.perform([{ kind: 'set', values: { page: 'typo' } }]);
		expect(changes).toBe(1);
	});

	it('script results drive navigation without a context', () => {
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(parseLayout(partyWithDetail));
		renderer.update({ party: [] });
		// What `return { set = { selected = 0 }, navigate = "detail" }` from actions.* becomes.
		renderer.perform([
			{ kind: 'set', values: { selected: 0 } },
			{ kind: 'navigate', page: 'detail', state: 'page' },
		]);
		expect(renderer.ui.page).toBe('detail');
		expect(isHidden(el.children[1])).toBe(false);
		expect(el.children[1].children[1].textContent).toBe(' #0');
	});

	it('buttons get a label child and :pressed while held', () => {
		const el = createRenderer(packBaseUrl).build(
			parseLayout(JSON.stringify({ type: 'button', text: 'Go', onClick: { navigate: 'x' } })),
		);
		expect(el.dataset.type).toBe('button');
		expect(el.children[0].dataset.type).toBe('text');
		expect(el.children[0].className).toBe('label');
		expect(el.children[0].textContent).toBe('Go');
		el.dispatchEvent(new Event('pointerdown'));
		expect(el.classList.contains('pressed')).toBe(true);
		el.dispatchEvent(new Event('pointerup'));
		expect(el.classList.contains('pressed')).toBe(false);
	});

	it('$ui is readable in bindings, including visibleIf', () => {
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(
			parseLayout(
				JSON.stringify({
					type: 'column',
					children: [
						{ type: 'text', text: 'all', visibleIf: '$ui.showAll' },
						{ type: 'button', text: 'Show', onClick: { set: { showAll: true } } },
					],
				}),
			),
		);
		renderer.update({});
		expect(el.children[0].style.display).toBe('none');
		tap(el.children[1]);
		expect(el.children[0].style.display).not.toBe('none');
	});
});

describe('applyScrollContainers', () => {
	it("a column scroll container's items don't shrink — the engine's verticalScroll lays them out unbounded", () => {
		injectTestStyle(`
			.scroller { display: flex; flex-direction: column; overflow: auto; }
			.row-scroller { display: flex; flex-direction: row; overflow: auto; }
		`);
		const scroller = document.createElement('div');
		scroller.className = 'scroller';
		scroller.append(document.createElement('div'), document.createElement('div'));
		const row = document.createElement('div');
		row.className = 'row-scroller';
		row.append(document.createElement('div'));
		document.body.append(scroller, row);

		applyScrollContainers(document.body);

		expect([...scroller.children].map((c) => c.style.flexShrink)).toEqual(['0', '0']);
		expect(row.children[0].style.flexShrink).toBe(''); // a row's width is still bounded
	});
});

// ---- update() can drive pages — ported from CompanionTreeTest.kt ----------------------

const battlePages = JSON.stringify({
	type: 'pages',
	pages: [
		{ name: 'overworld', child: { type: 'text', text: 'walking' } },
		{ name: 'battle', child: { type: 'text', text: 'vs {battle.foe} · {ui.page}' } },
	],
});

describe('a ui entry from update() runs as UI actions', () => {
	it('navigates after the data is applied', () => {
		let changes = 0;
		const renderer = createRenderer(packBaseUrl, { onUiChange: () => changes++ });
		const el = renderer.build(parseLayout(battlePages));
		renderer.update({ battle: { foe: 'Brock' } });
		expect(renderer.ui.page).toBe('overworld');

		renderer.update({ battle: { foe: 'Onix' }, ui: { navigate: 'battle' } });
		expect(renderer.ui.page).toBe('battle');
		expect(el.children[0].hasAttribute('data-gbaduo-hidden')).toBe(true);
		expect(el.children[1].hasAttribute('data-gbaduo-hidden')).toBe(false);
		expect(el.children[1].textContent).toBe('vs Onix · battle');
		expect(changes).toBe(1);

		renderer.update({ battle: { foe: 'Onix' }, ui: { navigate: 'battle' } });
		expect(changes).toBe(1);

		renderer.update({ ui: { back: true } });
		expect(renderer.ui.page).toBe('overworld');
	});

	it('can set keys but not call', () => {
		let calls = 0;
		const renderer = createRenderer(packBaseUrl, { onCall: () => calls++ });
		renderer.build(parseLayout(battlePages));
		renderer.update({ ui: [{ set: { turn: 3 } }, { call: 'heal' }] });
		expect(renderer.ui.turn).toBe(3);
		expect(calls).toBe(0);
	});
});

describe('nested lists', () => {
	it("iterate the parent item's own list first, like CompanionTree.buildList", () => {
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(
			parseLayout(
				JSON.stringify({
					type: 'list',
					items: '$mons',
					template: { type: 'list', items: '$types', template: { type: 'text', text: '{name}' } },
				}),
			),
		);
		renderer.update({ mons: [{ types: [{ name: 'Grass' }, { name: 'Poison' }] }, { types: [{ name: 'Fire' }] }], types: [] });
		const inner = [...el.querySelectorAll(':scope > [data-list-item]')].map((m) =>
			[...m.querySelectorAll('[data-list-item]')].map((t) => t.textContent),
		);
		expect(inner).toEqual([['Grass', 'Poison'], ['Fire']]);
	});
});
