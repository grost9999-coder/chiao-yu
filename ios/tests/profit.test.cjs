const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../VendorLedger/Web/index.html'),'utf8');
const data=process.argv[2]?JSON.parse(fs.readFileSync(process.argv[2],'utf8')):null;
const fixture={app:'qy_v3',dailyRecs:[{id:'demo',date:'2026-07-01',revenue:100,totalCogs:40,purchaseCost:40,diyCost:0,rent:10,opCost:5,net:45,purchaseItems:[{name:'商品',qty:1,amount:40}]}],purchaseRecs:[],monthlyRecs:[{id:'asset',date:'2026-07-01',month:'2026-07',name:'真空封口機',amount:529}],inventory:{rawMeat:[{name:'原料',qty:1,unit:'公斤'}]}};
const code=html.slice(html.indexOf('const LedgerProfit='),html.indexOf('function VendorBackupPage('));
const ctx=vm.createContext({console,Date});vm.runInContext(code+';globalThis.P=LedgerProfit;globalThis.convert=legacyConvert;globalThis.validate=validateLedgerRows',ctx);
const P=ctx.P,rows=ctx.convert(data||fixture,'test'),range={start:'2026-01-01',end:'2026-12-31'};let checks=0;function eq(a,b){assert.equal(a,b);checks++}function ok(x){assert.ok(x);checks++}
ctx.validate(rows);checks++;
const daily=rows.vb_daily_v29,purchases=rows.vb_purchase_v29,fixed=rows.vb_fixed_v29,assets=rows.vb_equip_v29;
if(data){
 for(const raw of data.dailyRecs){const d=daily.find(x=>x.id==='qy3-'+raw.id),p=P.daily(d,purchases);eq(p.revenue,raw.revenue);eq(p.cogs,raw.totalCogs);eq(p.gross,raw.gross);eq(p.baseNet,raw.net)}
 const result=P.summarize(daily,purchases,[],[],range);eq(result.revenue,data.dailyRecs.reduce((s,r)=>s+r.revenue,0));eq(result.gross,data.dailyRecs.reduce((s,r)=>s+r.gross,0));eq(result.net,data.dailyRecs.reduce((s,r)=>s+r.net,0));
 eq(fixed.length,data.monthlyRecs.length);
 const old=JSON.parse(JSON.stringify(rows));for(const p of old.vb_purchase_v29){delete p.dailyId;delete p.recordKind}for(const x of old.vb_fixed_v29){delete x.expenseMonth;delete x.treatment}
 eq(P.summarize(old.vb_daily_v29,old.vb_purchase_v29,[],[],range).net,result.net);
}
eq(JSON.stringify(ctx.validate(JSON.parse(JSON.stringify(rows)))),JSON.stringify(rows));for(const key of Object.keys(rows)){const merged=new Map([...rows[key],...ctx.convert(data||fixture,'test')[key]].map(r=>[r.id,r]));eq(merged.size,rows[key].length)}
const sample={id:'manual',vendorId:'test',date:'2026-07-01',sales:[{amount:1000}],platforms:[{amount:100}],rent:{cash:100,transfer:20},misc:[{amount:30}],costOfGoods:400};
const summarize=(ds=[sample],ps=[],fx=[],as=[],r={start:'2026-07-01',end:'2026-07-01'})=>P.summarize(ds,ps,fx,as,r);
eq(summarize().gross,700);eq(summarize().net,550);eq(summarize([sample],[{id:'purchase',vendorId:'test',date:sample.date,price:9000}]).net,550);
const noCost={...sample};delete noCost.costOfGoods;eq(summarize([noCost]).gross,null);eq(summarize([noCost]).net,null);eq(summarize([{...sample,costOfGoods:0}]).gross,1100);eq(summarize([{...sample,costOfGoods:-1}]).net,null);
// Refunds and platform accounting: sales are not multiplied by quantity and cash reconciliation is not revenue.
eq(summarize([{...sample,sales:[{amount:1000,qty:3},{amount:-100}],platforms:[{amount:100}],openCash:{100:50},closeCash:{1000:100}}]).revenue,1000);
const charge={id:'fx',vendorId:'test',date:'2026-08-01',expenseMonth:'2026-07',name:'租約',type:'租金',amount:31,treatment:'expense'};
eq(summarize([sample],[],[charge]).net,549);eq(P.summarize([],[],[charge],[],{start:'2026-07-01',end:'2026-07-31'}).fixedTotal,31);eq(P.summarize([],[],[charge],[],{start:'2026-08-01',end:'2026-08-31'}).fixedTotal,0);
for(const amount of [0,0.01,1,31,100.01,12000,-13.25])for(const month of ['2026-02','2028-02','2026-07','2026-12']){const days=new Date(Date.UTC(+month.slice(0,4),+month.slice(5),0)).getUTCDate();let cents=0;for(let i=1;i<=days;i++){const day=month+'-'+String(i).padStart(2,'0');cents+=Math.round(P.monthlyAmount(amount,month,{start:day,end:day})*100)}eq(cents,Math.round(amount*100))}
for(const t of ['inventory','included','exclude'])eq(summarize([sample],[],[{...charge,treatment:t}]).net,550);
eq(summarize([sample],[],[{...charge,treatment:'review'}]).net,null);eq(summarize([sample],[],[{...charge,treatment:'asset'}]).net,null);
// Asset recognition delegates to linked asset, preventing payment + depreciation double deduction.
const asset={id:'asset',vendorId:'test',sourceFixedId:'fx',date:'2026-07-01',name:'機器',amount:1200,expenseMethod:'depreciate',depreciationStart:'2026-07',usefulLifeMonths:12,residualValue:0},assetFixed={...charge,treatment:'asset',amount:1200};
let a=P.summarize([],[],[assetFixed],[asset],{start:'2026-07-01',end:'2026-07-31'});eq(a.fixedTotal,0);eq(a.depreciation,100);eq(a.net,-100);
eq(P.summarize([],[],[{...assetFixed,treatment:'expense'}],[asset],{start:'2026-07-01',end:'2026-07-31'}).net,-1200);
eq(P.summarize([],[],[assetFixed],[{...asset,expenseMethod:'expense'}],{start:'2026-07-01',end:'2026-07-31'}).net,-1200);
eq(P.summarize([],[],[assetFixed],[{...asset,expenseMethod:'review'}],range).net,null);eq(P.summarize([],[],[assetFixed],[{...asset,usefulLifeMonths:0}],range).net,null);eq(P.summarize([],[],[assetFixed],[{...asset,residualValue:1300}],range).net,null);
let allCents=0;for(let year=2026;year<=2027;year++)for(let month=1;month<=12;month++){const m=year+'-'+String(month).padStart(2,'0'),last=new Date(Date.UTC(year,month,0)).getUTCDate();allCents+=Math.round(P.summarize([],[],[],[{...asset,amount:1200.01,residualValue:100}],{start:m+'-01',end:m+'-'+last}).depreciation*100)}eq(allCents,110001);
// Other vendors cannot become the cost source for a current daily row.
eq(P.cost({...noCost,id:'qy3-shared'},[{id:'qy3-cost-shared-外購-0',vendorId:'other',price:999}]),null);
// Malformed imports rejected before any storage writes.
for(const mutate of [r=>r.vb_daily_v29[0].sales[0].amount='oops',r=>r.vb_daily_v29[0].date='2026-02-30',r=>r.vb_fixed_v29[0].amount=Infinity,r=>r.vb_equip_v29[0].expenseMethod='oops',r=>r.vb_inventory_v29[0].qty='oops',r=>r.vb_daily_v29.push(r.vb_daily_v29[0]),r=>r.vb_daily_v29[0].closeCash={'100':-1}]){const bad=JSON.parse(JSON.stringify(rows));mutate(bad);assert.throws(()=>ctx.validate(bad));checks++}
console.log(JSON.stringify({checks,status:'passed',originalDailyRows:data?.dailyRecs.length||0}));
