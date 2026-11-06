(function(root){
 'use strict';
 const tables=['vb_daily_v29','vb_purchase_v29','vb_fixed_v29','vb_processing_v29','vb_equip_v29','vb_inventory_v29','vb_memo_v29'];
 const allowed=k=>tables.includes(k)||['vb_profiles_v30','vb_vendor_v29','vb_legacy_archives_v31'].includes(k)||/^vb_(recipes_v32|options_[A-Za-z0-9_]+)_v[0-9]{1,2}$/.test(k);
 function validate(raw){
  if(typeof raw!=='string'||new TextEncoder().encode(raw).length>25000000)throw Error('備份格式錯誤或超過 25 MB');
  const x=JSON.parse(raw);
  if(x.app!=='vendor_account_snapshot'||x.version!==1||!x.data||Array.isArray(x.data)||Object.getPrototypeOf(x.data)!==Object.prototype)throw Error('不支援此帳號備份');
  for(const [k,v] of Object.entries(x.data)){
   if(!allowed(k)||typeof v!=='string')throw Error('備份包含不支援的資料表');
   const value=JSON.parse(v);
   if(tables.includes(k)||k==='vb_profiles_v30'||k.startsWith('vb_recipes_v32_')){
    if(!Array.isArray(value)||value.some(r=>!r||typeof r!=='object'||Array.isArray(r)||typeof r.id!=='string'))throw Error('資料表格式錯誤：'+k);
    if(new Set(value.map(r=>r.id)).size!==value.length)throw Error('資料編號重複：'+k);
    if(k==='vb_profiles_v30'&&value.length>20)throw Error('超過 20 個攤商');
   }
   if(k==='vb_vendor_v29'&&typeof value!=='string')throw Error('攤商選擇格式錯誤');
   if(k==='vb_legacy_archives_v31'&&(!value||typeof value!=='object'||Array.isArray(value)))throw Error('舊版封存格式錯誤');
   if(k.startsWith('vb_options_')&&!Array.isArray(value))throw Error('自訂選項格式錯誤');
  }
  return x;
 }
 function read(storage){
  const data={};for(let i=0;i<storage.length;i++){const k=storage.key(i);if(allowed(k))data[k]=storage.getItem(k)}
  const raw=JSON.stringify({app:'vendor_account_snapshot',version:1,exportedAt:new Date().toISOString(),data});validate(raw);return raw;
 }
 function apply(storage,raw){
  const incoming=validate(raw),old=validate(read(storage)).data;
  const clear=()=>{const keys=[];for(let i=0;i<storage.length;i++){const k=storage.key(i);if(allowed(k))keys.push(k)}keys.forEach(k=>storage.removeItem(k))};
  try{clear();for(const [k,v]of Object.entries(incoming.data))storage.setItem(k,v)}
  catch(error){try{clear();for(const [k,v]of Object.entries(old))storage.setItem(k,v)}catch(rollback){throw Error('還原未完成；回復也失敗，請使用還原前自動匯出的檔案。')}throw error}
  return true;
 }
 root.LedgerAccountStorage={read,validate,apply,allowed};
})(globalThis);
