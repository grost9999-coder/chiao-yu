const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync(path.join(__dirname,'../VendorLedger/Web/index.html'),'utf8');
const source=html.slice(html.indexOf('function inventoryDraft('),html.indexOf('function A10(',html.indexOf('function inventoryDraft(')));
let slots=[],cursor=0,current=[],orders=[],fail=false,checks=0;
const ctx=vm.createContext({console,Date,JSON,Number,Math,Error,E10:['斤','公斤'],LedgerProfit:{money:x=>String(x)},X0:()=> '2026-10-27',M0:()=> 'new-'+current.length,C:(tag,props,key)=>({tag,props,key}),m:(tag,props,key)=>({tag,props,key})});
ctx.Q0={useState:init=>{const i=cursor++;if(!(i in slots))slots[i]=typeof init==='function'?init():init;return[slots[i],value=>slots[i]=typeof value==='function'?value(slots[i]):value]},useEffect:()=>{}};ctx.Kn=(key,init)=>ctx.Q0.useState(init);vm.runInContext(source,ctx);
function reset(){slots=[];current=[{id:'stock',vendorId:'a',name:'雞翅',qty:18.5,min:2,unit:'公斤',unitPrice:80,rawMetadata:{keep:true}},{id:'stock',vendorId:'b',name:'另一攤',qty:99,min:1,unit:'包',unitPrice:5}];orders=[];fail=false}
function render(){cursor=0;return ctx.S10({items:current.filter(x=>x.vendorId==='a'),all:current,vendorId:'a',setAll:update=>{if(fail)return false;current=typeof update==='function'?update(current):update;return true},setPurchaseAll:update=>{if(fail)return false;orders=typeof update==='function'?update(orders):update;return true}})}
function nodes(t){if(!t||typeof t!=='object')return[];return[t,...(Array.isArray(t.props?.children)?t.props.children:[t.props?.children]).flat(Infinity).flatMap(nodes)]}
function button(label){const node=nodes(render()).find(x=>x.tag==='button'&&x.props.children===label);assert.ok(node,'missing button '+label);return node}
function type(label,value){const node=nodes(render()).find(x=>x.tag==='input'&&x.props['aria-label']===label);assert.ok(node,'missing input '+label);node.props.onChange({target:{value}})}
function text(t){if(t==null||t===false)return'';if(typeof t!=='object')return String(t);return(Array.isArray(t.props?.children)?t.props.children:[t.props?.children]).flat(Infinity).map(text).join(' ')}
function eq(a,b){assert.equal(a,b);checks++}
reset();button('盤點／編輯').props.onClick();type('編輯盤點數量','0');button('儲存盤點').props.onClick();eq(current[0].qty,0);eq(current[1].qty,99);eq(current[0].unitPrice,80);eq(current[0].rawMetadata.keep,true);eq(orders.length,0);assert.match(text(render()),/已儲存盤點/);checks++;
button('盤點／編輯').props.onClick();type('編輯盤點數量','2.375');type('編輯單位','包');type('編輯最低庫存警示','0.5');type('編輯單價（每一單位）','15.25');button('儲存盤點').props.onClick();eq(current[0].qty,2.375);eq(current[0].unit,'包');eq(current[0].min,0.5);eq(current[0].unitPrice,15.25);
for(const bad of ['','-1','not-number','Infinity']){button('盤點／編輯').props.onClick();type('編輯盤點數量',bad);button('儲存盤點').props.onClick();eq(current[0].qty,2.375);assert.ok(nodes(render()).some(x=>x.props?.role==='alert'));checks++;button('取消').props.onClick()}
button('盤點／編輯').props.onClick();type('編輯盤點數量','8');button('取消').props.onClick();eq(current[0].qty,2.375);
button('盤點／編輯').props.onClick();type('編輯盤點數量','8');fail=true;button('儲存盤點').props.onClick();eq(current[0].qty,2.375);assert.ok(button('儲存盤點'));checks++;fail=false;button('儲存盤點').props.onClick();eq(current[0].qty,8);
button('盤點／編輯').props.onClick();type('編輯盤點數量','4');current[0]={...current[0],qty:7};button('儲存盤點').props.onClick();eq(current[0].qty,7);assert.match(text(render()),/此品項已更新/);checks++;button('取消').props.onClick();
button('加入進貨').props.onClick();eq(current[0].qty,7);eq(orders.length,1);eq(orders[0].vendorId,'a');
button('刪除').props.onClick();eq(current.length,2);button('取消刪除').props.onClick();eq(current.length,2);
button('刪除').props.onClick();button('確認刪除').props.onClick();eq(current.length,1);eq(current[0].vendorId,'b');
type('新增品項名稱','新商品');type('新增單位','袋');type('新增盤點數量','0');button('加入庫存').props.onClick();eq(current.length,2);eq(current[1].qty,0);eq(current[1].unit,'袋');eq(current[1].vendorId,'a');
console.log(JSON.stringify({checks,status:'passed'}));
