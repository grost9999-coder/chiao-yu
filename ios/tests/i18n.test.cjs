const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const path=require('node:path'); const base=path.join(__dirname,'..');
const code=fs.readFileSync(path.join(base,'VendorLedger/Web/i18n.js'),'utf8');
let checks=0;function check(a,b){assert.deepEqual(a,b);checks++;}
function load(language,system='zh-TW'){
 const c={URLSearchParams,location:{search:language?'?language='+encodeURIComponent(language):''},navigator:{language:system},document:{documentElement:{}}};
 vm.createContext(c);vm.runInContext(code,c);check(c.document.documentElement.lang,c.LedgerI18n.locale);return c.LedgerI18n;
}
for(const [lang,resolved] of [['en-US','en'],['ja-JP','ja'],['zh-CN','zh-Hans'],['zh-TW','zh-Hant'],['zh-HK','zh-Hant'],['fr-FR','zh-Hant'],['zh-SG','zh-Hans']])check(load(lang).locale,resolved);
check(load(null,'ja-JP').locale,'ja');
check(load('en').t('毛利'),'Gross profit');check(load('ja').t('庫存'),'在庫');check(load('zh-Hans').t('稅前淨利'),'税前净利');check(load('zh-Hant').t('毛利'),'毛利');
for(const lang of ['en','ja','zh-Hans','zh-Hant']){
 const api=load(lang);for(const custom of ['我的咖啡小攤','商品A-自訂','kg',100,0])check(api.t(custom),custom);
 const before=JSON.stringify({name:'我的咖啡小攤',qty:2,unit:'杯',amount:100});api.t('營收');check(JSON.stringify(JSON.parse(before)),before);
 for(const [key,values]of Object.entries(api.translations))for(const l of ['en','ja','zh-Hans']){assert.equal(typeof values[l],'string');assert.ok(values[l].length);checks++;}
}
const html=fs.readFileSync(path.join(base,'VendorLedger/Web/index.html'),'utf8');
assert.ok(html.indexOf('src="i18n.js"')<html.indexOf('<script type="module">'));checks++;
assert.ok(html.includes('LedgerI18n?.t(l.l)'));checks++;
for(const loc of ['en','ja','zh-Hans','zh-Hant']){
 const strings=fs.readFileSync(path.join(base,`VendorLedger/Resources/${loc}.lproj/Localizable.strings`),'utf8');
 const keys=new Set();for(const line of strings.trim().split('\n')){const m=line.match(/^("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");$/);assert.ok(m,line);const key=JSON.parse(m[1]);assert.ok(!keys.has(key),key);keys.add(key);JSON.parse(m[2]);checks++;}
}
console.log(JSON.stringify({status:'passed',checks,scope:'locale resolution, UI dictionaries, source fallback, user content preservation, native resource syntax; not an iOS runtime test'}));
