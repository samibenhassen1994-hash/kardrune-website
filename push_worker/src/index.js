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
  if (!env.DB || (!env.__sendPush &&
      (!env.VAPID_PUBLIC_KEY || !env.VAPID_PRIVATE_KEY || !env.VAPID_SUBJECT))) {
    throw Error('Web Push not configured: DB + VAPID vars required');
  }
  if (!env.__sendPush) {
    webpush.setVapidDetails(env.VAPID_SUBJECT,env.VAPID_PUBLIC_KEY,env.VAPID_PRIVATE_KEY);
  }
  const sendPush=env.__sendPush||((subscription,payload,options)=>
    webpush.sendNotification(subscription,payload,options));
  // One read plus at most three writes per delivery and one cleanup query.
  // LIMIT 15 therefore stays at or below 47 D1 queries per invocation, under
  // the Workers Free-plan limit of 50. Completed/dead/exhausted deliveries are
  // excluded before LIMIT so they cannot starve newer notifications.
  const deliveries=await env.DB.prepare(`SELECT e.id,e.uid,e.topic,e.due_at,e.expires_at,
      s.endpoint,s.subscription_json
    FROM notification_events e
    JOIN notification_preferences p
      ON p.uid=e.uid AND p.topic=e.topic AND p.enabled=1
    JOIN push_subscriptions s ON s.uid=e.uid
    LEFT JOIN notification_deliveries d
      ON d.event_id=e.id AND d.endpoint=s.endpoint
    WHERE e.due_at<=? AND e.expires_at>?
      AND (d.event_id IS NULL OR (d.attempts<5 AND
        (d.status='retry' OR (d.status='sending' AND d.claimed_until<?))))
    ORDER BY e.due_at,e.id,s.endpoint LIMIT 15`).bind(now,now,now).all();
  for (const delivery of deliveries.results||[]) {
    const payload=topics[delivery.topic];
    if (!payload) continue;
    await env.DB.prepare(`INSERT OR IGNORE INTO notification_deliveries
      (event_id,endpoint,status,attempts,claimed_until)
      VALUES(?,?,'retry',0,0)`).bind(delivery.id,delivery.endpoint).run();
    const claim=await env.DB.prepare(`UPDATE notification_deliveries
      SET status='sending', attempts=attempts+1,claimed_until=?
      WHERE event_id=? AND endpoint=? AND attempts<5
      AND (status='retry' OR (status='sending' AND claimed_until<?))`)
      .bind(now+120000,delivery.id,delivery.endpoint,now).run();
    if (!claim.meta?.changes) continue;
    try {
      await sendPush(JSON.parse(delivery.subscription_json),
        JSON.stringify({...payload,id:delivery.id,topic:delivery.topic}),
        {TTL:1800,urgency:'normal'});
      await env.DB.prepare(`UPDATE notification_deliveries SET status='sent',sent_at=?
        WHERE event_id=? AND endpoint=?`).bind(Date.now(),delivery.id,delivery.endpoint).run();
    } catch(err) {
      const code=Number(err.statusCode||0);
      if(code===404||code===410) {
        await env.DB.prepare('DELETE FROM push_subscriptions WHERE endpoint=?').bind(delivery.endpoint).run();
      } else {
        const dead=code===400||code===401||code===403;
        await env.DB.prepare(`UPDATE notification_deliveries SET status=?
          WHERE event_id=? AND endpoint=?`).bind(dead?'dead':'retry',delivery.id,delivery.endpoint).run();
        console.error('Web Push failed',code,err.message);
      }
    }
  }
  await env.DB.prepare('DELETE FROM notification_events WHERE expires_at<?')
    .bind(now-86400000).run();
}
