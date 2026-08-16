import { readFileSync, writeFileSync, chmodSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

// VIBE_USAGE_CONFIG_DIR overrides the dir (test hook).
const CONFIG_DIR = process.env.VIBE_USAGE_CONFIG_DIR?.trim() || join(homedir(), '.vibe-usage');
const isDev = process.env.VIBE_USAGE_DEV === '1';
const CONFIG_FILE = join(CONFIG_DIR, isDev ? 'config.dev.json' : 'config.json');

export function getConfigPath() {
  return CONFIG_FILE;
}

export function loadConfig() {
  if (!existsSync(CONFIG_FILE)) {
    const apiKey = process.env.VIBE_USAGE_API_KEY?.trim();
    return apiKey ? { apiKey } : null;
  }
  try {
    const config = JSON.parse(readFileSync(CONFIG_FILE, 'utf-8'));
    const apiKey = process.env.VIBE_USAGE_API_KEY?.trim();
    if (apiKey) config.apiKey = apiKey;
    return config;
  } catch {
    return null;
  }
}

export function saveConfig(config) {
  mkdirSync(CONFIG_DIR, { recursive: true, mode: 0o700 });
  const persisted = { ...config };
  // The hardened app injects its Keychain-backed secret into this one child
  // process. Never copy that environment secret back into plaintext JSON.
  if (process.env.VIBE_USAGE_API_KEY?.trim()) delete persisted.apiKey;
  // The file holds the vbu_ API key — never leave it group/world-readable.
  // mode only applies at file creation, so chmod explicitly for pre-existing
  // files written before this hardening.
  writeFileSync(CONFIG_FILE, JSON.stringify(persisted, null, 2) + '\n', { encoding: 'utf-8', mode: 0o600 });
  try {
    chmodSync(CONFIG_FILE, 0o600);
  } catch (err) {
    // Windows permission models vary; on POSIX, do not silently leave an API
    // key file broader than owner-only if hardening a pre-existing file fails.
    if (process.platform !== 'win32') throw err;
  }
}
