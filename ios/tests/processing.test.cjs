const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../VendorLedger/Web/index.html'),'utf8');
const ctx=vm.createContext({});vm.runInContext(html.slice(html.indexOf('const LedgerProcessing='),html.indexOf('function $10('))+';globalThis.P=LedgerProcessing',ctx);const P=ctx.P;
let checks=0;const eq=(a,b)=>{assert.equal(a,b);checks++},bad=f=>{assert.throws(f);checks++};
const names=['紅麴豆腐乳','醬油','米酒','白砂糖','蒜粉','白胡椒粉','豆漿粉','甜菜根粉','玉米粉','地瓜粉','中筋麵粉'];
const quantities=[1000,1000,2400,2000,720,400,1000,680,3600,4800,2400],costs=[150,22,100,44,128,100,340,748,108,208,76];
const batch={date:'2026-11-04',product:'自製翅腿',recipe:'測試配方',rawKg:340,rawUnitPrice:55,weight:360,unit:'公斤',ingredients:names.map((name,i)=>({id:String(i),name,qty:quantities[i],unit:'公克',packQty:quantities[i],packUnit:'公克',packPrice:costs[i]}))};
const snap=P.snapshot(batch);eq(snap.costing.marinadeCost,2024);eq(snap.costing.rawCost,18700);eq(snap.costing.totalCost,20724);eq(snap.costing.costPerKg,20724/360);eq(P.convert(1,'台斤','公克'),600);eq(P.convert(1000,'ml','L'),1);bad(()=>P.convert(1,'L','公斤'));bad(()=>P.convert(1,'包','瓶'));
const template=P.template(batch,'a');const half={...batch,rawKg:170,weight:180,ingredients:P.scale(template.ingredients,.5)};eq(P.calculate(half).totalCost,10362);eq(P.calculate(half).costPerKg,snap.costing.costPerKg);
batch.ingredients[0].packPrice=999;eq(snap.costing.ingredients[0].packPrice,150);eq(template.ingredients[0].packPrice,150);eq(snap.costing.totalCost,20724);
P.validateSnapshot(snap);checks++;bad(()=>P.validateSnapshot({...snap,costing:{...snap.costing,totalCost:1}}));
for(const value of ['',null,-1,Infinity,'NaN']){bad(()=>P.calculate({...batch,rawUnitPrice:value}));bad(()=>P.calculate({...batch,ingredients:[{...batch.ingredients[0],packPrice:value}]}))}
for(const value of [0,'',-1]){bad(()=>P.calculate({...batch,weight:value}));bad(()=>P.calculate({...batch,rawKg:value}));bad(()=>P.calculate({...batch,ingredients:[{...batch.ingredients[0],packQty:value}]}))}
eq(P.calculate({...batch,rawUnitPrice:0,ingredients:[]}).totalCost,0);eq(P.ingredient({name:'免費',qty:1,unit:'包',packQty:1,packUnit:'包',packPrice:0}).cost,0);
eq(P.ingredient({name:'醬油',qty:500,unit:'ml',packQty:1,packUnit:'L',packPrice:30}).cost,15);
eq(P.templates([template])[0].id,'a');bad(()=>P.templates([template,template]));bad(()=>P.templates([{...template,baseRawKg:0}]));bad(()=>P.templates([{...template,ingredients:[{name:'x',qty:1,unit:'g',packQty:1,packUnit:'L',packPrice:1}]}]));
// Actual backup wiring: recipes remain per vendor and missing recipes on old backups are left alone.
assert.ok(html.includes("recipes:LedgerProcessing.templates(get('vb_recipes_v32_'+vendorId)||[])"));checks++;
assert.ok(html.includes("preview.parsed.recipes!==undefined"));checks++;
assert.ok(html.includes('C($10,{items:j,all:q,setAll:w,vendorId:f},f)'));checks++;
assert.ok(html.includes('if(r.costing)LedgerProcessing.validateSnapshot(r)'));checks++;
console.log('Processing costing: '+checks+' checks passed');
// The native recovery path (available even after subscription expiry) includes templates too.
const swift=fs.readFileSync(path.join(__dirname,'../VendorLedger/Sources/LedgerRecovery.swift'),'utf8');
const exportBody=swift.match(/static let exportBody = #"""([\s\S]*?)"""#/)[1];
const storage={vb_recipes_v32_v1:JSON.stringify([template]),vb_profiles_v30:JSON.stringify([{id:'v1'},{id:'v2'}]),vb_processing_v29:JSON.stringify([{...snap,id:'batch',vendorId:'v1'}])};
const localStorage={getItem:k=>storage[k]??null,key:i=>Object.keys(storage)[i],length:Object.keys(storage).length};
const exported=JSON.parse(new Function('localStorage','id',exportBody)(localStorage,'v1'));eq(exported.recipes.length,1);eq(exported.data.vb_processing_v29[0].costing.totalCost,20724);
eq(JSON.parse(new Function('localStorage','id',exportBody)(localStorage,'v2')).recipes.length,0);
console.log('Native recipe recovery: 3 checks passed');
