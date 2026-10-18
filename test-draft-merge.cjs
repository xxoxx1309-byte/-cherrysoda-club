const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ctx={window:{}};vm.createContext(ctx);vm.runInContext(fs.readFileSync(__dirname+'/draft-merge.js','utf8'),ctx);const M=ctx.window.CherryDraftMerge;
const clone=x=>JSON.parse(JSON.stringify(x));const base={version:1,settings:{intro:'old',headline:'title'},members:[],themes:[{id:'a',title:'old',description:'old'}],events:[],records:[]};
let local=clone(base),remote=clone(base);local.themes[0].title='draft';remote.records.push({id:'upload',_cloud:true,title:'member upload'});
let p=M.plan(local,remote,base);assert.equal(p.conflicts.length,0);assert.equal(p.merged.records.length,1);assert.equal(p.merged.themes[0].title,'draft');
remote.themes[0].description='latest';p=M.plan(local,remote,base);assert.equal(p.conflicts.length,0);assert.equal(p.merged.themes[0].description,'latest');
remote.themes[0].title='other';p=M.plan(local,remote,base);assert.equal(p.conflicts.length,1);assert.throws(()=>M.resolve(p,[]));assert.equal(M.resolve(p,['local']).themes[0].title,'draft');assert.equal(M.resolve(p,['remote']).themes[0].title,'other');
// Old drafts cannot prove their changes; decisions must be explicit, uploads survive.
p=M.plan(local,remote,null);assert.equal(p.conflicts.length,1);assert.equal(p.merged.records.length,1);assert.equal(M.resolve(p,['local']).records[0].title,'member upload');
local=clone(base);remote=clone(base);local.themes=[];remote.themes[0].title='new';p=M.plan(local,remote,base);assert.equal(p.conflicts.length,1);assert.equal(M.resolve(p,['local']).themes.length,0);assert.equal(M.resolve(p,['remote']).themes.length,1);
local=clone(base);remote=clone(base);local.settings.intro='draft';remote.settings.headline='latest';p=M.plan(local,remote,base);assert.equal(p.conflicts.length,0);assert.equal(p.merged.settings.intro,'draft');assert.equal(p.merged.settings.headline,'latest');
local=clone(base);remote=clone(base);remote.themes=[];p=M.plan(local,remote,base);assert.equal(p.conflicts.length,0);assert.equal(p.merged.themes.length,0);
assert.equal(base.themes[0].title,'old');assert.equal(M.same({b:1,a:2},{a:2,b:1}),true);
console.log('PASS: member uploads preserved; independent fields merged; conflicts require explicit choices; legacy drafts reviewed; deletions respected; inputs immutable');
