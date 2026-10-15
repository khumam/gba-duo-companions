import { readdirSync } from 'node:fs';
import { join } from 'node:path';

const PACKS_DIR = join(process.cwd(), '..', 'packs');

export function load() {
	const packIds = readdirSync(PACKS_DIR, { withFileTypes: true })
		.filter((entry) => entry.isDirectory())
		.map((entry) => entry.name)
		.sort();
	return { packIds };
}
