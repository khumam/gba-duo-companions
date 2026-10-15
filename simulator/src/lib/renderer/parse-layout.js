import { DEFAULT_STATE, isValidKey, parseActions } from './actions.js';

export class InvalidLayoutError extends Error {}

function bindingKey(raw) {
	return raw.startsWith('$') ? raw.slice(1) : raw;
}

function parseChildren(obj, warnings) {
	return Array.isArray(obj.children) ? obj.children.map((c) => parseWidget(c, warnings)) : [];
}

/**
 * Mirrors Layout.kt's WidgetMeta: id/class/style/classIf/bindStyle/onClick, present on
 * every widget. `onClick` problems are skipped and reported in [warnings], like Kotlin.
 */
function parseStyleMeta(obj, warnings) {
	const id = obj.id ?? null;
	const classes = typeof obj.class === 'string' ? obj.class.split(/\s+/).filter(Boolean) : [];
	const inlineStyle = obj.style ?? {};
	const classIf = {};
	if (obj.classIf) {
		for (const [className, binding] of Object.entries(obj.classIf)) {
			classIf[className] = bindingKey(binding);
		}
	}
	const bindStyle = obj.bindStyle ?? {};
	const actionWarnings = [];
	const onClick = parseActions(obj.onClick, actionWarnings);
	for (const w of actionWarnings) warnings.push(`${obj.type}: onClick: ${w}`);
	return { id, classes, inlineStyle, classIf, bindStyle, onClick };
}

/**
 * Mirrors WidgetMeta's `obj.has(key)` gating in Layout.kt: a legacy key only produces a
 * declaration when the author actually wrote it, not whenever it happens to differ from a
 * schema default. Only `box` and `text` widgets carry legacy keys in the real engine.
 */
function presentLegacyKeys(obj, keys) {
	const present = {};
	for (const key of keys) {
		if (Object.prototype.hasOwnProperty.call(obj, key)) present[key] = obj[key];
	}
	return present;
}

const EMPTY_META = { id: null, classes: [], inlineStyle: {}, classIf: {}, bindStyle: {}, onClick: [] };

export function parseWidget(obj, warnings = []) {
	const visibleIf = obj.visibleIf != null ? bindingKey(obj.visibleIf) : null;
	const meta = parseStyleMeta(obj, warnings);
	switch (obj.type) {
		// `gap`/`size` below are legacyPx keys in Layout.kt: CSS declarations only when present,
		// so default.css (and the pack's own CSS) decide otherwise.
		case 'column':
			return { type: 'column', children: parseChildren(obj, warnings), gap: obj.gap ?? 0, legacy: presentLegacyKeys(obj, ['gap']), visibleIf, meta };
		case 'row':
			return { type: 'row', children: parseChildren(obj, warnings), gap: obj.gap ?? 0, legacy: presentLegacyKeys(obj, ['gap']), visibleIf, meta };
		case 'tabs': {
			if (!Array.isArray(obj.tabs)) throw new InvalidLayoutError("tabs needs 'tabs' array");
			const tabs = obj.tabs.map((t) => ({ title: t.title, child: parseWidget(t.child, warnings) }));
			return { type: 'tabs', tabs, visibleIf, meta };
		}
		case 'pages': {
			if (!Array.isArray(obj.pages)) throw new InvalidLayoutError("pages needs a 'pages' array");
			if (obj.pages.length === 0) throw new InvalidLayoutError('pages needs at least one page');
			const pages = obj.pages.map((p) => {
				if (typeof p?.name !== 'string') throw new InvalidLayoutError('pages: every page needs a "name"');
				if (p.child == null) throw new InvalidLayoutError(`pages: page '${p.name}' needs a "child"`);
				return { name: p.name, child: parseWidget(p.child, warnings) };
			});
			const names = pages.map((p) => p.name);
			if (new Set(names).size !== names.length) throw new InvalidLayoutError('pages has two pages with the same name');
			const state = obj.state ?? DEFAULT_STATE;
			if (!isValidKey(state)) throw new InvalidLayoutError(`pages: invalid state name '${state}'`);
			const initial = obj.initial ?? names[0];
			if (!names.includes(initial)) throw new InvalidLayoutError(`pages: initial page '${initial}' doesn't exist`);
			return { type: 'pages', pages, state, initial, visibleIf, meta };
		}
		case 'button': {
			// Like Layout.kt: `text` becomes a `text` child with class `label` (button > .label).
			const label =
				obj.text != null
					? { type: 'text', text: String(obj.text), legacy: {}, visibleIf: null, meta: { ...EMPTY_META, classes: ['label'] } }
					: null;
			return { type: 'button', children: [...(label ? [label] : []), ...parseChildren(obj, warnings)], visibleIf, meta };
		}
		case 'text':
			return {
				type: 'text',
				text: obj.text ?? '',
				legacy: presentLegacyKeys(obj, ['size', 'color', 'bold', 'font']),
				visibleIf,
				meta,
			};
		case 'bar':
			return {
				type: 'bar',
				valueKey: bindingKey(obj.value ?? ''),
				maxKey: obj.maxKey != null ? bindingKey(obj.maxKey) : null,
				max: obj.max ?? 1.0,
				label: obj.label ?? null,
				visibleIf,
				meta,
			};
		case 'image':
			return { type: 'image', src: obj.src ?? '', size: obj.size ?? 32, legacy: presentLegacyKeys(obj, ['size']), visibleIf, meta };
		case 'spacer':
			return { type: 'spacer', size: obj.size ?? 8, legacy: presentLegacyKeys(obj, ['size']), visibleIf, meta };
		case 'list': {
			if (!obj.template) throw new InvalidLayoutError("list needs a 'template'");
			return {
				type: 'list',
				itemsPath: bindingKey(obj.items ?? ''),
				template: parseWidget(obj.template, warnings),
				emptyText: obj.empty ?? null,
				visibleIf,
				meta,
			};
		}
		case 'box': {
			const hasChild = obj.child != null;
			const hasChildren = obj.children != null;
			if (hasChild && hasChildren) {
				throw new InvalidLayoutError("box cannot have both 'child' and 'children'");
			}
			let children;
			if (hasChildren) children = parseChildren(obj, warnings);
			else if (hasChild) children = [parseWidget(obj.child, warnings)];
			else throw new InvalidLayoutError("box needs a 'child' or 'children'");
			return {
				type: 'box',
				children,
				legacy: presentLegacyKeys(obj, [
					'width', 'height', 'background', 'cornerRadius', 'borderColor', 'borderWidth', 'padding',
				]),
				visibleIf,
				meta,
			};
		}
		default:
			throw new InvalidLayoutError(`Unknown widget type '${obj.type}'`);
	}
}

/** Parses a layout and also returns non-fatal problems (bad `onClick` actions), like Kotlin's parseWithWarnings. */
export function parseLayoutWithWarnings(json) {
	let root;
	try {
		root = JSON.parse(json);
	} catch (e) {
		throw new InvalidLayoutError(`Malformed JSON: ${e.message}`);
	}
	const warnings = [];
	return { root: parseWidget(root, warnings), warnings };
}

export function parseLayout(json) {
	return parseLayoutWithWarnings(json).root;
}
