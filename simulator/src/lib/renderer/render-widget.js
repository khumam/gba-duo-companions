import { resolve, interpolate, isTruthy, asNumber, asList, scopedValues } from './binding.js';

// Matches the Thor's companion display: 369dpi / 160 = 2.30625x, the same multiplier
// WidgetRenderer.kt's `px(dpValue) = (dpValue * dp).toInt()` uses. Only applies to legacy
// numeric widget keys (image/spacer size, legacy box-model keys) — CSS lengths in a pack's
// style.css are rescaled separately, by prepare-stylesheet.js's rescalePxLengths.
const DEVICE_DENSITY = 2.30625;

function px(dpValue) {
	return Math.round(dpValue * DEVICE_DENSITY);
}

/**
 * @param packBaseUrl base path assets/fonts resolve against, e.g. `/packs/{id}`.
 */
export function createRenderer(packBaseUrl) {
	const bindings = [];

	function applyMeta(el, widget) {
		el.dataset.type = widget.type;
		if (widget.meta?.id) el.id = widget.meta.id;
		if (widget.meta?.classes?.length) el.className = widget.meta.classes.join(' ');
		if (widget.meta?.inlineStyle) {
			for (const [prop, value] of Object.entries(widget.meta.inlineStyle)) {
				el.style.setProperty(prop, value);
			}
		}
		const classIfEntries = Object.entries(widget.meta?.classIf ?? {});
		const bindStyleEntries = Object.entries(widget.meta?.bindStyle ?? {});
		if (classIfEntries.length || bindStyleEntries.length) {
			bindings.push((ctx) => {
				for (const [className, path] of classIfEntries) {
					el.classList.toggle(className, isTruthy(resolve(path, ctx)));
				}
				for (const [prop, template] of bindStyleEntries) {
					el.style.setProperty(prop, interpolate(template, ctx));
				}
			});
		}
	}

	function applyVisibility(el, visibleIf) {
		if (visibleIf == null) return;
		bindings.push((ctx) => {
			el.style.display = isTruthy(resolve(visibleIf, ctx)) ? '' : 'none';
		});
	}

	function inflate(widget) {
		switch (widget.type) {
			case 'column':
				return buildBox(widget, 'column');
			case 'row':
				return buildBox(widget, 'row');
			case 'tabs':
				return buildTabs(widget);
			case 'text':
				return buildText(widget);
			case 'bar':
				return buildBar(widget);
			case 'image':
				return buildImage(widget);
			case 'spacer':
				return buildSpacer(widget);
			case 'list':
				return buildList(widget);
			case 'box':
				return buildStyledBox(widget);
			default:
				throw new Error(`Unknown widget type '${widget.type}'`);
		}
	}

	function buildBox(widget, direction) {
		const el = document.createElement('div');
		applyMeta(el, widget);
		el.style.display = 'flex';
		el.style.flexDirection = direction;
		widget.children.forEach((child, i) => {
			el.appendChild(inflate(child));
			if (i < widget.children.length - 1 && widget.gap > 0) {
				const spacer = document.createElement('div');
				if (direction === 'column') spacer.style.height = `${px(widget.gap)}px`;
				else spacer.style.width = `${px(widget.gap)}px`;
				el.appendChild(spacer);
			}
		});
		applyVisibility(el, widget.visibleIf);
		return el;
	}

	function applyLegacyText(el, legacy) {
		// Rescaled by DEVICE_DENSITY like every other legacy dimension: at the default system
		// font scale, Compose's `.sp` text sizing and `.dp` box-model sizing both resolve to
		// the same pixel math, so this stays faithful without needing a separate "sp" concept.
		if ('size' in legacy) el.style.fontSize = `${px(legacy.size)}px`;
		if ('color' in legacy) el.style.color = legacy.color;
		if ('bold' in legacy && legacy.bold) el.style.fontWeight = 'bold';
		if ('font' in legacy) {
			const fontFamily = legacy.font.replace(/[^a-zA-Z0-9]/g, '_');
			ensureFontFace(fontFamily, `${packBaseUrl}/assets/${legacy.font}`);
			el.style.fontFamily = `"${fontFamily}"`;
		}
	}

	function buildText(widget) {
		const el = document.createElement('div');
		applyMeta(el, widget);
		applyLegacyText(el, widget.legacy);
		el.textContent = widget.text;
		bindings.push((ctx) => {
			el.textContent = interpolate(widget.text, ctx);
		});
		applyVisibility(el, widget.visibleIf);
		return el;
	}

	function buildBar(widget) {
		const el = document.createElement('div');
		applyMeta(el, widget);
		const fill = document.createElement('div');
		fill.dataset.type = 'fill';
		fill.className = 'fill';
		el.appendChild(fill);
		let labelEl = null;
		if (widget.label != null) {
			labelEl = document.createElement('div');
			labelEl.dataset.type = 'label';
			labelEl.className = 'label';
			labelEl.textContent = widget.label;
			el.appendChild(labelEl);
		}
		bindings.push((ctx) => {
			const value = asNumber(resolve(widget.valueKey, ctx));
			const maxValue = widget.maxKey ? asNumber(resolve(widget.maxKey, ctx)) : widget.max;
			const max = Math.max(maxValue, 1);
			const clamped = Math.min(Math.max(value, 0), max);
			const percent = clamped / max;
			fill.style.width = `${percent * 100}%`;
			if (labelEl) labelEl.textContent = interpolate(widget.label, ctx);
		});
		applyVisibility(el, widget.visibleIf);
		return el;
	}

	function buildImage(widget) {
		const el = document.createElement('img');
		applyMeta(el, widget);
		el.style.width = `${px(widget.size)}px`;
		el.style.height = `${px(widget.size)}px`;
		if (widget.src.startsWith('asset:')) {
			el.src = `${packBaseUrl}/assets/${widget.src.slice('asset:'.length)}`;
		} else if (widget.src.startsWith('gfx:')) {
			el.alt = '[gfx: not renderable in simulator]';
		} else if (widget.src.startsWith('$')) {
			el.alt = '[dynamic sprite: not renderable in simulator]';
		}
		applyVisibility(el, widget.visibleIf);
		return el;
	}

	function buildSpacer(widget) {
		const el = document.createElement('div');
		applyMeta(el, widget);
		el.style.width = `${px(widget.size)}px`;
		el.style.height = `${px(widget.size)}px`;
		applyVisibility(el, widget.visibleIf);
		return el;
	}

	function applyLegacyBox(el, legacy) {
		if ('width' in legacy) el.style.width = `${px(legacy.width)}px`;
		if ('height' in legacy) el.style.height = `${px(legacy.height)}px`;
		if ('padding' in legacy) el.style.padding = `${px(legacy.padding)}px`;
		if ('background' in legacy) el.style.backgroundColor = legacy.background;
		if ('cornerRadius' in legacy) el.style.borderRadius = `${px(legacy.cornerRadius)}px`;
		if ('borderWidth' in legacy) {
			el.style.borderStyle = 'solid';
			el.style.borderWidth = `${px(legacy.borderWidth)}px`;
		}
		if ('borderColor' in legacy) el.style.borderColor = legacy.borderColor;
	}

	function buildStyledBox(widget) {
		const el = document.createElement('div');
		applyMeta(el, widget);
		applyLegacyBox(el, widget.legacy);
		widget.children.forEach((child) => el.appendChild(inflate(child)));
		applyVisibility(el, widget.visibleIf);
		return el;
	}

	function buildTabs(widget) {
		const container = document.createElement('div');
		applyMeta(container, widget);

		const tabBar = document.createElement('div');
		tabBar.dataset.type = 'tab-bar';
		tabBar.className = 'tab-bar';

		const content = document.createElement('div');
		content.dataset.type = 'tab-content';
		content.className = 'tab-content';

		const childEls = widget.tabs.map((tab) => inflate(tab.child));
		const tabEls = [];

		function selectTab(index) {
			content.innerHTML = '';
			content.appendChild(childEls[index]);
			tabEls.forEach((tabEl, i) => tabEl.classList.toggle('active', i === index));
		}

		widget.tabs.forEach((tab, i) => {
			const tabEl = document.createElement('div');
			tabEl.dataset.type = 'tab';
			tabEl.className = 'tab';
			tabEl.textContent = tab.title;
			tabEl.addEventListener('click', () => selectTab(i));
			tabEl.addEventListener('pointerdown', () => tabEl.classList.add('pressed'));
			tabEl.addEventListener('pointerup', () => tabEl.classList.remove('pressed'));
			tabEl.addEventListener('pointerleave', () => tabEl.classList.remove('pressed'));
			tabBar.appendChild(tabEl);
			tabEls.push(tabEl);
		});

		container.appendChild(tabBar);
		container.appendChild(content);
		selectTab(0);
		applyVisibility(container, widget.visibleIf);
		return container;
	}

	/**
	 * Data-driven repeat: rebuilds item elements only when the resolved list's length
	 * changes; otherwise just re-binds each existing item renderer. Mirrors
	 * CompanionTree.kt's list handling.
	 */
	function buildList(widget) {
		const container = document.createElement('div');
		applyMeta(container, widget);
		const emptyEl = document.createElement('div');
		emptyEl.dataset.type = 'empty';
		emptyEl.className = 'empty';
		emptyEl.textContent = widget.emptyText ?? '';
		emptyEl.style.display = 'none';
		container.appendChild(emptyEl);

		let itemRenderers = [];

		bindings.push((ctx) => {
			const snapshotRoot = ctx != null && typeof ctx === 'object' && 'root' in ctx ? ctx.root : ctx;
			const items = asList(resolve(widget.itemsPath, snapshotRoot));

			if (items.length !== itemRenderers.length) {
				while (container.children.length > 1) {
					container.removeChild(container.lastChild);
				}
				itemRenderers = items.map(() => {
					const renderer = createRenderer(packBaseUrl);
					const el = renderer.build(widget.template);
					el.setAttribute('data-list-item', '');
					container.appendChild(el);
					return renderer;
				});
			}

			emptyEl.style.display = items.length === 0 && widget.emptyText != null ? '' : 'none';

			itemRenderers.forEach((renderer, index) => {
				renderer.update(scopedValues(items[index] ?? null, index, snapshotRoot));
			});
		});
		applyVisibility(container, widget.visibleIf);
		return container;
	}

	return {
		build(widget) {
			bindings.length = 0;
			return inflate(widget);
		},
		update(context) {
			for (const apply of bindings) apply(context);
		},
	};
}

/**
 * `display: stack` (prepare-stylesheet.js's `translateStackDisplay`) is rewritten to
 * `display: grid` plus a `--gbaduo-stack: 1` marker, since browsers have no native overlay-
 * stack layout. Once [root] is attached to a real document (so its stylesheet has actually
 * matched), this places every non-absolutely-positioned direct child of a marked element
 * into the same grid cell — reproducing Compose's `Box` overlay stacking using only standard
 * grid placement. Safe to call repeatedly (e.g. after every preview-data update):
 * already-placed children are just reassigned the same value. Call after inserting the
 * built tree into the DOM.
 */
export function applyStackChildPlacement(root) {
	const candidates = [root, ...root.querySelectorAll('*')];
	for (const el of candidates) {
		const computed = getComputedStyle(el);
		// `--gbaduo-stack` is a custom property, which *inherits* — every descendant of a real
		// stack container reports the same value via inheritance, not just the container
		// itself. `display` is never inherited, so checking it too (must be `grid`, set
		// directly by translateStackDisplay on this exact element) is what actually narrows
		// this down to genuine stack containers instead of every element nested inside one.
		if (computed.display !== 'grid') continue;
		if (computed.getPropertyValue('--gbaduo-stack').trim() !== '1') continue;
		for (const child of el.children) {
			if (getComputedStyle(child).position === 'absolute') continue;
			child.style.gridRow = '1';
			child.style.gridColumn = '1';
		}
	}
}

/**
 * `accent-color` is a real, inherited CSS property every browser resolves through the
 * normal cascade. CompanionScreen.kt reads it off a bar's *own* resolved style (not the
 * fill's) to color the fill — a pack sets `accent-color` on `bar`/a bar's class, never on
 * `.fill` directly. Call after [root] is attached to a real document.
 */
export function applyBarAccentColors(root) {
	const candidates = [root, ...root.querySelectorAll('*')].filter((el) => el.dataset?.type === 'bar');
	for (const barEl of candidates) {
		const fillEl = barEl.querySelector(':scope > [data-type="fill"]');
		if (fillEl) fillEl.style.backgroundColor = getComputedStyle(barEl).accentColor;
	}
}

const injectedFontFaces = new Set();

function ensureFontFace(fontFamily, fontUrl) {
	if (injectedFontFaces.has(fontFamily)) return;
	injectedFontFaces.add(fontFamily);
	const style = document.createElement('style');
	style.textContent = `@font-face { font-family: "${fontFamily}"; src: url("${fontUrl}"); }`;
	document.head.appendChild(style);
}
