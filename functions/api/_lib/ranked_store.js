import {LEAGUES,RANK_POINTS_PER_WIN,rankProgress} from './ranked_leagues.js';

// The authoritative match history is immutable client-side. Exclude forfeit wins.
// Per UTC day, only the first 3 wins against a given opponent and the first
// 10 wins total count. Ranking has no dependency on Shards reward claims.
const rankedSql=`WITH eligible AS (
 SELECT h.id,h.winner_uid AS uid,
 CASE WHEN h.winner_uid=h.player_a THEN h.player_b ELSE h.player_a END AS opponent,
 h.completed_at,CAST(h.completed_at/86400000 AS INTEGER) AS utc_day
 FROM pvp_live_history h
 WHERE h.reason='completed' AND h.winner_uid IS NOT NULL
 AND h.player_a<>h.player_b
), per_opponent AS (
 SELECT *,ROW_NUMBER() OVER (
 PARTITION BY uid,utc_day,opponent ORDER BY completed_at,id
 ) AS opponent_n FROM eligible
), limited AS (
 SELECT *,ROW_NUMBER() OVER (
 PARTITION BY uid,utc_day ORDER BY completed_at,id
 ) AS daily_n FROM per_opponent WHERE opponent_n<=3
)
SELECT uid,COUNT(*) AS wins,COUNT(*)*25 AS points
FROM limited WHERE daily_n<=10 GROUP BY uid`;

export async function ranking(env,uid){
 const values=await env.DB.prepare(rankedSql).all();
 const scores=(values.results||[]).map(row=>({uid:row.uid,wins:Number(row.wins)||0,points:Number(row.points)||0}))
 .sort((a,b)=>b.points-a.points||a.uid.localeCompare(b.uid));
 const mine=scores.findIndex(x=>x.uid===uid);
 return {mine:mine<0?{uid,wins:0,position:null,...rankProgress(0)}:
  {...scores[mine],position:mine+1,...rankProgress(scores[mine].points)},
  top:scores.slice(0,50),all:scores,leagues:LEAGUES,pointsPerWin:RANK_POINTS_PER_WIN};
}
