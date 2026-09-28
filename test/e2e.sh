#!/usr/bin/env bash
# SideHustle AI e2e tests — 8 flows exercising real logic in Node. Exit non-zero on failure.
set -u
cd "$(dirname "$0")/.."
pass=0; fail=0
flow() { # $1 = description, $2 = node script
  if node -e "$2" >/dev/null 2>&1; then echo "PASS: $1"; pass=$((pass+1));
  else echo "FAIL: $1"; fail=$((fail+1)); fi
}

flow "writer with 6h/wk ranks freelance-writing near top" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const r=L.scoreHustles({skills:['writing'],interests:['creative'],hoursPerWeek:6,maxCost:2},B);
  const top3=r.slice(0,3).map(x=>x.hustle.id);
  if(!top3.includes('freelance-writing')) throw new Error('top3='+top3);
  if(r[0].score<40) throw new Error('top score too low: '+r[0].score);
"

flow "maxCost filter excludes paid-startup ideas" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const r=L.scoreHustles({skills:[],interests:[],hoursPerWeek:10,maxCost:0},B);
  if(r.some(x=>x.hustle.cost>0)) throw new Error('costly idea leaked through');
  if(!r.length) throw new Error('empty result');
"

flow "scores sorted desc, 0-100 range" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const r=L.scoreHustles({skills:['coding'],interests:['tech'],hoursPerWeek:8,maxCost:3},B);
  for(let i=1;i<r.length;i++) if(r[i].score>r[i-1].score) throw new Error('not sorted');
  if(r.some(x=>x.score<0||x.score>100)) throw new Error('out of range');
"

flow "time fit: 2h/wk penalizes 8h ideas" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const r=L.scoreHustles({skills:['handyman'],interests:['home'],hoursPerWeek:2,maxCost:3},B);
  const lawn=r.find(x=>x.hustle.id==='lawn-care');
  if(lawn.breakdown.timeFit>=1) throw new Error('timeFit should be <1, got '+lawn.breakdown.timeFit);
"

flow "launch plan: 4 weeks, tasks from steps, capped at 5" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const h=B.HUSTLES.find(x=>x.id==='tutoring');
  const p=L.launchPlan(h);
  if(p.length!==4) throw new Error('weeks='+p.length);
  if(p[0].title!=='Validate'||p[3].title!=='Grow') throw new Error('phase titles');
  for(const w of p) if(!w.tasks.length||w.tasks.length>5) throw new Error('w'+w.week+' tasks='+w.tasks.length);
"

flow "projectedMonthly scales with hours" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const h=B.HUSTLES.find(x=>x.id==='web-freelance');
  const a=L.projectedMonthly(h,10), b=L.projectedMonthly(h,5);
  if(a.low!==1000||a.high!==5000) throw new Error('10h='+JSON.stringify(a));
  if(b.low!==500||b.high!==2500) throw new Error('5h='+JSON.stringify(b));
"

flow "incomeTotals: goal progress math" "
  const L=require('./js/logic.js');
  const t=L.incomeTotals([{amount:200},{amount:150.5}],500);
  if(t.total!==350.5) throw new Error('total='+t.total);
  if(t.pct!==70) throw new Error('pct='+t.pct);
  if(t.remaining!==149.5) throw new Error('remaining='+t.remaining);
  const over=L.incomeTotals([{amount:600}],500);
  if(over.pct!==100||over.remaining!==0) throw new Error('cap');
"

flow "validateProfile catches bad hours" "
  const L=require('./js/logic.js');
  if(!L.validateProfile({hoursPerWeek:0}).length) throw new Error('zero hours ok?');
  if(!L.validateProfile({hoursPerWeek:100}).length) throw new Error('100h ok?');
  if(L.validateProfile({hoursPerWeek:6}).length) throw new Error('6h flagged');
"

echo "--- e2e: $pass passed, $fail failed ---"
exit $((fail>0))
