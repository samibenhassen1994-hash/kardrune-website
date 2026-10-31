export const CARD_STAT_LIMITS=Object.freeze({
  1:Object.freeze({attack:Object.freeze([25,50]),crit:Object.freeze([0,8])}),
  2:Object.freeze({attack:Object.freeze([40,75]),crit:Object.freeze([4,16])}),
  3:Object.freeze({attack:Object.freeze([60,100]),crit:Object.freeze([8,25])}),
});

export function limitsForStage(stage){
 const limits=CARD_STAT_LIMITS[stage];
 if(!limits)throw new RangeError('Invalid card stage');
 return limits;
}

const bounded=(value,[minimum,maximum])=>Math.max(minimum,Math.min(maximum,
 Number.isFinite(value)?Math.trunc(value):minimum));

export function effectiveCardStats(stage,attack,crit){
 const limits=limitsForStage(stage);
 return {attack:bounded(attack,limits.attack),crit:bounded(crit,limits.crit)};
}

export function rollCardStats(stage,randomInt){
 const limits=limitsForStage(stage);
 const roll=range=>range[0]+randomInt(range[1]-range[0]+1);
 return {attack:roll(limits.attack),crit:roll(limits.crit)};
}
