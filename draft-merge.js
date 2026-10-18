'use strict';
window.CherryDraftMerge=(()=>{
 const copy=x=>x===undefined?undefined:JSON.parse(JSON.stringify(x));
 const same=(a,b)=>{if(a===b)return true;if(!a||!b||typeof a!=='object'||typeof b!=='object')return false;const ka=Object.keys(a).sort(),kb=Object.keys(b).sort();return ka.length===kb.length&&ka.every((k,i)=>k===kb[i]&&same(a[k],b[k]));};
 function plan(local,remote,base){
  const merged=copy(remote),conflicts=[];
  function pick(l,r,b,path){
   if(same(l,r))return copy(r);
   if(base&&same(l,b))return copy(r);
   if(base&&same(r,b))return copy(l);
   conflicts.push({path,local:copy(l),remote:copy(r)});return copy(r);
  }
  for(const key of new Set([...Object.keys(local.settings),...Object.keys(remote.settings)])){
   const value=pick(local.settings[key],remote.settings[key],base?.settings?.[key],['settings',key]);
   if(value===undefined)delete merged.settings[key];else merged.settings[key]=value;
  }
  for(const section of ['members','themes','events','records','categories']){
   const lm=new Map((local[section]||[]).map(x=>[x.id,x])),rm=new Map((remote[section]||[]).map(x=>[x.id,x])),bm=new Map((base?.[section]||[]).map(x=>[x.id,x]));
   const rows=[];
   for(const id of new Set([...rm.keys(),...lm.keys()])){
    const l=lm.get(id),r=rm.get(id),b=bm.get(id);
    // Old drafts have no trustworthy base: preserve newly uploaded remote rows by default.
    if(!base&&!l){rows.push(copy(r));continue;}
    let row;
    if(l&&r&&b){row=copy(r);for(const key of new Set([...Object.keys(l),...Object.keys(r)])){const value=pick(l[key],r[key],b[key],[section,id,key]);if(value===undefined)delete row[key];else row[key]=value;}}
    else row=pick(l,r,b,[section,id]);
    if(row)rows.push(row);
   }
   merged[section]=rows;
  }
  return {merged,conflicts};
 }
 function resolve(plan,choices){
  const out=copy(plan.merged);
  plan.conflicts.forEach((c,i)=>{if(!['local','remote'].includes(choices[i]))throw Error('모든 항목에서 사용할 내용을 선택해주세요.');const value=copy(c[choices[i]]),[section,id,key]=c.path;
   if(section==='settings'){if(value===undefined)delete out.settings[id];else out.settings[id]=value;}
   else if(key){const row=out[section].find(x=>x.id===id);if(value===undefined)delete row[key];else row[key]=value;}
   else {const index=out[section].findIndex(x=>x.id===id);if(index>=0)out[section].splice(index,1);if(value)out[section].push(value);}
  });return out;
 }
 return {plan,resolve,same};
})();
