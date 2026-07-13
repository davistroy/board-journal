## Learning Capture — Every Session

After any non-trivial finding (Flutter build failure, Drift codegen issue, AI integration surprise, state machine quirk, sync/SQLite behavior, multi-attempt fix):
1. Update `CLAUDE.md` — add/update bullet in relevant section
2. Update memory file — `C:\Users\Troy Davis\.claude\projects\C--Users-Troy-Davis-dev-personal-board-journal\memory\`
3. Update `MEMORY.md` — concise bullet + link to topic file

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Operational rules, always enforced |
| `memory/MEMORY.md` | Concise index, survives compaction |
| `memory/flutter-build-learnings.md` | Build, codegen, toolchain issues |
| `memory/ai-integration-learnings.md` | Claude API, schema validation, governance FSM |
| `memory/data-layer-learnings.md` | Drift, SQLite, sync behavior |

### Verified Operational Rules

*(None yet — add as discovered)*

---

# CLAUDE.md

## Project Overview

Boardroom Journal — Flutter mobile app (iOS + Android) for voice-first career journaling with AI-powered governance.

**Core loop:** Daily capture → Weekly brief → Board governance (Quick/Setup/Quarterly) → portfolio + bets updated → repeat

## Build Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # After modifying Drift tables
dart run build_runner watch                               # Continuous codegen
flutter test
flutter test test/data/database/database_test.dart
flutter run
cd backend && dart test
```

## Pre-commit Hooks (Lefthook)

```bash
npm install -g @evilmartians/lefthook  # or: brew install lefthook
lefthook install
```

- **pre-commit:** Format check, Flutter analyze, Backend analyze
- **pre-push:** Flutter tests, Backend tests

## Architecture

### Data Layer (`lib/data/`)

**Drift ORM:**
- `database/database.dart` — Main DB config with all tables
- `database/tables/` — 11 table definitions
- `database/converters/` — Enum ↔ string converters
- Generated: `database.g.dart` (gitignored)

**Enums:**
- `SignalType` — 7 types (wins, blockers, risks, avoidedDecision, comfortWork, actions, learnings)
- `BetStatus` — OPEN → CORRECT/WRONG/EXPIRED (no partial states)
- `BoardRoleType` — 5 core + 2 growth roles
- `ProblemDirection` — appreciating/depreciating/stable

### Key Domain Concepts

**Board Roles:** 5 core always active; 2 growth roles (PortfolioDefender, OpportunityScout) activate only when appreciating problems exist.

**Governance Sessions:** Finite state machines. Three types:
- Quick Version: 15-min 5-question audit
- Setup: Portfolio (3-5 problems) + Board creation
- Quarterly: Full report with board interrogation

**Evidence/Receipts:** Claims require EvidenceItems with type (Decision/Artifact/Calendar/Proxy/None) and strength rating.

### Sync Strategy

- Local-first SQLite via Drift
- All tables: `syncStatus`, `serverVersion`, `deletedAtUtc` columns
- Last-write-wins conflict resolution with user notification
- Soft delete with 30-day retention

## Technical Constraints

- Voice entries: max 15 min, max 7500 words including follow-ups
- Weekly brief: target 600 words, max 800 words
- Governance vagueness gates: max 2 skips per session
- Portfolio: exactly 3-5 problems, time allocation must sum to 95-105%
- Bets: 90-day duration, auto-expire without grace period

## LLM Integration

- Claude Opus 4.5 — governance (Setup, Quarterly)
- Claude Sonnet 4.5 — daily operations (extraction, briefs)
- Deepgram Nova-2 — speech-to-text
- All AI outputs validated against strict schemas with word/bullet caps
