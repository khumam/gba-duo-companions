/**
 * Port of gbaduo's Action.kt: what tapping a widget does (its `onClick`). Parsed actions
 * are plain objects tagged by `kind`:
 *   { kind: 'set', values }          sets UI state keys ($ui.<key>)
 *   { kind: 'navigate', page, state } shows a page, remembering the current one for back
 *   { kind: 'back', state }           returns to the previous page (or the initial one)
 *   { kind: 'call', name, args }      calls the pack script's actions.<name>(args...)
 * Strings in `values`, `page` and `args` may hold `{binding}` placeholders, resolved
 * against the tapped widget's data when the tap happens.
 */

/** The UI key `pages`, `navigate` and `back` use unless told otherwise. */
export const DEFAULT_STATE = 'page';

const KEY = /^[A-Za-z_][A-Za-z0-9_]*$/;
const KNOWN = new Set(['set', 'navigate', 'back', 'state', 'call', 'args']);

export function isValidKey(key) {
	return KEY.test(key);
}

/**
 * Parses an `onClick` value: one action object, a list of them, or the shorthand `"back"`.
 * An object may combine `set`, `navigate`/`back` and `call`; they run in that order.
 * Problems are skipped and described in [warnings], same as Actions.parse in Kotlin.
 */
export function parseActions(value, warnings = []) {
	if (value == null) return [];
	if (Array.isArray(value)) return value.flatMap((v) => parseActions(v, warnings));
	if (typeof value === 'string') {
		if (value === 'back') return [{ kind: 'back', state: DEFAULT_STATE }];
		warnings.push(`unknown action '${value}' (use an object like { "navigate": "${value}" })`);
		return [];
	}
	if (typeof value === 'object') return parseObject(value, warnings);
	warnings.push('an action must be an object, a list of objects, or "back"');
	return [];
}

function parseObject(obj, warnings) {
	const actions = [];
	for (const key of Object.keys(obj)) {
		if (!KNOWN.has(key)) warnings.push(`unknown action key '${key}'`);
	}
	const state = obj.state != null ? String(obj.state) : DEFAULT_STATE;
	if (!isValidKey(state)) {
		warnings.push(`invalid state name '${state}'`);
		return [];
	}

	const set = obj.set;
	if (set != null) {
		if (typeof set === 'object' && !Array.isArray(set)) {
			const values = {};
			for (const [name, v] of Object.entries(set)) {
				if (isValidKey(name)) values[name] = v;
				else warnings.push(`invalid UI key '${name}' in set`);
			}
			if (Object.keys(values).length) actions.push({ kind: 'set', values });
		} else {
			warnings.push("'set' must be an object of UI keys to values");
		}
	}

	const { navigate, back } = obj;
	if (navigate != null && back != null && back !== false) {
		warnings.push("an action can't both navigate and go back");
	} else if (typeof navigate === 'string') {
		actions.push({ kind: 'navigate', page: navigate, state });
	} else if (navigate != null) {
		warnings.push("'navigate' must be a page name");
	} else if (back === true) {
		actions.push({ kind: 'back', state });
	} else if (typeof back === 'string') {
		if (isValidKey(back)) actions.push({ kind: 'back', state: back });
		else warnings.push(`invalid state name '${back}'`);
	} else if (back != null && back !== false) {
		warnings.push("'back' must be true or a state name");
	}

	const call = obj.call;
	if (call != null) {
		if (typeof call === 'string') {
			const raw = obj.args;
			const args = raw == null ? [] : Array.isArray(raw) ? raw : [raw];
			if (isValidKey(call)) actions.push({ kind: 'call', name: call, args });
			else warnings.push(`invalid action name '${call}'`);
		} else {
			warnings.push("'call' must be the name of a function in the script's actions table");
		}
	}
	return actions;
}

/**
 * UI actions the pack's script returned — from `actions.<name>()`, or as the `ui` entry of
 * `update()` (Actions.parseScriptResult). Same shape as an `onClick`, minus `call`, which is
 * dropped with a warning.
 */
export function parseScriptResult(value, warnings = []) {
	return parseActions(value, warnings).filter((action) => {
		if (action.kind !== 'call') return true;
		warnings.push("a script can't return 'call'; call the Lua function directly");
		return false;
	});
}
