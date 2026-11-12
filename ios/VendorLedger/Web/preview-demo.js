// Only injected by the native DEBUG simulator path, never loaded by index.html.
(()=>{
 if(!window.__ledgerPreviewStory)return;
 const put=(k,v)=>localStorage.setItem(k,JSON.stringify(v));
 const month=new Date().toISOString().slice(0,7),day=month+'-05';
 put('vb_vendor_v29','v1');
 put('vb_profiles_v30',Array.from({length:20},(_,i)=>({id:'v'+(i+1),name:i===0?'市集示範攤':i===1?'飲品示範攤':'攤商'+String(i+1).padStart(2,'0'),product:'自製翅腿',configured:i<2})));
 put('vb_daily_v29',Array.from({length:5},(_,i)=>({id:'demo-d'+i,vendorId:'v1',date:month+'-0'+(i+1),sales:[{name:'自製翅腿',qty:60+i*5,amount:3600+i*300}],platforms:[{name:'外送平台',amount:600+i*50}],rent:{cash:300,transfer:0},misc:[{name:'清潔耗材',amount:100}],costOfGoods:2100+i*175,openCash:{100:5,500:2},closeCash:{100:11,500:6}})));
 put('vb_purchase_v29',[{id:'demo-soy-purchase',vendorId:'v1',date:day,recordKind:'procurement',category:'醃料',name:'醬油',qty:2,unit:'公斤',price:60},{id:'demo-sugar-purchase',vendorId:'v1',date:day,recordKind:'procurement',category:'醃料',name:'白砂糖',qty:1,unit:'公斤',price:22}]);
 put('vb_fixed_v29',[{id:'demo-f1',vendorId:'v1',date:month+'-01',expenseMonth:month,type:'瓦斯',name:'營業瓦斯',amount:850,treatment:'expense'},{id:'demo-f2',vendorId:'v1',date:month+'-01',expenseMonth:month,type:'耗材',name:'包材',amount:600,treatment:'expense'}]);
 const batch={"id":"demo-batch","vendorId":"v1","date":"2026-11-05","product":"自製翅腿","weight":"11","unit":"公斤","recipe":"市集原味配方","rawKg":"10","rawUnitPrice":"55","ingredients":[{"id":"demo-soy","name":"醬油","qty":1000,"unit":"公克","packQty":2,"packUnit":"公斤","packPrice":60,"cost":30}],"sourceText":"","mode":"total","note":"","costing":{"version":1,"rawKg":10,"rawUnitPrice":55,"yieldKg":11,"ingredients":[{"id":"demo-soy","name":"醬油","qty":1000,"unit":"公克","packQty":2,"packUnit":"公斤","packPrice":60,"cost":30}],"rawCost":550,"marinadeCost":30,"totalCost":580,"costPerKg":52.72727272727273}};batch.date=day;put('vb_processing_v29',[batch]);
 let started=false;
 const click=label=>[...document.querySelectorAll('button')].find(b=>b.textContent.trim()===label)?.click();
 const go=label=>{document.querySelector('[aria-label="功能分頁"]')?.querySelectorAll('button').forEach(b=>{if(b.textContent.includes(label))b.click()});window.scrollTo(0,0)};
 const scroll=text=>[...document.querySelectorAll('h2,h3,label,button,p,span,div')].find(e=>e.textContent.trim()===text)?.scrollIntoView({block:'center',behavior:'smooth'});
 function start(){
  if(started||!document.querySelector('[aria-label="功能分頁"]'))return;started=true;
  const story=window.__ledgerPreviewStory;
  if(story===1){go('分析');setTimeout(()=>scroll('營收'),7000);setTimeout(()=>go('固定支出'),14000);setTimeout(()=>go('今日帳'),21000)}
  if(story===2){go('進貨');setTimeout(()=>{go('加工');setTimeout(()=>click('編輯此批次'),300)},7000);setTimeout(()=>document.querySelector('[data-testid="batch-summary"]')?.scrollIntoView({block:'center',behavior:'smooth'}),14000);setTimeout(()=>scroll('儲存批次修改'),21000)}
  if(story===3){click('業別／品項');setTimeout(()=>{click('取消');go('庫存')},7000);setTimeout(()=>go('備份／匯入'),14000);setTimeout(()=>scroll('匯出目前攤商備份'),21000)}
 }
 document.addEventListener('DOMContentLoaded',()=>{const o=new MutationObserver(()=>{start();if(started)o.disconnect()});o.observe(document.documentElement,{childList:true,subtree:true});start()});
})();
