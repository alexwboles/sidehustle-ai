/* SideHustle AI — core logic: scoring, launch plans, income math.
   Pure functions; browser-safe. Node tests require this file. */
"use strict";

function overlap(a, b) {
  const set = new Set(a || []);
  return (b || []).filter(x => set.has(x)).length;
}

/**
 * Rank hustles for a user profile.
 * profile: {skills:[], interests:[], hoursPerWeek, maxCost (0-3)}
 * Returns [{hustle, score, breakdown}] sorted desc, filtered to maxCost.
 */
function scoreHustles(profile, bank) {
  const skills = profile.skills || [], interests = profile.interests || [];
  const hpw = Math.max(1, profile.hoursPerWeek || 1);
  const maxCost = profile.maxCost == null ? 3 : profile.maxCost;
  return bank.HUSTLES
    .filter(h => h.cost <= maxCost)
    .map(h => {
      const skillMatch = overlap(skills, h.skills) / Math.max(1, h.skills.length);
      const interestMatch = overlap(interests, h.interests) / Math.max(1, h.interests.length);
      const timeFit = Math.min(1, hpw / h.hours);
      const costScore = (3 - h.cost) / 3;
      const earnScore = h.earning / 5;
      const score = Math.round(100 * (0.30 * skillMatch + 0.25 * interestMatch +
        0.20 * timeFit + 0.10 * costScore + 0.15 * earnScore));
      return { hustle: h, score, breakdown: { skillMatch, interestMatch, timeFit, costScore, earnScore } };
    })
    .sort((a, b) => b.score - a.score || b.hustle.earning - a.hustle.earning);
}

/** Monthly pay range for a hustle scaled to the user's weekly hours. */
function projectedMonthly(hustle, hoursPerWeek) {
  const f = Math.max(1, hoursPerWeek || 1) / 10;
  return { low: Math.round(hustle.pay[0] * f), high: Math.round(hustle.pay[1] * f) };
}

/**
 * 30-day launch plan: 4 weekly phases built from the hustle's first steps
 * plus generic validation/scale tasks.
 */
function launchPlan(hustle) {
  const steps = hustle.steps || [];
  const weeks = [
    { week: 1, title: "Validate", tasks: [] },
    { week: 2, title: "Set up", tasks: [] },
    { week: 3, title: "Launch", tasks: [] },
    { week: 4, title: "Grow", tasks: [] }
  ];
  steps.forEach((s, i) => weeks[Math.min(3, Math.floor(i / 1))].tasks.push(s));
  weeks[0].tasks.push("Talk to 5 potential customers — would they pay?");
  weeks[1].tasks.push("Set your prices and a simple way to get paid");
  weeks[2].tasks.push("Deliver for your first 3 paying customers");
  weeks[3].tasks.push("Ask every customer for a review or referral");
  return weeks.map(w => ({ week: w.week, title: w.title, tasks: w.tasks.slice(0, 5) }));
}

/** Income tracker math: entries [{date, amount, note}]. */
function incomeTotals(entries, goal) {
  const total = (entries || []).reduce((s, e) => s + (Number(e.amount) || 0), 0);
  const g = Number(goal) || 0;
  return { total: Math.round(total * 100) / 100, goal: g, pct: g > 0 ? Math.min(100, Math.round(total / g * 100)) : 0,
    remaining: Math.max(0, Math.round((g - total) * 100) / 100), count: (entries || []).length };
}

/** Validate the quiz profile; returns error strings. */
function validateProfile(p) {
  const errs = [];
  if (!p.hoursPerWeek || p.hoursPerWeek < 1) errs.push("Tell us how many hours per week you have.");
  if (p.hoursPerWeek > 80) errs.push("Hours per week looks unrealistic — keep it under 80.");
  return errs;
}

/** CSV export of the income log: Date,Amount,Note. */
function incomeCSV(entries) {
  const q = v => '"' + String(v == null ? "" : v).replace(/"/g, '""') + '"';
  const lines = [["Date", "Amount", "Note"].map(q).join(",")];
  (entries || []).forEach(e => {
    lines.push([e.date || "", Number(e.amount) || 0, e.note || ""].map(q).join(","));
  });
  return lines.join("\n");
}

/** Group income entries by month (YYYY-MM), newest first: [{month,total,count}]. */
function monthlyTotals(entries) {
  const by = {};
  (entries || []).forEach(e => {
    const m = String(e.date || "").slice(0, 7);
    if (!/^\d{4}-\d{2}$/.test(m)) return;
    if (!by[m]) by[m] = { month: m, total: 0, count: 0 };
    by[m].total = Math.round((by[m].total + (Number(e.amount) || 0)) * 100) / 100;
    by[m].count++;
  });
  return Object.values(by).sort((a, b) => (a.month < b.month ? 1 : -1));
}

/** Re-sort a ranked hustle list: 'score' (default) | 'earning' | 'cost' | 'hours'. */
function sortRanked(ranked, by) {
  const arr = (ranked || []).slice();
  if (by === "earning") arr.sort((a, b) => b.hustle.earning - a.hustle.earning || b.score - a.score);
  else if (by === "cost") arr.sort((a, b) => a.hustle.cost - b.hustle.cost || b.score - a.score);
  else if (by === "hours") arr.sort((a, b) => a.hustle.hours - b.hustle.hours || b.score - a.score);
  else arr.sort((a, b) => b.score - a.score || b.hustle.earning - a.hustle.earning);
  return arr;
}

/** Run-rate projection for the current month: are you on pace for the goal? */
function incomeRunRate(entries, goal, refDate) {
  const ref = refDate ? new Date(refDate + "T12:00:00") : new Date();
  const y = ref.getFullYear(), m = ref.getMonth();
  const month = y + "-" + String(m + 1).padStart(2, "0");
  let monthTotal = 0;
  (entries || []).forEach(e => {
    if (String(e.date || "").slice(0, 7) === month) monthTotal += Number(e.amount) || 0;
  });
  monthTotal = Math.round(monthTotal * 100) / 100;
  const daysElapsed = Math.max(1, ref.getDate());
  const daysInMonth = new Date(y, m + 1, 0).getDate();
  const perDay = Math.round(monthTotal / daysElapsed * 100) / 100;
  const projected = Math.round(perDay * daysInMonth * 100) / 100;
  const g = Number(goal) || 0;
  return {
    month, monthTotal, daysElapsed, daysInMonth, perDay, projected, goal: g,
    onTrack: g > 0 ? projected >= g : null,
    needed: g > 0 ? Math.max(0, Math.round((g - projected) * 100) / 100) : 0
  };
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { overlap, scoreHustles, projectedMonthly, launchPlan, incomeTotals, validateProfile, incomeCSV, monthlyTotals, sortRanked, incomeRunRate };
}
