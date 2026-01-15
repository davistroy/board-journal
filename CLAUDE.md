# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Boardroom Journal is a Flutter app (iOS, Android, and Web) for voice-first career journaling with AI-powered governance. Users record daily entries, receive weekly executive briefs, and engage in structured career governance sessions with a 5-7 role AI board.

**Core loop:** Daily capture → Weekly brief → Board governance (Quick/Setup/Quarterly) → portfolio + bets updated → repeat

## Build Commands

```bash
# Install dependencies
flutter pub get

# Generate Drift database code (required after modifying tables)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for continuous code generation
dart run build_runner watch

# Run all tests
flutter test

# Run a single test file
flutter test test/data/database/database_test.dart

# Run the app
flutter run

# Run backend tests
cd backend && dart test
```

## Web Development

```bash
# Run web version locally
flutter run -d chrome

# Build for production (with API keys)
flutter build web --release \
  --dart-define=ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  --dart-define=DEEPGRAM_API_KEY=$DEEPGRAM_API_KEY \
  --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY

# Test production build locally
cd build/web && python -m http.server 8080
```

### Web Platform Limitations

- **Audio Recording**: Uses WAV format (larger files than mobile AAC)
- **Background Tasks**: Not available; weekly briefs checked on app load
- **Token Storage**: Uses localStorage (less secure than mobile Keychain/Keystore)
- **Apple Sign-In**: Not available on web
- **Database**: Uses sql.js (SQLite compiled to WebAssembly) with IndexedDB persistence

## Pre-commit Hooks (Optional)

This project uses [Lefthook](https://github.com/evilmartians/lefthook) for pre-commit hooks:

```bash
# Install lefthook (choose one)
npm install -g @evilmartians/lefthook
# or: brew install lefthook

# Enable hooks in this repo
lefthook install
```

Hooks run automatically on commit/push:
- **pre-commit:** Format check, Flutter analyze, Backend analyze
- **pre-push:** Flutter tests, Backend tests

## Architecture

### Data Layer (`lib/data/`)

**Database (Drift ORM):**
- `database/database.dart` - Main database configuration with all tables
- `database/tables/` - 11 Drift table definitions (DailyEntries, WeeklyBriefs, Problems, etc.)
- `database/converters/` - Type converters for enum ↔ string mapping
- Generated code goes to `database.g.dart` (gitignored)

**Enums (`enums/`):**
- `SignalType` - 7 types extracted from entries (wins, blockers, risks, avoidedDecision, comfortWork, actions, learnings)
- `BetStatus` - OPEN → CORRECT/WRONG/EXPIRED (no partial states)
- `BoardRoleType` - 5 core roles + 2 growth roles with metadata extensions
- `ProblemDirection` - appreciating/depreciating/stable

### Key Domain Concepts

**Board Roles:** 5 core roles always active; 2 growth roles (PortfolioDefender, OpportunityScout) activate only when appreciating problems exist. Each role anchors to a specific problem with a specific demand.

**Governance Sessions:** Implemented as finite state machines (not free-form chat). Three types:
- Quick Version: 15-min 5-question audit
- Setup: Portfolio (3-5 problems) + Board creation
- Quarterly: Full report with board interrogation

**Evidence/Receipts:** Claims require EvidenceItems with type (Decision/Artifact/Calendar/Proxy/None) and strength rating.

### Sync Strategy

- Local-first SQLite via Drift (native SQLite on mobile, sql.js on web)
- All tables include `syncStatus`, `serverVersion`, `deletedAtUtc` columns
- Last-write-wins conflict resolution with user notification
- Soft delete with 30-day retention before hard delete
- Web uses IndexedDB for database persistence

## Technical Constraints (from PRD)

- Voice entries: max 15 min recording, max 7500 words including follow-ups
- Weekly brief: target 600 words, max 800 words
- Governance vagueness gates: max 2 skips per session
- Portfolio: exactly 3-5 problems, time allocation must sum to 95-105%
- Bets: 90-day duration, auto-expire without grace period

## LLM Integration

- Claude Opus 4.5 for governance (Setup, Quarterly)
- Claude Sonnet 4.5 for daily operations (extraction, briefs)
- Deepgram Nova-2 for speech-to-text
- All AI outputs validated against strict schemas with word/bullet caps
