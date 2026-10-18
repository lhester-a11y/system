/**
 * Pure game rules: level configuration, upgrade table, scoring, badges and the shop.
 * No DOM, no canvas - every function here is unit-testable.
 */
import { QUESTIONS, LANGUAGES, questionsFor } from '../data/questions.js';

// Re-exported so the rest of the app can treat rules.js as the single data facade.
export { QUESTIONS, LANGUAGES, questionsFor };

export const START_HEARTS = 3;
export const HEART_CAP = 5;

/* --------------------------------- levels -------------------------------- */

/** Language + difficulty + pacing for a module. Modules beyond 6 replay the languages harder. */
export function levelConfig(module) {
  const m = Math.max(1, Math.floor(module));
  const langIndex = (m - 1) % LANGUAGES.length;
  const lap = Math.floor((m - 1) / LANGUAGES.length); // 0 = first pass, 1 = second pass...
  const lang = LANGUAGES[langIndex];
  return {
    module: m,
    lang: lang.id,
    langName: lang.name,
    sky: lang.sky,
    lap,
    checkpoints: 4 + Math.min(m, 4),
    maxDifficulty: m <= 2 ? 2 : 3,
    batSpeed: 46 + m * 5 + lap * 10,
    spawnInterval: Math.max(0.85, 1.9 - m * 0.1),
    batAltitudeMin: 110,
    batAltitudeMax: 330,
    swoopChance: Math.min(0.5, 0.1 + m * 0.05),
    bossHp: 2 + Math.ceil(m / 2),
    bossSpeed: 32 + m * 4,
    bossFireInterval: Math.max(0.8, 1.7 - m * 0.1),
    bugSpeed: 105 + m * 8,
  };
}

/* ------------------------------- upgrades -------------------------------- */

export const UPGRADES = [
  { id: 'damage',    icon: '🗡', name: 'Sharpened Spear', max: 3, describe: (lv) => `+${lv} spear damage` },
  { id: 'speed',     icon: '💨', name: 'Swift Feet',      max: 3, describe: (lv) => `+${lv * 18}% move speed` },
  { id: 'cooldown',  icon: '⏱', name: 'Quick Hands',      max: 3, describe: (lv) => `throw ${lv * 22}% faster` },
  { id: 'shield',    icon: '🛡', name: 'Anito Shield',    max: 3, describe: (lv) => `${lv} shield charge${lv > 1 ? 's' : ''}` },
  // No Triple Throw: throwing is single - one press, one spear - so the fan of
  // three was the one buff that had to go.
  { id: 'pierce',    icon: '➹',  name: 'Piercing Tip',    max: 2, describe: (lv) => (lv >= 2 ? 'spears pierce bats and bosses' : 'spears pierce bats') },
];

export const UPGRADE_IDS = UPGRADES.map((u) => u.id);

export function upgradeDef(id) {
  return UPGRADES.find((u) => u.id === id) || null;
}

export function emptyUpgrades() {
  return UPGRADE_IDS.reduce((acc, id) => ({ ...acc, [id]: 0 }), {});
}

/** Human sentence for a level-up, e.g. "Sharpened Spear Lv2 (+2 spear damage)". */
export function upgradeLabel(id, level) {
  const def = upgradeDef(id);
  if (!def) return 'Upgrade';
  return `${def.name} Lv${level} (${def.describe(level)})`;
}

/**
 * Weighted pick of an upgrade the player does not have maxed yet.
 * `affinity` is the topic family of the question that was just answered.
 */
export function chooseUpgrade(rng, upgrades, affinity) {
  const pool = UPGRADES.filter((u) => (upgrades[u.id] || 0) < u.max);
  if (!pool.length) return null;
  const weights = pool.map((u) => (u.id === affinity ? 3 : 1));
  const total = weights.reduce((a, b) => a + b, 0);
  let roll = rng() * total;
  for (let i = 0; i < pool.length; i += 1) {
    roll -= weights[i];
    if (roll <= 0) return pool[i].id;
  }
  return pool[pool.length - 1].id;
}

/* -------------------------------- scoring -------------------------------- */

const BASE_POINTS = { 1: 10, 2: 15, 3: 25 };

/** Points for a correct answer. Streaks reward consistency, not participation. */
export function pointsForCorrect(difficulty, streak = 0, bonusPerAnswer = 0) {
  const base = BASE_POINTS[difficulty] || 10;
  const streakBonus = streak >= 5 ? 10 : streak >= 3 ? 5 : 0;
  return base + streakBonus + bonusPerAnswer;
}

export function bossPoints(module) {
  return 60 + module * 15;
}

export function levelClearPoints(module, perfectAnswers) {
  return 40 + module * 10 + (perfectAnswers ? 50 : 0);
}

/* ------------------------------- progression ----------------------------- */

/** Unique correctly-answered question ids for a language. */
export function solvedIds(progress, lang) {
  const answered = progress.answered || {};
  return QUESTIONS.filter((q) => q.lang === lang && answered[q.id]).map((q) => q.id);
}

export function masteryPercent(progress, lang) {
  const total = questionsFor(lang).length;
  if (!total) return 0;
  return Math.min(100, Math.round((solvedIds(progress, lang).length / total) * 100));
}

export function accuracy(progress) {
  const correct = progress.correct || 0;
  const wrong = progress.wrong || 0;
  const attempts = correct + wrong;
  if (!attempts) return 0;
  return Math.round((correct / attempts) * 100);
}

/* --------------------------------- badges -------------------------------- */

function langName(lang) {
  const l = LANGUAGES.find((x) => x.id === lang);
  return l ? l.name : lang;
}

function bestUpgradeLevel(progress) {
  const up = progress.upgrades || {};
  return UPGRADE_IDS.reduce((max, id) => Math.max(max, up[id] || 0), 0);
}

export const BADGES = [
  { id: 'first-spear',  icon: '🏹', name: 'First Spear',      desc: 'Answer 1 checkpoint correctly',        check: (p) => (p.correct || 0) >= 1 },
  { id: 'streak-5',     icon: '🔥', name: 'Hot Streak',       desc: '5 correct answers in a row',           check: (p) => (p.bestStreak || 0) >= 5 },
  { id: 'ten-check',    icon: '🎯', name: 'Ten Checkpoints',  desc: 'Answer 10 checkpoints correctly',      check: (p) => (p.correct || 0) >= 10 },
  { id: 'sharpened',    icon: '🪨', name: 'Sharpened Stone',  desc: 'Reach level 3 of any upgrade',         check: (p) => bestUpgradeLevel(p) >= 3 },
  { id: 'boss-slayer',  icon: '👑', name: 'Boss Slayer',      desc: 'Defeat your first Boss bat',           check: (p) => (p.bossesDefeated || 0) >= 1 },
  { id: 'tradepost',    icon: '🛍', name: 'Tradepost Regular', desc: 'Own 3 items from the shop',           check: (p) => (p.owned || []).length >= 3 },
  { id: 'six-mountains',icon: '🎓', name: 'Six Mountains',    desc: 'Clear all six language modules',       check: (p) => (p.modulesCleared || 0) >= LANGUAGES.length },
  ...LANGUAGES.flatMap((l) => [
    {
      id: `${l.id}-trainee`, icon: '🥉', name: `${l.name} Trainee`,
      desc: `Answer 3 ${l.name} checkpoints correctly`,
      check: (p) => solvedIds(p, l.id).length >= 3,
    },
    {
      id: `${l.id}-master`, icon: '🥇', name: `${l.name} Master`,
      desc: `Master every ${l.name} checkpoint (${questionsFor(l.id).length} questions)`,
      check: (p) => solvedIds(p, l.id).length >= questionsFor(l.id).length,
    },
  ]),
];

export function badgeById(id) {
  return BADGES.find((b) => b.id === id) || null;
}

/** Every badge id the progress now qualifies for. */
export function earnedBadges(progress) {
  return BADGES.filter((b) => {
    try { return Boolean(b.check(progress)); } catch { return false; }
  }).map((b) => b.id);
}

/** Badge ids that are newly unlocked. */
export function newBadges(progress, alreadyOwned) {
  const owned = new Set(alreadyOwned || []);
  return earnedBadges(progress).filter((id) => !owned.has(id));
}

/* ---------------------------------- shop --------------------------------- */

export const SHOP_CATEGORIES = [
  { id: 'spear',    name: 'Spears',    slot: 'spear' },
  { id: 'garment',  name: 'Garments',  slot: 'garment' },
  { id: 'effect',   name: 'Effects',   slot: 'effect' },
];

export const SHOP_ITEMS = [
  { id: 'spear-bamboo',  cat: 'spear',   name: 'Bamboo Spear',     cost: 0,   free: true, perk: null,                 desc: 'A spear cut from the groves below the terraces.' },
  { id: 'spear-iron',    cat: 'spear',   name: 'Iron Spear',       cost: 120, perk: 'spearSpeed',  value: 0.1,  desc: 'Trade-wrought iron head.' , perkText: '+10% spear speed' },
  { id: 'spear-gold',    cat: 'spear',   name: 'Gilded Spear',     cost: 300, perk: 'pointBonus',  value: 1,    desc: 'Blessed by the elders of the village.', perkText: '+1 point per correct answer' },
  { id: 'spear-crystal', cat: 'spear',   name: 'Crystal Spear',    cost: 650, perk: 'startShield', value: 1,    desc: 'Carved from a cold mountain spring.', perkText: 'Start every module with a shield' },

  { id: 'garment-bahag', cat: 'garment', name: 'Woven Bahag',      cost: 0,   free: true, perk: null,                 desc: 'Traditional loincloth of the Cordillera.' },
  { id: 'garment-tapis', cat: 'garment', name: 'Embroidered Tapis',cost: 160, perk: 'moveSpeed',   value: 0.05, desc: 'Layered wrap with geometric patterns.', perkText: '+5% move speed' },
  { id: 'garment-blank', cat: 'garment', name: 'Mountain Blanket', cost: 340, perk: 'maxHearts',   value: 1,    desc: 'Thick weave against the cold.',         perkText: '+1 maximum heart' },
  { id: 'garment-crown', cat: 'garment', name: 'Elder Headdress',  cost: 520, perk: 'revive',      value: 1,    desc: 'Hornbill feathers of the respected.',   perkText: 'Survive one fatal hit per module' },

  { id: 'effect-none',   cat: 'effect',  name: 'No Effect',        cost: 0,   free: true, desc: 'Clean and simple.' },
  { id: 'effect-fly',    cat: 'effect',  name: 'Fireflies',        cost: 90,  desc: 'Alagaw fireflies trail your spear.' },
  { id: 'effect-ember',  cat: 'effect',  name: 'Ember Trail',      cost: 210, desc: 'Glowing embers drift behind you.' },
  { id: 'effect-leaf',   cat: 'effect',  name: 'Leaf Swirl',       cost: 380, desc: 'Falling leaves circle the warrior.' },
  { id: 'effect-spark',  cat: 'effect',  name: 'Crystal Sparks',   cost: 600, desc: 'Cold blue sparks on every hit.' },
];

export function shopItem(id) {
  return SHOP_ITEMS.find((i) => i.id === id) || null;
}

export function itemsInCategory(cat) {
  return SHOP_ITEMS.filter((i) => i.cat === cat);
}

export const DEFAULT_EQUIPPED = { spear: 'spear-bamboo', garment: 'garment-bahag', effect: 'effect-none' };

/** Total perk value across every owned OR equipped item of a given perk key. */
export function perkTotal(progress, perk) {
  const owned = new Set([...(progress.owned || [])]);
  // default equipment always counts as owned
  Object.values(DEFAULT_EQUIPPED).forEach((id) => owned.add(id));
  return SHOP_ITEMS.filter((i) => owned.has(i.id) && i.perk === perk).reduce((sum, i) => sum + (i.value || 0), 0);
}

/** Gameplay numbers from an upgrade map plus flat perk bonuses. Pure and reusable by the simulation. */
export function statsFromUpgrades(up, perks = {}) {
  const u = { ...emptyUpgrades(), ...(up || {}) };
  const p = {
    moveSpeed: 0, spearSpeed: 0, pointBonus: 0,
    maxHearts: 0, startShield: 0, revive: 0,
    ...(perks || {}),
  };
  const maxHearts = Math.min(HEART_CAP, START_HEARTS + p.maxHearts);
  return {
    weaponDamage: 1 + u.damage,
    moveSpeed: 130 * (1 + u.speed * 0.18) * (1 + p.moveSpeed),
    throwCooldown: Math.max(0.18, 0.62 * (1 - u.cooldown * 0.22)),
    spearSpeed: 430 * (1 + p.spearSpeed),
    maxHearts,
    startHearts: maxHearts,
    startShield: u.shield + p.startShield,
    pierce: u.pierce,
    pointBonus: p.pointBonus,
    revives: p.revive,
  };
}

/** Flat perk totals contributed by everything the player owns. */
export function perksFrom(progress) {
  return {
    moveSpeed: perkTotal(progress, 'moveSpeed'),
    spearSpeed: perkTotal(progress, 'spearSpeed'),
    pointBonus: perkTotal(progress, 'pointBonus'),
    maxHearts: perkTotal(progress, 'maxHearts'),
    startShield: perkTotal(progress, 'startShield'),
    revive: perkTotal(progress, 'revive'),
  };
}

export function derivedStats(progress) {
  return statsFromUpgrades(progress.upgrades, perksFrom(progress));
}

/** Can the player buy this item right now? */
export function canBuy(progress, itemId) {
  const item = shopItem(itemId);
  if (!item) return { ok: false, reason: 'Unknown item' };
  if ((progress.owned || []).includes(itemId)) return { ok: false, reason: 'Already owned' };
  if ((progress.points || 0) < item.cost) return { ok: false, reason: 'Not enough points' };
  return { ok: true };
}

/** Pure purchase: returns a NEW progress object (or the same one when the purchase fails). */
export function buyItem(progress, itemId) {
  const check = canBuy(progress, itemId);
  const item = shopItem(itemId);
  if (!check.ok) return { progress, item, ok: false, reason: check.reason };
  const next = { ...progress, points: progress.points - item.cost, owned: [...(progress.owned || []), itemId] };
  return { progress: next, item, ok: true, reason: null };
}

/** Pure equip: returns a NEW progress object. */
export function equipItem(progress, itemId) {
  const item = shopItem(itemId);
  if (!item) return { progress, ok: false, reason: 'Unknown item' };
  const owned = new Set([...(progress.owned || []), ...Object.values(DEFAULT_EQUIPPED)]);
  if (!owned.has(itemId)) return { progress, ok: false, reason: 'Not owned' };
  return { progress: { ...progress, equipped: { ...DEFAULT_EQUIPPED, ...(progress.equipped || {}), [item.cat]: itemId } }, ok: true, reason: null };
}
