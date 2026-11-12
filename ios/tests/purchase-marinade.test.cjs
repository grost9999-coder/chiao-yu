const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const h=fs.readFileSync(path.join(__dirname,'../VendorLedger/Web/index.html'),'utf8'),ctx=vm.createContext({});vm.runInContext(h.slice(h.indexOf('const LedgerPurchase='),h.indexOf('function L10('))+';globalThis.P=LedgerPurchase',ctx);let checks=0;const eq=(a,b)=>{assert.equal(a,b);checks++};
const rows=[{id:'a',vendorId:'v1',date:'2026-11-01',name:'醬油',qty:1,unit:'公斤',price:22},{id:'b',vendorId:'v1',date:'2026-11-05',name:'醬油',qty:2,unit:'公斤',price:60},{id:'c',vendorId:'v2',date:'2026-11-06',name:'醬油',qty:1,unit:'公斤',price:999},{id:'d',vendorId:'v1',date:'2026-11-07',name:'醬油',qty:1,unit:'公斤',price:888,recordKind:'consumed'}];
let prices=ctx.P.prices(rows,'v1');eq(prices.length,1);eq(prices[0].packQty,2);eq(prices[0].packPrice,60);eq(ctx.P.prices(rows,'v2')[0].packPrice,999);eq(ctx.P.prices(rows,'v3').length,0);eq(ctx.P.prices([...rows,{vendorId:'v1',date:'2026-11-05',name:'醬油',qty:1,price:30,unit:'公斤'}],'v1')[0].packPrice,30);
for(const values of [{qty:0,price:2},{qty:1,price:0},{qty:-1,price:10},{qty:2,price:Infinity}])eq(ctx.P.prices([{vendorId:'v1',name:'米酒',...values}],'v1').length,0);
eq(ctx.P.marinadeNames.includes('醬油'),true);eq(ctx.P.marinadeNames.includes('地瓜粉'),true);
assert.ok(h.includes("...LedgerPurchase.prices(B10('vb_purchase_v29',[]),vendorId)"));checks++;
assert.ok(h.includes('C(L10,{items:L,all:Y,setAll:H,vendorId:f},f)'));checks++;
console.log('Marinade purchase categories and latest per-vendor prices: '+checks+' checks passed');
