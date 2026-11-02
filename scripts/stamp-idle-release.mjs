import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

function assetFiles(directory) {
  const root = join(directory, 'assets');
  if (!existsSync(root)) throw Error('Flutter assets missing');
  const files = [];
  function visit(path) {
    for (const entry of readdirSync(path, { withFileTypes: true })) {
      const child = join(path, entry.name);
      if (entry.isDirectory()) visit(child);
      else if (entry.isFile()) files.push(child);
    }
  }
  visit(root);
  return files.sort((a, b) => a.localeCompare(b, 'en'));
}

function digest(directory) {
  const bundle = createHash('sha256')
    .update(readFileSync(join(directory, 'main.dart.js'))).digest('hex');
  const assets = createHash('sha256');
  for (const file of assetFiles(directory)) {
    assets.update(relative(directory, file).replaceAll('\\', '/'));
    assets.update('\0');
    assets.update(readFileSync(file));
  }
  return { bundleSha256: bundle, assetsSha256: assets.digest('hex') };
}

export function stampRelease(release, directory) {
  if (!/^[0-9a-f]{7,40}$/i.test(release)) throw Error('Invalid release SHA');
  const identity = { release, ...digest(directory) };
  writeFileSync(join(directory, 'release-id.json'), JSON.stringify(identity) + '\n');
  return identity;
}

export function verifyRelease(directory) {
  const identity = JSON.parse(readFileSync(join(directory, 'release-id.json'), 'utf8'));
  const current = digest(directory);
  return identity.bundleSha256 === current.bundleSha256 &&
      identity.assetsSha256 === current.assetsSha256;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [, , release, directory] = process.argv;
  if (!directory) throw Error('Usage: node stamp-idle-release.mjs RELEASE BUILD_DIR');
  stampRelease(release, directory);
  if (!verifyRelease(directory)) throw Error('Release identity does not match build');
}
