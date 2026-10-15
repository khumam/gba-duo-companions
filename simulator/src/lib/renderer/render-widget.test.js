import { describe, it, expect, afterEach } from 'vitest';
import { parseLayout } from './parse-layout.js';
import { createRenderer, applyStackChildPlacement, applyBarAccentColors } from './render-widget.js';

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

	it('renders column children with gap spacers', () => {
		const widget = parseLayout(
			'{"type":"column","gap":8,"children":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}',
		);
		const renderer = createRenderer(packBaseUrl);
		const el = renderer.build(widget);
		expect(el.children).toHaveLength(3);
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
