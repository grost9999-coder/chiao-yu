const {webkit}=require('playwright'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const root=path.join(__dirname,'../VendorLedger/Web');
const server=http.createServer((req,res)=>{const name=req.url.split('?')[0].split('/').pop()||'index.html';if(!['index.html','i18n.js','account-storage.js'].includes(name)){res.writeHead(404);return res.end()}res.setHeader('Content-Type',name.endsWith('.js')?'text/javascript':'text/html');res.end(fs.readFileSync(path.join(root,name)))});
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await webkit.launch();try{
const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
await page.goto('http://127.0.0.1:'+server.address().port+'/?language=zh-Hant');
const open=page.getByTestId('open-cash-1000'),close=page.getByTestId('close-cash-1000');
await open.waitFor();assert.equal(await open.inputValue(),'0');assert.equal(await close.inputValue(),'0');
await open.fill('2');await close.fill('5');
await page.getByText('合計開攤: $2000',{exact:true}).waitFor();
await page.getByText('合計收攤: $5000 / 差異: $3000',{exact:true}).waitFor();
await page.getByRole('button',{name:'💾 儲存今日',exact:true}).click();
await page.reload();await open.waitFor();assert.equal(await open.inputValue(),'2');assert.equal(await close.inputValue(),'5');
await page.evaluate(()=>{const rows=JSON.parse(localStorage.getItem('vb_daily_v29'));delete rows[0].openCash['1000'];delete rows[0].closeCash['1000'];rows[0].openCash['500']=3;localStorage.setItem('vb_daily_v29',JSON.stringify(rows))});
await page.reload();await open.waitFor();assert.equal(await open.inputValue(),'0');assert.equal(await close.inputValue(),'0');assert.equal(await page.getByTestId('open-cash-500').inputValue(),'3');
await close.fill('4');await page.getByRole('button',{name:'💾 儲存今日',exact:true}).click();await page.reload();await close.waitFor();assert.equal(await close.inputValue(),'4');
console.log('Mobile WebKit: NT$1000 fields, totals, save/reload and old record editing passed');
}finally{await browser.close();server.close()}})().catch(e=>{console.error(e);server.close();process.exit(1)});
