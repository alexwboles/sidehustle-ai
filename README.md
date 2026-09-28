# SideHustle AI

**Find your hustle, launch in 30 days.** Tell SideHustle AI your skills, interests, and weekly hours → get 24 side-hustle ideas ranked by fit (with startup cost and earning-potential estimates), a week-by-week 30-day launch plan for your pick, and an income tracker that measures progress toward your monthly goal. All running 100% locally in your browser.

## The problem

"Start a side hustle" advice is generic. What works depends on *your* skills, *your* schedule, and *your* budget — and most people stall between the idea and the first paying customer. SideHustle AI closes that gap:

1. **24-idea bank** — freelance writing, meal prep, mobile detailing, bookkeeping, tutoring, and more, each with skill/interest tags, weekly time need, startup cost tier, and realistic pay ranges
2. **Fit scoring** — ranks ideas by skill match, interest match, time fit, startup cost, and earning potential (transparent weighted score, not a black box)
3. **30-day launch plans** — every idea expands into 4 weekly phases (Validate → Set up → Launch → Grow) with checkable tasks
4. **Income tracker** — log earnings, watch a progress bar climb toward your monthly goal
5. **Optional AI brainstorm** — paste your own OpenAI API key for custom ideas beyond the bank (never required)

## How to run

No build step, no server, no account. Just open `index.html` in any browser — or serve it statically:

```bash
npx serve .        # or: python3 -m http.server 8080
```

Your income log and plan progress live in `localStorage` (`sidehustle.income.v1`, `sidehustle.plan.<id>`). Nothing ever leaves your device. If you use the optional AI brainstorm, your key is sent only to OpenAI's API, directly from your browser.

## How matching works

`scoreHustles()` in `js/logic.js` filters the bank by your max startup cost, then scores each idea: 30% skill overlap, 25% interest overlap, 20% time fit, 10% cost, 15% earning potential. `projectedMonthly()` scales each idea's pay range to your actual weekly hours. Pure functions — fully testable in Node.

## Tests

```bash
bash test/smoke.sh   # static + logic checks
bash test/e2e.sh     # end-to-end matching/planning/income flows
```
