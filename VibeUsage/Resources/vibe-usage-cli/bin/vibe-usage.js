#!/usr/bin/env node

/**
 * vibe-usage CLI entry point.
 * Routes to the appropriate command handler.
 */

import '../src/security.js';

const args = process.argv.slice(2);
const [command, ...commandArgs] = args;
if (command === 'sync' && commandArgs.length === 0) {
  const { runSync } = await import('../src/sync.js');
  await runSync({ surface: 'mac-app' });
} else if (command === 'snapshot') {
  try {
    const { runLocalSnapshot } = await import('../src/local-snapshot.js');
    await runLocalSnapshot(commandArgs);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
  }
} else {
  console.error('The bundled collector accepts only sync or snapshot.');
  process.exitCode = 2;
}
