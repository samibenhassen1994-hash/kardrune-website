/* Safe autosave reconciliation, kept independent of Firebase and the DOM. */
(function(root){
'use strict';
function decide(localSnapshot,remoteSnapshot,serverRevision,link){
 if(typeof localSnapshot!=='string'||!Number.isSafeInteger(serverRevision)||serverRevision<0)return 'review';
 if(serverRevision===0||remoteSnapshot===null)return 'review';
 if(localSnapshot===remoteSnapshot)return 'adopt';
 if(!link||!Number.isSafeInteger(link.revision)||typeof link.snapshot!=='string')return 'review';
 if(serverRevision===link.revision){
  return localSnapshot===link.snapshot?'synced':'upload';
 }
 if(serverRevision>link.revision&&localSnapshot===link.snapshot)return 'download';
 return 'review'; // Both modified, stale account link, or remote was reset.
}
const api=Object.freeze({decide});
root.IDLE_CLOUD_SYNC=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window!=='undefined'?window:globalThis);
