import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { error } from '@sveltejs/kit';

const PACKS_DIR = join(process.cwd(), '..', 'packs');

const MIME_TYPES = {
	'.ttf': 'font/ttf',
	'.png': 'image/png',
	'.jpg': 'image/jpeg',
	'.jpeg': 'image/jpeg'
};

export function GET({ params }) {
	const filePath = join(PACKS_DIR, params.id, 'assets', params.path);
	if (!filePath.startsWith(join(PACKS_DIR, params.id, 'assets'))) {
		throw error(403, 'Invalid path');
	}
	if (!existsSync(filePath)) throw error(404, 'Asset not found');

	const ext = filePath.slice(filePath.lastIndexOf('.'));
	const contentType = MIME_TYPES[ext] ?? 'application/octet-stream';
	return new Response(readFileSync(filePath), {
		headers: { 'content-type': contentType }
	});
}
