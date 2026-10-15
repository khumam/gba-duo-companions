export class InvalidLayoutError extends Error {}

function bindingKey(raw) {
	return raw.startsWith('$') ? raw.slice(1) : raw;
}

function parseChildren(obj) {
	return Array.isArray(obj.children) ? obj.children.map(parseWidget) : [];
}

/** Mirrors Layout.kt's StyleMeta: id/class/style/classIf/bindStyle, present on every widget. */
function parseStyleMeta(obj) {
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
	return { id, classes, inlineStyle, classIf, bindStyle };
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

export function parseWidget(obj) {
	const visibleIf = obj.visibleIf != null ? bindingKey(obj.visibleIf) : null;
	const meta = parseStyleMeta(obj);
	switch (obj.type) {
		case 'column':
			return { type: 'column', children: parseChildren(obj), gap: obj.gap ?? 0, visibleIf, meta };
		case 'row':
			return { type: 'row', children: parseChildren(obj), gap: obj.gap ?? 0, visibleIf, meta };
		case 'tabs': {
			if (!Array.isArray(obj.tabs)) throw new InvalidLayoutError("tabs needs 'tabs' array");
			const tabs = obj.tabs.map((t) => ({ title: t.title, child: parseWidget(t.child) }));
			return { type: 'tabs', tabs, visibleIf, meta };
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
			return { type: 'image', src: obj.src ?? '', size: obj.size ?? 32, visibleIf, meta };
		case 'spacer':
			return { type: 'spacer', size: obj.size ?? 8, visibleIf, meta };
		case 'list': {
			if (!obj.template) throw new InvalidLayoutError("list needs a 'template'");
			return {
				type: 'list',
				itemsPath: bindingKey(obj.items ?? ''),
				template: parseWidget(obj.template),
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
			if (hasChildren) children = parseChildren(obj);
			else if (hasChild) children = [parseWidget(obj.child)];
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

export function parseLayout(json) {
	let root;
	try {
		root = JSON.parse(json);
	} catch (e) {
		throw new InvalidLayoutError(`Malformed JSON: ${e.message}`);
	}
	return parseWidget(root);
}
