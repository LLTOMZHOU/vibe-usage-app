import assert from 'node:assert/strict';
import { mkdtemp, readFile, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

const collectorRoot = new URL('../VibeUsage/Resources/vibe-usage-cli/', import.meta.url);

test('registered parsers exclude credential and process inspection paths', async () => {
  const { parsers } = await import(new URL('src/parsers/index.js', collectorRoot));
  assert.equal('cursor' in parsers, false);
  assert.equal('antigravity' in parsers, false);
  assert.ok('codex' in parsers);
  assert.ok('claude-code' in parsers);
});

test('environment-injected API key is never persisted', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'vibe-usage-hardened-config-'));
  process.env.VIBE_USAGE_CONFIG_DIR = dir;
  process.env.VIBE_USAGE_API_KEY = 'vbu_test_environment_secret';

  const configModule = await import(
    new URL(`src/config.js?test=${Date.now()}`, collectorRoot)
  );
  configModule.saveConfig({
    apiKey: 'vbu_test_environment_secret',
    apiUrl: 'https://vibecafe.ai',
  });

  const path = configModule.getConfigPath();
  const contents = await readFile(path, 'utf8');
  assert.equal(contents.includes('vbu_test_environment_secret'), false);
  assert.equal(configModule.loadConfig().apiKey, 'vbu_test_environment_secret');

  if (process.platform !== 'win32') {
    assert.equal((await stat(dir)).mode & 0o777, 0o700);
    assert.equal((await stat(path)).mode & 0o777, 0o600);
  }
});

test('client metadata omits runtime fingerprint fields', async () => {
  const { createSyncClient } = await import(new URL('src/client-meta.js', collectorRoot));
  const client = createSyncClient({ hostname: 'Mac-private' });
  assert.equal('runtime' in client, false);
  assert.equal('runtimeVersion' in client, false);
  assert.equal('platform' in client, false);
  assert.equal(client.hostname, 'Mac-private');
});

test('public leaderboard is opt-in and server changes are verified', async () => {
  const { desiredShowInRank, enforceShowInRank } = await import(
    new URL('src/api.js', collectorRoot)
  );

  assert.equal(desiredShowInRank(undefined), false);
  assert.equal(desiredShowInRank('0'), false);
  assert.equal(desiredShowInRank('1'), true);

  const patches = [];
  const responses = [
    { uploadProject: false, showInRank: true },
    { uploadProject: false, showInRank: false },
  ];
  const settings = await enforceShowInRank('https://vibecafe.ai', 'test-key', false, {
    fetchSettings: async () => responses.shift(),
    patchSettings: async (_apiUrl, _apiKey, patch) => { patches.push(patch); },
  });
  assert.deepEqual(patches, [{ showInRank: false }]);
  assert.equal(settings.showInRank, false);
});

test('sync fails closed when the server does not confirm leaderboard privacy', async () => {
  const { enforceShowInRank } = await import(new URL('src/api.js', collectorRoot));
  await assert.rejects(
    enforceShowInRank('https://vibecafe.ai', 'test-key', false, {
      fetchSettings: async () => ({ uploadProject: false, showInRank: true }),
      patchSettings: async () => {},
    }),
    /PRIVACY_SETTING_UNVERIFIED/,
  );
});
