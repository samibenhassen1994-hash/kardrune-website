// One-time Idle KardRune player-name policy.
// Enforced server-side before the permanent name is stored in D1.
// Character and reserved-name rules are strict; the curated language lists
// are a first moderation layer, not a claim to detect every offensive term.

export const MIN_PLAYER_NAME_LENGTH = 3;
export const MAX_PLAYER_NAME_LENGTH = 16;

// Include combining marks so names in supported non-Latin scripts stay valid.
// Spaces, zero-width characters, emoji, punctuation and HTML are not allowed.
const VALID_CHARACTERS = /^[\p{L}\p{M}\p{N}_]+$/u;

// Prevent impersonation of staff or games, including names like Admin_01.
const RESERVED = [
  'admin', 'administrator', 'administrador', 'administrateur',
  'amministratore', 'moderator', 'moderatore', 'moderador',
  'staff', 'support', 'suporte', 'soporte', 'sistema',
  'system', 'official', 'offiziell', 'ufficiale', 'oficial',
  'developer', 'desarrollador', 'entwickler', 'devteam',
  'kardrune', 'idle', 'runebearer', 'gubify', 'firebase',
  '관리자', '운영자', '公式', '管理者', '管理人', '管理员', '管理員',
  '官方', '運営', '운영팀', 'カドゥルーン'
];

// Carefully selected explicit insults/profanity covering the seven languages
// currently selectable in Idle: English, Italian, Spanish, German, Japanese,
// Korean and Chinese. Avoid very short roots which flag harmless names.
const OFFENSIVE = [
  // English
  'fuck', 'motherfuck', 'shit', 'bitch', 'asshole', 'cunt',
  'nigger', 'nigga', 'faggot', 'dickhead', 'wanker', 'whore',
  'slut', 'bastard', 'twat',
  // Italiano
  'cazzo', 'stronz', 'merda', 'puttan', 'troia', 'vaffancul',
  'coglion', 'porcodio', 'porcamadonna', 'minchia', 'frocio',
  'ricchion',
  // Español
  'mierda', 'joder', 'cabron', 'pendej', 'chingad', 'chingar',
  'gilipoll', 'maricon', 'hijueput', 'jueputa', 'culero',
  'malparid', 'verga',
  // Deutsch
  'scheiss', 'arschloch', 'hurensohn', 'wichser', 'fick',
  'fotze', 'schlampe', 'drecksau', 'missgeburt',
  // 日本語
  '死ね', 'しね', '氏ね', 'くたばれ', 'ばかやろう', '馬鹿野郎',
  'バカヤロー', 'きちがい', 'キチガイ', 'ちんこ', 'まんこ',
  'くそったれ', 'クソ',
  // 한국어
  '씨발', '시발', '씹새끼', '개새끼', '병신', '좆', '존나',
  '니애미', '개같은', '지랄', '염병', 'ㅅㅂ',
  // 简体中文 / 繁體中文
  '傻逼', '傻屄', '煞笔', '操你妈', '操你媽', '草泥马',
  '草泥馬', '他妈的', '他媽的', '去你妈', '去你媽',
  '狗日的', '鸡巴', '雞巴', '死全家',
  // Common romanizations of explicit terms
  'ssibal', 'shibal', 'gaesaekki', 'bakayaro', 'caonima',
];

// Common lookalikes used to impersonate staff/evade filters. Full-width forms
// are already handled by NFKC. Keep other writing systems valid.
const CONFUSABLE_LATIN = Object.freeze({
  'а':'a', 'ɑ':'a', 'α':'a', 'е':'e', 'ε':'e',
  'і':'i', 'ı':'i', 'Ι':'i', 'ӏ':'l', 'ⅼ':'l',
  'о':'o', 'ο':'o', 'р':'p', 'ρ':'p',
  'с':'c', 'ϲ':'c', 'ѕ':'s', 'ԁ':'d',
  'у':'y', 'υ':'u', 'х':'x', 'χ':'x',
  'к':'k', 'κ':'k', 'м':'m', 'ո':'n',
});

function skeleton(value) {
  return Array.from(value.normalize('NFKD').toLowerCase().replace(/ß/g, 'ss'))
    .filter(character => !/\p{M}/u.test(character))
    .map(character => CONFUSABLE_LATIN[character] || character)
    .join('')
    .replace(/_/g, '')
    .replace(/[0134578]/g, character =>
      ({'0':'o','1':'i','3':'e','4':'a','5':'s','7':'t','8':'b'})[character])
    .replace(/(.)\1{3,}/gu, '$1');
}

export function validatePlayerName(raw) {
  if (typeof raw !== 'string') return {name: null, reason: 'characters'};
  // No auto-trimming: a leading/trailing space must not silently pass.
  const name = raw.normalize('NFKC');
  const length = Array.from(name).length;
  if (length < MIN_PLAYER_NAME_LENGTH || length > MAX_PLAYER_NAME_LENGTH)
    return {name: null, reason: 'length'};
  if (/\s/u.test(name) || /\p{Z}/u.test(name))
    return {name: null, reason: 'spaces'};
  if (!VALID_CHARACTERS.test(name))
    return {name: null, reason: 'characters'};
  if (!/\p{L}/u.test(name))
    return {name: null, reason: 'characters'};

  const candidate = skeleton(name);
  const terms = [candidate, name.toLowerCase().replace(/_/g, '')];
  if (RESERVED.some(term => terms.some(text => text.includes(skeleton(term)))))
    return {name: null, reason: 'reserved'};
  if (OFFENSIVE.some(term => terms.some(text => text.includes(skeleton(term)))))
    return {name: null, reason: 'inappropriate'};
  return {name, reason: null};
}
