import { describe, it, expect, afterEach } from 'vitest';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { parseLayout } from './parse-layout.js';
import { createRenderer, applyStackChildPlacement, applyBarAccentColors } from './render-widget.js';
import { prepareStylesheetCss } from './prepare-stylesheet.js';

const PACKS_DIR = join(process.cwd(), '..', 'packs');
const DEFAULT_CSS = readFileSync(
	join(process.cwd(), '..', '..', 'gbaduo', 'app', 'src', 'main', 'assets', 'companion', 'default.css'),
	'utf-8',
);

// harvest-moon-fomt-companion has no preview-data.json (built before that convention existed
// for it); this fixture matches its real binding shape (a `$loves` list of bachelorette
// cards, each with a `bar` bound to `$pct`) closely enough to exercise its `bar` widgets.
const PREVIEW_DATA_FALLBACK = {
	'harvest-moon-fomt-companion': {
		money: 5420,
		year: 1,
		day: 12,
		time: '08:45',
		weatherToday: 3,
		weatherTomorrow: 1,
		horseRaceMedals: 0,
		frisbeeRecord: 0,
		loves: [
			{ name: 'Popuri', value: 240, pct: 0.24 },
			{ name: 'Mary', value: 500, pct: 0.5 },
		],
	},
};

function loadPreviewData(packId, packDir) {
	const previewDataPath = join(packDir, 'preview-data.json');
	if (existsSync(previewDataPath)) return JSON.parse(readFileSync(previewDataPath, 'utf-8'));
	return PREVIEW_DATA_FALLBACK[packId] ?? {};
}

afterEach(() => {
	document.body.innerHTML = '';
	document.head.querySelectorAll('style[data-real-pack-test]').forEach((el) => el.remove());
});

describe.each(['pokemon-firered-companion', 'harvest-moon-fomt-companion'])('real pack: %s', (packId) => {
	it('renders without throwing and every bar gets a fill part', () => {
		const packDir = join(PACKS_DIR, packId);
		const layoutJson = readFileSync(join(packDir, 'layout.json'), 'utf-8');
		const styleCss = readFileSync(join(packDir, 'style.css'), 'utf-8');
		const previewData = loadPreviewData(packId, packDir);

		const widget = parseLayout(layoutJson);
		const styleEl = document.createElement('style');
		styleEl.setAttribute('data-real-pack-test', '');
		styleEl.textContent = prepareStylesheetCss(styleCss, `/packs/${packId}`, DEFAULT_CSS);
		document.head.appendChild(styleEl);

		const renderer = createRenderer(`/packs/${packId}`);
		const rootEl = renderer.build(widget);
		document.body.appendChild(rootEl);

		expect(() => renderer.update(previewData)).not.toThrow();

		// Only the selected tab's content is attached to the DOM (matching the real engine:
		// inactive tabs aren't part of the visible composition). Click through every tab,
		// checking after each click, so a bar living in any tab (not just the default one —
		// e.g. harvest-moon's Love tab) is actually reached and checked at some point.
		let foundBarWithFill = false;
		const tabs = [...rootEl.querySelectorAll('[data-type="tab"]')];
		for (const tab of tabs) {
			tab.dispatchEvent(new Event('click', { bubbles: true }));
			applyStackChildPlacement(rootEl);
			applyBarAccentColors(rootEl);
			const bars = rootEl.querySelectorAll('[data-type="bar"]');
			bars.forEach((bar) => {
				expect(bar.querySelector(':scope > [data-type="fill"]')).not.toBeNull();
				foundBarWithFill = true;
			});
		}
		expect(foundBarWithFill).toBe(true);
	});

	it('every tabs widget gets a tab per entry plus a tab-content', () => {
		const packDir = join(PACKS_DIR, packId);
		const layoutJson = readFileSync(join(packDir, 'layout.json'), 'utf-8');
		const widget = parseLayout(layoutJson);
		const renderer = createRenderer(`/packs/${packId}`);
		const rootEl = renderer.build(widget);
		document.body.appendChild(rootEl);

		const tabsContainers = rootEl.querySelectorAll('[data-type="tabs"]');
		expect(tabsContainers.length).toBeGreaterThan(0);
		tabsContainers.forEach((tabsEl) => {
			const tabBar = tabsEl.querySelector(':scope > [data-type="tab-bar"]');
			const content = tabsEl.querySelector(':scope > [data-type="tab-content"]');
			expect(tabBar).not.toBeNull();
			expect(content).not.toBeNull();
			expect(tabBar.querySelectorAll('[data-type="tab"]').length).toBeGreaterThan(0);
		});
	});
});
