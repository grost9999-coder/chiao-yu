const {before,after,test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,serverTimestamp,runTransaction}=require('firebase/firestore');
let env;const revision='12345678-1234-1234-1234-123456789ABC';
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-vendor-ledger',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}})});
after(async()=>env?.cleanup());
const metadata=(rev=revision)=>({revision:rev,chunks:1,digest:'a'.repeat(64),bytes:20,updatedAt:serverTimestamp(),format:1});
test('verified owner only; anonymous, unverified, other UID and immutable chunk updates are denied',async()=>{
 const a=env.authenticatedContext('a',{email_verified:true}).firestore(),b=env.authenticatedContext('b',{email_verified:true}).firestore();
 const path='ledgerAccounts/a/snapshots/'+revision,chunk=doc(a,path+'/chunks/0');
 await assertSucceeds(setDoc(chunk,{payload:'e30='}));
 await assertFails(setDoc(chunk,{payload:'replacement'}));
 await assertSucceeds(setDoc(doc(a,path),metadata()));
 await assertSucceeds(setDoc(doc(a,'ledgerAccounts/a'),metadata()));
 await assertSucceeds(getDoc(doc(a,'ledgerAccounts/a')));
 await assertFails(getDoc(doc(b,'ledgerAccounts/a')));
 await assertFails(getDoc(doc(b,path+'/chunks/0')));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'ledgerAccounts/a')));
 await assertFails(getDoc(doc(env.authenticatedContext('a',{email_verified:false}).firestore(),'ledgerAccounts/a')));
 await assertFails(setDoc(doc(a,'ledgerAccounts/b'),metadata()));
});
test('unpublished backups, oversized chunks and client deletion locks are denied',async()=>{
 const db=env.authenticatedContext('c',{email_verified:true}).firestore();
 await assertFails(setDoc(doc(db,'ledgerAccounts/c'),metadata()));
 await assertFails(setDoc(doc(db,'ledgerAccounts/c/snapshots/'+revision+'/chunks/0'),{payload:'x'.repeat(400001)}));
 await assertFails(setDoc(doc(db,'ledgerDeletion/c'),{expiresAt:serverTimestamp()}));
});
test('deletion tombstone blocks cached tokens',async()=>{
 await env.withSecurityRulesDisabled(async context=>setDoc(doc(context.firestore(),'ledgerDeletion/a'),{expiresAt:new Date(Date.now()+86400000)}));
 const db=env.authenticatedContext('a',{email_verified:true}).firestore();
 await assertFails(getDoc(doc(db,'ledgerAccounts/a')));
 await assertFails(setDoc(doc(db,'ledgerAccounts/a/snapshots/'+revision+'/chunks/1'),{payload:'e30='}));
});
test('stale revision cannot overwrite a newer cloud version',async()=>{
 const db=env.authenticatedContext('d',{email_verified:true}).firestore();
 const newer='22345678-1234-1234-1234-123456789ABC',path='ledgerAccounts/d';
 await setDoc(doc(db,path+'/snapshots/'+revision),metadata());await setDoc(doc(db,path),metadata());
 await setDoc(doc(db,path+'/snapshots/'+newer),metadata(newer));await setDoc(doc(db,path),metadata(newer));
 await assert.rejects(runTransaction(db,async transaction=>{const head=await transaction.get(doc(db,path));if(head.data().revision!==revision)throw Error('cloud-conflict');transaction.set(doc(db,path),metadata())}),/cloud-conflict/);
 assert.equal((await getDoc(doc(db,path))).data().revision,newer);
});
