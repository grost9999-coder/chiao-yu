const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../VendorLedger/Web/index.html'),'utf8');
const source=html.slice(html.indexOf('const VendorCatalog='),html.indexOf('function vendorProduct('));
let profiles=[{id:'a',name:'餐飲'},{id:'b',name:'服飾'}],checks=0;
const ctx=vm.createContext({console,JSON,Math,Number,Object,Set,Error,B10:()=>profiles,VX:[]});
vm.runInContext(source+';globalThis.cat=VendorCatalog;',ctx);const cat=ctx.cat;
function eq(a,b){assert.equal(a,b);checks++}function throws(fn){assert.throws(fn);checks++}
let seq=0,id=()=> 'item-'+(++seq),base={version:1,industry:'custom',items:[]};
for(const industry of Object.keys(cat.templates)){
 const settings=cat.apply(base,industry,id);eq(settings.industry,industry);eq(settings.items.length,cat.templates[industry].items.length);eq(cat.apply(settings,industry,id).items.length,settings.items.length);
 eq(settings.items.every(x=>x.unitPrice===0),true);
}
let item={id:id(),kind:'sale',name:'冰紅茶',unit:'杯',category:'飲料',qty:1.5,unitPrice:20.1};
let catalog=cat.put(base,item);eq(catalog.items[0].qty,1.5);eq(cat.total(1.5,20.1),30.15);eq(cat.total(0.1,0.2),0.02);eq(cat.total(0,99),0);
const historical=cat.sale(catalog.items[0]);catalog=cat.put(catalog,{...item,unitPrice:30});eq(historical.amount,30.15);eq(cat.sale(catalog.items[0]).amount,45);eq(historical.unit,'杯');
profiles[0].catalog=catalog;eq(ctx.vendorCatalog('b').items.length,0);eq(ctx.vendorCatalog('a').items[0].name,'冰紅茶');
catalog=cat.put(catalog,{...item,active:false});eq(catalog.items[0].active,false);eq(historical.amount,30.15);
for(const value of ['',-1,'Infinity','abc',1e13]){throws(()=>cat.put(base,{...item,qty:value}));throws(()=>cat.put(base,{...item,unitPrice:value}))}
throws(()=>cat.put(catalog,{...item,id:id()}));throws(()=>cat.validate({...base,industry:'__proto__'}));throws(()=>cat.put(base,{...item,kind:'constructor'}));throws(()=>cat.put(base,{...item,unit:''}));
eq(cat.put(base,{...item,qty:0,unitPrice:0}).items[0].unitPrice,0);
let restored=cat.restore(profiles,'b',catalog);eq(restored[0],profiles[0]);eq(restored[1].catalog.items.length,1);eq(restored[1].name,'服飾');eq(cat.restore(restored,'b',catalog)[1].catalog.items.length,1);
throws(()=>cat.restore(restored,'b',cat.put(catalog,{...item,unitPrice:42})));eq(restored[1].catalog.items[0].unitPrice,20.1);throws(()=>cat.restore(profiles,'missing',catalog));
// Full compiled web bundle must still parse after hand-editing component integration.
const scripts=[...html.matchAll(/<script\b(?![^>]*type="application\/json")[^>]*>([\s\S]*?)<\/script>/g)].map(m=>m[1]);scripts.forEach(code=>new vm.Script(code));checks++;
// Render and exercise the actual dialog, including draft confirmation and saved profile.
let slots=[],cursor=0,saved=null,failed=false;ctx.C=(tag,props,key)=>({tag,props,key});ctx.m=ctx.C;ctx.M0=id;
ctx.Q0={useRef:init=>({current:init}),useEffect:()=>{},useState:init=>{const i=cursor++;if(!(i in slots))slots[i]=typeof init==='function'?init():init;return [slots[i],value=>slots[i]=typeof value==='function'?value(slots[i]):value]}};
function render(){cursor=0;return ctx.CatalogSettings({profile:profiles[1],onSave:value=>{if(failed)return '儲存失敗';saved=value},onClose:()=>{}})}
function nodes(t){return !t||typeof t!=='object'?[]:[t,...[t.props?.children].flat(Infinity).flatMap(nodes)]}
function button(label){const t=nodes(render()).find(x=>x.tag==='button'&&x.props.children===label);assert.ok(t,label);return t}
function input(label,value){const n=nodes(render()).find(x=>x.props?.['aria-label']===label);assert.ok(n,label);n.props.onChange({target:{value}})}
input('攤商業別','service');button('加入此業別範本').props.onClick();eq(saved,null);
button('＋新增銷售商品／服務').props.onClick();input('品項name','按摩');input('品項unit','小時');input('品項qty','0.5');input('品項unitPrice','200');button('確認品項').props.onClick();eq(saved,null);failed=true;button('儲存本攤設定').props.onClick();eq(saved,null);eq(nodes(render()).some(x=>x.props?.role==='alert'),true);failed=false;button('儲存本攤設定').props.onClick();eq(saved.industry,'service');eq(saved.items.find(x=>x.name==='按摩').qty,0.5);
console.log(JSON.stringify({checks,status:'passed',scope:'catalog validation, templates, vendor isolation, UI persistence and historical totals'}));

