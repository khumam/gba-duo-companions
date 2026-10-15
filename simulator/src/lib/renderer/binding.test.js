import { describe, it, expect } from 'vitest';
import { resolve, interpolate, isTruthy, asNumber, asList, scopedValues } from './binding.js';

describe('resolve', () => {
	it('resolves a dot path', () => {
		expect(resolve('trainer.money', { trainer: { money: 3000 } })).toBe(3000);
	});

	it('resolves an array index', () => {
		expect(resolve('party[0].name', { party: [{ name: 'BULBASAUR' }] })).toBe('BULBASAUR');
	});

	it('returns null for a missing path', () => {
		expect(resolve('missing.path', { a: 1 })).toBeNull();
	});

	it('scoped values resolve item first, then root', () => {
		const ctx = scopedValues({ name: 'BULBASAUR' }, 0, { trainer: { money: 3000 } });
		expect(resolve('name', ctx)).toBe('BULBASAUR');
		expect(resolve('trainer.money', ctx)).toBe(3000);
	});

	it('@index resolves the scoped index', () => {
		const ctx = scopedValues({}, 2, {});
		expect(resolve('@index', ctx)).toBe(2);
	});
});

describe('interpolate', () => {
	it('replaces {tokens} with resolved values', () => {
		expect(interpolate('Money: {trainer.money}', { trainer: { money: 3000 } })).toBe('Money: 3000');
	});

	it('replaces unresolved tokens with empty string', () => {
		expect(interpolate('Hi {missing}', {})).toBe('Hi ');
	});
});

describe('isTruthy', () => {
	it('null/undefined are falsy', () => {
		expect(isTruthy(null)).toBe(false);
		expect(isTruthy(undefined)).toBe(false);
	});
	it('0 is falsy, nonzero numbers are truthy', () => {
		expect(isTruthy(0)).toBe(false);
		expect(isTruthy(5)).toBe(true);
	});
	it('empty string/array/object are falsy', () => {
		expect(isTruthy('')).toBe(false);
		expect(isTruthy([])).toBe(false);
		expect(isTruthy({})).toBe(false);
	});
	it('non-empty string/array/object are truthy', () => {
		expect(isTruthy('x')).toBe(true);
		expect(isTruthy([1])).toBe(true);
		expect(isTruthy({ a: 1 })).toBe(true);
	});
});

describe('asNumber / asList', () => {
	it('asNumber parses numeric strings, defaults to 0', () => {
		expect(asNumber('42')).toBe(42);
		expect(asNumber('not a number')).toBe(0);
		expect(asNumber(7)).toBe(7);
	});
	it('asList passes through arrays, defaults to empty', () => {
		expect(asList([1, 2])).toEqual([1, 2]);
		expect(asList(null)).toEqual([]);
		expect(asList('not an array')).toEqual([]);
	});
});
