// Canonical v1 skill definitions. Keep IDs and values stable for saved grants.
export const SKILL_VERSION=1;
export const RARITIES=['common','uncommon','rare','epic','legendary','ultra'];
export const SKILL_WEIGHTS={
  1:[550,270,120,50,8,2],
  2:[0,600,280,100,15,5],
  3:[0,0,700,230,60,10],
};
export const SKILLS=[
  {id:'C1',name:'Colpo preciso',vfx:'slash',description:'Il primo attacco diretto infligge +8 danni.',trigger:'Primo attacco',limit:'Una volta per duello'},
  {id:'C2',name:'Pelle dura',vfx:'shield',description:'Riduce di 8 il primo danno diretto ricevuto.',trigger:'Primo colpo subito',limit:'Una carica'},
  {id:'C3',name:'Resistenza',vfx:'shield',description:'Inizia il duello con +15 HP massimi e attuali.',trigger:'Inizio duello',limit:'Passiva'},
  {id:'C4',name:'Tenacia',vfx:'power',description:'Sotto il 50% HP, il prossimo colpo infligge +10 danni.',trigger:'Prima volta sotto metà HP',limit:'Una volta'},
  {id:'C5',name:'Mira stabile',vfx:'power',description:'+3 punti percentuali al CRIT effettivo, fino al 25%.',trigger:'Sempre attiva',limit:'Passiva'},
  {id:'N1',name:'Furia',vfx:'power',description:'Sotto il 50% HP, gli attacchi diretti infliggono +15% danni.',trigger:'Ogni attacco sotto metà HP',limit:'Finché la condizione vale'},
  {id:'N2',name:'Veleno',vfx:'poison',description:'Il primo colpo riuscito applica 6 danni per 2 azioni nemiche.',trigger:'Primo colpo riuscito',limit:'2 tick; non si riapplica'},
  {id:'N3',name:'Ripicca',vfx:'counter',description:'Alla prima perdita di HP diretta restituisce 15 danni.',trigger:'Primo danno diretto subito',limit:'Una reazione'},
  {id:'N4',name:'Meditazione',vfx:'heal',description:'Dopo il terzo attacco recupera 20 HP, senza superare il massimo.',trigger:'Terzo attacco proprio',limit:'Una volta'},
  {id:'N5',name:'Colpo indebolente',vfx:'curse',description:'Il primo colpo riuscito riduce ATK nemico del 10% per 2 attacchi.',trigger:'Primo colpo riuscito',limit:'2 attacchi nemici'},
  {id:'R1',name:'Vampirismo',vfx:'heal',description:'Recupera il 12% del danno diretto effettivamente inflitto.',trigger:'Ogni colpo diretto',limit:'HP massimi'},
  {id:'R2',name:'Schivata',vfx:'dodge',description:'25% di probabilità di annullare un colpo diretto.',trigger:'Colpo diretto in arrivo',limit:'Un proc per duello'},
  {id:'R3',name:'Scudo arcano',vfx:'shield',description:'Riduce del 40% il primo danno diretto ricevuto.',trigger:'Primo colpo non schivato',limit:'Una carica'},
  {id:'R4',name:'Sanguinamento',vfx:'bleed',description:'Il primo CRIT riuscito applica 12 danni per 2 azioni nemiche.',trigger:'Primo CRIT riuscito',limit:'2 tick; max 24'},
  {id:'R5',name:'Punizione',vfx:'power',description:'Se il nemico ha più HP attuali, infligge +20% danni diretti.',trigger:'Prima del colpo',limit:'Finché la condizione vale'},
  {id:'E1',name:'Doppio colpo',vfx:'double',description:'35% di probabilità di un secondo colpo al 50% di ATK.',trigger:'Attacco diretto',limit:'Un proc; colpo extra non critico'},
  {id:'E2',name:'Barriera runica',vfx:'shield',description:'Riduce del 30% i primi 2 danni diretti ricevuti.',trigger:'Colpo diretto in arrivo',limit:'2 cariche'},
  {id:'E3',name:'Ritorsione',vfx:'counter',description:'Dopo il primo CRIT subito, il prossimo attacco è CRIT garantito.',trigger:'Primo CRIT subito',limit:'Una volta'},
  {id:'E4',name:'Spaccascudi',vfx:'break',description:'Il primo attacco infligge +20% danni e ignora gli scudi.',trigger:'Primo attacco',limit:'Una volta; non ignora Schivata'},
  {id:'E5',name:'Carica Arcana',vfx:'magic',description:'Ogni colpo non critico carica +10 danni, fino a +30; scarica su CRIT o quinto attacco.',trigger:'Colpi non critici',limit:'Una scarica per duello'},
  {id:'L1',name:'Maledizione eterna',vfx:'curse',description:'Il primo colpo riuscito riduce ATK base nemico del 25% per il duello.',trigger:'Primo colpo riuscito',limit:'Non cumulabile'},
  {id:'L2',name:'Esecuzione',vfx:'execute',description:'Contro nemici sotto 30% HP massimi, un attacco infligge +50% danni.',trigger:'Bersaglio sotto 30% HP',limit:'Una volta'},
  {id:'L3',name:'Sigillo del Silenzio',vfx:'silence',description:'Il primo colpo riuscito sopprime le skill attivabili per 2 azioni nemiche.',trigger:'Primo colpo riuscito',limit:'2 azioni; passivi e DoT persistono'},
  {id:'L4',name:'Sabotaggio',vfx:'curse',description:'Il primo colpo riuscito riduce il CRIT nemico di 10 punti.',trigger:'Primo colpo riuscito',limit:'Resto del duello; minimo 0%'},
  {id:'L5',name:'Congelamento',vfx:'freeze',description:'Il primo CRIT riuscito salta il prossimo attacco nemico; altrimenti il quarto colpo riuscito.',trigger:'CRIT o quarto colpo riuscito',limit:'Un salto per duello'},
  {id:'U1',name:'Tempesta runica',vfx:'storm',description:'Ogni terzo attacco aggiunge un colpo non critico al 70% di ATK.',trigger:'Ogni terzo attacco',limit:'2 attivazioni; no catene'},
  {id:'U2',name:'Destino',vfx:'counter',description:'Annulla il primo CRIT nemico e contrattacca con il 100% di ATK.',trigger:'Primo CRIT nemico',limit:'Una volta; contrattacco non critico'},
  {id:'U3',name:'Fiamma cosmica',vfx:'burn',description:'Il primo colpo applica bruciatura del 10% HP massimi per 3 azioni.',trigger:'Primo colpo riuscito',limit:'Max 35 per tick; 3 tick'},
  {id:'U4',name:'Scudo divino',vfx:'shield',description:'Riduce del 60% i primi 2 danni diretti ricevuti.',trigger:'Colpo diretto in arrivo',limit:'2 cariche'},
  {id:'U5',name:'Ascensione',vfx:'ascend',description:'Dopo ogni attacco, ATK cresce del 15% fino a +60%.',trigger:'Fine di ogni attacco',limit:'4 stack; fino a fine duello'},
].map(skill=>Object.freeze({...skill,rarity:RARITIES['CNRELU'.indexOf(skill.id[0])],v:SKILL_VERSION}));
export const SKILL_BY_ID=Object.fromEntries(SKILLS.map(skill=>[skill.id,skill]));
export function rarityIndex(skillId){return RARITIES.indexOf(SKILL_BY_ID[skillId]?.rarity)}
export function validSkillForStage(skillId,stage){return Number.isInteger(stage)&&stage>=1&&stage<=3&&rarityIndex(skillId)>=stage-1}
