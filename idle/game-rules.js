/* Pure Idle demo mechanics. Keep portable for browser and Node tests. */
(function (root) {
  'use strict';
  const DAILY_REWARD_LIMIT = 10;
  const MIN_WIN_CHANCE = 0.05;
  const MAX_WIN_CHANCE = 0.90;
  function safeCount(value) {
    return Number.isSafeInteger(value) && value >= 0 ? value : 0;
  }
  function dayKey(now = Date.now()) {
    const day = new Date(now);
    const pad = n => String(n).padStart(2, '0');
    return day.getFullYear() + '-' + pad(day.getMonth() + 1) + '-' + pad(day.getDate());
  }
  function dailyRewardState(progress, now = Date.now()) {
    const today = dayKey(now);
    return {
      day: today,
      count: progress && progress.day === today
        ? Math.min(DAILY_REWARD_LIMIT, safeCount(progress.count)) : 0
    };
  }
  function practiceWinChance(power, stage) {
    const p = Number.isFinite(power) ? power : 0;
    const s = Number.isInteger(stage) ? Math.min(3, Math.max(1, stage)) : 1;
    return Math.max(MIN_WIN_CHANCE,
      Math.min(MAX_WIN_CHANCE, 0.43 + (p + (s - 1) * 18) / 200));
  }
  function resolvePractice(progress, power, stage, roll, now = Date.now()) {
    const chance = practiceWinChance(power, stage);
    const win = roll < chance;
    const daily = dailyRewardState(progress, now);
    const rewarded = daily.count < DAILY_REWARD_LIMIT;
    if (rewarded) daily.count++;
    return {win, chance, reward: rewarded ? (win ? 100 : 35) : 0, daily};
  }
  const rules = Object.freeze({
    DAILY_REWARD_LIMIT, safeCount, dayKey, dailyRewardState,
    practiceWinChance, resolvePractice
  });
  root.IDLE_GAME_RULES = rules;
  if (typeof module !== 'undefined' && module.exports) module.exports = rules;
})(typeof window !== 'undefined' ? window : globalThis);
