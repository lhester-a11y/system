/**
 * Locates a Godot 4 executable so the npm scripts can drive the GDScript build.
 *
 * Order: the GODOT environment variable, then the usual names on PATH, then a
 * few standard install locations. Returns null when nothing usable is found.
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

function candidates() {
  const list = [
    process.env.GODOT,
    'godot',
    'godot4',
    'Godot',
    '/usr/local/bin/godot',
    '/usr/bin/godot',
    join(homedir(), 'bin', 'godot'),
    '/Applications/Godot.app/Contents/MacOS/Godot',
  ];
  if (process.platform === 'win32') {
    const programFiles = process.env.ProgramFiles || 'C:\\Program Files';
    const localAppData = process.env.LOCALAPPDATA || '';
    list.push(
      join(programFiles, 'Godot', 'Godot.exe'),
      join(localAppData, 'Programs', 'Godot', 'Godot.exe'),
      'godot.exe',
    );
  }
  return list.filter(Boolean);
}

export function findGodot() {
  for (const candidate of candidates()) {
    if (candidate.includes('/') || candidate.includes('\\')) {
      if (!existsSync(candidate)) continue;
    }
    try {
      const probe = spawnSync(candidate, ['--version'], { encoding: 'utf8', timeout: 30000 });
      if (probe.status === 0 && /^4\./.test(String(probe.stdout).trim())) {
        return candidate;
      }
    } catch {
      /* keep looking */
    }
  }
  return null;
}

export const GODOT_HELP =
  'Install Godot 4.2+ and put it on PATH, or point GODOT at the executable (e.g. GODOT=/opt/godot/godot).';
