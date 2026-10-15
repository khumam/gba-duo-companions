import { readFileSync, writeFileSync, statSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { json, error } from '@sveltejs/kit';

const PACKS_DIR = join(process.cwd(), '..', 'packs');

function readJsonIfExists(path) {
	if (!existsSync(path)) return null;
	return JSON.parse(readFileSync(path, 'utf-8'));
}

function mtimeIfExists(path) {
	if (!existsSync(path)) return 0;
	return statSync(path).mtimeMs;
}

export function GET({ params }) {
	const packDir = join(PACKS_DIR, params.id);
	if (!existsSync(packDir)) throw error(404, 'Pack not found');

	const manifestPath = join(packDir, 'manifest.json');
	const manifest = readJsonIfExists(manifestPath);
	if (!manifest) throw error(400, 'Pack is missing manifest.json');

	const layoutPath = join(packDir, manifest.layout ?? 'layout.json');
	const layoutJson = existsSync(layoutPath) ? readFileSync(layoutPath, 'utf-8') : null;

	const previewDataPath = join(packDir, 'preview-data.json');
	// Raw text too, so the editor shows the file exactly as written — re-serializing it would
	// make the first keystroke's save reformat the whole file.
	const previewDataJson = existsSync(previewDataPath) ? readFileSync(previewDataPath, 'utf-8') : null;
	let previewData = {};
	try {
		previewData = previewDataJson ? JSON.parse(previewDataJson) : {};
	} catch {
		previewData = {};
	}

	const styleFiles = Array.isArray(manifest.styles) ? manifest.styles : [];
	const stylePaths = styleFiles.map((f) => join(packDir, f));
	const styleCss = stylePaths.length
		? stylePaths
				.filter((p) => existsSync(p))
				.map((p) => readFileSync(p, 'utf-8'))
				.join('\n')
		: null;
	const styleMtime = stylePaths.reduce((max, p) => Math.max(max, mtimeIfExists(p)), 0);

	return json({
		manifest,
		layoutJson,
		styleCss,
		previewData,
		previewDataJson,
		mtimes: {
			layout: mtimeIfExists(layoutPath),
			previewData: mtimeIfExists(previewDataPath),
			style: styleMtime
		}
	});
}

const EDITABLE_FILES = new Set(['layout', 'style', 'previewData']);

/**
 * Saves one of the three editor tabs back to the pack's real file on disk. `file` selects
 * which one (`layout`/`style`/`previewData`); the actual filename is resolved from the
 * pack's manifest.json the same way GET resolves it, not hardcoded, so a pack that names its
 * layout/style files differently still saves to the right place. `style` requires exactly
 * one entry in `manifest.styles` — concatenating edits across multiple stylesheet files back
 * into one save has no sensible meaning, and both real packs only declare one anyway.
 */
export async function PUT({ params, request }) {
	const packDir = resolve(join(PACKS_DIR, params.id));
	if (!packDir.startsWith(resolve(PACKS_DIR))) throw error(403, 'Invalid pack id');
	if (!existsSync(packDir)) throw error(404, 'Pack not found');

	const { file, content } = await request.json();
	if (!EDITABLE_FILES.has(file) || typeof content !== 'string') {
		throw error(400, 'Expected { file: "layout"|"style"|"previewData", content: string }');
	}

	const manifest = readJsonIfExists(join(packDir, 'manifest.json'));
	if (!manifest) throw error(400, 'Pack is missing manifest.json');

	let targetPath;
	if (file === 'layout') {
		targetPath = join(packDir, manifest.layout ?? 'layout.json');
	} else if (file === 'previewData') {
		targetPath = join(packDir, 'preview-data.json');
	} else {
		const styleFiles = Array.isArray(manifest.styles) ? manifest.styles : [];
		if (styleFiles.length !== 1) {
			throw error(400, `Can't save: manifest declares ${styleFiles.length} style files, expected exactly 1`);
		}
		targetPath = join(packDir, styleFiles[0]);
	}

	const resolvedTarget = resolve(targetPath);
	if (!resolvedTarget.startsWith(resolve(packDir))) throw error(403, 'Invalid file path');

	writeFileSync(resolvedTarget, content, 'utf-8');
	return json({ saved: true, mtime: mtimeIfExists(resolvedTarget) });
}
