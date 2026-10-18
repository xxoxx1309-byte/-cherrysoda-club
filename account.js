'use strict';
const $=id=>document.getElementById(id),{esc,safeImage}=CherryData,{client,check}=CherryCloud;
let who=null,club=null,mine=[],editing=null,images=[],busy=false;
let recovering=sessionStorage.getItem('cherry-password-recovery')==='1';
function showRecovery(){
  for(const id of ['auth-panel','profile-panel','owner-panel','record-panel','mine-panel','forgot-wrap'])$(id).hidden=true;
  $('recovery-panel').hidden=false;
  status('이메일 인증이 확인됐어요. 새 비밀번호를 직접 설정해주세요.');
}
client.auth.onAuthStateChange(event=>{
  if(event==='PASSWORD_RECOVERY'){recovering=true;sessionStorage.setItem('cherry-password-recovery','1');showRecovery();}
});
function status(s){$('status').textContent=s;}
function lock(on){busy=on;document.querySelectorAll('button,input,select,textarea').forEach(el=>el.disabled=on);}
async function action(fn){if(busy)return;lock(true);try{await fn();}catch(e){status(e.message);}finally{lock(false);}}
function reset(){editing=null;images=[];$('record-form').reset();$('record-date').value=CherryData.today();$('record-tag-set').value='#체리소다클럽 #체소클';$('record-tags').value='';$('form-title').textContent='새 기록';$('delete-record').hidden=true;renderPhotos();}
function renderPhotos(){$('photos').innerHTML=images.map((im,i)=>`<div class="photo"><img src="${esc(safeImage(im))}" alt="사진 ${i+1}"><button type="button" data-photo="${i}">사진 제거</button></div>`).join('');}
async function refresh(){
  if(recovering){const {data,error}=await client.auth.getSession();if(error)throw error;if(data.session){showRecovery();return;}recovering=false;sessionStorage.removeItem('cherry-password-recovery');}
  $('recovery-panel').hidden=true;
  club=(await CherryCloud.load()).data;who=await CherryCloud.identity();
  if(recovering){showRecovery();return;}
  $('forgot-wrap').hidden=!!who;
  $('auth-panel').hidden=!!who;$('profile-panel').hidden=!who;
  $('owner-panel').hidden=!who?.admin;$('record-panel').hidden=!who?.memberId;$('mine-panel').hidden=!who?.memberId;
  if(!who){status('로그인하면 내 기록을 올릴 수 있어요.');return;}
  const member=club.members.find(m=>m.id===who.memberId);
  $('greeting').textContent=member?`${member.symbol||'🍒'} ${member.name}님`:'멤버 연결을 기다리고 있어요';
  $('role-badge').textContent=who.admin?'🍒 방장':who.memberId?'☁️ 멤버':'연결 대기';
  $('role-badge').classList.toggle('owner',!!who.admin);
  $('role-description').textContent=who.admin?'방장 관리실에서 전체 기록·멤버·주제·이벤트를 관리할 수 있어요. 아래에서는 내 작품을 올릴 수 있어요.':who.memberId?'내 작품을 올리고 수정·삭제할 수 있어요. 저장한 작품은 전체 기록·멤버별 작품·연결한 커다에 함께 표시됩니다.':'이메일 인증 후 내 닉네임 연결을 요청해주세요. 방장이 확인하면 작품을 올릴 수 있어요.';
  $('account-note').textContent=who.user.email||'';$('admin-link').hidden=!who.admin;$('request-form').hidden=!!who.memberId;
  $('claim-member').innerHTML=club.members.map(m=>`<option value="${esc(m.id)}">${esc(m.name)}</option>`).join('');
  if(!who.memberId){const pending=check(await client.from('cherry_access_requests').select('member_id').eq('user_id',who.user.id).is('dismissed_at',null));$('cancel-request').hidden=!pending.length;$('request-state').textContent=pending.length?'연결 요청을 보냈어요. 방장 확인을 기다리고 있습니다.':'';if(pending.length)$('claim-member').value=pending[0].member_id;}
  $('record-theme').innerHTML='<option value="">연결 안 함</option>'+club.themes.map(t=>`<option value="${esc(t.id)}">${esc(t.round)} · ${esc(t.title)}</option>`).join('');
  if(who.memberId){mine=club.records.filter(r=>r._cloud&&r.memberId===who.memberId);$('mine').innerHTML=mine.length?mine.map(r=>`<article class="record">${r.images[0]?`<img src="${esc(safeImage(r.images[0]))}" alt="${esc(r.title)}">`:''}<h3>${esc(r.title)}</h3><p class="muted">${esc(r.date)}</p><button data-edit="${esc(r.id)}">수정하기</button></article>`).join(''):'<p class="muted">아직 직접 올린 기록이 없어요.</p>';}
  if(who.admin){const trash=check(await client.rpc('cherry_trash_list'));$('trash').innerHTML=trash.length?trash.map(r=>`<div class="request"><b>${esc(r.title)}</b><p class="muted">${esc(r.date)}</p><button data-restore="${esc(r.id)}">복원하기</button></div>`).join(''):'<p class="muted">삭제한 기록이 없습니다.</p>';const requests=check(await client.rpc('cherry_request_list'));$('requests').innerHTML=requests.length?requests.map(r=>`<div class="request"><b>${esc(club.members.find(m=>m.id===r.memberId)?.name||r.memberId)}</b><p class="muted">${esc(r.email)} · ${r.verified?'이메일 인증 완료':'이메일 미인증'} ${r.registered?'· 연결 완료':''}</p>${r.registered?'':`<div class="actions"><select aria-label="연결할 닉네임" data-request-member="${esc(r.userId)}">${club.members.map(m=>`<option value="${esc(m.id)}" ${m.id===r.memberId?'selected':''}>${esc(m.name)}</option>`).join('')}</select><button data-register="${esc(r.userId)}" ${r.verified?'':'disabled'}>멤버 연결</button></div>`}<p><button type="button" data-dismiss="${esc(r.userId)}">${r.registered?'요청 기록 삭제':'거절·삭제'}</button></p></div>`).join(''):'<p class="muted">새로운 연결 요청이 없습니다.</p>';}
  status(who.memberId?'로그인됐어요. 저장한 기록은 바로 공개됩니다.':'내 닉네임을 선택해 멤버 연결을 요청해주세요.');
}
$('auth-form').onsubmit=e=>{e.preventDefault();action(async()=>{check(await client.auth.signInWithPassword({email:$('email').value.trim(),password:$('password').value}));$('password').value='';await refresh();reset();});};
$('forgot-password').onclick=()=>action(async()=>{
  const email=$('email');if(!email.reportValidity())return;
  check(await client.auth.resetPasswordForEmail(email.value.trim(),{redirectTo:new URL('account.html',location.href).href}));
  status('재설정 요청을 접수했어요. 가입된 이메일이라면 메일이 발송됩니다. 받은편지함과 스팸함을 확인해주세요.');
});
$('recovery-form').onsubmit=e=>{e.preventDefault();action(async()=>{
  if(!recovering)throw Error('재설정 메일의 링크를 먼저 열어주세요.');
  if(!$('recovery-form').reportValidity())return;
  if($('new-password').value!==$('confirm-password').value)throw Error('새 비밀번호가 서로 다릅니다.');
  check(await client.auth.updateUser({password:$('new-password').value}));
  $('recovery-form').reset();recovering=false;sessionStorage.removeItem('cherry-password-recovery');
  check(await client.auth.signOut({scope:'local'}));await refresh();
  status('비밀번호를 변경했어요. 새 비밀번호로 로그인해주세요.');
});};
$('signup').onclick=()=>action(async()=>{if(!$('auth-form').reportValidity())return;const r=await client.auth.signUp({email:$('email').value.trim(),password:$('password').value,options:{emailRedirectTo:new URL('account.html',location.href).href}});if(r.error){if(/not authorized|email.*sending|rate limit/i.test(r.error.message))throw Error('가입 인증 메일 발송 설정이 아직 준비되지 않았습니다. 방장에게 알려주세요.');throw Error(r.error.message);}$('password').value='';status('가입 확인 메일을 보냈어요. 이메일의 링크를 누른 뒤 로그인해주세요.');});
$('logout').onclick=()=>action(async()=>{check(await client.auth.signOut());who=null;editing=null;images=[];await refresh();});
$('request-form').onsubmit=e=>{e.preventDefault();action(async()=>{check(await client.from('cherry_access_requests').upsert({user_id:who.user.id,member_id:$('claim-member').value,dismissed_at:null}));await refresh();status('멤버 연결을 요청했어요. 방장이 확인한 뒤 사용할 수 있습니다.');});};
$('requests').onclick=e=>{const remove=e.target.closest('[data-dismiss]');if(remove){if(!confirm('이 연결 요청을 목록에서 삭제할까요? 이미 승인된 멤버 권한과 계정은 유지됩니다.'))return;action(async()=>{if(!who?.admin)throw Error('방장 권한이 필요합니다.');const rows=check(await client.from('cherry_access_requests').update({dismissed_at:new Date().toISOString()}).eq('user_id',remove.dataset.dismiss).select('user_id'));if(!rows.length)throw Error('요청을 처리할 수 없습니다. 새로고침해주세요.');await refresh();status('요청을 목록에서 삭제했어요. 멤버 권한은 변경하지 않았습니다.');});return;}const b=e.target.closest('[data-register]');if(!b)return;const user=b.dataset.register,member=document.querySelector(`[data-request-member="${CSS.escape(user)}"]`).value;if(!confirm('이 이메일이 실제 멤버 본인의 계정인지 확인하셨나요? 연결하면 해당 멤버의 기록을 작성·수정할 수 있습니다.'))return;action(async()=>{check(await client.rpc('cherry_register_member',{p_user:user,p_member:member}));await refresh();status('멤버 계정을 연결했어요.');});};
$('cancel-request').onclick=()=>{if(!confirm('내 멤버 연결 요청을 취소할까요?'))return;action(async()=>{const rows=check(await client.from('cherry_access_requests').update({dismissed_at:new Date().toISOString()}).eq('user_id',who.user.id).select('user_id'));if(!rows.length)throw Error('취소할 요청이 없습니다.');await refresh();status('연결 요청을 취소했어요. 필요하면 다시 신청할 수 있습니다.');});};
$('trash').onclick=e=>{const b=e.target.closest('[data-restore]');if(b)action(async()=>{check(await client.rpc('cherry_restore_record',{p_id:b.dataset.restore}));await refresh();status('기록을 복원했어요.');});};
$('record-files').onchange=e=>action(async()=>{const files=[...e.target.files];if(images.length+files.length>6)throw Error('사진은 최대 6장까지 올릴 수 있어요.');for(const file of files){status('사진을 준비하고 있어요…');if(!['image/png','image/jpeg','image/webp'].includes(file.type)||file.size>10485760)throw Error('PNG·JPG·WEBP 사진을 10MB 이하로 선택해주세요.');const bitmap=await createImageBitmap(file);const scale=Math.min(1,1800/Math.max(bitmap.width,bitmap.height)),canvas=document.createElement('canvas');canvas.width=Math.round(bitmap.width*scale);canvas.height=Math.round(bitmap.height*scale);canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);bitmap.close();images.push(canvas.toDataURL('image/webp',.85));renderPhotos();}e.target.value='';status('사진이 준비됐어요. 바로 공개 저장을 눌러 기록을 완성해주세요.');});
$('photos').onclick=e=>{const b=e.target.closest('[data-photo]');if(b&&!busy){images.splice(Number(b.dataset.photo),1);renderPhotos();}};
$('new-record').onclick=()=>{if((images.length||$('record-title').value)&&!confirm('작성 중인 내용을 비우고 새 기록을 시작할까요?'))return;reset();};
$('mine').onclick=e=>{const b=e.target.closest('[data-edit]');if(!b||busy)return;const r=mine.find(r=>r.id===b.dataset.edit);editing=r.id;images=[...r.images];for(const [id,key] of [['record-title','title'],['record-date','date'],['record-kind','kind'],['record-theme','themeId'],['record-description','description'],['record-music','musicUrl']])$(id).value=r[key]||'';const tagSets=['#체리소다동아리 #체소동','#체리소다클럽 #체소클'];const tags=r.tags||[];const selected=tagSets.find(set=>set.split(' ').every(t=>tags.includes(t)))||'';$('record-tag-set').value=selected;$('record-tags').value=tags.filter(t=>!selected.split(' ').includes(t)).join(' ');$('form-title').textContent='기록 수정';$('delete-record').hidden=false;renderPhotos();$('record-panel').scrollIntoView({behavior:'smooth'});};
$('record-form').onsubmit=e=>{e.preventDefault();action(async()=>{const r={title:$('record-title').value.trim(),memberId:who.memberId,date:$('record-date').value,kind:$('record-kind').value,themeId:$('record-theme').value,description:$('record-description').value.trim(),musicUrl:$('record-music').value.trim(),images,tags:[...new Set(($('record-tag-set').value+' '+$('record-tags').value).trim().split(/\s+/).filter(Boolean))]};if(r.musicUrl){const url=CherryData.safeMusicLink(r.musicUrl);if(!url)throw Error('브금은 유튜브 또는 스포티파이의 https:// 링크를 입력해주세요.');r.musicUrl=url;}if(!r.title||!r.date)throw Error('제목과 날짜를 확인해주세요.');if(r.tags.length>15)throw Error('해시태그는 최대 15개입니다.');for(let i=0;i<r.images.length;i++){if(r.images[i].startsWith('data:')){status('사진 업로드 중…');const blob=await(await fetch(r.images[i])).blob();r.images[i]=await CherryCloud.upload(new File([blob],'photo.webp',{type:blob.type}));}}if(editing){const rows=check(await client.from('cherry_records').update(CherryCloud.toRow(r)).eq('id',editing).select('id'));if(!rows.length)throw Error('이 기록을 수정할 수 없습니다. 최신 내용을 확인해주세요.');}else check(await client.from('cherry_records').insert({...CherryCloud.toRow(r),user_id:who.user.id}));if(window.BroadcastChannel){const channel=new BroadcastChannel('cherry-updated');channel.postMessage('refresh');channel.close();}await refresh();reset();status('저장했어요! 공개 사이트에서 바로 볼 수 있습니다.');});};
$('delete-record').onclick=()=>{if(!editing||!confirm('이 기록을 공개 사이트에서 삭제할까요?'))return;action(async()=>{check(await client.from('cherry_records').update({deleted_at:new Date().toISOString()}).eq('id',editing));await refresh();reset();status('기록을 공개 목록에서 삭제했어요.');});};
reset();refresh().catch(e=>status(e.message));
