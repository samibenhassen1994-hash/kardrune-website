export const LEAGUES=Object.freeze([
 {name:'Bronze',points:0,reward:0},
 {name:'Silver',points:100,reward:150},
 {name:'Gold',points:250,reward:300},
 {name:'Platinum',points:500,reward:500},
 {name:'Diamond',points:900,reward:850},
 {name:'Legend',points:1500,reward:1500},
]);
export const RANK_POINTS_PER_WIN=25;
export const DAILY_RANKED_WINS=10;
export const DAILY_SAME_OPPONENT=3;
export const RANKED_REASON='completed';
export function leagueFor(points){return [...LEAGUES].reverse().find(l=>points>=l.points)||LEAGUES[0]}
export function isRankedResult(m,uid){
 return m && m.reason===RANKED_REASON && m.winner_uid===uid
   && m.player_a!==m.player_b && (m.player_a===uid||m.player_b===uid);
}
export function opponentFor(m,uid){return m.player_a===uid?m.player_b:m.player_a;}
export function rankProgress(points){
 const league=leagueFor(points), index=LEAGUES.findIndex(l=>l.name===league.name);
 return {league:league.name,points,next:LEAGUES[index+1]?.points??null,
  remaining:LEAGUES[index+1]?LEAGUES[index+1].points-points:0};
}
