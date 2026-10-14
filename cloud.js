'use strict';
window.CherryCloud = (() => {
  const url='https://aqessidqzmekfigbglkc.supabase.co';
  const key='sb_publishable_AFRna4TzpQRatRFsvFrH8Q_86UrPiUl';
  const client=supabase.createClient(url,key,{auth:{storage:sessionStorage,persistSession:true}});
  const check=r=>{if(r.error)throw Error(({ '42501':'이 작업을 할 권한이 없습니다. 멤버 연결 상태를 확인해주세요.','23514':'기록의 제목·사진·커다 연결을 확인해주세요.','23505':'이미 연결된 계정 또는 닉네임입니다.','40P01':'다른 저장과 겹쳤습니다. 잠시 후 다시 저장해주세요.'}[r.error.code])||r.error.message);return r.data;};
  const fromRow=r=>({id:r.id,title:r.title,memberId:r.member_id,date:r.date,kind:r.kind,themeId:r.theme_id||'',description:r.description,images:r.images,tags:r.tags,_cloud:true});
  const toRow=r=>({title:r.title,member_id:r.memberId,date:r.date,kind:r.kind,theme_id:r.themeId||null,description:r.description||'',images:r.images||[],tags:r.tags||[]});
  async function content(){const rows=check(await client.from('cherry_content').select('document,revision').eq('id',1));if(rows.length)return rows[0];const r=await fetch('content.json',{cache:'no-store'});if(!r.ok)throw Error('내용을 불러오지 못했습니다.');return {document:await r.json(),revision:0};}
  async function records(){return check(await client.from('cherry_records').select('id,title,member_id,date,kind,theme_id,description,images,tags').is('deleted_at',null).order('date',{ascending:false})).map(fromRow);}
  async function load(){const [c,rs]=await Promise.all([content(),records()]);const data=structuredClone(c.document);data.records=[...data.records.filter(r=>!r._cloud),...rs];return {data:CherryData.validate(data),revision:String(c.revision)};}
  async function identity(){const {data:{user},error}=await client.auth.getUser();if(error||!user)return null;const role=check(await client.rpc('cherry_identity'));return {...role,user};}
  async function upload(file){const who=await identity();if(!who?.memberId)throw Error('등록된 멤버만 사진을 올릴 수 있습니다.');if(!['image/png','image/jpeg','image/webp'].includes(file.type)||file.size>10485760)throw Error('PNG·JPG·WEBP 사진을 10MB 이하로 선택해주세요.');const path=who.user.id+'/'+crypto.randomUUID()+'.'+({ 'image/png':'png','image/jpeg':'jpg','image/webp':'webp'}[file.type]);check(await client.storage.from('cherry-images').upload(path,file,{upsert:false,contentType:file.type}));return client.storage.from('cherry-images').getPublicUrl(path).data.publicUrl;}
  return {client,check,content,records,load,identity,upload,toRow,fromRow};
})();
