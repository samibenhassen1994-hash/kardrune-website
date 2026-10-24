/* Lightweight, self-hosted localization. Default language: device/browser. */
(function(root){
'use strict';
const STORAGE_KEY='idle-kardrune-language';
const supported=Object.freeze(['en','it']);
const messages={
 it:{
  'THE POCKET REALM':'IL REGNO TASCABILE',
  'Idle KardRune is designed exclusively for phones. Open this page on your iPhone or Android device to play and install the mini app.':'Idle KardRune è pensato per gli smartphone. Apri la pagina su iPhone o Android per giocare e installare la mini app.',
  '← BACK TO KARDRUNE':'← TORNA A KARDRUNE',
  'ARENA OF THE RUNES':'ARENA DELLE RUNE',
  'TOURNAMENT':'TORNEO','Build your team. Face your rivals. Rise to the top of the Rune Circuit.':'Crea la tua squadra, sfida gli avversari e conquista il Circuito delle Rune.',
  'SEASON PREVIEW':'ANTEPRIMA STAGIONE','THE RUNE':'IL CIRCUITO','CIRCUIT':'DELLE RUNE','First championship • Coming with online accounts':'Primo campionato • In arrivo con gli account online',
  'YOUR NEXT BATTLE':'LA TUA PROSSIMA BATTAGLIA','Practice Arena':'Arena di allenamento','SOLO DEMO':'DEMO IN SOLITARIA',
  'YOUR HERO':'IL TUO EROE','RANDOM OPPONENT':'AVVERSARIO CASUALE','Rival':'Rivale',
  'Ready for a real-time duel':'Pronto per un duello in tempo reale','HITS:':'COLPI:',
  '· 1 turn every 1.2s':'· 1 turno ogni 1,2 s','↻ RANDOM OPPONENT':'↻ AVVERSARIO CASUALE',
  'CHOOSE YOUR CHAMPION':'SCEGLI IL CAMPIONE','⚔ START PRACTICE DUEL':'⚔ INIZIA IL DUELLO',
  'Turn-based battles play automatically in real time against randomized demo opponents. Rewarded duels remaining today:':'I duelli a turni si svolgono automaticamente contro avversari casuali. Duelli premiati rimasti oggi:',
  '/10 (local midnight reset). You can still practice afterward. Real PvP requires a separate online server.':'/10 (si azzerano a mezzanotte). Puoi continuare ad allenarti. Il vero PvP richiede un server online.',
  'COMPETITION ROADMAP':'PROSSIMAMENTE','Championship Bracket':'Tabellone del campionato',
  'Qualifiers':'Qualificazioni','Register your team':'Iscrivi la tua squadra','Playoffs':'Playoff',
  'Advance through the ranks':'Avanza in classifica','Grand Final':'Gran finale','One champion remains':'Resterà un solo campione','SOON':'PRESTO',
  'YOUR':'LE TUE','CARDS':'CARTE','CARD GRID':'GRIGLIA','BY HERO':'PER EROE',
  'COLLECTION PROGRESS':'PROGRESSO COLLEZIONE','All Heroes':'Tutti gli eroi','Owned':'Possedute','Locked':'Bloccate',
  'PAGE 1':'PAGINA 1','Previous cards page':'Pagina precedente','Next cards page':'Pagina successiva',
  'HERO':'EROE','SUMMON':'EVOCAZIONI','FEATURED HERO':'EROE IN EVIDENZA',
  'EPIC · SHADOW':'EPICO · OMBRA','The darkness answers his call.':'L’oscurità risponde al suo richiamo.',
  'SUMMON PORTAL 01':'PORTALE EVOCAZIONE 01','Standard Summon':'Evocazione standard',
  'SUMMON PORTAL 02':'PORTALE EVOCAZIONE 02','Featured Summon':'Evocazione in evidenza',
  'SUMMON 1':'EVOCA 1','FEATURED PULL':'EVOCA IN EVIDENZA',
  '✦ ALL HEROES':'✦ TUTTI GLI EROI','ⓘ RATES & INFO':'ⓘ PROBABILITÀ E INFO',
  'YOUR LEGEND BEGINS':'INIZIA LA TUA LEGGENDA','PLAYER':'GIOCATORE','PROFILE':'PROFILO',
  'Your local adventurer profile. Online accounts will be introduced before real PvP.':'Il tuo profilo locale. Gli account online arriveranno prima del vero PvP.',
  'RUNE ADVENTURER':'AVVENTURIERO DELLE RUNE','LOCAL ACCOUNT · LEVEL 1':'ACCOUNT LOCALE · LIVELLO 1',
  'CHOOSE YOUR AVATAR':'SCEGLI IL TUO AVATAR','Your avatar choice is saved on this device.':'L’avatar scelto viene salvato su questo dispositivo.',
  'DISPLAY NAME':'NOME VISIBILE','SAVE':'SALVA',
  'PRACTICE DUELS':'DUELLI DI PROVA','PRACTICE WINS':'VITTORIE DI PROVA',
  'SUMMONS':'EVOCAZIONI','OWNED CARDS':'CARTE POSSEDUTE',
  '＋ INSTALL IDLE KARDRUNE':'＋ INSTALLA IDLE KARDRUNE',
  'Install to your home screen from your browser menu.':'Installa il gioco dalla schermata iniziale tramite il menu del browser.',
  'Reset local demo progress':'Reimposta progressi locali',
  'Independent prototype: it does not access or modify your KardRune app account, purchases or database.':'Prototipo indipendente: non accede né modifica il tuo account KardRune, gli acquisti o il database.',
  'Tournament':'Torneo','Cards':'Carte','Summon':'Evoca','Profile':'Profilo',
  'CONTINUE':'CONTINUA','Close dialog':'Chiudi finestra','Idle KardRune home':'Home Idle KardRune',
  'Set local test Rune Shards':'Imposta Rune Shards di prova','Set your test Rune Shards':'Imposta Rune Shards di prova',
  'STAGE':'FASE','NOT COLLECTED':'NON POSSEDUTA','✦ SELECTED CHAMPION':'✦ CAMPIONE SELEZIONATO',
  'No cards in this filter.':'Nessuna carta per questo filtro.',
  'ALL SUMMONABLE HEROES':'TUTTI GLI EROI EVOCABILI','Preview any hero and its three stages.':'Visualizza un eroe e le sue tre evoluzioni.',
  'STAGES 1–3':'FASI 1–3','All stages':'Tutte le fasi',
  'Tap a stage to preview the matching summon animation.':'Tocca una fase per vedere l’animazione di evocazione.',
  'SUMMON RATES':'PROBABILITÀ EVOCAZIONE',
  'STANDARD · 300 Shards: Stage 1 78% · Stage 2 19% · Stage 3 3%.':'STANDARD · 300 Rune: Fase 1 78% · Fase 2 19% · Fase 3 3%.',
  'FEATURED · 600 Shards: Stage 1 60% · Stage 2 30% · Stage 3 10%. Dren has a 35% rate-up before the regular hero draw.':'IN EVIDENZA · 600 Rune: Fase 1 60% · Fase 2 30% · Fase 3 10%. Dren ha una probabilità maggiorata del 35%.',
  'Local test currency and probabilities. Summon results are stored on this device only.':'Valuta e probabilità di prova. Le evocazioni sono salvate solo su questo dispositivo.',
  'TEST RUNE SHARDS':'RUNE DI PROVA','SET SHARD BALANCE':'IMPOSTA SALDO RUNE',
  'Local test balance only. No purchases or official game accounts are affected.':'Solo saldo di prova. Nessun acquisto o account ufficiale viene modificato.',
  'SAVE SHARDS':'SALVA RUNE',
  'Not enough Rune Shards':'Rune insufficienti',
  'DUPLICATE FOUND':'CARTA DUPLICATA','✦ TWO CARDS · ONE SLOT ✦':'✦ DUE CARTE · UN POSTO ✦',
  'Compare both cards. Keep the current one, or replace it with this pull.':'Confronta le carte. Tieni quella attuale oppure sostituiscila con la nuova.',
  'YOUR CARD':'LA TUA CARTA','NEW PULL':'NUOVA EVOCAZIONE',
  'KEEP CURRENT':'TIENI ATTUALE','KEEP NEW':'TIENI NUOVA',
  'HP depends on Stage. Discarding the new duplicate rewards 100 demo Shards.':'Gli HP dipendono dalla fase. Scartando il doppione ottieni 100 Rune di prova.',
  '✦ SUMMON PREVIEW ✦':'✦ ANTEPRIMA EVOCAZIONE ✦',
  '✦ RUNIC ECHO ✦':'✦ ECO RUNICA ✦','✦ HERO SUMMONED ✦':'✦ EROE EVOCATO ✦',
  'Preview of this hero evolution':'Anteprima dell’evoluzione del personaggio',
  'NEW CARD UNLOCKED · Saved to your collection.':'NUOVA CARTA SBLOCCATA · Salvata nella collezione.',
  'BACK TO SUMMON':'TORNA ALLE EVOCAZIONI',
  'The summon animation could not be loaded.':'Impossibile caricare l’animazione.',
  'TRAINING VICTORY!':'VITTORIA IN ALLENAMENTO!','TRAINING DEFEAT':'SCONFITTA IN ALLENAMENTO',
  'DUEL IN PROGRESS…':'DUELLO IN CORSO…','⚔ START ANOTHER DUEL':'⚔ NUOVO DUELLO',
  'Battle started — turns alternate automatically':'Battaglia iniziata: i turni si alternano automaticamente.',
  'Battle in progress…':'Battaglia in corso…',
  'Name saved on this device':'Nome salvato su questo dispositivo',
  'Local demo reset':'Progressi locali reimpostati',
  'Use Safari Share or Chrome menu → Add to Home Screen':'Usa Condividi su Safari o il menu di Chrome → Aggiungi alla schermata Home',
  'Ready to add to your home screen.':'Pronto da aggiungere alla schermata Home.',
  'INSTALL IDLE KARDRUNE':'INSTALLA IDLE KARDRUNE',
  'In Safari tap Share → Add to Home Screen.':'Su Safari premi Condividi → Aggiungi alla schermata Home.',
  'In Chrome tap ⋮ → Install app or Add to Home Screen.':'Su Chrome premi ⋮ → Installa app o Aggiungi alla schermata Home.',
  'CHOOSE YOUR LANGUAGE':'SCEGLI LA LINGUA','LANGUAGE':'LINGUA','Automatic (device)':'Automatica (dispositivo)',
  'Italiano':'Italiano','English':'English'
 }
};
let choice='auto';
try {const stored=root.localStorage?.getItem(STORAGE_KEY);if(stored==='auto'||supported.includes(stored))choice=stored;}catch{}
const deviceLanguage=languageList=>{
  const preferences=Array.isArray(languageList)?languageList:[languageList];
  for(const l of preferences){
    const code=String(l||'').toLowerCase().split('-')[0];
    if(supported.includes(code))return code;
  }
  return 'en';
};
let locale=choice==='auto'?deviceLanguage(root.navigator?.languages||[root.navigator?.language||'en']):choice;
const originals=new WeakMap();
const originalAttributes=new WeakMap();
function dynamicIt(s){
 const patterns=[
  [/^PAGE (\d+)(.*)$/,'PAGINA $1$2'],
  [/^(.+) · All stages$/,'$1 · Tutte le fasi'],
  [/^Stage (\d+)$/,'Fase $1'],
  [/^STAGE (\d+)$/,'FASE $1'],
  [/^(.+) Stage (\d+) selected$/,'$1 Fase $2 selezionato'],
  [/^(.+) avatar selected$/,'Avatar $1 selezionato'],
  [/^New random opponent ready$/,'Nuovo avversario casuale pronto'],
  [/^You hit(.*)$/,'Hai colpito$1'],
  [/^Opponent hits(.*)$/,'L’avversario colpisce$1'],
  [/^VICTORY!(.*)$/,'VITTORIA!$1'],
  [/^DEFEAT!(.*)$/,'SCONFITTA!$1'],
  [/^Earned (\d+) demo Rune Shards\.$/,'Hai guadagnato $1 Rune di prova.'],
  [/^The battle.*$/,'La battaglia è in corso.'],
  [/^CURRENT ATK: (\d+)$/,'ATK ATTUALE: $1'],
  [/^NEW ATK: (\d+)$/,'NUOVO ATK: $1'],
  [/^Animation coming soon for (.+)\.$/,'Animazione in arrivo per $1.'],
  [/^Select (.+) Stage (\d+)$/,'Seleziona $1 Fase $2'],
  [/^Critical chance (\d+)% · Double damage$/,'Probabilità critica $1% · Danno doppio'],
  [/^Critical chance (\d+) percent$/,'Probabilità critica $1 percento'],
  [/^Duplicate card · 100 demo Shards refunded\.$/,'Carta duplicata · Rimborsate 100 Rune di prova.']
 ];
 for(const [rx,replacement] of patterns){if(rx.test(s))return s.replace(rx,replacement);}
 return s;
}
function translate(text){
 if(locale==='en'||typeof text!=='string')return text;
 const leading=(text.match(/^\s*/)||[''])[0],trailing=(text.match(/\s*$/)||[''])[0];
 const core=text.trim();
 if(!core)return text;
 const mapped=messages[locale]?.[core]||dynamicIt(core);
 return leading+mapped+trailing;
}
function translateNode(node){
 if(node.nodeType===3){
  const parent=node.parentElement;
  if(parent?.closest('script,style,noscript,code,svg,[data-no-i18n]'))return;
  const value=node.nodeValue;
  const saved=originals.get(node);
  const original=saved&&saved.localized===value?saved.original:value;
  const localized=translate(original);
  originals.set(node,{original,localized});
  if(value!==localized)node.nodeValue=localized;
  return;
 }
 if(node.nodeType!==1&&node.nodeType!==9)return;
 if(node.nodeType===1){
  if(node.matches('script,style,svg,[data-no-i18n]'))return;
  for(const key of ['aria-label','title','placeholder']){
   const value=node.getAttribute(key);
   if(value===null)continue;
   let saved=originalAttributes.get(node)||{};
   const prior=saved[key];
   const original=prior&&prior.localized===value?prior.original:value;
   const localized=translate(original);
   saved[key]={original,localized};originalAttributes.set(node,saved);
   if(localized!==value)node.setAttribute(key,localized);
  }
 }
 const walker=document.createTreeWalker(node,NodeFilter.SHOW_TEXT);
 let textNode;while((textNode=walker.nextNode()))translateNode(textNode);
 if(node.nodeType===9)node.querySelectorAll('[aria-label],[title],[placeholder]').forEach(el=>translateNodeAttributes(el));
 else if(node.nodeType===1)node.querySelectorAll('[aria-label],[title],[placeholder]').forEach(el=>translateNodeAttributes(el));
}
function translateNodeAttributes(el){
 for(const key of ['aria-label','title','placeholder']){
  const value=el.getAttribute(key);if(value===null)continue;
  const saved=originalAttributes.get(el)||{};const prev=saved[key];
  const original=prev&&prev.localized===value?prev.original:value;
  const localized=translate(original);
  saved[key]={original,localized};originalAttributes.set(el,saved);
  if(value!==localized)el.setAttribute(key,localized);
 }
}
function translateAll(){
 if(!root.document)return;
 root.document.documentElement.lang=locale;
 translateNode(root.document);
}
function setLanguage(selection){
 if(selection!=='auto'&&!supported.includes(selection))return false;
 choice=selection;
 try{root.localStorage?.setItem(STORAGE_KEY,choice);}catch{}
 locale=choice==='auto'?deviceLanguage(root.navigator?.languages||[root.navigator?.language||'en']):choice;
 translateAll();
 return true;
}
function watch(){
 if(!root.document||!root.MutationObserver)return;
 const observer=new MutationObserver(records=>{
  for(const rec of records){
   if(rec.type==='characterData')translateNode(rec.target);
   else for(const n of rec.addedNodes)translateNode(n);
  }
 });
 observer.observe(root.document.body,{subtree:true,childList:true,characterData:true});
}
function init(){
 translateAll();
 watch();
}
const api={supported,deviceLanguage,translate,setLanguage,init,get locale(){return locale},get choice(){return choice}};
root.IDLE_I18N=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window!=='undefined'?window:globalThis);
