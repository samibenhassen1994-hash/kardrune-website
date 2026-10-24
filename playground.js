/* Self-contained, account-free RPG browser tools. No user input is sent to a server. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const page = document.body.dataset.tool;
  if (!page) return;
  const cap = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
  const randInt = max => {
    if (!Number.isSafeInteger(max) || max < 1 || max > 1000000) throw new Error('Invalid random range');
    const cryptoObj = window.crypto;
    if (cryptoObj && typeof cryptoObj.getRandomValues === 'function') {
      const buf = new Uint32Array(1);
      const limit = Math.floor(4294967296 / max) * max;
      do { cryptoObj.getRandomValues(buf); } while (buf[0] >= limit);
      return buf[0] % max;
    }
    return Math.floor(Math.random() * max);
  };
  const percent = n => `${(n * 100).toLocaleString('en-US', { maximumFractionDigits: 4 })}%`;
  const setText = (id, value) => { const node = $(id); if (node) node.textContent = String(value); };

  if (page === 'dice') {
    const history = [];
    const mode = $('dice-mode');
    function toggleMode() {
      const usable = +$('dice-type').value === 20 && +$('dice-count').value === 1;
      if (!usable) mode.value = 'normal';
      mode.disabled = !usable;
      mode.title = usable ? '' : 'Advantage requires exactly one D20';
    }
    $('dice-type').addEventListener('change', toggleMode);
    $('dice-count').addEventListener('input', toggleMode);
    $('dice-form').addEventListener('submit', event => {
      event.preventDefault();
      if (!$('dice-form').reportValidity()) return;
      const sides = Number($('dice-type').value);
      const count = cap(Math.trunc(Number($('dice-count').value)), 1, 20);
      const modifier = cap(Math.trunc(Number($('dice-modifier').value)), -100, 100);
      const special = sides === 20 && count === 1 ? mode.value : 'normal';
      const faces = Array.from({ length: special === 'normal' ? count : 2 }, () => randInt(sides) + 1);
      const rolls = special === 'advantage' ? [Math.max(...faces)] : special === 'disadvantage' ? [Math.min(...faces)] : faces;
      const total = rolls.reduce((a, b) => a + b, 0) + modifier;
      const expression = `${count}d${sides}${modifier ? (modifier < 0 ? ` − ${Math.abs(modifier)}` : ` + ${modifier}`) : ''}${special !== 'normal' ? ` · ${special}` : ''}`;
      setText('dice-total', total);
      setText('dice-expression', expression);
      const faceWrap = $('dice-faces');
      faceWrap.replaceChildren();
      faces.forEach(f => { const span = document.createElement('span'); span.textContent = String(f); faceWrap.appendChild(span); });
      history.unshift(`${expression}: ${faces.join(', ')} → ${total}`);
      history.splice(12);
      const list = $('dice-history'); list.replaceChildren();
      history.forEach(x => { const li = document.createElement('li'); li.textContent = x; list.appendChild(li); });
      $('dice-total').animate?.([{ transform: 'scale(.8)', opacity: .4 }, { transform: 'scale(1)', opacity: 1 }], { duration: 260 });
    });
    $('dice-clear').addEventListener('click', () => { history.length = 0; $('dice-history').replaceChildren(); setText('dice-expression', 'History cleared'); });
    toggleMode();
  }

  if (page === 'gacha') {
    const form = $('gacha-form');
    $('gacha-preset').addEventListener('change', () => {
      if ($('gacha-preset').value === 'event') { $('gacha-rate').value = 10; $('gacha-pity').value = 10; $('gacha-current').value = 0; }
    });
    ['gacha-rate', 'gacha-pity', 'gacha-current'].forEach(id => $(id).addEventListener('input', () => { $('gacha-preset').value = 'custom'; }));
    function settings() {
      if (!form.reportValidity()) return null;
      const rate = Number($('gacha-rate').value) / 100;
      const pity = Math.trunc(Number($('gacha-pity').value));
      const current = Math.trunc(Number($('gacha-current').value));
      const pulls = Math.trunc(Number($('gacha-pulls').value));
      if (!Number.isFinite(rate) || rate < .0001 || rate > 1 || current < 0 || (pity > 0 && current >= pity)) {
        setText('gacha-guarantee', 'Invalid pity position: the current counter must be below the guarantee.');
        return null;
      }
      return { rate, pity, current, pulls };
    }
    function calculate() {
      const settingsValue = settings(); if (!settingsValue) return null;
      const { rate, pity, current, pulls } = settingsValue;
      const guaranteedIn = pity ? pity - current : Infinity;
      const chance = pulls >= guaranteedIn ? 1 : -Math.expm1(pulls * Math.log1p(-rate));
      setText('gacha-chance', percent(chance));
      $('gacha-meter').style.width = `${chance * 100}%`;
      setText('gacha-guarantee', pity ? `Guaranteed success within ${guaranteedIn} pull${guaranteedIn === 1 ? '' : 's'} (if there is no earlier success).` : 'No hard pity: independent base success rate on each pull.');
      return settingsValue;
    }
    form.addEventListener('submit', event => { event.preventDefault(); calculate(); });
    $('gacha-simulate').addEventListener('click', () => {
      const value = calculate(); if (!value) return;
      let successes = 0, first = null, pityCounter = value.current;
      const limit = Math.round(value.rate * 1000000);
      for (let i = 1; i <= value.pulls; i++) {
        pityCounter++;
        const hit = (value.pity > 0 && pityCounter >= value.pity) || randInt(1000000) < limit;
        if (hit) { successes++; first ??= i; pityCounter = 0; }
      }
      setText('gacha-success', successes);
      setText('gacha-first', first === null ? 'None' : `#${first}`);
      setText('gacha-last', pityCounter);
      setText('gacha-sim-note', `One random experiment over ${value.pulls.toLocaleString('en-US')} pulls. It does not affect KardRune inventory.`);
    });
    calculate();
  }

  if (page === 'card') {
    const canvas = $('card-canvas');
    const ctx = canvas.getContext('2d');
    if (!ctx) { setText('card-message', 'Canvas is not supported in this browser.'); return; }
    const sourceImage = new Image();
    let objectUrl = null;
    const colors = {
      Common: ['#b9c7d2', '#243344'], Rare: ['#74d6fd', '#123e68'],
      Epic: ['#d9a3ff', '#483074'], Legendary: ['#ffe3a2', '#674318']
    };
    const oldSrc = 'assets/young_sam_stage_1.webp';
    sourceImage.onload = draw;
    sourceImage.onerror = () => setText('card-message', 'Could not load the selected image.');
    sourceImage.src = oldSrc;
    function roundedRect(x, y, w, h, r) {
      ctx.beginPath(); ctx.roundRect(x, y, w, h, r);
    }
    function centeredFitText(value, x, y, max, px, weight = '700') {
      ctx.font = `${weight} ${px}px Cinzel, serif`;
      let str = String(value).trim();
      while (ctx.measureText(str).width > max && str.length > 1) str = str.slice(0, -2) + '…';
      ctx.fillText(str, x, y);
    }
    function wrapText(text, maxWidth, maxLines) {
      const words = String(text).trim().split(/\s+/).filter(Boolean);
      const lines = []; let line = '';
      for (const word of words) {
        const cand = line ? `${line} ${word}` : word;
        if (ctx.measureText(cand).width > maxWidth && line) { lines.push(line); line = word; }
        else line = cand;
        if (lines.length >= maxLines) break;
      }
      if (line && lines.length < maxLines) lines.push(line);
      return lines;
    }
    function draw() {
      const rarity = $('card-rarity').value;
      const [a, b] = colors[rarity];
      const name = $('card-name').value || 'Unnamed Hero';
      const element = $('card-element').value;
      const power = cap(Math.trunc(Number($('card-power').value) || 1), 1, 9999);
      const ability = $('card-skill').value || 'A new legend rises.';
      const g = ctx.createLinearGradient(0, 0, 720, 1008);
      g.addColorStop(0, '#101c34'); g.addColorStop(.52, b); g.addColorStop(1, '#09172d');
      ctx.fillStyle = g; ctx.fillRect(0, 0, 720, 1008);
      // Outer collectible-card silhouette + geometric runic motif
      ctx.lineJoin = 'round';
      roundedRect(18, 18, 684, 972, 28); ctx.strokeStyle = a; ctx.lineWidth = 19; ctx.stroke();
      roundedRect(40, 40, 640, 928, 22); ctx.strokeStyle = '#f1d79b'; ctx.lineWidth = 4; ctx.stroke();
      ctx.fillStyle = a; ctx.textAlign = 'center';
      ctx.font = '58px serif'; ctx.fillText('◆', 360, 100);
      for (let i = 0; i < 11; i++) {
        const px = 75 + i * 57;
        ctx.fillStyle = i % 2 ? 'rgba(255,220,151,.24)' : 'rgba(126,215,255,.24)';
        ctx.fillRect(px, 55, 3, 15);
      }
      // Portrait window
      ctx.save(); roundedRect(65, 145, 590, 585, 19); ctx.clip();
      const portraitBg = ctx.createRadialGradient(360, 350, 50, 360, 410, 410);
      portraitBg.addColorStop(0, '#3c5374'); portraitBg.addColorStop(1, '#0a162c');
      ctx.fillStyle = portraitBg; ctx.fillRect(65, 145, 590, 585);
      if (sourceImage.complete && sourceImage.naturalWidth > 0) {
        const scale = Math.min(590 / sourceImage.naturalWidth, 585 / sourceImage.naturalHeight);
        const w = sourceImage.naturalWidth * scale, h = sourceImage.naturalHeight * scale;
        ctx.drawImage(sourceImage, 360 - w / 2, 145 + (585 - h) / 2, w, h);
      }
      const shade = ctx.createLinearGradient(0, 530, 0, 755);
      shade.addColorStop(0, 'rgba(6,15,29,0)'); shade.addColorStop(1, 'rgba(3,11,23,.8)');
      ctx.fillStyle = shade; ctx.fillRect(65, 500, 590, 230); ctx.restore();
      ctx.strokeStyle = a; ctx.lineWidth = 8; roundedRect(65, 145, 590, 585, 19); ctx.stroke();
      // Card title plaque
      roundedRect(75, 682, 570, 84, 15); ctx.fillStyle = '#061225'; ctx.fill();
      ctx.strokeStyle = '#eacb83'; ctx.lineWidth = 4; ctx.stroke();
      ctx.fillStyle = '#fff0c9'; ctx.textAlign = 'center'; centeredFitText(name, 360, 739, 525, 37);
      ctx.textAlign = 'left'; ctx.font = '700 25px Inter, sans-serif'; ctx.fillStyle = a;
      ctx.fillText(`${rarity.toUpperCase()}  ·  ${element.toUpperCase()}`, 78, 821);
      ctx.fillStyle = '#ffffff'; ctx.font = '600 22px Inter, sans-serif';
      wrapText(ability, 535, 3).forEach((line, i) => ctx.fillText(line, 78, 862 + i * 27));
      ctx.textAlign = 'right'; ctx.fillStyle = '#fce3a8'; ctx.font = '800 26px Inter, sans-serif'; ctx.fillText(`PWR ${power}`, 628, 950);
      ctx.font = '800 18px Cinzel, serif'; ctx.textAlign = 'left'; ctx.fillText('FANTASY CARD CREATOR', 78, 950);
    }
    ['card-name', 'card-rarity', 'card-element', 'card-power', 'card-skill'].forEach(id => $(id).addEventListener('input', draw));
    $('card-image').addEventListener('change', event => {
      const file = event.target.files?.[0];
      if (!file) return;
      if (!['image/png', 'image/jpeg', 'image/webp'].includes(file.type) || file.size > 10 * 1024 * 1024) {
        setText('card-message', 'Please choose a PNG, JPEG or WebP image no larger than 10 MB.');
        event.target.value = ''; return;
      }
      if (objectUrl) URL.revokeObjectURL(objectUrl);
      objectUrl = URL.createObjectURL(file);
      sourceImage.src = objectUrl;
      setText('card-message', 'Using your image locally.');
    });
    $('card-export').addEventListener('click', () => {
      if (!$('card-form').reportValidity()) return;
      draw();
      const link = document.createElement('a');
      link.download = 'kardrune-fantasy-card.png';
      link.href = canvas.toDataURL('image/png');
      link.click();
      setText('card-message', 'PNG generated. Your image was not uploaded anywhere.');
    });
    $('card-reset').addEventListener('click', () => {
      $('card-form').reset(); $('card-image').value = '';
      if (objectUrl) { URL.revokeObjectURL(objectUrl); objectUrl = null; }
      sourceImage.src = oldSrc; draw(); setText('card-message', 'Card reset.');
    });
    window.addEventListener('pagehide', () => { if (objectUrl) URL.revokeObjectURL(objectUrl); });
    draw();
  }

  if (page === 'battle') {
    const heroes = {
      sam: { name: 'Sam', art: 'young_sam_stage_1.webp', stages: ['young_sam_stage_1.webp', 'sam_of_aster_stage_2.webp', 'Sam_Last_Guardian_stage_3.webp'], hp: 40, atk: 5, def: 13 },
      lira: { name: 'Lira', art: 'lira_act_2.webp', hp: 32, atk: 5, def: 12 },
      rhea: { name: 'Rhea', art: 'rhea_act_2.webp', hp: 36, atk: 6, def: 12 },
      dren: { name: 'Dren', art: 'dren_act_2.webp', hp: 33, atk: 7, def: 11 },
      tor: { name: 'Tor', art: 'tor_act_2(1).webp', hp: 46, atk: 5, def: 14 },
      aria: { name: 'Aria', art: 'aria_act_2.webp', hp: 31, atk: 7, def: 11 }
    };
    const enemies = {
      husk: { name: 'Runic Husk', art: 'runic_husk.webp', hp: 33, atk: 4, def: 11 },
      crow: { name: 'Dusk Crow', art: 'dusk_crow.webp', hp: 28, atk: 6, def: 12 },
      wraith: { name: 'Rune Wraith', art: 'rune_wraith.webp', hp: 42, atk: 6, def: 13 },
      sentinel: { name: 'Corrupted Sentinel', art: 'corrupted_sentinel.webp', hp: 50, atk: 5, def: 15 }
    };
    let player = null, enemy = null, finished = false, turn = 0;
    function entry(text) {
      const li = document.createElement('li'); li.textContent = text;
      $('battle-log').prepend(li);
      while ($('battle-log').children.length > 20) $('battle-log').lastChild.remove();
    }
    function show() {
      for (const [side, actor] of [['player', player], ['enemy', enemy]]) {
        const prefix = side === 'player' ? 'battle-player' : 'battle-enemy';
        setText(prefix + '-name', actor.name);
        setText(prefix + '-hp', `${actor.hp} / ${actor.maxHp} HP`);
        $(prefix + '-bar').style.width = `${Math.round(100 * actor.hp / actor.maxHp)}%`;
      }
    }
    function perform(from, to) {
      const die = 1 + randInt(20);
      const hit = die === 20 || (die !== 1 && die + from.atk >= to.def);
      const damage = hit ? Math.max(1, 2 + Math.ceil(die / 4) + Math.floor(from.atk / 2)) * (die === 20 ? 2 : 1) : 0;
      to.hp = Math.max(0, to.hp - damage);
      entry(`${from.name} rolled ${die} + ${from.atk} vs DEF ${to.def}: ${hit ? `${die === 20 ? 'CRITICAL! ' : ''}${damage} damage` : 'MISS'}.`);
      if (hit) {
        const elt = to === player ? $('battle-player') : $('battle-opponent');
        elt.classList.remove('hit'); void elt.offsetWidth; elt.classList.add('hit');
      }
      return hit;
    }
    function start() {
      const hero = heroes[$('battle-hero').value];
      const monster = enemies[$('battle-enemy').value];
      const stage = Number($('battle-stage').value);
      player = { ...hero, hp: hero.hp + 7 * (stage - 1), maxHp: hero.hp + 7 * (stage - 1), atk: hero.atk + stage - 1, def: hero.def + stage - 1 };
      enemy = { ...monster, hp: monster.hp, maxHp: monster.hp };
      $('battle-player-image').src = `assets/${hero.stages ? hero.stages[stage - 1] : hero.art}`;
      $('battle-player-image').alt = `${hero.name} illustration`;
      $('battle-enemy-image').src = `assets/${monster.art}`;
      $('battle-enemy-image').alt = monster.name;
      $('battle-log').replaceChildren();
      turn = 0; finished = false; $('battle-attack').disabled = false;
      setText('battle-status', 'Battle ready. Roll the D20 to attack!');
      entry('Demo stats are illustrative and not your in-game character stats.');
      show();
    }
    $('battle-start').addEventListener('click', start);
    $('battle-attack').addEventListener('click', () => {
      if (!player || !enemy || finished) return;
      turn++; perform(player, enemy);
      if (enemy.hp > 0) perform(enemy, player);
      show();
      if (enemy.hp <= 0 || player.hp <= 0) {
        finished = true; $('battle-attack').disabled = true;
        const result = enemy.hp <= 0 ? 'Victory! The enemy has fallen.' : 'Defeat! Try another duel.';
        setText('battle-status', result); entry(result);
      } else setText('battle-status', `Round ${turn} complete. Roll again to attack.`);
    });
    start();
  }

  if (page === 'loot') {
    const bases = ['Potion of Dawn', 'Moonlit Dagger', 'Traveler’s Cloak', 'Sunsteel Sword', 'Rune-carved Amulet', 'Crystal Lantern', 'Guardian Shield', 'Arcane Scroll', 'Ancient Compass', 'Phoenix Feather', 'Enchanted Ring', 'Warden Helm', 'Silverthorn Bow', 'Celestial Rune'];
    const modifiers = ['Forgotten', 'Whispering', 'Gilded', 'Frostbound', 'Echoing', 'Starlit', 'Ancient', 'Restored', 'Runic', 'Radiant'];
    const ranks = { common: ['Common', 'Uncommon'], rare: ['Uncommon', 'Rare'], epic: ['Rare', 'Epic'], legendary: ['Epic', 'Legendary'] };
    let last = [];
    const form = $('loot-form');
    form.addEventListener('submit', e => {
      e.preventDefault(); if (!form.reportValidity()) return;
      const tier = $('loot-tier').value, count = cap(Math.trunc(Number($('loot-count').value)), 1, 10);
      const coinMult = { common: 1, rare: 3, epic: 8, legendary: 20 }[tier];
      last = [];
      const list = $('loot-results'); list.replaceChildren();
      for (let i = 0; i < count; i++) {
        let rank, name;
        if (i === 0) { rank = 'Currency'; name = `${(randInt(140) + 20) * coinMult} gold coins`; }
        else { rank = ranks[tier][randInt(2)]; name = `${modifiers[randInt(modifiers.length)]} ${bases[randInt(bases.length)]}`; }
        last.push(`${name} (${rank})`);
        const li = document.createElement('li'); li.textContent = name;
        const badge = document.createElement('span'); badge.className = 'loot-rank'; badge.textContent = rank;
        li.appendChild(badge); list.appendChild(li);
      }
      setText('loot-title', `YOUR ${tier.toUpperCase()} TREASURE`);
      setText('loot-message', `${count} randomized rewards · all fictional, not claimable in KardRune.`);
    });
    $('loot-copy').addEventListener('click', async () => {
      if (!last.length) { setText('loot-message', 'Open a chest first.'); return; }
      try { await navigator.clipboard.writeText(last.join('\n')); setText('loot-message', 'Treasure list copied to your clipboard.'); }
      catch { setText('loot-message', 'Copy not available in this browser; select the results instead.'); }
    });
    form.requestSubmit();
  }

  if (page === 'wiki') {
    const items = [...document.querySelectorAll('.wiki-entry')];
    const apply = () => {
      const query = $('wiki-search').value.trim().toLowerCase();
      const kind = $('wiki-kind').value;
      let visible = 0;
      items.forEach(item => {
        const match = (kind === 'all' || item.dataset.kind === kind) && (!query || item.dataset.search.includes(query));
        item.hidden = !match;
        if (match) visible++;
      });
      $('wiki-empty').hidden = visible > 0;
    };
    $('wiki-search').addEventListener('input', apply);
    $('wiki-kind').addEventListener('change', apply);
    apply();
  }
})();