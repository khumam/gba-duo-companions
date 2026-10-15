import { readFileSync, statSync, existsSync } from 'node:fs';
import { join } from 'node:path';
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
	const previewData = readJsonIfExists(previewDataPath) ?? {};

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
		mtimes: {
			layout: mtimeIfExists(layoutPath),
			previewData: mtimeIfExists(previewDataPath),
			style: styleMtime
		}
	});
}
