'use strict';
(() => {
 const $=id=>document.getElementById(id),esc=CherryData.esc,client=CherryCloud.client;
 let who=null,state=null,club=null,image='',busy=false,dirty=false;
 const names=id=>club?.members.find(m=>m.id===id)?.name||'탈퇴 멤버';
 const photo=src=>/^data:image\/(webp|jpeg|png);base64,[A-Za-z0-9+/=]+$/.test(src||'')?src:'';
 const status=message=>{$('status').textContent=message;};
 function lock(on){busy=on;document.querySelectorAll('button,input,select,textarea').forEach(el=>el.disabled=on);if(!on&&state)applyPhase();}
 async function action(fn){if(busy)return;lock(true);try{await fn();}catch(e){status(e.message||'처리하지 못했어요. 다시 확인해주세요.');}finally{lock(false);}}
 async function rpc(action='state',payload={}){
  const {data,error}=await client.rpc('cherry_halloween',{p_action:action,p_payload:payload});
  if(error){if(['PGRST202','42883'].includes(error.code)){const e=Error('익명 이벤트 설정이 아직 준비되지 않았어요.');e.setup=true;throw e;}throw Error(error.message);}
  return data;
 }
 function applyPhase(){
  const closed=state.phase!=='collecting';
  $('submit-form').querySelectorAll('input,button').forEach(el=>el.disabled=closed);
  $('submit').textContent=closed?'접수 마감':state.mine?.submitted?'수정한 작품 저장':'익명 작품 제출';
  $('next-phase').hidden=state.phase==='revealed';
  $('mission-form').querySelectorAll('textarea,button').forEach(el=>el.disabled=state.phase!=='collecting'||state.joined>0);
 }
 function render(){
  $('event').hidden=false;$('setup-panel').hidden=true;
  document.querySelectorAll('[data-phase]').forEach(el=>{const active=el.dataset.phase===state.phase;el.classList.toggle('current',active);if(active)el.setAttribute('aria-current','step');else el.removeAttribute('aria-current');});
  $('counts').textContent=`미션 수령 ${state.joined}명 · 작품 제출 ${state.submitted}명`;
  $('join-panel').hidden=!!state.mine||state.phase!=='collecting'||!state.missionCount;$('mission-wait').hidden=state.phase!=='collecting'||!!state.missionCount;$('mine-panel').hidden=!state.mine;
  if(state.mine){$('mission').textContent=state.mine.mission;$('mission').hidden=true;$('show-mission').textContent='미션 확인하기';
   $('title').value=state.mine.title;image=state.mine.image||'';$('photo-preview').hidden=!image;if(image)$('photo-preview').src=photo(image);else $('photo-preview').removeAttribute('src');
   $('mine-state').textContent=state.mine.submitted?'✓ 작품이 접수됐어요. 추리 시작 전까지 수정·취소할 수 있어요.':'미션을 받았어요. 작품을 완성해 제출해주세요.';
   $('withdraw').hidden=!state.mine.submitted||state.phase!=='collecting';$('anonymous-check').checked=false;$('file').value='';
  }
  dirty=false;
  const notes={collecting:'작품은 접수 마감 후 방장이 추리를 열면 한꺼번에 공개됩니다.',guessing:'사진을 눌러 크게 보고, 작가와 미션을 골라주세요. 발표 전까지 내 추리를 수정할 수 있어요.',revealed:'드디어 유령들의 정체가 밝혀졌어요! 각 작품의 작가와 비밀 미션을 확인해보세요.'};
  $('gallery-note').textContent=notes[state.phase];
  $('gallery').innerHTML=state.gallery.length?state.gallery.map(e=>{
   const guess=state.guesses.find(g=>g.entry===e.id);
   return `<article class="card work"><span class="alias">${esc(e.alias)}</span><h3>${esc(e.title)}</h3><img src="${esc(photo(e.image))}" alt="${esc(e.title)}" data-zoom="${esc(e.id)}" tabindex="0" role="button" aria-label="${esc(e.title)} 크게 보기">${e.mine?'<p class="saved">내가 제출한 작품이에요.</p>':''}${state.phase==='revealed'?`<div class="answer"><b>${esc(names(e.author))}</b><br>💌 ${esc(e.mission)}${guess?`<p class="muted">내 추리: ${esc(names(guess.author))} / ${esc(state.missions.find(m=>m.id===guess.mission)?.label||'')}<br>작가 ${guess.author===e.author?'정답 ✓':'오답'} · 미션 ${guess.mission===e.missionId?'정답 ✓':'오답'}</p>`:''}</div>`:!e.mine?`<form data-guess="${esc(e.id)}"><label for="author-${esc(e.id)}">이 작품의 주인은?</label><select name="author" id="author-${esc(e.id)}" required><option value="">멤버 선택</option>${club.members.map(m=>`<option value="${esc(m.id)}" ${guess?.author===m.id?'selected':''}>${esc(m.name)}</option>`).join('')}</select><label for="mission-${esc(e.id)}">숨겨진 미션은?</label><select name="mission" id="mission-${esc(e.id)}" required><option value="">미션 선택</option>${state.missions.map(m=>`<option value="${m.id}" ${guess?.mission===m.id?'selected':''}>${esc(m.label)}</option>`).join('')}</select><p class="actions"><button class="primary">${guess?'추리 수정 저장':'추리 저장'}</button>${guess?'<span class="saved">✓ 저장된 추리</span>':''}</p></form>`:''}</article>`;
  }).join(''):'<div class="empty">아직 공개된 유령 작품이 없어요.</div>';
  $('score-panel').hidden=state.phase!=='revealed';
  let previous=null,rank=0;
  $('scores').innerHTML=state.scores.length?'<table><thead><tr><th>순위</th><th>멤버</th><th>점수</th></tr></thead><tbody>'+state.scores.map((s,i)=>{if(previous!==s.score)rank=i+1;previous=s.score;return `<tr><td>${rank}위</td><td>${esc(names(s.member))}</td><td>${s.score}점</td></tr>`;}).join('')+'</tbody></table>':'<p class="muted">접수된 추리가 없어요.</p>';
  $('mission-list').value=(state.adminMissions||[]).join('\n');$('mission-edit-note').textContent=state.joined?'미션 배정이 시작되어 목록이 잠겼어요.':`등록된 미션 ${state.missionCount}개 · 미션을 저장하면 참여자가 수령할 수 있어요.`;
  $('owner-panel').hidden=!who.admin;$('next-phase').textContent=state.phase==='collecting'?'접수 마감 · 익명 추리 열기':'정체 공개 · 추리왕 발표';
  $('owner-entries').innerHTML='<table><thead><tr><th>멤버</th><th>배정 미션</th><th>제출</th></tr></thead><tbody>'+state.adminEntries.map(e=>`<tr><td>${esc(names(e.member))}</td><td>${esc(e.mission)}</td><td>${e.submitted?'완료':'미제출'}</td></tr>`).join('')+'</tbody></table>';
  applyPhase();
 }
 async function refresh(){
  who=await CherryCloud.identity();$('login').hidden=!!who;$('waiting').hidden=!who||!!who.memberId;$('event').hidden=true;$('setup-panel').hidden=true;
  if(!who){status('로그인하면 나만의 비밀 미션을 받을 수 있어요.');return;}
  if(!who.memberId){status('멤버 연결을 완료하면 유령의 방에 입장할 수 있어요.');return;}
  try{state=await rpc();if(!club)club=(await CherryCloud.content()).document;render();status({collecting:'비밀 접수 중 · 미션과 작품은 본인과 방장만 확인할 수 있어요.',guessing:'익명 추리 진행 중 · 내 추리는 본인만 확인할 수 있어요.',revealed:'유령들의 정체와 추리 결과가 공개됐어요.'}[state.phase]);}
  catch(e){state=null;$('event').hidden=true;if(!e.setup)throw e;$('setup-panel').hidden=false;$('owner-setup').hidden=!who.admin;status(e.message);if(who.admin){const r=await fetch('backend-halloween.sql',{cache:'no-store'});if(r.ok)$('setup-sql').value=await r.text();}}
 }
 $('login-form').onsubmit=e=>{e.preventDefault();action(async()=>{CherryCloud.check(await client.auth.signInWithPassword({email:$('email').value.trim(),password:$('password').value}));$('password').value='';await refresh();});};
 $('join').onclick=()=>action(async()=>{state=await rpc('join');render();status('미션을 받았어요! ‘미션 확인하기’를 눌러 혼자 확인해주세요.');});
 $('show-mission').onclick=()=>{const show=$('mission').hidden;$('mission').hidden=!show;$('show-mission').textContent=show?'미션 가리기':'미션 확인하기';};
 $('mission-list').oninput=()=>{dirty=true;};
 $('mission-form').onsubmit=e=>{e.preventDefault();const missions=$('mission-list').value.split(/\r?\n/).map(m=>m.trim()).filter(Boolean);action(async()=>{state=await rpc('configure_missions',{missions});render();status('직접 작성한 미션을 저장했어요. 참여자가 무작위로 한 개씩 받을 수 있습니다.');});};
 $('title').oninput=()=>{dirty=true;};$('anonymous-check').onchange=()=>{dirty=true;};
 $('file').onchange=()=>action(async()=>{
  const file=$('file').files[0];if(!file)return;
  if(!['image/png','image/jpeg','image/webp'].includes(file.type)||file.size>10485760){$('file').value='';throw Error('10MB 이하의 PNG·JPG·WEBP 사진을 선택해주세요.');}
  status('사진을 준비하고 있어요…');const bitmap=await createImageBitmap(file);
  try{const scale=Math.min(1,1600/Math.max(bitmap.width,bitmap.height)),canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale));canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);
   let encoded=canvas.toDataURL('image/webp',.85);if(encoded.length>2000000)encoded=canvas.toDataURL('image/webp',.6);if(encoded.length>2000000)throw Error('사진 용량이 커요. 크기를 줄인 뒤 다시 선택해주세요.');
   image=encoded;dirty=true;$('photo-preview').src=image;$('photo-preview').hidden=false;status('사진이 준비됐어요. 아래 제출 버튼을 눌러야 접수됩니다.');
  }finally{bitmap.close();$('file').value='';}
 });
 $('submit-form').onsubmit=e=>{e.preventDefault();action(async()=>{if(!image)throw Error('완성 사진을 선택해주세요.');state=await rpc('submit',{title:$('title').value.trim(),image});render();status('✓ 익명 작품을 접수했어요! 추리가 시작되기 전까지 수정할 수 있어요.');});};
 $('withdraw').onclick=()=>{if(!confirm('제출한 사진과 제목을 삭제할까요? 미션은 유지되며 접수 기간에 다시 제출할 수 있어요.'))return;action(async()=>{state=await rpc('withdraw');render();status('작품 제출을 취소했어요. 배정 미션은 유지됩니다.');});};
 $('gallery').onsubmit=e=>{const form=e.target.closest('[data-guess]');if(!form)return;e.preventDefault();const fields=new FormData(form);action(async()=>{const next=await rpc('guess',{entry:form.dataset.guess,author:fields.get('author'),mission:Number(fields.get('mission'))});state=next;form.querySelector('button').textContent='추리 수정 저장';let saved=form.querySelector('.saved');if(!saved){saved=document.createElement('span');saved.className='saved';form.querySelector('.actions').append(saved);}saved.textContent='✓ 저장된 추리';status('추리를 저장했어요. 정체 공개 전까지 수정할 수 있어요.');});};
 const zoom=id=>{const e=state?.gallery.find(e=>e.id===id);if(e){$('zoom-image').src=photo(e.image);$('zoom').showModal();}};
 $('gallery').onclick=e=>{const im=e.target.closest('[data-zoom]');if(im)zoom(im.dataset.zoom);};$('gallery').onkeydown=e=>{if(['Enter',' '].includes(e.key)&&e.target.dataset.zoom){e.preventDefault();zoom(e.target.dataset.zoom);}};
 $('close-zoom').onclick=()=>$('zoom').close();
 $('next-phase').onclick=()=>{const next=state.phase==='collecting'?'guessing':'revealed';if(!confirm(next==='guessing'?'접수를 마감하고 모든 제출 작품을 익명 공개할까요? 이후 작품 수정은 불가능합니다.':'모든 작가·미션과 추리 결과를 공개할까요? 이후 추리 수정은 불가능합니다.'))return;action(async()=>{state=await rpc('phase',{phase:next});render();status(next==='guessing'?'익명 갤러리와 추리를 열었어요.':'정체와 추리 결과를 공개했어요!');});};
 function reload(){if(dirty&&!confirm('저장하지 않은 작성 내용이 있어요. 새로 불러올까요?'))return;action(refresh);}
 $('refresh').onclick=reload;$('retry').onclick=()=>action(refresh);
 $('copy-setup').onclick=()=>action(async()=>{if(!$('setup-sql').value)throw Error('설정 파일을 불러오지 못했어요. 다시 확인해주세요.');try{await navigator.clipboard.writeText($('setup-sql').value);status('설정 내용을 복사했어요. SQL Editor에 붙여넣고 Run을 눌러주세요.');}catch{$('setup-sql').parentElement.open=true;$('setup-sql').select();status('설정 내용을 선택했어요. Ctrl+C로 복사해주세요.');}});
 window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
 document.addEventListener('visibilitychange',()=>{if(document.hidden){$('mission').hidden=true;$('show-mission').textContent='미션 확인하기';}});
 action(refresh);
})();
