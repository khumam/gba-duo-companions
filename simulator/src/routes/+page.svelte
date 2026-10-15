<script>
	import { onDestroy } from 'svelte';
	import { parseLayout } from '../lib/renderer/parse-layout.js';
	import { createRenderer, applyStackChildPlacement, applyBarAccentColors } from '../lib/renderer/render-widget.js';
	import { prepareStylesheetCss, extractFontFaceCss } from '../lib/renderer/prepare-stylesheet.js';

	let { data } = $props();

	let selectedPackId = $state(data.packIds[0] ?? null);
	let canvasEl;
	let currentMtimes = { layout: 0, previewData: 0, style: 0 };
	let pollHandle;
	let defaultCss = '';
	let defaultCssSource = $state('live');
	let previewDataText = $state('{}');
	let previewDataError = $state('');
	let activeRenderer = null;
	// `pollForChanges` fires every 500ms regardless of whether an earlier `loadAndRender` call
	// is still in flight (its awaits can take longer than that, e.g. on first load fetching
	// default-css + pack data). Without this guard, two overlapping calls both end up calling
	// `shadowRoot.innerHTML = ''` and rebuilding — interleaved DOM mutations on the same shadow
	// tree produce visibly broken layout (confirmed: text lines collapsing to 0-height and
	// overlapping). Each call captures its own generation number and bails before touching the
	// DOM if a newer call has since started, so only the most recent call's result ever lands.
	let renderGeneration = 0;

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
	 * load — covers both pack switching and live-reload without accumulating stale rules.
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

	/**
	 * Re-runs the binding pass with hand-edited preview data, so transition-driven changes
	 * (a bar width/color, a tab pill switch) are visible without needing to execute main.lua.
	 */
	function applyPreviewDataEdit() {
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
		const shadowRoot = getShadowRoot();
		if (shadowRoot.firstElementChild) {
			applyStackChildPlacement(shadowRoot.firstElementChild);
			applyBarAccentColors(shadowRoot.firstElementChild);
		}
	}

	async function loadAndRender(packId) {
		if (!packId || !canvasEl) return;
		const myGeneration = ++renderGeneration;

		await ensureDefaultCss();
		if (myGeneration !== renderGeneration) return;

		const res = await fetch(`/api/pack/${packId}`);
		if (!res.ok) return;
		const packData = await res.json();
		if (myGeneration !== renderGeneration) return;

		currentMtimes = packData.mtimes;
		previewDataText = JSON.stringify(packData.previewData, null, 2);
		previewDataError = '';

		const shadowRoot = getShadowRoot();
		shadowRoot.innerHTML = '';
		activeRenderer = null;
		if (!packData.layoutJson) {
			shadowRoot.textContent = 'Pack has no layout.json';
			return;
		}

		let widget;
		try {
			widget = parseLayout(packData.layoutJson);
		} catch (e) {
			shadowRoot.textContent = `Layout error: ${e.message}`;
			return;
		}

		const packBaseUrl = `/packs/${packId}`;
		const styleEl = document.createElement('style');
		styleEl.textContent = prepareStylesheetCss(packData.styleCss ?? '', packBaseUrl, defaultCss);
		shadowRoot.appendChild(styleEl);
		if (packData.styleCss) {
			injectGlobalFontFaces(extractFontFaceCss(packData.styleCss, packBaseUrl));
		}

		const renderer = createRenderer(packBaseUrl);
		const rootEl = renderer.build(widget);
		// `:root` in a pack's/default.css's CSS (prepare-stylesheet.js) targets this marker,
		// not the shadow host — see that file for why.
		rootEl.setAttribute('data-gbaduo-root', '');
		shadowRoot.appendChild(rootEl);
		activeRenderer = renderer;
		renderer.update(packData.previewData);
		applyStackChildPlacement(rootEl);
		applyBarAccentColors(rootEl);
	}

	async function pollForChanges() {
		if (!selectedPackId) return;
		const res = await fetch(`/api/pack/${selectedPackId}`);
		if (!res.ok) return;
		const packData = await res.json();
		if (
			packData.mtimes.layout !== currentMtimes.layout ||
			packData.mtimes.previewData !== currentMtimes.previewData ||
			packData.mtimes.style !== currentMtimes.style
		) {
			loadAndRender(selectedPackId);
		}
	}

	$effect(() => {
		loadAndRender(selectedPackId);
	});

	pollHandle = setInterval(pollForChanges, 500);
	onDestroy(() => clearInterval(pollHandle));
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
		<h1>GBADuo<br />Companion<br />Simulator</h1>
	</header>

	<section class="controls">
		<label for="pack-select">01 — Pack</label>
		<select id="pack-select" bind:value={selectedPackId}>
			{#each data.packIds as packId (packId)}
				<option value={packId}>{packId}</option>
			{/each}
		</select>
		{#if defaultCssSource === 'fallback'}
			<p class="warning-banner">
				Could not read default.css from the sibling gbaduo repo — using a bundled copy, which may be stale.
			</p>
		{/if}
	</section>

	<section class="canvas-section">
		<label for="canvas-frame">02 — Preview — 1080 × 1240</label>
		<div id="canvas-frame" class="canvas-frame">
			<div bind:this={canvasEl} class="canvas"></div>
		</div>
	</section>

	<section class="data-section">
		<label for="preview-data">03 — Preview data</label>
		<textarea id="preview-data" bind:value={previewDataText}></textarea>
		{#if previewDataError}<p class="data-error">{previewDataError}</p>{/if}
		<button type="button" onclick={applyPreviewDataEdit}>Apply</button>
	</section>
</main>

<style>
	:global(body) {
		margin: 0;
		background: #f5f5f0;
		color: #111111;
		font-family: 'Inter', sans-serif;
	}

	main {
		display: grid;
		grid-template-columns: 240px 1fr;
		grid-template-rows: auto 1fr;
		gap: 0;
		max-width: 1440px;
		min-height: 100vh;
		margin: 0 auto;
		box-sizing: border-box;
	}

	header {
		grid-column: 1;
		grid-row: 1 / -1;
		padding: 48px 32px 32px 48px;
		border-right: 1px solid #111111;
		box-sizing: border-box;
	}

	.mark {
		display: block;
		width: 16px;
		height: 16px;
		background: #d40000;
		margin-bottom: 24px;
	}

	h1 {
		font-size: 22px;
		font-weight: 700;
		line-height: 1.15;
		letter-spacing: -0.02em;
		margin: 0;
		text-transform: uppercase;
	}

	label {
		display: block;
		font-size: 11px;
		font-weight: 600;
		letter-spacing: 0.12em;
		text-transform: uppercase;
		color: #111111;
		margin-bottom: 12px;
	}

	.controls {
		grid-column: 2;
		padding: 48px 48px 24px 48px;
		border-bottom: 1px solid #111111;
	}

	select {
		appearance: none;
		font-family: 'Inter', sans-serif;
		font-size: 14px;
		font-weight: 500;
		padding: 10px 14px;
		background: #ffffff;
		color: #111111;
		border: 1px solid #111111;
		border-radius: 0;
		min-width: 280px;
	}

	select:focus {
		outline: none;
		border-color: #d40000;
		box-shadow: inset 0 0 0 1px #d40000;
	}

	.canvas-section {
		grid-column: 2;
		padding: 32px 48px 48px 48px;
	}

	.canvas-frame {
		display: inline-block;
		border: 1px solid #111111;
		line-height: 0;
	}

	.canvas {
		width: 1080px;
		height: 1240px;
		background: black;
		color: white;
		overflow: hidden;
		position: relative;
		/* `.canvas-frame`'s `line-height: 0` (below) is inherited CSS meant only to remove the
		   inline-block whitespace gap under this element — but `line-height` inherits, and shadow
		   DOM doesn't block inheritance, so without this reset every bit of text rendered inside
		   the shadow tree (which never declares its own line-height) collapses to 0-height lines
		   and visibly overlaps. Confirmed via a side-by-side clone comparison. */
		line-height: normal;
	}

	.warning-banner {
		margin: 12px 0 0;
		padding: 8px 12px;
		background: #fff3cd;
		border: 1px solid #d4a017;
		font-size: 12px;
	}

	.data-section {
		grid-column: 2;
		padding: 0 48px 48px 48px;
	}

	#preview-data {
		width: 100%;
		min-height: 180px;
		box-sizing: border-box;
		font-family: monospace;
		font-size: 13px;
		padding: 12px;
		border: 1px solid #111111;
	}

	.data-error {
		color: #d40000;
		font-size: 12px;
		margin: 8px 0;
	}

	.data-section button {
		margin-top: 8px;
		font-family: 'Inter', sans-serif;
		font-size: 13px;
		font-weight: 600;
		padding: 8px 16px;
		background: #111111;
		color: #ffffff;
		border: none;
		cursor: pointer;
	}
</style>
