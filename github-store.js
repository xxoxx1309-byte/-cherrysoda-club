'use strict';
window.CherryStore = (() => {
  const base='https://api.github.com/repos/xxoxx1309-byte/-cherrysoda-club';
  let token='',revision='',pendingHead='',pendingPayload='';
  async function api(path,method='GET',body){const r=await fetch(base+path,{method,headers:{Accept:'application/vnd.github+json',Authorization:'Bearer '+token,'X-GitHub-Api-Version':'2026-03-10',...(body?{'Content-Type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{})});if(!r.ok){if(r.status===401)throw Error('연결 키가 만료되었거나 올바르지 않습니다.');if(r.status===403||r.status===404)throw Error('이 저장소의 Contents 읽기·쓰기 권한을 확인해주세요.');if(r.status===409||r.status===422)throw Error('다른 수정과 겹쳤습니다. 초안을 백업한 뒤 최신 내용을 다시 불러와주세요.');throw Error('GitHub 저장에 실패했습니다. 잠시 후 다시 시도해주세요. ('+r.status+')');}return r.status===204?null:r.json();}
  function decode(s){const bytes=Uint8Array.from(atob(s.replace(/\s/g,'')),c=>c.charCodeAt(0));return new TextDecoder().decode(bytes);}
  async function current(){return api('/contents/content.json?ref=main');}
  async function connect(key){token=key.trim();if(!token)throw Error('연결 키를 입력해주세요.');try{const file=await current();const data=CherryData.validate(JSON.parse(decode(file.content)));revision=file.sha;pendingHead='';return {data,revision};}catch(e){token='';throw e;}}
  function disconnect(){token='';pendingHead='';}
  async function publish(data,assets,expectedRevision,progress=()=>{}) {
    if(!token)throw Error('먼저 GitHub를 연결해주세요.');CherryData.validate(data);
    // If the previous PATCH timed out, discover whether it actually succeeded before retrying.
    if(pendingHead){const ref=await api('/git/ref/heads/main');if(ref.object.sha===pendingHead){revision=(await current()).sha;pendingHead='';if(pendingPayload===JSON.stringify(data))return revision;expectedRevision=revision;}pendingHead='';}
    const head=(await api('/git/ref/heads/main')).object.sha;
    const commit=await api('/git/commits/'+head);
    const latest=await api('/contents/content.json?ref='+head);
    if(!expectedRevision || latest.sha!==expectedRevision)throw Error('사이트 내용이 다른 곳에서 수정되었습니다. 초안을 백업한 뒤 최신 내용을 다시 불러와주세요.');
    const tree=[{path:'content.json',mode:'100644',type:'blob',content:JSON.stringify(data,null,2)+'\n'}];
    const used=new Set([data.settings.heroImage,...data.members.map(x=>x.image),...data.themes.map(x=>x.image),...data.events.map(x=>x.image),...data.records.flatMap(x=>x.images||[])]);
    const files=Object.entries(assets).filter(([path])=>used.has(path));
    for(let i=0;i<files.length;i++){const [path,src]=files[i];if(!/^assets\/[a-zA-Z0-9._-]+$/.test(path)||!/^data:image\/(png|jpeg|webp);base64,/.test(src))throw Error('사진 파일이 올바르지 않습니다.');progress(`사진 업로드 중 ${i+1}/${files.length}`);const blob=await api('/git/blobs','POST',{content:src.split(',')[1],encoding:'base64'});tree.push({path,mode:'100644',type:'blob',sha:blob.sha});}
    progress('내용 저장 중…');const t=await api('/git/trees','POST',{base_tree:commit.tree.sha,tree});const c=await api('/git/commits','POST',{message:'Update Cherry Soda Club content',tree:t.sha,parents:[head]});pendingHead=c.sha;pendingPayload=JSON.stringify(data);await api('/git/refs/heads/main','PATCH',{sha:c.sha,force:false});
    revision=(await current()).sha;pendingHead='';return revision;
  }
  async function reload(){if(!token)throw Error('GitHub 연결이 필요합니다.');const file=await current();revision=file.sha;pendingHead='';return {data:CherryData.validate(JSON.parse(decode(file.content))),revision};}
  return {connect,disconnect,publish,reload,connected:()=>!!token};
})();
