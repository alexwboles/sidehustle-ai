/* SideHustle AI — DOM glue. Bank + logic loaded globally. */
(function () {
  "use strict";
  const $ = id => document.getElementById(id);
  const LS_INCOME = "sidehustle.income.v1";
  const LS_PLAN = "sidehustle.plan.v1";
  const LS_PIN = "sidehustle.pins.v1";
  const sel = { skills: new Set(), interests: new Set() };
  let lastRanked = [];
  let lastProfile = null;
  let sortBy = "score";

  function loadJSON(k, fb) { try { return JSON.parse(localStorage.getItem(k)) ?? fb; } catch { return fb; } }
  function saveJSON(k, v) { localStorage.setItem(k, JSON.stringify(v)); }
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }
  function money(n) { return "$" + Number(n).toLocaleString("en-US"); }

  function renderChips() {
    const mk = (list, set, box) => {
      $(box).innerHTML = "";
      list.forEach(s => {
        const b = document.createElement("button");
        b.type = "button"; b.className = "chip" + (set.has(s) ? " on" : "");
        b.textContent = s[0].toUpperCase() + s.slice(1);
        b.addEventListener("click", () => { set.has(s) ? set.delete(s) : set.add(s); renderChips(); });
        $(box).appendChild(b);
      });
    };
    mk(SKILLS, sel.skills, "skillChips");
    mk(INTERESTS, sel.interests, "interestChips");
  }

  function findMatches() {
    const profile = {
      skills: [...sel.skills], interests: [...sel.interests],
      hoursPerWeek: +$("hours").value, maxCost: +$("maxCost").value
    };
    const errs = validateProfile(profile);
    $("quizErrors").textContent = errs.join(" ");
    if (errs.length) return;
    lastProfile = profile;
    lastRanked = scoreHustles(profile, { SKILLS, INTERESTS, HUSTLES, COST_LABELS });
    renderRanked();
    renderShortlist();
    $("results").classList.remove("hidden");
    $("results").scrollIntoView({ behavior: "smooth", block: "start" });
  }

  // Render the top 8 matches, honoring the sort control and pin state.
  function renderRanked() {
    const pins = new Set(loadJSON(LS_PIN, []));
    const top = sortRanked(lastRanked, sortBy).slice(0, 8);
    $("rankList").innerHTML = top.map((r) => {
      const h = r.hustle, pm = projectedMonthly(h, lastProfile.hoursPerWeek);
      const pinned = pins.has(h.id);
      return "<li><h4>" + escapeHtml(h.name) + "<span class='score'>" + r.score + " match</span></h4>" +
        "<p>" + escapeHtml(h.desc) + "</p>" +
        "<p class='meta'>" + COST_LABELS[h.cost] + " · ~" + h.hours + "h/wk · " +
        "est. " + money(pm.low) + "–" + money(pm.high) + "/mo at " + lastProfile.hoursPerWeek + "h/wk</p>" +
        "<div class='row tight'>" +
        "<button class='pick' data-pick='" + h.id + "'>See 30-day plan</button>" +
        "<button class='pin" + (pinned ? " on" : "") + "' data-pin='" + h.id + "'>" +
        (pinned ? "Pinned ✓" : "Pin to compare") + "</button></div></li>";
    }).join("");
    $("rankList").querySelectorAll("[data-pick]").forEach(b =>
      b.addEventListener("click", () => {
        const h = HUSTLES.find(x => x.id === b.dataset.pick);
        if (h) showPlan(h);
      }));
    $("rankList").querySelectorAll("[data-pin]").forEach(b =>
      b.addEventListener("click", () => {
        const pinsArr = loadJSON(LS_PIN, []);
        const id = b.dataset.pin;
        const i = pinsArr.indexOf(id);
        if (i >= 0) pinsArr.splice(i, 1); else pinsArr.push(id);
        saveJSON(LS_PIN, pinsArr);
        renderRanked(); renderShortlist();
      }));
  }

  // Pinned hustles side-by-side comparison.
  function renderShortlist() {
    const box = $("shortlist");
    const pins = loadJSON(LS_PIN, []);
    if (!pins.length) { box.classList.add("hidden"); return; }
    const rows = pins.map(id => {
      const h = HUSTLES.find(x => x.id === id);
      if (!h) return null;
      const r = lastRanked.find(x => x.hustle.id === id);
      const pm = projectedMonthly(h, lastProfile ? lastProfile.hoursPerWeek : 10);
      return { h, score: r ? r.score : null, pm };
    }).filter(Boolean);
    $("pinTable").innerHTML = rows.map(({ h, score, pm }) =>
      "<tr><td><strong>" + escapeHtml(h.name) + "</strong></td>" +
      "<td>" + (score === null ? "—" : score) + "</td>" +
      "<td>" + COST_LABELS[h.cost] + "</td>" +
      "<td>~" + h.hours + "h/wk</td>" +
      "<td>" + "★".repeat(h.earning) + "</td>" +
      "<td>" + money(pm.low) + "–" + money(pm.high) + "</td>" +
      "<td><button class='del' data-unpin='" + h.id + "'>Unpin</button></td></tr>").join("");
    $("pinTable").querySelectorAll("[data-unpin]").forEach(b =>
      b.addEventListener("click", () => {
        saveJSON(LS_PIN, loadJSON(LS_PIN, []).filter(id => id !== b.dataset.unpin));
        renderRanked(); renderShortlist();
      }));
    box.classList.remove("hidden");
  }

  function showPlan(hustle) {
    const done = loadJSON(LS_PLAN + "." + hustle.id, {});
    $("planFor").textContent = "· " + hustle.name;
    $("planWeeks").innerHTML = launchPlan(hustle).map(w =>
      "<div class='week'><h4><span>Week " + w.week + "</span>" + escapeHtml(w.title) + "</h4><ul>" +
      w.tasks.map((t, i) => {
        const id = w.week + "-" + i, d = !!done[id];
        return "<li><label class='" + (d ? "done" : "") + "'><input type='checkbox' data-id='" + id + "'" +
          (d ? " checked" : "") + "><span>" + escapeHtml(t) + "</span></label></li>";
      }).join("") + "</ul></div>").join("");
    const total = launchPlan(hustle).reduce((s, w) => s + w.tasks.length, 0);
    const n = Object.values(done).filter(Boolean).length;
    $("planProgress").textContent = n + " of " + total + " tasks complete";
    $("plan").classList.remove("hidden");
    $("plan").scrollIntoView({ behavior: "smooth", block: "start" });
    $("planWeeks").querySelectorAll("input").forEach(cb =>
      cb.addEventListener("change", () => {
        const d = loadJSON(LS_PLAN + "." + hustle.id, {});
        d[cb.dataset.id] = cb.checked; saveJSON(LS_PLAN + "." + hustle.id, d);
        showPlan(hustle);
      }));
  }

  function renderIncome() {
    const entries = loadJSON(LS_INCOME, []);
    const goal = +$("goal").value || 0;
    const t = incomeTotals(entries, goal);
    $("goalFill").style.width = t.pct + "%";
    $("incomeLine").textContent = money(t.total) + " earned of " + money(t.goal) + " goal" +
      (t.remaining > 0 ? " — " + money(t.remaining) + " to go" : t.goal > 0 ? " — goal hit!" : "");
    $("incomeList").innerHTML = entries.length ? entries.map((e, i) =>
      "<li><span><strong>" + money(e.amount) + "</strong> <span class='muted'>" +
      escapeHtml(e.date) + (e.note ? " · " + escapeHtml(e.note) : "") + "</span></span>" +
      "<button class='del' data-del='" + i + "'>Remove</button></li>").join("")
      : "<li class='muted'>No income logged yet — log your first win above.</li>";
    $("incomeList").querySelectorAll("[data-del]").forEach(b =>
      b.addEventListener("click", () => {
        const a = loadJSON(LS_INCOME, []); a.splice(+b.dataset.del, 1);
        saveJSON(LS_INCOME, a); renderIncome();
      }));
    // monthly breakdown
    const months = monthlyTotals(entries);
    $("monthList").innerHTML = months.length ? months.map(m =>
      "<li><span><strong>" + money(m.total) + "</strong></span> " +
      "<span class='muted'>" + monthLabel(m.month) + " · " + m.count + " entr" +
      (m.count === 1 ? "y" : "ies") + "</span></li>").join("")
      : "<li class='muted'>Monthly totals will appear here once you log income.</li>";
    // run-rate projection for the current month
    const rr = incomeRunRate(entries, goal);
    $("runRate").textContent = rr.goal > 0
      ? money(rr.monthTotal) + " this month · " + money(rr.perDay) + "/day pace → " +
        "projected " + money(rr.projected) + " by month end — " +
        (rr.onTrack ? "on track ✓" : money(rr.needed) + " short of goal")
      : rr.monthTotal > 0
        ? money(rr.monthTotal) + " this month · " + money(rr.perDay) + "/day pace"
        : "Log income to see your pace toward the goal.";
    $("runRate").className = "runrate" + (rr.goal > 0 ? (rr.onTrack ? " on" : " off") : "");
  }

  function monthLabel(ym) {
    const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const p = String(ym).split("-");
    return names[+p[1] - 1] + " " + p[0];
  }

  function downloadCSV(filename, text) {
    const blob = new Blob([text], { type: "text/csv;charset=utf-8" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(a.href), 5000);
  }

  document.addEventListener("DOMContentLoaded", () => {
    renderChips(); renderIncome(); renderShortlist();
    $("matchBtn").addEventListener("click", findMatches);
    $("sortSel").addEventListener("change", () => { sortBy = $("sortSel").value; renderRanked(); });
    $("goal").addEventListener("input", renderIncome);
    $("exportCsvBtn").addEventListener("click", () =>
      downloadCSV("sidehustle-income.csv", incomeCSV(loadJSON(LS_INCOME, []))));
    $("logBtn").addEventListener("click", () => {
      const amt = parseFloat($("amt").value);
      if (!(amt > 0)) { $("amt").focus(); return; }
      const a = loadJSON(LS_INCOME, []);
      a.unshift({ amount: Math.round(amt * 100) / 100, note: $("note").value.trim(),
        date: new Date().toISOString().slice(0, 10) });
      saveJSON(LS_INCOME, a);
      $("amt").value = ""; $("note").value = "";
      renderIncome();
    });
    $("brainBtn").addEventListener("click", async () => {
      const key = $("apiKey").value.trim();
      if (!key) { $("aiMsg").textContent = "Paste your OpenAI API key first (optional)."; return; }
      const ctx = "Skills: " + [...sel.skills].join(", ") + ". Interests: " + [...sel.interests].join(", ") +
        ". Hours/week: " + $("hours").value + ".";
      $("aiMsg").textContent = "Brainstorming…";
      try {
        const r = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": "Bearer " + key },
          body: JSON.stringify({ model: "gpt-4o-mini", messages: [
            { role: "system", content: "Suggest 5 concrete side-hustle ideas beyond the obvious. For each: name, one-line description, startup cost, realistic monthly earning range. Keep it tight." },
            { role: "user", content: ctx }
          ]})
        });
        const j = await r.json();
        const out = j.choices && j.choices[0] && j.choices[0].message.content;
        $("aiMsg").textContent = out ? "Ideas (not saved — pick what resonates):\n\n" + out : "The API didn't return text.";
      } catch { $("aiMsg").textContent = "Couldn't reach the API."; }
    });
  });
})();
