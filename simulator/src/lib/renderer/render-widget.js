import { resolve, interpolate, isTruthy, asNumber, asList, scopedValues } from './binding.js';
import { parseScriptResult } from './actions.js';

// Matches the Thor's companion display: 369dpi / 160 = 2.30625x, the same multiplier
// WidgetRenderer.kt's `px(dpValue) = (dpValue * dp).toInt()` uses. Only applies to legacy
// numeric widget keys (image/spacer size, legacy box-model keys) — CSS lengths in a pack's
// style.css are rescaled separately, by prepare-stylesheet.js's rescalePxLengths.
const DEVICE_DENSITY = 2.30625;

function px(dpValue) {
	return Math.round(dpValue * DEVICE_DENSITY);
}

/** The snapshot key bindings read UI state from (`$ui.page`), as CompanionTree.UI_KEY. */
export const UI_KEY = 'ui';
const MAX_HISTORY = 32;
const EMPTY_IMAGE = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
const WHOLE_BINDING = /^\{([^{}]+)\}$/;

/**
 * The UI state (`$ui.*`) one screen shares across its root renderer and every nested list
 * item renderer — mirrors CompanionTree's uiState/history/initialPages.
 */
function createStore(initialUi) {
	return {
		ui: { ...(initialUi ?? {}) },
		history: {},
		initialPages: {},
		snapshot: null,
		rebind: () => {},
		onCall: () => {},
		onUiChange: () => {},
	};
}

/**
 * @param packBaseUrl base path assets/fonts resolve against, e.g. `/packs/{id}`.
 * @param options.onCall (name, args) => void — a tap's `call` action. The simulator has
 *   no Lua, so this is where the caller can log/show it.
 * @param options.onUiChange (ui) => void — after any UI state change from a tap.
 * @param options.initialUi UI state to start from instead of empty (e.g. to stay on the
 *   same page across a layout/style edit, which rebuilds the whole tree).
 * @param options.store internal: the parent screen's store, for list item renderers.
 */
export function createRenderer(packBaseUrl, options = {}) {
	const bindings = [];
	const isRoot = options.store == null;
	const store = options.store ?? createStore(options.initialUi);
	if (isRoot) {
		if (options.onCall) store.onCall = options.onCall;
		if (options.onUiChange) store.onUiChange = options.onUiChange;
		store.rebind = () => applyAll(withUi(store.snapshot));
	}

	function applyAll(context) {
		for (const apply of bindings) apply(context);
	}

	/** Bindings also see the UI state, under `ui` (CompanionTree.withUi). */
	function withUi(context) {
		const ui = { ...store.ui };
		if (context == null) return { [UI_KEY]: ui };
		if (typeof context === 'object' && !Array.isArray(context)) return { ...context, [UI_KEY]: ui };
		return context;
	}

	/** A whole-string `{path}` keeps the bound value's type (e.g. `{@index}` stays a number). */
	function actionValue(value, context) {
		if (typeof value !== 'string') return value;
		const whole = WHOLE_BINDING.exec(value);
		if (!whole) return interpolate(value, context);
		return resolve(whole[1], context);
	}

	/**
	 * Runs actions from a tap (with the tapped widget's binding context): UI changes apply
	 * at once and re-bind the whole screen; `call`s go to onCall afterwards. Port of
	 * CompanionTree.perform.
	 */
	function perform(actions, context) {
		let changed = false;
		const calls = [];
		const setUi = (key, value) => {
			if (key in store.ui && store.ui[key] === value) return;
			store.ui[key] = value;
			changed = true;
		};
		for (const action of actions) {
			switch (action.kind) {
				case 'set':
					for (const [key, value] of Object.entries(action.values)) setUi(key, actionValue(value, context));
					break;
				case 'navigate': {
					const page = interpolate(action.page, context);
					const current = store.ui[action.state] == null ? null : String(store.ui[action.state]);
					if (page !== current) {
						if (current != null) {
							const stack = (store.history[action.state] ??= []);
							stack.push(current);
							if (stack.length > MAX_HISTORY) stack.shift();
						}
						setUi(action.state, page);
					}
					break;
				}
				case 'back': {
					const stack = store.history[action.state];
					const previous = (stack && stack.length ? stack.pop() : null) ?? store.initialPages[action.state];
					if (previous != null) setUi(action.state, previous);
					break;
				}
				case 'call':
					calls.push({ name: action.name, args: action.args.map((v) => actionValue(v, context)) });
					break;
			}
		}
		if (changed) {
			store.rebind();
			store.onUiChange({ ...store.ui });
		}
		for (const call of calls) store.onCall(call.name, call.args);
	}

	/** `:pressed` while held — prepare-stylesheet.js turns `:pressed` into `.pressed`. */
	function bindPressed(el) {
		el.addEventListener('pointerdown', () => el.classList.add('pressed'));
		el.addEventListener('pointerup', () => el.classList.remove('pressed'));
		el.addEventListener('pointerleave', () => el.classList.remove('pressed'));
	}

	function bindClick(el, actions) {
		let context = null;
		bindings.push((ctx) => {
			context = ctx;
		});
		el.style.cursor = 'pointer';
		bindPressed(el);
		el.addEventListener('click', (event) => {
			// Compose's innermost clickable consumes the tap; outer ones don't also fire.
			event.stopPropagation();
			perform(actions, context);
		});
	}

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
		if (widget.meta?.onClick?.length) bindClick(el, widget.meta.onClick);
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
				return buildBox(widget);
			case 'row':
				return buildBox(widget);
			case 'tabs':
				return buildTabs(widget);
			case 'pages':
				return buildPages(widget);
			case 'button':
				return buildButton(widget);
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

	/**
	 * row/column: layout comes from default.css (`row`/`column` rules) so pack CSS can override
	 * it, and a legacy `gap` becomes a CSS `gap` — Layout.kt's legacyPx("gap", "gap") — rather
	 * than inline display/flex-direction plus spacer elements that pack CSS couldn't touch.
	 */
	function buildBox(widget) {
		const el = document.createElement('div');
		applyMeta(el, widget);
		if ('gap' in (widget.legacy ?? {})) el.style.gap = `${px(widget.legacy.gap)}px`;
		widget.children.forEach((child) => el.appendChild(inflate(child)));
		applyVisibility(el, widget.visibleIf);
		return el;
	}

	/** Legacy `size` on image/spacer → width+height, only when written (Layout.kt legacyPx). */
	function applyLegacySize(el, widget) {
		if (!('size' in (widget.legacy ?? {}))) return;
		el.style.width = `${px(widget.legacy.size)}px`;
		el.style.height = `${px(widget.legacy.size)}px`;
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
		applyLegacySize(el, widget);
		el.alt = '';
		let shownKey;
		// CompanionTree.showImage: `asset:` loads from the pack; `gfx:` sprites only exist once
		// the pack's Lua decodes them, which the simulator can't do, so they stay empty (like an
		// undecoded sprite on device) with a tooltip saying why.
		const show = (key) => {
			if (key === shownKey) return;
			shownKey = key;
			if (typeof key === 'string' && key.startsWith('asset:')) {
				el.src = `${packBaseUrl}/assets/${key.slice('asset:'.length)}`;
				el.removeAttribute('title');
			} else {
				// A transparent pixel, not a missing src: Chromium draws a gray placeholder border
				// around a src-less <img>, while the device draws nothing in an empty image box.
				el.src = EMPTY_IMAGE;
				el.title = typeof key === 'string' && key.startsWith('gfx:') ? `${key} (Lua-decoded sprite, not available in the simulator)` : '';
			}
		};
		if (widget.src.startsWith('$')) {
			const path = widget.src.slice(1);
			show(null); // empty until the first snapshot binds it
			bindings.push((ctx) => {
				const value = resolve(path, ctx);
				show(typeof value === 'string' ? value : null);
			});
		} else {
			show(widget.src);
		}
		applyVisibility(el, widget.visibleIf);
		return el;
	}

	function buildSpacer(widget) {
		const el = document.createElement('div');
		applyMeta(el, widget);
		applyLegacySize(el, widget);
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
			// The newly-attached tab's subtree may have sat detached (never in the live
			// document) until now, e.g. a non-default tab's content between initial render and
			// this click. getComputedStyle on a detached node doesn't resolve real cascaded
			// values — confirmed: a bar's accent-color read as transparent for a tab that
			// hadn't been attached yet when applyBarAccentColors first ran. Both passes are
			// cheap and idempotent, so just re-running them here is simplest.
			applyStackChildPlacement(content);
			applyScrollContainers(content);
			applyBarAccentColors(content);
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
	 * Shows one page at a time: the one named by UI key `widget.state`, or the initial page
	 * until something navigates (unknown names fall back to it too). Port of
	 * CompanionTree.buildPages. Unlike tabs, every page stays attached and bound — hidden
	 * ones just carry `data-gbaduo-hidden` (display:none !important, see
	 * prepare-stylesheet.js), the counterpart of CompanionNode.hiddenBySwitch — so they're
	 * up to date when opened and getComputedStyle still resolves inside them.
	 */
	function buildPages(widget) {
		const el = document.createElement('div');
		applyMeta(el, widget);
		if (!(widget.state in store.initialPages)) store.initialPages[widget.state] = widget.initial;
		if (!(widget.state in store.ui)) store.ui[widget.state] = widget.initial;

		const panels = widget.pages.map((page) => {
			const panel = inflate(page.child);
			el.appendChild(panel);
			return panel;
		});

		function show(name) {
			let index = widget.pages.findIndex((p) => p.name === name);
			if (index < 0) index = widget.pages.findIndex((p) => p.name === widget.initial);
			panels.forEach((panel, i) => panel.toggleAttribute('data-gbaduo-hidden', i !== index));
		}

		show(store.ui[widget.state] == null ? null : String(store.ui[widget.state]));
		bindings.push(() => show(store.ui[widget.state] == null ? null : String(store.ui[widget.state])));
		applyVisibility(el, widget.visibleIf);
		return el;
	}

	/** A tappable container (a flex row via default.css); its `text` is a `text.label` child. */
	function buildButton(widget) {
		const el = document.createElement('div');
		applyMeta(el, widget);
		widget.children.forEach((child) => el.appendChild(inflate(child)));
		applyVisibility(el, widget.visibleIf);
		return el;
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
			// Like CompanionTree.buildList: against the current list item first, then the
			// snapshot root, so a nested list can iterate its parent item's own list ($types).
			const items = asList(resolve(widget.itemsPath, ctx));

			if (items.length !== itemRenderers.length) {
				while (container.children.length > 1) {
					container.removeChild(container.lastChild);
				}
				itemRenderers = items.map(() => {
					const renderer = createRenderer(packBaseUrl, { store });
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
		/**
		 * The root renderer takes the pack's snapshot and adds `ui` to it (CompanionTree.update);
		 * a list item renderer takes its ScopedValues as-is.
		 */
		update(context) {
			if (!isRoot) {
				applyAll(context);
				return;
			}
			// CompanionTree.updateFromScript: a top-level `ui` entry from update() (here: in
			// preview-data.json) runs as UI actions after the data, and never reaches the
			// bindings as data — `$ui.*` is always the UI state.
			let uiActions = null;
			let data = context;
			if (context != null && typeof context === 'object' && !Array.isArray(context) && UI_KEY in context) {
				({ [UI_KEY]: uiActions, ...data } = context);
			}
			store.snapshot = data;
			applyAll(withUi(data));
			if (uiActions != null) {
				const warnings = [];
				perform(parseScriptResult(uiActions, warnings), null);
				for (const w of warnings) console.warn(`[simulator] update() ui: ${w}`);
			}
		},
		/** The current UI state (`$ui.*`). */
		get ui() {
			return { ...store.ui };
		},
		/**
		 * Runs parsed actions with no binding context — how CompanionTree.perform applies what
		 * a script's actions.* returns (e.g. `{ set = { selected = 0 }, navigate = "detail" }`).
		 */
		perform(actions) {
			perform(actions, null);
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
 * The engine scrolls `overflow: auto|scroll` with Compose's verticalScroll, which lays the
 * content out with *unbounded* height — so a flex column inside it never shrinks its items,
 * it just gets taller and scrolls. A browser scroll box keeps its definite height, and with
 * min-height: 0 (the engine's "auto is 0", see prepare-stylesheet.js) the items would shrink
 * to fit and nothing would scroll. Pinning flex-shrink: 0 on a column scroll container's
 * direct children reproduces the engine. Rows are left alone: their main axis is width,
 * which verticalScroll still bounds. Call after [root] is attached; safe to re-run.
 */
export function applyScrollContainers(root) {
	const candidates = [root, ...root.querySelectorAll('*')];
	for (const el of candidates) {
		const cs = getComputedStyle(el);
		// jsdom doesn't expand the `overflow` shorthand into overflow-y, so check both.
		const isScroll = (v) => v === 'auto' || v === 'scroll';
		const scrolls = isScroll(cs.overflowY) || isScroll((cs.overflow ?? '').split(/\s+/).pop());
		const column = cs.display.includes('flex') && cs.flexDirection.startsWith('column');
		if (!scrolls || !column) continue;
		for (const child of el.children) child.style.flexShrink = '0';
	}
}

const DEFAULT_ACCENT = '#6c4ab6';

/**
 * `accent-color` is a real, inherited CSS property every browser resolves through the
 * normal cascade. Like CompanionScreen.kt's boxPaint, a bar's fill *defaults* to the bar's
 * own resolved accent-color — but only when the fill has no background of its own
 * (transparent, no image/gradient). A pack styling `bar > fill { background: ... }` keeps
 * it. Call after [root] is attached to a real document; safe to re-run.
 */
export function applyBarAccentColors(root) {
	const candidates = [root, ...root.querySelectorAll('*')].filter((el) => el.dataset?.type === 'bar');
	for (const barEl of candidates) {
		const fillEl = barEl.querySelector(':scope > [data-type="fill"]');
		if (!fillEl) continue;
		// Drop our own previous fallback first, so the check sees only the pack's styles.
		fillEl.style.backgroundColor = '';
		const fill = getComputedStyle(fillEl);
		const transparent = fill.backgroundColor === '' || fill.backgroundColor === 'transparent' || /^rgba\(.*,\s*0\)$/.test(fill.backgroundColor);
		const noImage = !fill.backgroundImage || fill.backgroundImage === 'none';
		if (!transparent || !noImage) continue;
		const accent = getComputedStyle(barEl).accentColor;
		fillEl.style.backgroundColor = !accent || accent === 'auto' ? DEFAULT_ACCENT : accent;
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
