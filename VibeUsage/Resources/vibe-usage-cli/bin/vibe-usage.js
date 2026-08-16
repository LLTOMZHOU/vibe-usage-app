#!/usr/bin/env node

/**
 * vibe-usage CLI entry point.
 * Routes to the appropriate command handler.
 */

import '../src/security.js';
import { runSync } from '../src/sync.js';

const args = process.argv.slice(2);
if (args.length !== 1 || args[0] !== 'sync') {
  console.error('The bundled collector accepts only the sync command.');
  process.exitCode = 2;
} else {
  await runSync({ surface: 'mac-app' });
}
