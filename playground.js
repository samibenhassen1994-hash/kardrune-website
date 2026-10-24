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
    document.addEventListener('kardrune-card-preset', event => {
      if (objectUrl) { URL.revokeObjectURL(objectUrl); objectUrl = null; }
      sourceImage.src = event.detail.src;
    });
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

})();