/** Persistence: one JSON blob in localStorage, with an in-memory fallback for tests. */
import { emptyUpgrades, DEFAULT_EQUIPPED, SHOP_ITEMS, LANGUAGES } from './rules.js';

export const SAVE_KEY = 'codeplay.save.v1';
export const SAVE_VERSION = 1;

export function defaultProgress() {
  return {
    version: SAVE_VERSION,
    createdAt: null,
    hero: 'boy',
    name: 'Bagani',
    points: 0,
    module: 1,
    highestModule: 1,
    modulesCleared: 0,
    bossesDefeated: 0,
    correct: 0,
    wrong: 0,
    streak: 0,
    bestStreak: 0,
    answered: {},
    mastery: {},
    badges: [],
    owned: SHOP_ITEMS.filter((i) => i.free).map((i) => i.id),
    equipped: { ...DEFAULT_EQUIPPED },
    upgrades: emptyUpgrades(),
    playSeconds: 0,
  };
}

function memoryStorage() {
  const map = new Map();
  return {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, String(v)),
    removeItem: (k) => map.delete(k),
  };
}

/** Pick the best available storage: localStorage when present, otherwise memory. */
export function resolveStorage(preferred) {
  if (preferred) return preferred;
  try {
    if (typeof localStorage !== 'undefined') {
      const probe = '__codeplay_probe__';
      localStorage.setItem(probe, '1');
      localStorage.removeItem(probe);
      return localStorage;
    }
  } catch {
    /* private mode or blocked storage - fall through to memory */
  }
  return memoryStorage();
}

/** Fill in anything missing so an old or hand-edited save still loads. */
export function migrate(raw) {
  const base = defaultProgress();
  if (!raw || typeof raw !== 'object') return base;
  const merged = { ...base, ...raw };
  merged.version = SAVE_VERSION;
  merged.answered = raw.answered && typeof raw.answered === 'object' ? { ...raw.answered } : {};
  merged.mastery = raw.mastery && typeof raw.mastery === 'object' ? { ...raw.mastery } : {};
  merged.badges = Array.isArray(raw.badges) ? [...raw.badges] : [];
  merged.upgrades = { ...base.upgrades, ...(raw.upgrades || {}) };
  merged.equipped = { ...base.equipped, ...(raw.equipped || {}) };
  const owned = Array.isArray(raw.owned) ? [...raw.owned] : [];
  merged.owned = Array.from(new Set([...base.owned, ...owned]));
  merged.points = Math.max(0, Math.floor(Number(merged.points) || 0));
  merged.module = Math.min(LANGUAGES.length * 20, Math.max(1, Math.floor(Number(merged.module) || 1)));
  merged.highestModule = Math.max(merged.module, Math.floor(Number(merged.highestModule) || 1));
  merged.hero = merged.hero === 'girl' ? 'girl' : 'boy';
  merged.name = String(merged.name || 'Bagani').slice(0, 12);
  return merged;
}

export function loadProgress(storage) {
  const store = resolveStorage(storage);
  try {
    const raw = store.getItem(SAVE_KEY);
    if (!raw) {
      const fresh = defaultProgress();
      fresh.createdAt = new Date().toISOString();
      return fresh;
    }
    return migrate(JSON.parse(raw));
  } catch {
    return defaultProgress();
  }
}

export function saveProgress(progress, storage) {
  const store = resolveStorage(storage);
  try {
    store.setItem(SAVE_KEY, JSON.stringify(progress));
    return true;
  } catch {
    return false;
  }
}

export function resetProgress(storage) {
  const store = resolveStorage(storage);
  try { store.removeItem(SAVE_KEY); } catch { /* ignore */ }
  const fresh = defaultProgress();
  fresh.createdAt = new Date().toISOString();
  return fresh;
}
