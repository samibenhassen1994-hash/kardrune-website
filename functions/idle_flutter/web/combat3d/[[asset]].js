export function onRequest() {
  return new Response(null,{status:404,headers:{'Cache-Control':'no-store'}});
}
