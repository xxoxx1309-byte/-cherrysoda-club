'use strict';
window.CherryStore=(()=>{
  let ready=false;
  async function connect(){const role=await CherryCloud.identity();if(!role?.admin)throw Error('방장 계정으로 로그인해주세요.');ready=true;return reload();}
  async function reload(){return CherryCloud.load();}
  async function publish(data,assets,revision,progress){
    if(!ready)throw Error('방장 로그인이 필요합니다.');if(!(await CherryCloud.identity())?.admin){ready=false;throw Error('방장 계정으로 다시 로그인해주세요.');}
    CherryData.validate(data);
    const used=new Set([data.settings.heroImage,...data.members.map(x=>x.image),...data.themes.map(x=>x.image),...data.events.map(x=>x.image),...data.records.flatMap(x=>x.images||[])]);
    const mapping={};let i=0;
    for(const [path,src] of Object.entries(assets)){if(!used.has(path))continue;progress('사진 업로드 중 '+(++i));const blob=await (await fetch(src)).blob();mapping[path]=await CherryCloud.upload(new File([blob],'photo.webp',{type:blob.type}));}
    const next=JSON.parse(JSON.stringify(data),(_,v)=>typeof v==='string'&&mapping[v]?mapping[v]:v);
    progress('공개 사이트에 저장 중…');
    const rev=CherryCloud.check(await CherryCloud.client.rpc('cherry_publish',{p_document:next,p_revision:Number(revision)}));
    Object.assign(data,next);if(window.BroadcastChannel){const c=new BroadcastChannel('cherry-updated');c.postMessage('refresh');c.close();}return String(rev);
  }
  async function disconnect(){ready=false;await CherryCloud.client.auth.signOut();}
  return {connect,reload,publish,disconnect,connected:()=>ready};
})();
