'use strict';
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const functionsV1 = require('firebase-functions/v1');
const {deleteOwnedAccount} = require('./deletion.cjs');
initializeApp();
const db = getFirestore();
const lock = (uid, seconds) => db.collection('ledgerDeletion').doc(uid).set({expiresAt: Timestamp.fromMillis(seconds * 1000)});
const deleteSnapshots = uid => db.recursiveDelete(db.collection('ledgerAccounts').doc(uid));
exports.deleteLedgerAccount = onCall({region:'asia-east1', timeoutSeconds:540, memory:'512MiB'}, request => deleteOwnedAccount(request, {
  now:()=>Math.floor(Date.now()/1000),
  error:(code,message)=>new HttpsError(code,message),
  lock, deleteSnapshots,
  deleteUser:async uid=>{try{await getAuth().deleteUser(uid)}catch(error){if(error.code!=='auth/user-not-found')throw error}}
}));
// Also clean up if an administrator removes the Auth account outside the app.
exports.cleanupDeletedLedgerUser = functionsV1.region('asia-east1').auth.user().onDelete(async user => {
  await lock(user.uid, Math.floor(Date.now()/1000) + 7*86400);
  await deleteSnapshots(user.uid);
});
