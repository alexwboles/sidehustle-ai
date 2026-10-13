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

flow "incomeCSV full log export" "
  const L=require('./js/logic.js');
  const csv=L.incomeCSV([
    {date:'2026-09-28',amount:320,note:'First client'},
    {date:'2026-10-01',amount:150.75,note:''},
    {date:'2026-10-05',amount:89.99,note:'Tips, \"cash\"'}
  ]);
  const lines=csv.split('\n');
  if(lines.length!==4) throw new Error('lines='+lines.length);
  if(!lines[2].includes('150.75')) throw new Error('row2 missing amount');
  if(lines[3]!=='\"2026-10-05\",\"89.99\",\"Tips, \"\"cash\"\"\"') throw new Error('escaping: '+lines[3]);
"

flow "monthly totals tell the income story" "
  const L=require('./js/logic.js');
  const ms=L.monthlyTotals([
    {date:'2026-08-02',amount:120},{date:'2026-09-10',amount:300},
    {date:'2026-09-20',amount:200},{date:'2026-10-01',amount:450}]);
  if(ms.length!==3||ms[0].month!=='2026-10') throw new Error('order');
  if(ms[1].total!==500||ms[1].count!==2) throw new Error('Sep math');
  const t=L.incomeTotals(ms.flatMap(m=>[]),0);
  if(t.total!==0) throw new Error('sanity');
"

flow "sortRanked keeps ties stable by secondary key" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const r=L.scoreHustles({skills:['coding'],interests:['tech'],hoursPerWeek:8,maxCost:3},B);
  const byCost=L.sortRanked(r,'cost');
  // within the same cost tier, higher score comes first (documented tiebreak)
  for(let i=1;i<byCost.length;i++){
    const a=byCost[i-1],b=byCost[i];
    if(b.hustle.cost===a.hustle.cost&&b.score>a.score) throw new Error('tiebreak broken');
  }
"

flow "run-rate on a real month: on track then falls behind" "
  const L=require('./js/logic.js');
  const es=[];
  for(let d=1;d<=10;d++) es.push({date:'2026-10-'+String(d).padStart(2,'0'),amount:50});
  const early=L.incomeRunRate(es.slice(0,5),1200,'2026-10-05');
  if(early.onTrack!==true) throw new Error('day 5 should be on track');
  // same entries, but now it's day 20 with no new income -> behind
  const late=L.incomeRunRate(es,1200,'2026-10-20');
  if(late.monthTotal!==500||late.onTrack!==false) throw new Error('day 20 should be behind: '+JSON.stringify(late));
  if(late.needed!==1200-late.projected) throw new Error('needed math');
"

flow "end-to-end: quiz -> sort -> pin ids are stable across sorts" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const r=L.scoreHustles({skills:['design'],interests:['creative'],hoursPerWeek:6,maxCost:2},B);
  const byScore=L.sortRanked(r,'score').slice(0,8).map(x=>x.hustle.id);
  const byEarn=L.sortRanked(r,'earning').slice(0,8).map(x=>x.hustle.id);
  const pin=byEarn[0];
  if(!byScore.includes(pin)) throw new Error('pin id not in top-8 of another sort');
  if(new Set(byScore).size!==8) throw new Error('dupes');
"

flow "end-to-end: expenses + tagged income -> net profit, by-hustle, analytics" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const income=[
    {date:'2026-10-08',amount:150,note:'client A',hustleId:'freelance-writing'},
    {date:'2026-10-09',amount:200,note:'client B',hustleId:'freelance-writing'},
    {date:'2026-10-10',amount:120,note:'weekend shift',hustleId:'pet-sitting'}
  ];
  const expenses=[{date:'2026-10-08',amount:40,note:'hosting'},{date:'2026-10-09',amount:60,note:'supplies'}];
  const np=L.netProfit(income,expenses,500);
  if(np.income!==470||np.expenses!==100||np.net!==370) throw new Error('net math: '+JSON.stringify(np));
  if(np.remaining!==130) throw new Error('remaining: '+np.remaining);
  const byH=L.earningsByHustle(income,B);
  if(byH.length!==2) throw new Error('two hustles tagged: '+byH.length);
  if(byH[0].hustleId!=='freelance-writing'||byH[0].total!==350) throw new Error('top hustle: '+JSON.stringify(byH[0]));
  const a=L.incomeAnalytics(income,'2026-10-10');
  if(a.streak!==3) throw new Error('streak should be 3, got '+a.streak);
  if(a.bestDay.date!=='2026-10-09'||a.bestDay.total!==200) throw new Error('best day: '+JSON.stringify(a.bestDay));
  if(a.avgPerDay!==Math.round(470/3*100)/100) throw new Error('avg: '+a.avgPerDay);
  const exp=L.expenseTotals(expenses);
  if(exp.total!==100||exp.count!==2) throw new Error('expenseTotals: '+JSON.stringify(exp));
"

flow "sweep-2: net profit per hustle, tax reserve, plan pacing" "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const income=[
    {date:'2026-10-01',amount:400,hustleId:'freelance-writing'},
    {date:'2026-10-05',amount:150,hustleId:'freelance-writing'},
    {date:'2026-10-06',amount:300,hustleId:'mobile-detailing'}];
  const expenses=[
    {date:'2026-10-02',amount:60,hustleId:'freelance-writing',note:'software'},
    {date:'2026-10-07',amount:90,hustleId:'mobile-detailing',note:'supplies'},
    {date:'2026-10-08',amount:25,note:'untagged'}];
  const pb=L.profitByHustle(income,expenses,B);
  if(pb.length!==2) throw new Error('two tagged hustles');
  const fw=pb.find(r=>r.hustleId==='freelance-writing');
  const md=pb.find(r=>r.hustleId==='mobile-detailing');
  if(!fw||fw.net!==490||fw.income!==550||fw.expenses!==60) throw new Error('writing: '+JSON.stringify(fw));
  if(!md||md.net!==210) throw new Error('detailing: '+JSON.stringify(md));
  if(pb[0].hustleId!=='freelance-writing') throw new Error('best net first');
  // tax reserve on the combined net
  const net=L.netProfit(income,expenses,2000).net;
  if(net!==675) throw new Error('net: '+net);
  const tr=L.taxReserve(net,25);
  if(tr.amount!==168.75||tr.afterTax!==506.25) throw new Error('tax: '+JSON.stringify(tr));
  // launch plan pacing for a real bank hustle
  const hustle=B.HUSTLES.find(h=>h.id==='freelance-writing');
  const done={'1-0':true,'1-1':true,'3-0':true};
  const p=L.planProgress(hustle,done);
  if(p.done!==3||p.total<=0) throw new Error('plan totals: '+p.done+'/'+p.total);
  if(p.weeks[0].done!==2||p.weeks[2].done!==1||p.weeks[1].done!==0) throw new Error('per-week: '+JSON.stringify(p.weeks.map(w=>w.done)));
  // UI wiring for the new surfaces
  const fs=require('fs');
  const html=fs.readFileSync('index.html','utf8');
  const app=fs.readFileSync('js/app.js','utf8');
  if(html.indexOf('expHustle')<0) throw new Error('expHustle select missing');
  if(html.indexOf('taxRate')<0||html.indexOf('taxLine')<0) throw new Error('tax UI missing');
  if(html.indexOf('planFill')<0) throw new Error('planFill bar missing');
  if(app.indexOf('wbar')<0) throw new Error('week bars missing');
"

echo "--- e2e: $pass passed, $fail failed ---"
exit $((fail>0))
