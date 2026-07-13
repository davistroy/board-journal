# Boardroom Journal — Brief

**Created:** 2026-07-12 (retroactive — project began 2026-01-09)

## Problem

Boardroom Journal is a voice-first journaling app that turns a week of daily voice/text entries into a 600–800 word executive brief, and runs a "receipts-based" career-governance system — a 5-7 persona AI board (Accountability, Market Reality, Avoidance, Long-term Positioning, Devil's Advocate, plus two growth roles) that interrogates avoided decisions and comfort work rather than letting vague self-assessment slide. It's built as a standalone Flutter app (iOS/Android/web) with a custom Dart backend for multi-device sync, Claude (Opus for governance, Sonnet for daily ops) for summarization/interrogation, and Deepgram Nova-2 for transcription. Work ran from 2026-01-09 through 2026-01-15 (Phase 13 visual overhaul, Phase 14 technical-debt remediation, full web-platform support, 1.0.0 tag) and stopped there — no commits in the ~6 months since. Separately, open-brain's PRD (`~/dev/personal/open-brain/docs/PRD.md`) explicitly designates board-journal's governance functionality as "replaced": a Slack-native, clean-room reimplementation informed only by board-journal's *principles* (governance philosophy, anti-vagueness criteria, board personas, bet-tracking model) via a conceptual reference doc — "no code ported" (PRD.md:41, :1924). So the live question isn't whether this codebase still compiles; it's whether the underlying product (weekly executive brief + AI board) is worth keeping at all, and if so, in which vehicle.

## Success Criteria

- [ ] Daily voice/text entries actually used by Troy for several consecutive weeks (dogfooding, not just test coverage)
- [ ] At least one full governance cycle completed end-to-end (Quick audit → Setup → weekly briefs → Quarterly report) and judged useful
- [ ] At least one bet closed (OPEN → CORRECT/WRONG) with a retrospective that changed a decision
- [ ] App installed and used on a personal device outside of the dev/CI loop

## Kill Criteria

- Not used in 30 days
- Core approach needs more than 2 weekends of additional work to reach Success Criteria
- [ ] Product concept superseded by a clean-room reimplementation elsewhere (open-brain PRD already stakes this claim for board-journal specifically)

## Review Date

2026-07-19

## Disposition

**VERDICT: ARCHIVE — signed off by Troy 2026-07-13.** (Recommendation accepted; archived via `/archive-project` on 2026-07-13.)

Six months idle since the last commit (2026-01-15), with no evidence in CHANGELOG/PROGRESS of the governance loop or weekly-brief loop ever being exercised outside test suites — only build-out and CI-hardening work is recorded. Independent of code staleness, open-brain's own PRD already claims this product territory and explicitly commits to a clean-room reimplementation with no code reuse — so even under the most generous reading ("the product is worth keeping"), this repo isn't the vehicle for it; open-brain is. Recommend archiving the Flutter+backend codebase as-is. If the product itch returns, the right move (already scoped in open-brain's own plan) is extracting a short "board-journal principles" reference doc — not reviving or thinning this ~15K-line app.
