const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),swift=fs.readFileSync(path.join(root,'VendorLedger/Sources/LedgerRecovery.swift'),'utf8'),access=fs.readFileSync(path.join(root,'VendorLedger/Sources/SubscriptionAccess.swift'),'utf8');
const profiles=swift.match(/static let profiles = #"""\n([\s\S]*?)\n    """#/)[1],body=swift.match(/static let exportBody = #"""\n([\s\S]*?)\n    """#/)[1];
const storage=new Map(),localStorage={getItem:k=>storage.get(k)??null,key:i=>[...storage.keys()][i],get length(){return storage.size}};const ctx=vm.createContext({localStorage,Date});
const put=(k,v)=>storage.set(k,JSON.stringify(v));
put('vb_profiles_v30',[{id:'v1',name:'喬鈺酥香屋'},{id:'v2',name:'攤商二'}]);
const keys=['vb_daily_v29','vb_purchase_v29','vb_fixed_v29','vb_processing_v29','vb_equip_v29','vb_inventory_v29','vb_memo_v29'];
for(const k of keys)put(k,[{id:'first',vendorId:'v1',amount:1.25},{id:'second',vendorId:'v2',amount:99}]);
put('vb_options_products_v1',['雞翅']);put('vb_options_products_v2',['其他']);put('vb_legacy_archives_v31',{v1:[{app:'qy_v3',records:['original']}],v2:[{private:'other'}]});
const before=JSON.stringify([...storage]);let checks=0;
const listed=JSON.parse(vm.runInContext(profiles,ctx));assert.equal(listed.length,2);assert.equal(listed[0].count,7);checks+=2;
for(const id of ['v1','v2']){
 const result=JSON.parse(vm.runInContext('(function(){const id='+JSON.stringify(id)+';'+body+'})()',ctx));assert.equal(result.app,'vendor_v29_backup');assert.equal(result.version,1);assert.equal(result.vendor.id,id);checks+=3;
 for(const k of keys){assert.equal(result.data[k].length,1);assert.equal(result.data[k][0].vendorId,id);checks+=2}
 assert.equal(Object.keys(result.options)[0],'vb_options_products_');assert.equal(result.legacyArchives.length,1);checks+=2;
}
assert.equal(JSON.stringify([...storage]),before);checks++;
// A hostile name or ID is data, never source code or another vendor's records.
const id='v";throw Error("injected");//';put('vb_profiles_v30',[{id,name:'特殊名稱'}]);put('vb_daily_v29',[{id:'item',vendorId:id,amount:7}]);const odd=JSON.parse(vm.runInContext('(function(){const id='+JSON.stringify([id])+'[0];'+body+'})()',ctx));assert.equal(odd.data.vb_daily_v29.length,1);assert.equal(odd.vendor.id,id);checks+=2;
storage.clear();assert.deepEqual(JSON.parse(vm.runInContext(profiles,ctx)),[]);checks++;
storage.set('vb_profiles_v30','invalid');assert.throws(()=>vm.runInContext(profiles,ctx));checks++;
const config=JSON.parse(fs.readFileSync(path.join(root,'AppStore/subscriptions.json'),'utf8'));assert.deepEqual(config.products.map(p=>p.requestedPrice),['99.00','1089.00']);checks++;
for(const p of config.products){assert.ok(access.includes('"'+p.productID+'"'));assert.equal(p.introductoryOffer.duration,'ONE_MONTH');checks+=2}
console.log(JSON.stringify({checks,status:'passed',scope:'Native backup JavaScript and release configuration only; iOS StoreKit compile/sandbox tests still required'}));
