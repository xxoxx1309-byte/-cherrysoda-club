'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const elements=new Map(),calls=[];
function element(id){if(!elements.has(id))elements.set(id,{hidden:false,disabled:false,value:'',textContent:'',innerHTML:'',checked:false,files:[],dataset:{},classList:{toggle(){}},setAttribute(){},removeAttribute(){},querySelectorAll(){return[];}});return elements.get(id);}
let fixture={version:2,phase:'collecting',mine:{id:'entry-one',round:1,mission:'test mission',title:'work',image:'',submitted:true},myEntries:[{id:'entry-one',round:1,title:'work',submitted:true}],myCompleted:1,canNext:true,remaining:2,joined:1,submitted:1,missionCount:3,adminMissions:[],gallery:[],guesses:[],scores:[],missionScores:[],adminEntries:[],missions:[]};
const context={document:{getElementById:element,querySelectorAll:()=>[],addEventListener(){}},window:{addEventListener(){}},CherryData:{esc:s=>String(s)},CherryCloud:{identity:async()=>({memberId:'tester',admin:false}),content:async()=>({document:{members:[{id:'tester',name:'test member'}]}}),client:{rpc:async(name,args)=>{calls.push(args);return{data:fixture,error:null};}}},confirm:()=>true,console};
vm.createContext(context);vm.runInContext(fs.readFileSync(__dirname+'/halloween.js','utf8'),context);
const tick=()=>new Promise(resolve=>setImmediate(resolve));
(async()=>{
 await tick();await tick();
 assert.equal(element('next-mission').hidden,false);assert.equal(element('next-mission').disabled,false);
 assert.match(element('my-progress').textContent,/제출 완료 1개/);
 assert.match(element('my-entry').innerHTML,/entry-one/);
 await element('next-mission').onclick();
 await tick();await tick();
 assert.equal(calls.at(-1).p_action,'next_mission');
 fixture={...fixture,mine:{...fixture.mine,id:'entry-two',round:2,submitted:false},myEntries:[...fixture.myEntries,{id:'entry-two',round:2,title:'',submitted:false}],canNext:false};
 await element('refresh').onclick();await tick();await tick();
 assert.equal(element('next-mission').hidden,true);assert.match(element('my-entry').innerHTML,/entry-one/);assert.match(element('my-entry').innerHTML,/entry-two/);
 fixture={...fixture,phase:'revealed',missionScores:[{member:'tester',completed:2}],mine:{...fixture.mine,submitted:true},myCompleted:2};
 await element('refresh').onclick();await tick();await tick();
 assert.equal(element('mission-score-panel').hidden,false);assert.match(element('mission-scores').innerHTML,/2개/);assert.equal(element('next-mission').hidden,true);
 console.log('PASS: extra mission request, preserved entry selector, pending mission lock, completion ranking, phase closure');
})().catch(error=>{console.error(error);process.exitCode=1;});
