const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/admin.js','utf8');
const fn=source.slice(source.indexOf('async function publishChanges(){'),source.indexOf("$('publish').onclick=publishChanges;"));
async function run(overrides={}){
 const state={busy:false,uploads:0,dirtyForm:true,dirtyDraft:false,autosaveTimer:null,revision:'7',data:{settings:{},themes:[]},assets:{photo:'kept'},working:null,baseDocument:null,section:'themes',messages:[],connected:false,saves:0,publishes:0,...overrides};
 Object.assign(state,{clearTimeout(){},clone:structuredClone,controls(){},prepareMerge(){state.mergeRequested=true;},status(m){state.messages.push(m);},saveForm(){assert.equal(state.busy,false,'form must be read before disabling fields');state.dirtyForm=false;state.dirtyDraft=true;state.saves++;return true;},confirm:()=>overrides.confirmed!==false,persist:()=>true,renderEditor(){},CherryStore:{connected:()=>state.connected,async connect(){if(overrides.authError)throw Error('방장 계정으로 로그인해주세요.');state.connected=true;},async reload(){return {revision:overrides.serverRevision||state.revision,data:state.data};},async publish(){state.publishes++;if(overrides.publishError)throw Error('revision conflict');return '8';}}});
 vm.createContext(state);vm.runInContext(fn,state);await state.publishChanges();return state;
}
(async()=>{
 let s=await run();assert.equal(s.saves,1);assert.equal(s.publishes,1);assert.equal(s.revision,'8');assert.equal(s.dirtyDraft,false);assert.equal(s.busy,false);
 s=await run({authError:true});assert.equal(s.publishes,0);assert.equal(s.dirtyDraft,true);assert.equal(s.assets.photo,'kept');assert.match(s.messages.at(-1),/초안은 유지/);
 s=await run({publishError:true});assert.equal(s.revision,'7');assert.equal(s.dirtyDraft,true);assert.equal(s.assets.photo,'kept');assert.equal(s.busy,false);
 s=await run({confirmed:false});assert.equal(s.publishes,0);assert.equal(s.dirtyDraft,true);assert.equal(s.busy,false);
 s=await run({serverRevision:'9'});assert.equal(s.mergeRequested,true);assert.equal(s.publishes,0);assert.equal(s.dirtyDraft,true);
 s=await run({busy:true});assert.equal(s.saves,0);assert.equal(s.publishes,0);
 assert.match(source,/onsubmit=e=>\{e.preventDefault\(\);publishChanges\(\);\}/);
 console.log('PASS: editor saves through publishing, auto login check, form ordering, cancellation, failed authentication/conflict retain draft and assets, duplicate clicks blocked');
})().catch(e=>{console.error(e);process.exit(1)});
