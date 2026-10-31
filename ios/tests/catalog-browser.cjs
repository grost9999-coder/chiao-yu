const {webkit,devices}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const web=path.join(__dirname,'../VendorLedger/Web');
(async()=>{
const server=http.createServer((req,res)=>{const name=req.url.split('?')[0].endsWith('i18n.js')?'i18n.js':'index.html';res.setHeader('Content-Type',name.endsWith('.js')?'text/javascript':'text/html');res.end(fs.readFileSync(path.join(web,name)))});
await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;
try{
 browser=await webkit.launch({headless:true});const page=await browser.newPage({...devices['iPhone 13']});const errors=[];page.on('pageerror',e=>{errors.push(e.message);console.error('Browser error:',e.message)});
 const url='http://127.0.0.1:'+server.address().port+'/?language=zh-Hant';await page.goto(url);
 const open=async()=>{await page.getByRole('button',{name:'業別／品項',exact:true}).tap();await page.locator('dialog:modal').waitFor();};
 const button=name=>page.getByRole('dialog').getByRole('button',{name,exact:true});
 await open();assert.equal(await page.getByLabel('攤商業別',{exact:true}).locator('option').count(),21);
 await page.evaluate(()=>{window.__catalogEvents=[];for(const type of ['touchstart','touchend','pointerdown','pointerup','click'])document.addEventListener(type,e=>window.__catalogEvents.push({type,target:e.target.textContent?.slice(0,30)}),true)});await button('取消').tap();console.log('DIAGNOSTIC',await page.evaluate(()=>({events:window.__catalogEvents,buttons:[...document.querySelectorAll('dialog button')].map(el=>({text:el.textContent,props:Object.keys(el).filter(k=>k.startsWith('__reactProps')).map(k=>Object.keys(el[k]))}))})));await page.locator('dialog:modal').waitFor({state:'detached'});assert.equal(await page.locator('dialog:modal').count(),0);
 await open();await button('關閉').tap();await page.locator('dialog:modal').waitFor({state:'detached'});assert.equal(await page.locator('dialog:modal').count(),0);
 await open();await page.getByLabel('攤商業別',{exact:true}).selectOption('drink');await button('加入此業別範本').tap();await page.getByRole('status').filter({hasText:'已帶入'}).waitFor();
 for(const [kind,label,name,unit]of [['sale','銷售商品／服務','測試紅茶','杯'],['purchase','進貨／原料','測試茶葉','公斤'],['fixed','支出項目','測試電費','月'],['asset','資產設備','測試封口機','台']]){
  await button('＋新增'+label).tap();await page.getByLabel('品項name',{exact:true}).fill(name);await page.getByLabel('品項unit',{exact:true}).fill(unit);await page.getByLabel('品項qty',{exact:true}).fill('1.5');await page.getByLabel('品項unitPrice',{exact:true}).fill('20');await button('確認品項').tap();
 }
 await button('儲存本攤設定').tap();await page.locator('dialog:modal').waitFor({state:'detached'});assert.equal(await page.locator('dialog:modal').count(),0);
 await page.reload();await open();assert.equal(await page.getByLabel('攤商業別',{exact:true}).inputValue(),'drink');
 let stored=await page.evaluate(()=>JSON.parse(localStorage.getItem('vb_profiles_v30')));let saved=stored.find(p=>p.id==='v1').catalog;
 for(const name of ['測試紅茶','測試茶葉','測試電費','測試封口機']){assert.equal(saved.items.filter(x=>x.name===name).length,1);assert.equal(saved.items.find(x=>x.name===name).unitPrice,20);}
 assert.ok(!stored.find(p=>p.id==='v2').catalog);
 // A pending valid item is included by the main Save button, without a second confirmation.
 await button('＋新增銷售商品／服務').tap();await page.getByLabel('品項name',{exact:true}).fill('直接儲存商品');await button('儲存本攤設定').tap();await page.reload();await open();
 stored=await page.evaluate(()=>JSON.parse(localStorage.getItem('vb_profiles_v30')));assert.equal(stored[0].catalog.items.filter(x=>x.name==='直接儲存商品').length,1);
 // Invalid drafts keep the modal open and display feedback; Cancel remains usable.
 await button('＋新增銷售商品／服務').tap();await button('儲存本攤設定').tap();await page.getByRole('alert').waitFor();await button('取消').tap();await page.locator('dialog:modal').waitFor({state:'detached'});assert.equal(await page.locator('dialog:modal').count(),0);
 // All 20 industry templates can be applied, saved and recovered on reload.
 await open();const industries=await page.getByLabel('攤商業別',{exact:true}).locator('option').evaluateAll(nodes=>nodes.map(x=>x.value).filter(x=>x!=='custom'));await button('取消').tap();assert.equal(industries.length,20);
 for(const industry of industries){await open();await page.getByLabel('攤商業別',{exact:true}).selectOption(industry);await button('加入此業別範本').tap();await button('儲存本攤設定').tap();await page.reload();await open();assert.equal(await page.getByLabel('攤商業別',{exact:true}).inputValue(),industry);await button('取消').tap();}
 assert.deepEqual(errors,[]);console.log('PASS: iPhone WebKit touch actions, cancel/close, all four item types, draft save, reload persistence, isolation and 20 industry templates');
}finally{await browser?.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1});
