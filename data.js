'use strict';
window.CherryData = (() => {
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const safeImage = s => typeof s === 'string' && (/^(club-(poster\.jpeg|character\.png)|assets\/[a-zA-Z0-9._-]+)$/.test(s) || /^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(s)) ? s : '';
  const safeLink = s => {try {const u = new URL(s); return u.protocol === 'https:' ? u.href : '';} catch {return '';}};
  const date = s => /^\d{4}-\d{2}-\d{2}$/.test(s || '') && !Number.isNaN(Date.parse(s)) && new Date(s).toISOString().slice(0,10) === s;
  function validate(d) {
    if (!d || d.version !== 1 || !d.settings || typeof d.settings !== 'object') throw Error('지원하지 않는 데이터 형식입니다.');
    if (d.settings.memberCount !== undefined && (!Number.isInteger(d.settings.memberCount) || d.settings.memberCount < 0)) throw Error('총 인원은 0 이상의 정수로 입력해주세요.');
    for (const key of ['headline','intro','heroImage','hashtags','eventIntro']) if (typeof d.settings[key] !== 'string') throw Error('클럽 설정을 확인해주세요.');
    for (const key of ['participationRules','clubRules']) if (!Array.isArray(d.settings[key]) || d.settings[key].some(x => typeof x !== 'string')) throw Error('규칙은 문장 목록이어야 합니다.');
    for (const key of ['members','themes','events','records']) {
      if (!Array.isArray(d[key])) throw Error('내용 목록을 확인해주세요.');
      const ids = new Set();
      for (const x of d[key]) {
        if (!x || typeof x.id !== 'string' || !/^[a-zA-Z0-9_-]+$/.test(x.id) || ids.has(x.id)) throw Error('항목 ID가 없거나 중복됩니다.');
        ids.add(x.id);
        if (typeof x[key === 'members' ? 'name' : 'title'] !== 'string' || !x[key === 'members' ? 'name' : 'title'].trim()) throw Error('제목 또는 닉네임을 입력해주세요.');
        if (key === 'themes' && (!date(x.start) || !date(x.end) || x.start > x.end)) throw Error('커다 시작일과 마감일을 확인해주세요.');
        if (key === 'events' && (!date(x.date) || !['open','ongoing','ended'].includes(x.status))) throw Error('이벤트 날짜와 상태를 확인해주세요.');
        if (key === 'records' && (!date(x.date) || !['theme','free','meetup'].includes(x.kind) || !d.members.some(m=>m.id===x.memberId))) throw Error('기록 날짜·종류·작성 멤버를 확인해주세요.');
        if (key === 'records' && x.themeId && !d.themes.some(t=>t.id===x.themeId)) throw Error('기록에 연결된 커다를 확인해주세요.');
        if (key === 'records' && (!Array.isArray(x.images) || x.images.some(im=>!safeImage(im)))) throw Error('기록 사진 형식을 확인해주세요.');
        if (x.image && !safeImage(x.image)) throw Error('이미지 파일 형식을 확인해주세요.');
      }
    }
    if (d.settings.heroImage && !safeImage(d.settings.heroImage)) throw Error('대표 이미지 형식을 확인해주세요.');
    return d;
  }
  const today = () => new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Seoul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const themeStatus = t => t.start > today() ? '예정' : t.end < today() ? '완료' : '진행 중';
  return {esc,safeImage,safeLink,validate,today,themeStatus};
})();
