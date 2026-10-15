<script>
	import { onMount, onDestroy, untrack } from 'svelte';
	import { EditorView, keymap, lineNumbers, highlightActiveLine } from '@codemirror/view';
	import { EditorState, Annotation } from '@codemirror/state';
	import { defaultKeymap, history, historyKeymap } from '@codemirror/commands';
	import { json as jsonLang } from '@codemirror/lang-json';
	import { css as cssLang } from '@codemirror/lang-css';
	import { oneDark } from '@codemirror/theme-one-dark';

	/**
	 * @typedef {Object} Props
	 * @property {string} value - Current text. Only pushed into the editor when it changes
	 *   from *outside* (e.g. switching packs) — typing already updates this same value via
	 *   onChange, so echoing it back on every keystroke would fight the user's cursor.
	 * @property {'json' | 'css'} language
	 * @property {(value: string) => void} onChange - Fires only for actual user edits
	 *   (debounced by the caller) — never for the programmatic sync above.
	 */

	/** @type {Props} */
	let { value, language, onChange } = $props();

	let host;
	/** @type {EditorView} */
	let view;
	// Deliberately the *initial* value only — see the Props doc above for why this must not
	// reactively track every keystroke.
	let lastPushedValue = untrack(() => value);

	// Marks a dispatch as programmatic (the $effect syncing an externally-changed `value`,
	// e.g. switching packs), not a real user edit. CodeMirror's updateListener fires for
	// *every* doc change regardless of origin — without this, the programmatic sync below
	// would itself look like a user edit and fire onChange, which the page wires straight to
	// a save-to-disk. Confirmed: without this, just loading a pack re-saved its files.
	const programmaticSync = Annotation.define();

	function languageExtension() {
		return language === 'css' ? cssLang() : jsonLang();
	}

	onMount(() => {
		view = new EditorView({
			parent: host,
			state: EditorState.create({
				doc: value,
				extensions: [
					lineNumbers(),
					highlightActiveLine(),
					history(),
					keymap.of([...defaultKeymap, ...historyKeymap]),
					languageExtension(),
					oneDark,
					EditorView.theme({ '&': { height: '100%', fontSize: '16px' }, '.cm-scroller': { overflow: 'auto' } }),
					EditorView.updateListener.of((update) => {
						if (!update.docChanged) return;
						lastPushedValue = update.state.doc.toString();
						const isProgrammatic = update.transactions.some((tr) => tr.annotation(programmaticSync));
						if (!isProgrammatic) onChange(lastPushedValue);
					}),
				],
			}),
		});
	});

	onDestroy(() => view?.destroy());

	$effect(() => {
		if (!view || value === lastPushedValue) return;
		lastPushedValue = value;
		view.dispatch({
			changes: { from: 0, to: view.state.doc.length, insert: value },
			annotations: programmaticSync.of(true),
		});
	});
</script>

<div class="editor" bind:this={host}></div>

<style>
	.editor {
		height: 100%;
		overflow: hidden;
	}
	.editor :global(.cm-editor) {
		height: 100%;
	}
</style>
