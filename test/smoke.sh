#!/usr/bin/env bash
# SideHustle AI smoke tests — 12 checks. Exit non-zero on first failure.
set -u
cd "$(dirname "$0")/.."
pass=0; fail=0
check() { # $1 = description, rest = command
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS: $desc"; pass=$((pass+1));
  else echo "FAIL: $desc"; fail=$((fail+1)); fi
}

check "index.html exists" test -f index.html
check "css/style.css exists" test -f css/style.css
check "js/hustlebank.js exists" test -f js/hustlebank.js
check "js/logic.js exists" test -f js/logic.js
check "js/app.js exists" test -f js/app.js
check "hustlebank.js syntax valid" node --check js/hustlebank.js
check "logic.js syntax valid" node --check js/logic.js
check "app.js syntax valid" node --check js/app.js
check "24 hustles in bank" node -e "const b=require('./js/hustlebank.js'); if(b.HUSTLES.length!==24) throw new Error('got '+b.HUSTLES.length)"
check "every hustle has skills, pay range, steps" node -e "
  const b=require('./js/hustlebank.js');
  for (const h of b.HUSTLES) {
    if(!h.id||!h.name||!h.desc) throw new Error(h.id+' identity');
    if(!h.skills.length) throw new Error(h.id+' no skills');
    if(!Array.isArray(h.pay)||h.pay[0]>=h.pay[1]) throw new Error(h.id+' pay');
    if(h.steps.length<4) throw new Error(h.id+' steps');
    if(h.cost<0||h.cost>3||h.earning<1||h.earning>5) throw new Error(h.id+' ranges');
  }"
check "no emojis in hustle names (premium design bar)" node -e "
  const b=require('./js/hustlebank.js');
  const re=/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/u;
  for (const h of b.HUSTLES) if(re.test(h.name)) throw new Error(h.id+' has emoji')"
check "light theme: no gradients in CSS" node -e "
  const fs=require('fs'); const css=fs.readFileSync('css/style.css','utf8');
  if(/linear-gradient|radial-gradient/i.test(css)) throw new Error('gradient found')"
check "no rounded rectangles in css" node -e "
  const fs=require('fs'); const css=fs.readFileSync('css/style.css','utf8');
  const bad=[...css.matchAll(/border-radius:\s*([^;}]+)/g)].map(m=>m[1].trim())
    .filter(v=>!/^(0|50%|var\(--radius\))$/.test(v));
  if(bad.length) throw new Error(JSON.stringify(bad))"
check "index.html has new UI hooks" node -e "
  const fs=require('fs'); const h=fs.readFileSync('index.html','utf8');
  for(const id of ['sortSel','shortlist','pinTable','exportCsvBtn','runRate','monthList'])
    if(!h.includes('id=\"'+id+'\"')) throw new Error('missing '+id)"
check "index.html has improvement UI hooks" node -e "
  const fs=require('fs'); const h=fs.readFileSync('index.html','utf8');
  for(const id of ['incHustle','analyticsLine','hustleList','netLine','expAmt','expNote','logExpBtn','exportExpBtn','expenseList'])
    if(!h.includes('id=\"'+id+'\"')) throw new Error('missing '+id)"
check "expenseTotals math" node -e "
  const L=require('./js/logic.js');
  const t=L.expenseTotals([{date:'2026-10-01',amount:49.99},{date:'2026-10-02',amount:12.5},{date:'2026-10-03',amount:'bad'}]);
  if(t.total!==62.49) throw new Error('total '+t.total);
  if(t.count!==3) throw new Error('count '+t.count);
  const e=L.expenseTotals([]);
  if(e.total!==0||e.count!==0) throw new Error('empty')"
check "netProfit subtracts expenses from income vs goal" node -e "
  const L=require('./js/logic.js');
  const np=L.netProfit([{amount:500},{amount:300}],[{amount:120},{amount:30}],1000);
  if(np.income!==800) throw new Error('income '+np.income);
  if(np.expenses!==150) throw new Error('expenses '+np.expenses);
  if(np.net!==650) throw new Error('net '+np.net);
  if(np.pct!==65) throw new Error('pct '+np.pct);
  if(np.remaining!==350) throw new Error('remaining '+np.remaining);
  const neg=L.netProfit([{amount:100}],[{amount:400}],500);
  if(neg.net!==-300) throw new Error('negative net '+neg.net);
  if(neg.remaining!==800) throw new Error('remaining should count the hole '+neg.remaining)"
check "expenseCSV exports header + rows (with hustle column)" node -e "
  const L=require('./js/logic.js');
  const B=require('./js/hustlebank.js');
  const csv=L.expenseCSV([{date:'2026-10-01',amount:25,hustleId:'tutoring',note:'ads'}],B);
  const lines=csv.split('\n');
  if(lines[0]!=='\"Date\",\"Amount\",\"Hustle\",\"Note\"') throw new Error('header '+lines[0]);
  if(lines.length!==2||lines[1].indexOf('ads')<0) throw new Error('row');
  if(lines[1].indexOf('Online tutoring')<0) throw new Error('hustle name should resolve: '+lines[1])"
check "earningsByHustle ranks tagged income" node -e "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const es=[{date:'2026-10-01',amount:200,hustleId:'tutoring'},{date:'2026-10-02',amount:50,hustleId:'tutoring'},{date:'2026-10-03',amount:300,hustleId:'meal-prep'},{date:'2026-10-04',amount:75}];
  const r=L.earningsByHustle(es,B);
  if(r.length!==2) throw new Error('should skip untagged, got '+r.length);
  if(r[0].hustleId!=='meal-prep'||r[0].total!==300||r[0].count!==1) throw new Error('top: '+JSON.stringify(r[0]));
  if(r[0].name!=='Meal-prep service') throw new Error('bank name: '+r[0].name);
  if(r[1].hustleId!=='tutoring'||r[1].total!==250) throw new Error('second: '+JSON.stringify(r[1]));
  const unk=L.earningsByHustle([{amount:10,hustleId:'mystery'}],B);
  if(unk[0].name!=='mystery') throw new Error('unknown id keeps raw name')"
check "incomeAnalytics finds best day, streak, avg" node -e "
  const L=require('./js/logic.js');
  const es=[{date:'2026-10-08',amount:40},{date:'2026-10-09',amount:60},{date:'2026-10-10',amount:100},{date:'2026-10-10',amount:20},{date:'2026-10-01',amount:10}];
  const a=L.incomeAnalytics(es,'2026-10-10');
  if(a.activeDays!==4) throw new Error('activeDays '+a.activeDays);
  if(a.total!==230) throw new Error('total '+a.total);
  if(a.avgPerDay!==57.5) throw new Error('avg '+a.avgPerDay);
  if(a.bestDay.date!=='2026-10-10'||a.bestDay.total!==120) throw new Error('best: '+JSON.stringify(a.bestDay));
  if(a.streak!==3) throw new Error('streak '+a.streak);
  const gap=L.incomeAnalytics([{date:'2026-10-08',amount:40},{date:'2026-10-10',amount:40}],'2026-10-10');
  if(gap.streak!==1) throw new Error('broken streak should be 1, got '+gap.streak);
  const empty=L.incomeAnalytics([],'2026-10-10');
  if(empty.activeDays!==0||empty.bestDay!==null||empty.streak!==0) throw new Error('empty analytics')"
check "app.js wires expenses + hustle tags + analytics + sweep-2" node -e "
  const fs=require('fs'); const a=fs.readFileSync('js/app.js','utf8');
  for(const fn of ['netProfit','expenseCSV','incomeAnalytics','logExpBtn','incHustle','LS_EXP',
    'profitByHustle','taxReserve','planProgress','expHustle','taxRate','planFill'])
    if(!a.includes(fn)) throw new Error('missing '+fn)"
check "incomeCSV exports header + rows" node -e "
  const L=require('./js/logic.js');
  const csv=L.incomeCSV([{date:'2026-10-01',amount:200,note:'Logo'},{date:'2026-10-02',amount:150.5,note:''}]);
  const lines=csv.split('\n');
  if(lines.length!==3) throw new Error('want 3 lines');
  if(lines[0]!=='\"Date\",\"Amount\",\"Note\"') throw new Error('header: '+lines[0]);
  if(lines[1].indexOf('\"2026-10-01\",\"200\",\"Logo\"')!==0) throw new Error('row: '+lines[1])"
check "incomeCSV quotes notes with commas" node -e "
  const L=require('./js/logic.js');
  const csv=L.incomeCSV([{date:'2026-10-01',amount:50,note:'a, b \"c\"'}]);
  if(csv.split('\n')[1]!=='\"2026-10-01\",\"50\",\"a, b \"\"c\"\"\"') throw new Error('quoting')"
check "monthlyTotals groups by month, newest first" node -e "
  const L=require('./js/logic.js');
  const ms=L.monthlyTotals([
    {date:'2026-09-05',amount:100},{date:'2026-10-01',amount:200},
    {date:'2026-10-15',amount:50},{date:'2026-08-20',amount:25}]);
  if(ms.length!==3) throw new Error('want 3 months');
  if(ms[0].month!=='2026-10'||ms[0].total!==250||ms[0].count!==2) throw new Error(JSON.stringify(ms[0]));
  if(ms[2].month!=='2026-08') throw new Error('order: '+ms.map(m=>m.month))"
check "sortRanked re-sorts by earning, cost, hours" node -e "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const r=L.scoreHustles({skills:[],interests:[],hoursPerWeek:10,maxCost:3},B);
  const byEarn=L.sortRanked(r,'earning');
  for(let i=1;i<byEarn.length;i++) if(byEarn[i].hustle.earning>byEarn[i-1].hustle.earning) throw new Error('earning sort');
  const byCost=L.sortRanked(r,'cost');
  for(let i=1;i<byCost.length;i++) if(byCost[i].hustle.cost<byCost[i-1].hustle.cost) throw new Error('cost sort');
  const byHours=L.sortRanked(r,'hours');
  for(let i=1;i<byHours.length;i++) if(byHours[i].hustle.hours<byHours[i-1].hustle.hours) throw new Error('hours sort');
  const def=L.sortRanked(r,'score');
  for(let i=1;i<def.length;i++) if(def[i].score>def[i-1].score) throw new Error('score sort')"
check "incomeRunRate projects month-end pace" node -e "
  const L=require('./js/logic.js');
  // 7 entries of \$40 in the first week of Oct 2026 => \$280 by day 7, \$40/day pace
  const es=[]; for(let d=1;d<=7;d++) es.push({date:'2026-10-0'+d,amount:40});
  const rr=L.incomeRunRate(es,1200,'2026-10-07');
  if(rr.monthTotal!==280) throw new Error('total '+rr.monthTotal);
  if(rr.perDay!==40) throw new Error('perDay '+rr.perDay);
  if(rr.projected!==1240) throw new Error('projected '+rr.projected);
  if(rr.onTrack!==true) throw new Error('should be on track');
  const behind=L.incomeRunRate(es,1500,'2026-10-07');
  if(behind.onTrack!==false||behind.needed!==260) throw new Error('behind: '+JSON.stringify(behind));
  const nogoal=L.incomeRunRate(es,0,'2026-10-07');
  if(nogoal.onTrack!==null) throw new Error('no-goal onTrack should be null')"

check "profitByHustle nets income minus expenses per hustle" node -e "
  const L=require('./js/logic.js'); const B=require('./js/hustlebank.js');
  const inc=[{amount:500,hustleId:'tutoring'},{amount:300,hustleId:'meal-prep'},{amount:50}];
  const exp=[{amount:120,hustleId:'tutoring'},{amount:40,hustleId:'meal-prep'},{amount:10}];
  const pb=L.profitByHustle(inc,exp,B);
  if(pb.length!==2) throw new Error('two hustles: '+JSON.stringify(pb));
  if(pb[0].hustleId!=='tutoring'||pb[0].net!==380||pb[0].income!==500||pb[0].expenses!==120) throw new Error('tutoring: '+JSON.stringify(pb[0]));
  if(pb[1].net!==260) throw new Error('meal-prep: '+JSON.stringify(pb[1]));
  const unk=L.profitByHustle([{amount:10,hustleId:'zzz'}],[],B);
  if(unk[0].name!=='zzz'||unk[0].net!==10) throw new Error('unknown id keeps raw name')"
check "taxReserve computes set-aside and spendable remainder" node -e "
  const L=require('./js/logic.js');
  const t=L.taxReserve(380,25);
  if(t.amount!==95||t.afterTax!==285||t.rate!==25) throw new Error('tax: '+JSON.stringify(t));
  if(L.taxReserve(-50,25).amount!==0) throw new Error('negative net -> 0');
  if(L.taxReserve(100,150).rate!==100) throw new Error('rate clamps to 100');
  if(L.taxReserve(100,0).amount!==0) throw new Error('zero rate')"
check "planProgress tracks per-week completion" node -e "
  const L=require('./js/logic.js');
  const hustle={steps:['a','b','c']};
  const p=L.planProgress(hustle,{'1-0':true,'2-1':true,'2-0':false});
  if(p.weeks.length!==4) throw new Error('4 weeks');
  if(p.weeks[0].done!==1||p.weeks[1].done!==1||p.weeks[2].done!==0) throw new Error('per-week: '+JSON.stringify(p.weeks.map(w=>w.done)));
  if(p.done!==2||p.total!==7) throw new Error('totals: '+p.done+'/'+p.total);
  if(p.weeks[0].pct!==50) throw new Error('week pct');
  const e=L.planProgress(hustle,{});
  if(e.done!==0||e.pct!==0) throw new Error('empty')"

echo "--- smoke: $pass passed, $fail failed ---"
exit $((fail>0))
