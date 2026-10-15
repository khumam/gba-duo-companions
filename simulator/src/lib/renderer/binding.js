const TOKEN = /\{([^{}]+)\}/g;
const SEGMENT = /([a-zA-Z0-9_]+)|\[(\d+)\]/g;

export function scopedValues(item, index, root) {
	return { item, index, root };
}

function isScopedValues(ctx) {
	return ctx != null && typeof ctx === 'object' && 'item' in ctx && 'index' in ctx && 'root' in ctx;
}

function resolvePlain(path, root) {
	let current = root;
	for (const match of path.matchAll(SEGMENT)) {
		const key = match[1];
		if (key) {
			current = current != null && typeof current === 'object' ? current[key] : undefined;
		} else {
			const index = parseInt(match[2], 10);
			current = Array.isArray(current) ? current[index] : undefined;
		}
		if (current == null) return null;
	}
	return current;
}

export function resolve(path, context) {
	if (isScopedValues(context)) {
		if (path === '@index') return context.index;
		const fromItem = resolvePlain(path, context.item);
		if (fromItem != null) return fromItem;
		return resolvePlain(path, context.root);
	}
	return resolvePlain(path, context);
}

function format(value) {
	return value == null ? '' : String(value);
}

export function interpolate(template, context) {
	return template.replace(TOKEN, (_, path) => format(resolve(path, context)));
}

export function isTruthy(value) {
	if (value == null) return false;
	if (typeof value === 'boolean') return value;
	if (typeof value === 'number') return value !== 0;
	if (typeof value === 'string') return value.length > 0;
	if (Array.isArray(value)) return value.length > 0;
	if (typeof value === 'object') return Object.keys(value).length > 0;
	return true;
}

export function asNumber(value) {
	if (typeof value === 'number') return value;
	if (typeof value === 'string') {
		const n = parseInt(value, 10);
		return Number.isNaN(n) ? 0 : n;
	}
	return 0;
}

export function asList(value) {
	return Array.isArray(value) ? value : [];
}
