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

echo "--- smoke: $pass passed, $fail failed ---"
exit $((fail>0))
