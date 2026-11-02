import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createContext, runInContext } from 'node:vm';
import { stampRelease, verifyRelease } from './stamp-idle-release.mjs';

const workerSource = readFileSync(new URL('../idle_flutter/web/kardrune_service_worker.js', import.meta.url), 'utf8');
const indexSource = readFileSync(new URL('../idle_flutter/web/index.html', import.meta.url), 'utf8');

test('a new release preloads current artwork and serves it after an older cache', async () => {
  const requests = [];
  const stores = new Map([['idle-kardrune-flutter-v4', new Map([
    ['https://kardrune.com/idle/assets/assets/idle/arena/arena_background.webp', new Response('old arena')],
  ])]]);
  let online = true;
  const listeners = new Map();
  const scope = 'https://kardrune.com/idle/';
  const cache = (name) => {
    if (!stores.has(name)) stores.set(name, new Map());
    const entries = stores.get(name);
    return {
      addAll: async (paths) => {
        for (const path of paths) {
          const request = new Request(new URL(path, scope));
          entries.set(request.url, await context.fetch(request));
        }
      },
      put: async (request, response) => entries.set(new URL(request.url).href, response),
      match: async (request) => entries.get(new URL(request.url).href),
    };
  };
  const context = createContext({
    URL, Request, Response,
    self: {
      registration: { scope },
      clients: { claim: async () => {} },
      addEventListener: (type, callback) => listeners.set(type, callback),
      skipWaiting: () => {},
    },
    caches: {
      open: async (name) => cache(name),
      keys: async () => [...stores.keys()],
      delete: async (name) => stores.delete(name),
      match: async (request) => {
        for (const entries of stores.values()) {
          const response = entries.get(new URL(request.url).href);
          if (response) return response;
        }
      },
    },
    fetch: async (url, options) => {
      requests.push({ url: String(url), options });
      if (!online) throw Error('offline');
      return new Response(String(url).includes('arena_background.webp') ? 'new arena' : 'current asset');
    },
  });
  runInContext(workerSource.replaceAll('__KARDRUNE_PACKAGED_RELEASE__', 'new1234'), context);
  const wait = (type, extra = {}) => {
    let pending;
    listeners.get(type)({ ...extra, waitUntil: (promise) => { pending = promise; } });
    return pending;
  };
  await wait('install');
  await wait('activate');
  const asset = new Request(scope + 'assets/assets/idle/arena/arena_background.webp');
  let response;
  listeners.get('fetch')({ request: asset, respondWith: (promise) => { response = promise; }, waitUntil: () => {} });
  assert.equal(await (await response).text(), 'new arena');
  assert.ok(requests.some(({ url }) => url.includes('arena_background.webp?krv=new1234')));
  assert.ok(requests.every(({ options }) => options?.cache === 'reload'));
  assert.equal(stores.has('idle-kardrune-flutter-v4'), false);
  online = false;
  listeners.get('fetch')({ request: asset, respondWith: (promise) => { response = promise; }, waitUntil: () => {} });
  assert.equal(await (await response).text(), 'new arena');
});

test('release activation waits for the new controller and versioned worker', () => {
  for (const [, script] of indexSource.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) {
    new Function(script);
  }
  assert.equal(indexSource.includes('kardrune_service_worker.js?v=__KARDRUNE_PACKAGED_RELEASE__'), true);
  assert.equal(indexSource.includes('controllerchange'), true);
  assert.equal(indexSource.includes('setTimeout(() => window.location.reload(), 450)'), false);
});

test('release identity proves the bundle and asset contents match', () => {
  const directory = mkdtempSync(join(tmpdir(), 'kardrune-release-'));
  mkdirSync(join(directory, 'assets'));
  writeFileSync(join(directory, 'main.dart.js'), 'current bundle');
  writeFileSync(join(directory, 'assets', 'arena.webp'), 'current artwork');
  stampRelease('abc1234', directory);
  assert.equal(verifyRelease(directory), true);
  writeFileSync(join(directory, 'assets', 'arena.webp'), 'stale artwork');
  assert.equal(verifyRelease(directory), false);
});
