# REDESIGN-AUDIT — sidehustle-ai (2026-10-13)

Competitors referenced: **Everlance** (mileage + income + expenses in one app; "what's actually yours" after-tax framing; IRS-ready reports), **Stride** (free gig-worker tracker; ongoing tax-position estimate from logged numbers), **Gridwise** (profit charting per gig; earnings analytics strip: best periods, averages).

## Visual gaps vs competitors
- The app opens on the quiz, not on money. Everlance/Stride/Gridwise all lead with the earnings picture: net, pace, tax owed. Here the most motivating number (take-home) is buried in step 4 as two separate text lines (`netLine`, `taxLine`).
- The analytics strip (`analyticsLine`) is a single comma-joined text sentence — Gridwise renders best-day/streak/avg as stat tiles.
- Hustle matches render as a flat ordered list; gig-board-style cards with fit bars would match the "job board" mental model.
- 30-day plan weeks are stacked cards with plain bars; a vertical timeline reads as a launch sequence.
- Income/expense entries are plain lists; Everlance-style ledger rows (amount right-aligned tabular, tag chips, date hierarchy) scan faster.

## Functional gaps vs competitors
1. **No single "take-home" number.** Everlance's core frame: income − expenses − tax set-aside = what's actually yours. SideHustle shows net profit and the tax set-aside as separate lines; nothing combines them.
2. **No per-hustle $/hour efficiency.** Gridwise's profit charting answers "which gig pays best per hour." `profitByHustle` gives net per hustle but nothing divides by time (the bank stores weekly hours per hustle).
3. Match scores render as a bare number; no fit-breakdown visibility (skill/interest/time/cost/earning weights exist in logic).

## What this redesign does (bounded)
- **Earnings dashboard hero** above the workflow: take-home this month (income − expenses − tax set-aside), monthly goal bar, and a 4-stat strip (best day, earning streak, avg/day, run-rate pace) — Gridwise/Everlance pattern.
- **Net-per-hustle ranking with $/hr**: hustle leaderboard rows show net, gross in/out, and effective $/hr (net ÷ weekly-hours × 4.33/mo) so the best-paying gig is obvious.
- **Fit-score bars** on match cards + match-breakdown tooltip text from the existing score weights (skill/interest/time/cost/earning).
- **Launch plan as vertical timeline** with week nodes and progress.
- **Ledger-styled income/expense feeds** (tabular numerals, tag chips).
- Visual identity: "first-dollar" gig ledger — warm cream paper, espresso ink, single amber-gold accent; serif display + tabular figures; square geometry (radius stays 0).
- All existing features preserved: quiz + scoring + sorting, pinned shortlist compare, launch plans with per-hustle checklists, income/expense CSV export, monthly ledger, tax set-aside, AI brainstorm.
