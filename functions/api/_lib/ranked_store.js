import {LEAGUES,RANK_POINTS_PER_WIN,rankProgress,leagueFor} from './ranked_leagues.js';

// One verified match -> at most one win entry. This is the only source for
// points. The database triggers fire when the authoritative PvP worker writes
// a completed match; neither the client nor the reward endpoint may add points.
const BACKFILL_SQL = `INSERT OR IGNORE INTO pvp_ranked_wins(match_id,uid,opponent_uid,day,completed_at)
WITH eligible AS (
 SELECT id,winner_uid AS uid,
 CASE WHEN winner_uid=player_a THEN player_b ELSE player_a END AS opponent,
 completed_at,CAST(completed_at/86400000 AS INTEGER) AS day
 FROM pvp_live_history
 WHERE reason='completed' AND winner_uid IN (player_a,player_b)
 AND player_a<>player_b
), opponent_filtered AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY uid,day,opponent ORDER BY completed_at,id) AS opponent_n FROM eligible
), daily_filtered AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY uid,day ORDER BY completed_at,id) AS daily_n
 FROM opponent_filtered WHERE opponent_n<=3
)
SELECT id,uid,opponent,day,completed_at FROM daily_filtered
WHERE daily_n<=10 ORDER BY completed_at,id`;

let initPromise;
export async function ensureRankedSchema(env){
 if (initPromise) return initPromise;
 initPromise=(async()=>{
  const db=env.DB;
  await db.prepare(`CREATE TABLE IF NOT EXISTS pvp_league_claims(
   uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
   league TEXT NOT NULL,
   points_at_claim INTEGER NOT NULL,
   expected_revision INTEGER NOT NULL,
   shards INTEGER NOT NULL CHECK(shards>0),
   claimed_at INTEGER NOT NULL,
   PRIMARY KEY(uid,league)
  )`).run();
  await db.prepare(`CREATE TRIGGER IF NOT EXISTS pvp_league_revision_guard
   BEFORE INSERT ON pvp_league_claims
   WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT NEW.expected_revision
   BEGIN SELECT RAISE(ABORT,'league revision conflict'); END`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS pvp_rankings(
   uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
   wins INTEGER NOT NULL DEFAULT 0 CHECK(wins>=0),
   points INTEGER NOT NULL DEFAULT 0 CHECK(points>=0),
   updated_at INTEGER NOT NULL DEFAULT 0
  )`).run();
  await db.prepare('CREATE INDEX IF NOT EXISTS idx_pvp_rankings_points ON pvp_rankings(points DESC,uid ASC)').run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS pvp_ranked_wins(
   match_id TEXT PRIMARY KEY REFERENCES pvp_live_history(id),
   uid TEXT NOT NULL REFERENCES players(uid),
   opponent_uid TEXT NOT NULL REFERENCES players(uid),
   day INTEGER NOT NULL,
   completed_at INTEGER NOT NULL
  )`).run();
  await db.prepare('CREATE INDEX IF NOT EXISTS idx_ranked_wins_uid_day ON pvp_ranked_wins(uid,day,opponent_uid)').run();
  await db.prepare(`CREATE TRIGGER IF NOT EXISTS ranked_win_increment
   AFTER INSERT ON pvp_ranked_wins
   BEGIN
    INSERT INTO pvp_rankings(uid,wins,points,updated_at)
    VALUES(NEW.uid,1,25,NEW.completed_at)
    ON CONFLICT(uid) DO UPDATE SET wins=wins+1,points=points+25,updated_at=NEW.completed_at;
   END`).run();
  await db.prepare(`CREATE TRIGGER IF NOT EXISTS ranked_from_verified_match
   AFTER INSERT ON pvp_live_history
   WHEN NEW.reason='completed' AND NEW.winner_uid IN (NEW.player_a,NEW.player_b)
    AND NEW.player_a<>NEW.player_b
   BEGIN
    INSERT OR IGNORE INTO pvp_ranked_wins(match_id,uid,opponent_uid,day,completed_at)
    SELECT NEW.id,NEW.winner_uid,
     CASE WHEN NEW.winner_uid=NEW.player_a THEN NEW.player_b ELSE NEW.player_a END,
     CAST(NEW.completed_at/86400000 AS INTEGER), NEW.completed_at
    WHERE (SELECT COUNT(*) FROM pvp_ranked_wins
     WHERE uid=NEW.winner_uid AND day=CAST(NEW.completed_at/86400000 AS INTEGER))<10
    AND (SELECT COUNT(*) FROM pvp_ranked_wins
     WHERE uid=NEW.winner_uid AND day=CAST(NEW.completed_at/86400000 AS INTEGER)
     AND opponent_uid=CASE WHEN NEW.winner_uid=NEW.player_a THEN NEW.player_b ELSE NEW.player_a END)<3;
   END`).run();
  await db.prepare('CREATE TABLE IF NOT EXISTS pvp_ranked_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL)').run();
  const migrated=await db.prepare("SELECT value FROM pvp_ranked_meta WHERE key='backfill_v1'").first();
  if(!migrated){
   await db.batch([
    db.prepare(BACKFILL_SQL),
    db.prepare("INSERT OR IGNORE INTO pvp_ranked_meta(key,value) VALUES('backfill_v1','done')")
   ]);
  }
 })().catch(error=>{initPromise=null;throw error});
 return initPromise;
}

export async function playerRank(env,uid){
 const db=env.DB;
 // A valid registered player starts in Bronze even before their first match.
 await db.prepare('INSERT OR IGNORE INTO pvp_rankings(uid,wins,points,updated_at) VALUES(?,0,0,0)').bind(uid).run();
 const mine=await db.prepare('SELECT wins,points FROM pvp_rankings WHERE uid=?').bind(uid).first();
 const points=Number(mine.points)||0;
 const league=leagueFor(points),index=LEAGUES.findIndex(l=>l.name===league.name);
 const next=LEAGUES[index+1]?.points??null;
 const better='points>? OR(points=? AND uid<?)';
 const global=await db.prepare(`SELECT COUNT(*) AS n FROM pvp_rankings WHERE ${better}`)
  .bind(points,points,uid).first();
 const lower=league.points, upper=next;
 const leaguePosition=await db.prepare(`SELECT COUNT(*) AS n FROM pvp_rankings
  WHERE points>=? ${upper==null?'':'AND points<?'} AND (${better})`)
  .bind(...(upper==null?[lower]:[lower,upper]),points,points,uid).first();
 return {uid,wins:Number(mine.wins)||0,points,...rankProgress(points),
  position:Number(global.n)+1,leaguePosition:Number(leaguePosition.n)+1};
}

// Retained for the existing milestone-claim endpoint without scanning match
// history or materializing an unbounded leaderboard in JavaScript.
export async function ranking(env,uid){
 return {mine:await playerRank(env,uid),leagues:LEAGUES,pointsPerWin:RANK_POINTS_PER_WIN};
}

export async function rankedPage(env,scope,uid,offset){
 const mine=await playerRank(env,uid);
 const current=leagueFor(mine.points);
 const next=LEAGUES.find(l=>l.points>current.points);
 const condition=scope==='league'
  ? 'WHERE r.points>=? '+(next?'AND r.points<?':'') : '';
 const params=scope==='league'
  ? [current.points,...(next?[next.points]:[])] : [];
 const rows=(await env.DB.prepare(`SELECT r.uid,r.points,r.wins,p.display_name
  FROM pvp_rankings r JOIN players p ON p.uid=r.uid
  ${condition} ORDER BY r.points DESC,r.uid ASC LIMIT 11 OFFSET ?`)
 .bind(...params,offset).all()).results||[];
 return {you:mine,leaders:rows.slice(0,10).map((r,i)=>({
   name:r.display_name||'Runebearer',points:Number(r.points)||0,
   wins:Number(r.wins)||0,league:leagueFor(Number(r.points)||0).name,
   position:offset+i+1,isYou:r.uid===uid
  })),hasMore:rows.length>10,offset,limit:10};
}
