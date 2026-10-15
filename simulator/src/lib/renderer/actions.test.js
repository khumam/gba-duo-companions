import { describe, it, expect } from 'vitest';
import { parseActions, parseScriptResult } from './actions.js';

// Ported from gbaduo's ActionTest.kt.
function parse(value) {
	const warnings = [];
	return [parseActions(value, warnings), warnings];
}

describe('parseActions', () => {
	it('an object runs set, then navigation, then call', () => {
		const [actions, warnings] = parse({
			call: 'open',
			args: ['{@index}', 2],
			navigate: 'detail',
			set: { selected: '{@index}' },
		});
		expect(warnings).toEqual([]);
		expect(actions).toEqual([
			{ kind: 'set', values: { selected: '{@index}' } },
			{ kind: 'navigate', page: 'detail', state: 'page' },
			{ kind: 'call', name: 'open', args: ['{@index}', 2] },
		]);
	});

	it('lists and the back shorthand', () => {
		const [actions, warnings] = parse(['back', { back: 'menu' }, { navigate: 'x', state: 'menu' }, { back: true }]);
		expect(warnings).toEqual([]);
		expect(actions).toEqual([
			{ kind: 'back', state: 'page' },
			{ kind: 'back', state: 'menu' },
			{ kind: 'navigate', page: 'x', state: 'menu' },
			{ kind: 'back', state: 'page' },
		]);
	});

	it('a single call argument needs no list', () => {
		expect(parse({ call: 'heal', args: 'all' })[0]).toEqual([{ kind: 'call', name: 'heal', args: ['all'] }]);
	});

	it('problems are skipped with warnings', () => {
		const [actions, warnings] = parse([
			'forward',
			3,
			{ navigate: 'a', back: true },
			{ set: { 'bad key': 1, ok: 2 } },
			{ call: 'no-dashes' },
			{ state: 'x y', navigate: 'a' },
			{ go: 'a' },
		]);
		expect(actions).toEqual([{ kind: 'set', values: { ok: 2 } }]);
		expect(warnings).toHaveLength(7);
	});
});

describe('parseScriptResult', () => {
	it('drops call with a warning', () => {
		const warnings = [];
		expect(parseScriptResult({ navigate: 'battle', call: 'heal' }, warnings)).toEqual([
			{ kind: 'navigate', page: 'battle', state: 'page' },
		]);
		expect(warnings).toHaveLength(1);
	});
});
