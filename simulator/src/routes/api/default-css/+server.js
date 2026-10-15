import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { json } from '@sveltejs/kit';
import { DEFAULT_CSS_FALLBACK } from '../../../lib/renderer/default-css-fallback.js';

// Two levels up from `simulator/`: gbaduo-companions/simulator -> gbaduo-companions -> Roomativ,
// then into the sibling `gbaduo` repo. Read live (not copied at build time) so this can never
// drift from whatever the Compose engine currently ships.
const DEFAULT_CSS_PATH = join(
	process.cwd(),
	'..',
	'..',
	'gbaduo',
	'app',
	'src',
	'main',
	'assets',
	'companion',
	'default.css',
);

export function GET() {
	if (existsSync(DEFAULT_CSS_PATH)) {
		return json({ css: readFileSync(DEFAULT_CSS_PATH, 'utf-8'), source: 'live' });
	}
	return json({ css: DEFAULT_CSS_FALLBACK, source: 'fallback' });
}
