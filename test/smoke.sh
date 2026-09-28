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

echo "--- smoke: $pass passed, $fail failed ---"
exit $((fail>0))
