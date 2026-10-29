/* KardRune Web Push sender. Deploy as a *separate* Cloudflare Worker
 * with the same D1 database binding as Cloudflare Pages. Configure:
 * VAPID_PUBLIC_KEY, VAPID_SUBJECT (e.g. mailto:you@example.com) as vars,
 * VAPID_PRIVATE_KEY as secret. Do not put private keys in Git.
 */
import webpush from 'web-push';
const topics={
  free_pull:{title:'KardRune · Free Summon',
    body:'One of your free Standard Summons is ready.',url:'/idle/'}
};
export default {
  async scheduled(_event,env,ctx) {
    ctx.waitUntil(processNotifications(env));
  },
  async fetch() {return new Response('Not found',{status:404});}
};
export async function processNotifications(env,now=Date.now()) {
  if (!env.DB || !env.VAPID_PUBLIC_KEY || !env.VAPID_PRIVATE_KEY || !env.VAPID_SUBJECT) {
    throw Error('Web Push not configured: DB + VAPID vars required');
  }
  webpush.setVapidDetails(env.VAPID_SUBJECT,env.VAPID_PUBLIC_KEY,env.VAPID_PRIVATE_KEY);
  const events=await env.DB.prepare(`SELECT e.id,e.uid,e.topic,e.due_at,e.expires_at
    FROM notification_events e JOIN notification_preferences p
    ON p.uid=e.uid AND p.topic=e.topic AND p.enabled=1
    WHERE e.due_at<=? AND e.expires_at>?
    ORDER BY e.due_at LIMIT 60`).bind(now,now).all();
  for (const event of events.results||[]) {
    const payload=topics[event.topic];
    if (!payload) continue;
    const subs=await env.DB.prepare(`SELECT endpoint,subscription_json
      FROM push_subscriptions WHERE uid=? LIMIT 5`).bind(event.uid).all();
    for (const sub of subs.results||[]) {
      await env.DB.prepare(`INSERT OR IGNORE INTO notification_deliveries
        (event_id,endpoint,status,attempts,claimed_until)
        VALUES(?,?,'retry',0,0)`).bind(event.id,sub.endpoint).run();
      const claim=await env.DB.prepare(`UPDATE notification_deliveries
        SET status='sending', attempts=attempts+1,claimed_until=?
        WHERE event_id=? AND endpoint=? AND attempts<5
        AND (status='retry' OR (status='sending' AND claimed_until<?))`)
        .bind(now+120000,event.id,sub.endpoint,now).run();
      if (!claim.meta?.changes) continue;
      try {
        await webpush.sendNotification(JSON.parse(sub.subscription_json),
          JSON.stringify({...payload,id:event.id,topic:event.topic}),
          {TTL:1800,urgency:'normal'});
        await env.DB.prepare(`UPDATE notification_deliveries SET status='sent',sent_at=?
          WHERE event_id=? AND endpoint=?`).bind(Date.now(),event.id,sub.endpoint).run();
      } catch(err) {
        const code=Number(err.statusCode||0);
        if(code===404||code===410) {
          await env.DB.prepare('DELETE FROM push_subscriptions WHERE endpoint=?').bind(sub.endpoint).run();
        } else {
          const dead=code===400||code===401||code===403;
          await env.DB.prepare(`UPDATE notification_deliveries SET status=?
            WHERE event_id=? AND endpoint=?`).bind(dead?'dead':'retry',event.id,sub.endpoint).run();
          console.error('Web Push failed',code,err.message);
        }
      }
    }
  }
  await env.DB.prepare('DELETE FROM notification_events WHERE expires_at<?')
    .bind(now-86400000).run();
}