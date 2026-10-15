<script>
	import CodeEditor from '../lib/CodeEditor.svelte';
	import { parseLayoutWithWarnings } from '../lib/renderer/parse-layout.js';
	import { createRenderer, applyStackChildPlacement, applyBarAccentColors, applyScrollContainers } from '../lib/renderer/render-widget.js';
	import { prepareStylesheetCss, extractFontFaceCss } from '../lib/renderer/prepare-stylesheet.js';

	let { data } = $props();

	// Same 1080 x 1240 device the real companion display uses — scaled down for the
	// preview column but kept at the exact same aspect ratio, never distorted.
	const DEVICE_WIDTH = 1080;
	const DEVICE_HEIGHT = 1240;
	const PREVIEW_SCALE = 0.6;

	const TABS = [
		{ id: 'layout', label: 'layout.json', language: 'json' },
		{ id: 'style', label: 'style.css', language: 'css' },
		{ id: 'previewData', label: 'preview-data.json', language: 'json' },
	];

	let selectedPackId = $state(data.packIds[0] ?? null);
	let activeTab = $state('layout');
	let canvasEl;
	let defaultCss = '';
	let defaultCssSource = $state('live');

	let layoutText = $state('');
	let styleText = $state('');
	let previewDataText = $state('{}');
	let previewDataError = $state('');
	let layoutError = $state('');
	let styleError = $state('');
	let saveStatus = $state('');

	let activeRenderer = null;
	let rootElement = null;
	/** UI state to start the next rebuild from when there's no live renderer (e.g. after a layout error). */
	let keptUi = {};
	let uiState = $state({});
	let lastCall = $state('');
	// Guards the same overlapping-async-call hazard as the old polling loop did: switching
	// packs (or a slow default-css fetch) shouldn't let an older in-flight load clobber a
	// newer one's DOM. See render-widget.js/applyStackChildPlacement's sibling note.
	let renderGeneration = 0;
	const saveTimers = {};

	/**
	 * Pack content renders inside a Shadow DOM root so a pack's style.css (real selectors like
	 * `.card`, `#screen`, element-type selectors) is fully scoped away from the simulator's own
	 * chrome, the same way Android's companion screen is its own isolated View tree.
	 */
	function getShadowRoot() {
		return canvasEl.shadowRoot ?? canvasEl.attachShadow({ mode: 'open' });
	}

	/**
	 * Chromium does not register @font-face rules declared inside a shadow tree's stylesheet
	 * (verified: document.fonts never lists them, and the font never visibly applies), so
	 * they're injected into document.head instead, in one persistent element replaced on every
	 * render — covers both pack switching and live edits without accumulating stale rules.
	 */
	function injectGlobalFontFaces(cssText) {
		let styleEl = document.getElementById('gbaduo-sim-fontfaces');
		if (!styleEl) {
			styleEl = document.createElement('style');
			styleEl.id = 'gbaduo-sim-fontfaces';
			document.head.appendChild(styleEl);
		}
		styleEl.textContent = cssText;
	}

	/** Fetches the real default.css live from the sibling gbaduo repo (routes/api/default-css). */
	async function ensureDefaultCss() {
		const res = await fetch('/api/default-css');
		const result = await res.json();
		defaultCss = result.css;
		defaultCssSource = result.source;
	}

	/** Full rebuild from the current editor text — layout structure or CSS rules changed. */
	function rebuildAndRender() {
		if (!canvasEl) return;
		const shadowRoot = getShadowRoot();
		shadowRoot.innerHTML = '';
		if (activeRenderer) keptUi = activeRenderer.ui;
		activeRenderer = null;
		rootElement = null;
		layoutError = '';
		styleError = '';

		let widget;
		try {
			const parsed = parseLayoutWithWarnings(layoutText);
			widget = parsed.root;
			// Non-fatal (e.g. an unknown onClick action): the layout still renders, like on device.
			layoutError = parsed.warnings.join('\n');
		} catch (e) {
			layoutError = e.message;
			shadowRoot.textContent = `Layout error: ${e.message}`;
			return;
		}

		const packBaseUrl = `/packs/${selectedPackId}`;
		let preparedCss;
		try {
			preparedCss = prepareStylesheetCss(styleText, packBaseUrl, defaultCss);
		} catch (e) {
			styleError = e.message;
			shadowRoot.textContent = `Style error: ${e.message}`;
			return;
		}
		const styleEl = document.createElement('style');
		styleEl.textContent = preparedCss;
		shadowRoot.appendChild(styleEl);
		injectGlobalFontFaces(extractFontFaceCss(styleText, packBaseUrl));

		// Keep the current UI state (page, selection) across a layout/style edit, which rebuilds
		// the whole tree — otherwise every keystroke on a detail page's CSS would bounce back
		// to the first page. Switching packs starts fresh (loadPack clears it).
		const renderer = createRenderer(packBaseUrl, {
			initialUi: keptUi,
			onUiChange: (ui) => {
				uiState = ui;
				runComputedStylePasses();
			},
			onCall: (name, args) => {
				// The simulator doesn't run the pack's Lua: show what would have been called.
				lastCall = `actions.${name}(${args.map((a) => JSON.stringify(a)).join(', ')})`;
				console.info(`[simulator] onClick call: ${lastCall}`);
			},
		});
		const rootEl = renderer.build(widget);
		// `:root` in a pack's/default.css's CSS (prepare-stylesheet.js) targets this marker,
		// not the shadow host — see that file for why.
		rootEl.setAttribute('data-gbaduo-root', '');
		shadowRoot.appendChild(rootEl);
		rootElement = rootEl;
		activeRenderer = renderer;

		reapplyPreviewData();
		uiState = renderer.ui;
	}

	/** Stack placement and bar accent colors need the live, styled DOM — re-run after any rebind. */
	function runComputedStylePasses() {
		if (!rootElement) return;
		applyStackChildPlacement(rootElement);
		applyScrollContainers(rootElement);
		applyBarAccentColors(rootElement);
	}

	/**
	 * Re-runs the binding pass with the current preview-data text, so transition-driven
	 * changes (a bar width/color, a tab pill switch) are visible without needing to execute
	 * main.lua. Cheaper than rebuildAndRender — the widget tree and CSS didn't change.
	 */
	function reapplyPreviewData() {
		if (!activeRenderer) return;
		let parsed;
		try {
			parsed = JSON.parse(previewDataText);
		} catch (e) {
			previewDataError = e.message;
			return;
		}
		previewDataError = '';
		activeRenderer.update(parsed);
		runComputedStylePasses();
	}

	/** Persists one editor tab's content back to the pack's real file on disk. */
	async function saveFile(file, content) {
		if (!selectedPackId) return;
		saveStatus = 'saving…';
		try {
			const res = await fetch(`/api/pack/${selectedPackId}`, {
				method: 'PUT',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ file, content }),
			});
			if (!res.ok) throw new Error(await res.text());
			saveStatus = 'saved';
		} catch (e) {
			saveStatus = `error saving: ${e.message}`;
		}
	}

	function debounced(key, fn, delayMs = 400) {
		clearTimeout(saveTimers[key]);
		saveTimers[key] = setTimeout(fn, delayMs);
	}

	function onLayoutChange(text) {
		layoutText = text;
		debounced('layout', () => {
			saveFile('layout', text);
			rebuildAndRender();
		});
	}

	function onStyleChange(text) {
		styleText = text;
		debounced('style', () => {
			saveFile('style', text);
			rebuildAndRender();
		});
	}

	function onPreviewDataChange(text) {
		previewDataText = text;
		debounced('previewData', () => {
			saveFile('previewData', text);
			reapplyPreviewData();
		});
	}

	async function loadPack(packId) {
		if (!packId || !canvasEl) return;
		const myGeneration = ++renderGeneration;

		await ensureDefaultCss();
		if (myGeneration !== renderGeneration) return;

		const res = await fetch(`/api/pack/${packId}`);
		if (!res.ok) return;
		const packData = await res.json();
		if (myGeneration !== renderGeneration) return;

		layoutText = packData.layoutJson ?? '';
		styleText = packData.styleCss ?? '';
		previewDataText = packData.previewDataJson ?? JSON.stringify(packData.previewData, null, 2);
		previewDataError = '';
		saveStatus = '';
		// Like the device: UI state starts empty (apart from each pages widget's initial page)
		// whenever a pack is loaded.
		activeRenderer = null;
		keptUi = {};
		lastCall = '';

		rebuildAndRender();
	}

	function resetUi() {
		activeRenderer = null;
		keptUi = {};
		lastCall = '';
		rebuildAndRender();
	}

	$effect(() => {
		loadPack(selectedPackId);
	});
</script>

<svelte:head>
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link
		href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
		rel="stylesheet"
	/>
</svelte:head>

<main>
	<header>
		<span class="mark" aria-hidden="true"></span>
		<h1>GBADuo Companion Simulator</h1>
		<select bind:value={selectedPackId}>
			{#each data.packIds as packId (packId)}
				<option value={packId}>{packId}</option>
			{/each}
		</select>
		{#if defaultCssSource === 'fallback'}
			<p class="warning-banner">
				Could not read default.css from the sibling gbaduo repo — using a bundled copy, which may be stale.
			</p>
		{/if}
	</header>

	<div class="columns">
		<section class="editor-column">
			<div class="tab-strip">
				{#each TABS as tab (tab.id)}
					<button type="button" class="tab" class:active={activeTab === tab.id} onclick={() => (activeTab = tab.id)}>
						{tab.label}
					</button>
				{/each}
				<span class="save-status" class:error={saveStatus.startsWith('error')}>{saveStatus}</span>
			</div>
			<div class="editor-body">
				<div class="editor-pane" class:hidden={activeTab !== 'layout'}>
					<CodeEditor value={layoutText} language="json" onChange={onLayoutChange} />
				</div>
				<div class="editor-pane" class:hidden={activeTab !== 'style'}>
					<CodeEditor value={styleText} language="css" onChange={onStyleChange} />
				</div>
				<div class="editor-pane" class:hidden={activeTab !== 'previewData'}>
					<CodeEditor value={previewDataText} language="json" onChange={onPreviewDataChange} />
				</div>
			</div>
			{#if activeTab === 'layout' && layoutError}<p class="data-error">{layoutError}</p>{/if}
			{#if activeTab === 'style' && styleError}<p class="data-error">{styleError}</p>{/if}
			{#if activeTab === 'previewData' && previewDataError}<p class="data-error">{previewDataError}</p>{/if}
		</section>

		<section class="preview-column">
			<label for="canvas-frame">Preview — {DEVICE_WIDTH} × {DEVICE_HEIGHT}</label>
			<div id="canvas-frame" class="canvas-frame" style="width: {DEVICE_WIDTH * PREVIEW_SCALE}px; height: {DEVICE_HEIGHT * PREVIEW_SCALE}px;">
				<div class="canvas-scaler" style="transform: scale({PREVIEW_SCALE});">
					<div bind:this={canvasEl} class="canvas"></div>
				</div>
			</div>
			<div class="ui-panel" style="width: {DEVICE_WIDTH * PREVIEW_SCALE}px;">
				<div class="ui-row">
					<span class="ui-key">UI state ($ui)</span>
					<code class="ui-value">{JSON.stringify(uiState)}</code>
					<button type="button" class="ui-reset" onclick={resetUi}>Reset</button>
				</div>
				{#if lastCall}
					<div class="ui-row">
						<span class="ui-key">Last call</span>
						<code class="ui-value">{lastCall}</code>
					</div>
					<p class="ui-note">The simulator doesn't run the pack's Lua — on device this calls the script's <code>actions</code> table.</p>
				{/if}
			</div>
		</section>
	</div>
</main>

<style>
	:global(body) {
		margin: 0;
		background: #f5f5f0;
		color: #111111;
		font-family: 'Inter', sans-serif;
	}

	main {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		box-sizing: border-box;
		padding: 0 32px;
	}

	header {
		display: flex;
		align-items: center;
		gap: 16px;
		padding: 16px 0;
		border-bottom: 1px solid #111111;
		box-sizing: border-box;
	}

	.mark {
		display: block;
		width: 14px;
		height: 14px;
		flex-shrink: 0;
		background: #d40000;
	}

	h1 {
		font-size: 16px;
		font-weight: 700;
		letter-spacing: -0.01em;
		margin: 0;
		text-transform: uppercase;
		white-space: nowrap;
	}

	select {
		appearance: none;
		font-family: 'Inter', sans-serif;
		font-size: 13px;
		font-weight: 500;
		padding: 6px 10px;
		background: #ffffff;
		color: #111111;
		border: 1px solid #111111;
		border-radius: 0;
		min-width: 240px;
	}

	select:focus {
		outline: none;
		border-color: #d40000;
		box-shadow: inset 0 0 0 1px #d40000;
	}

	.warning-banner {
		margin: 0;
		padding: 6px 10px;
		background: #fff3cd;
		border: 1px solid #d4a017;
		font-size: 11px;
	}

	.columns {
		display: grid;
		grid-template-columns: 1fr 1fr;
		flex: 1 1 auto;
		min-height: 0;
	}

	.editor-column {
		display: flex;
		flex-direction: column;
		min-width: 0;
		border-right: 1px solid #111111;
	}

	.tab-strip {
		display: flex;
		align-items: center;
		border-bottom: 1px solid #111111;
	}

	.tab {
		font-family: 'Inter', sans-serif;
		font-size: 12px;
		font-weight: 600;
		padding: 10px 16px;
		background: #f5f5f0;
		color: #666666;
		border: none;
		border-right: 1px solid #111111;
		cursor: pointer;
	}

	.tab.active {
		background: #111111;
		color: #ffffff;
	}

	.save-status {
		margin-left: auto;
		padding: 0 12px;
		font-size: 11px;
		color: #666666;
	}

	.save-status.error {
		color: #d40000;
	}

	.editor-body {
		flex: 1 1 auto;
		min-height: 0;
		position: relative;
	}

	.editor-pane {
		position: absolute;
		inset: 0;
	}

	.editor-pane.hidden {
		display: none;
	}

	.data-error {
		margin: 0;
		padding: 8px 16px;
		background: #fde8e8;
		border-top: 1px solid #d40000;
		color: #d40000;
		font-size: 12px;
		font-family: monospace;
	}

	.preview-column {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		padding: 24px;
		overflow: auto;
	}

	.preview-column label {
		display: block;
		font-size: 11px;
		font-weight: 600;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: #111111;
		margin-bottom: 12px;
	}

	.canvas-frame {
		border: 1px solid #111111;
		overflow: hidden;
		line-height: 0;
	}

	.ui-panel {
		margin-top: 12px;
		font-size: 12px;
		box-sizing: border-box;
	}

	.ui-row {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 6px 0;
		border-top: 1px solid #d8d8d0;
	}

	.ui-key {
		flex-shrink: 0;
		width: 96px;
		font-size: 11px;
		font-weight: 600;
		letter-spacing: 0.06em;
		text-transform: uppercase;
	}

	.ui-value {
		flex: 1 1 auto;
		min-width: 0;
		font-family: monospace;
		font-size: 12px;
		overflow-wrap: anywhere;
	}

	.ui-reset {
		font-family: 'Inter', sans-serif;
		font-size: 11px;
		font-weight: 600;
		padding: 4px 10px;
		background: #ffffff;
		border: 1px solid #111111;
		cursor: pointer;
	}

	.ui-note {
		margin: 4px 0 0;
		font-size: 11px;
		color: #666666;
	}

	.canvas-scaler {
		transform-origin: top left;
	}

	.canvas {
		width: 1080px;
		height: 1240px;
		background: black;
		color: white;
		overflow: hidden;
		position: relative;
		/* `.canvas-frame`'s `line-height: 0` is inherited CSS meant only to remove the inline-
		   block whitespace gap under this element — but `line-height` inherits, and shadow DOM
		   doesn't block inheritance, so without this reset every bit of text rendered inside the
		   shadow tree (which never declares its own line-height) collapses to 0-height lines and
		   visibly overlaps. Confirmed via a side-by-side clone comparison. */
		line-height: normal;
	}
</style>
