# Development Progress

This document tracks the implementation progress of Boardroom Journal.

## Current Status: AI Signal Extraction Complete

The data layer, state management, navigation, core entry flow, and AI signal extraction are complete. Users can create text entries, have signals automatically extracted via Claude API, view signals grouped by type, and manually re-extract if needed. The app has a working Home screen with real data.

---

## Completed Milestones

### 1. Flutter Project Initialization
**PR #8** - Initial project setup

- Initialized Flutter project with Material 3
- Configured Drift ORM for local SQLite storage
- Set up build_runner for code generation
- Added core dependencies (drift, riverpod, uuid, intl)

### 2. Data Layer Implementation
**PR #8** - Complete database schema

**11 Drift Tables:**
| Table | Purpose |
|-------|---------|
| DailyEntries | Voice/text journal entries with transcripts |
| WeeklyBriefs | Auto-generated executive summaries |
| Problems | Career problems in portfolio (3-5) |
| PortfolioHealth | Health metrics snapshot |
| PortfolioVersions | Historical portfolio snapshots |
| BoardMembers | AI board roles with personas |
| GovernanceSessions | Session state and output |
| Bets | 90-day predictions with evaluation |
| EvidenceItems | Receipts/proof statements |
| ReSetupTriggers | Portfolio refresh conditions |
| UserPreferences | User settings (singleton) |

**All tables include sync columns:**
- `syncStatus` (pending/synced/conflict)
- `serverVersion` (int)
- `deletedAtUtc` (soft delete)

**8 Domain Enums:**
- SignalType (7 types: wins, blockers, risks, avoidedDecision, comfortWork, actions, learnings)
- BetStatus (open, correct, wrong, expired)
- BoardRoleType (5 core + 2 growth roles)
- ProblemDirection (appreciating, depreciating, stable)
- GovernanceSessionType (quick, setup, quarterly)
- EvidenceType + EvidenceStrength
- EntryType (voice, text)

### 3. Repository Layer Implementation
**PR #9** - Data access abstraction

**12 Repositories with full CRUD + reactive streams:**
| Repository | Key Features |
|------------|--------------|
| DailyEntryRepository | Date range queries, word counting, signal extraction storage |
| WeeklyBriefRepository | Week-based queries, regeneration tracking |
| ProblemRepository | Validation (3-5 problems, 95-105% allocation), direction tracking |
| BoardMemberRepository | Role management, anchor tracking, persona customization |
| GovernanceSessionRepository | State machine progression, transcript management |
| BetRepository | Status transitions, expiration logic |
| EvidenceItemRepository | Session-linked evidence |
| PortfolioVersionRepository | Snapshot creation, version history |
| PortfolioHealthRepository | Health calculations, trend analysis |
| ReSetupTriggerRepository | Trigger conditions, met status |
| UserPreferencesRepository | Settings singleton, onboarding state |
| BaseRepository | Common CRUD interface |

**Each repository provides:**
- Create, read, update, delete operations
- Soft delete with 30-day retention
- Sync status management
- Stream watchers for reactive UI
- Domain-specific business logic

### 4. Riverpod State Management
**PR #9** - Provider layer

**35+ Providers:**
- 12 Repository Providers (singletons)
- 15 Stream Providers (reactive data)
- 8 Future Providers (one-time fetches)

**Key providers:**
```dart
dailyEntriesStreamProvider      // Watch all entries
weeklyBriefsStreamProvider      // Watch all briefs
activeBoardMembersStreamProvider // Watch active board
hasPortfolioProvider            // Check portfolio exists
shouldShowSetupPromptProvider   // Show prompt after 3-5 entries
totalEntryCountProvider         // Entry count for stats
```

### 5. Navigation Foundation
**PR #10** - go_router setup

**Router Configuration:**
- Declarative routing with go_router
- Deep linking support
- Type-safe route constants in `AppRoutes`
- Error handling with fallback screen

**Routes Defined:**
| Route | Screen |
|-------|--------|
| `/` | Home |
| `/record-entry` | Record Entry |
| `/entry/:entryId` | Entry Review |
| `/weekly-brief/latest` | Latest Weekly Brief |
| `/weekly-brief/:briefId` | Weekly Brief by ID |
| `/governance` | Governance Hub |
| `/governance/quick` | Quick Version (15-min) |
| `/governance/setup` | Setup |
| `/governance/quarterly` | Quarterly Report |
| `/settings` | Settings |
| `/history` | History |

### 6. Home Screen Implementation
**PR #10** - Main hub with real data

**Fully implemented features:**
- Record Entry button (prominent, one tap away per PRD)
- Latest Weekly Brief preview with real data
- Setup prompt (appears after 3-5 entries if no portfolio)
- Quick Actions (15-min Audit, Governance Hub)
- Entry stats display (total entries, board status)
- Pull-to-refresh functionality
- Dark mode following system setting

**Data bindings:**
- `weeklyBriefsStreamProvider` → Brief preview
- `shouldShowSetupPromptProvider` → Setup prompt visibility
- `hasPortfolioProvider` → Board status
- `totalEntryCountProvider` → Entry count

### 7. Screen Scaffolds
**PR #10** - UI structure for all screens

| Screen | Status | Notes |
|--------|--------|-------|
| HomeScreen | **Complete** | Real data, all CTAs working |
| RecordEntryScreen | **Complete** | Text entry with word count, voice placeholder |
| EntryReviewScreen | **Complete** | View, edit, delete entries |
| WeeklyBriefViewerScreen | Scaffold | Export menu stubbed |
| GovernanceHubScreen | Scaffold | Tab structure with 3 tabs |
| QuickVersionScreen | Scaffold | 5-question list shown |
| SetupScreen | Scaffold | 7-step list shown |
| QuarterlyScreen | Scaffold | 8-section list shown |
| SettingsScreen | Scaffold | Full UI structure, all sections |
| HistoryScreen | Partial | Entry list works, needs briefs + pagination |

### 8. Text Entry Flow Implementation
**PR #11** - Core daily entry functionality

**Record Entry Screen:**
- Mode selection (Voice placeholder / Text entry)
- Full text entry UI with:
  - Real-time word count display
  - Warning at 6,500+ words (approaching limit)
  - Error state at 7,500+ words (over limit)
  - Discard confirmation dialog
  - Save button with loading state
- Riverpod state management (`TextEntryNotifier`)
- Saves to database via `DailyEntryRepository`
- Navigates to Entry Review after save

**Entry Review Screen:**
- Fetches entry by ID with `entryByIdProvider`
- Read mode with:
  - Entry metadata (type, date, word count, duration)
  - Selectable transcript display
  - Extracted signals placeholder (AI coming soon)
- Edit mode with:
  - Full transcript editing
  - Real-time word count
  - Unsaved changes detection
  - Save/Discard/Cancel dialog
- Delete with confirmation (soft delete, 30-day retention)
- Back navigation with unsaved changes handling

**Features per PRD:**
- Text entry as first-class alternative to voice
- Entries editable indefinitely (no time-based locking)
- Soft delete with 30-day retention before hard delete
- Word count limits (soft cap at 7,500 words)

### 9. AI Signal Extraction
**PR #12** - Claude API integration for signal extraction

**AI Service Layer (`lib/services/ai/`):**
- `ClaudeClient` - API client wrapper with retry logic and error handling
- `ClaudeConfig` - Configuration for Sonnet (daily ops) and Opus (governance)
- `SignalExtractionService` - Extracts 7 signal types from entry text
- `ExtractedSignal` / `ExtractedSignals` - Data models for signal storage

**Signal Types (per PRD Section 9):**
| Type | Description | Icon |
|------|-------------|------|
| Wins | Completed accomplishments | Trophy |
| Blockers | Current obstacles | Block |
| Risks | Potential future problems | Warning |
| Avoided Decision | Decisions being put off | Hourglass |
| Comfort Work | Tasks that feel productive but don't advance goals | Beach |
| Actions | Forward commitments | Task |
| Learnings | Realizations and reflections | Lightbulb |

**Entry Flow Integration:**
- Signals extracted automatically after entry save
- Two-phase save: save entry → extract signals
- UI shows "Saving..." then "Extracting signals..."
- Extraction failure doesn't block entry save
- Entry stored even if AI service unavailable

**Entry Review Updates:**
- `SignalListWidget` displays signals grouped by type
- Color-coded sections with type-specific icons
- Signal count badges per category
- "Re-extract" button for manual re-extraction
- Empty state with explanation when no signals

**New Providers:**
```dart
aiConfigProvider              // AI configuration from environment
claudeClientProvider          // Claude Sonnet client
claudeOpusClientProvider      // Claude Opus client (for governance)
signalExtractionServiceProvider // Signal extraction service
extractionProvider            // Extraction state management
reExtractionProvider          // Per-entry re-extraction state
```

**Features per PRD Section 3A.1:**
- Claude Sonnet 4.5 for daily operations (signal extraction)
- Claude Opus 4.5 configured for governance (future use)
- Exponential backoff retry (1s, 2s, 4s)
- Graceful error handling

**Configuration:**
- Set `ANTHROPIC_API_KEY` environment variable
- Service degrades gracefully if not configured
- Signals can be extracted later via re-extract button

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                        UI Layer                          │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│  │  Home   │ │ Record  │ │ History │ │Settings │ ...    │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘        │
└───────┼──────────┼──────────┼──────────┼────────────────┘
        │          │          │          │
        ▼          ▼          ▼          ▼
┌─────────────────────────────────────────────────────────┐
│                   Riverpod Providers                     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│  │   Stream     │ │   AI/Service │ │  Repository  │     │
│  │  Providers   │ │  Providers   │ │  Providers   │     │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘     │
└─────────┼────────────────┼────────────────┼─────────────┘
          │                │                │
          ▼                ▼                ▼
┌─────────────────────────────────────────────────────────┐
│                   Service Layer                          │
│  ┌────────────────────────────────────────────────┐     │
│  │ AI Services (Claude API)                        │     │
│  │  SignalExtraction │ (WeeklyBrief) │ (Governance)│     │
│  └────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────┐
│                   Repository Layer                       │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐           │
│  │DailyEntry  │ │  Problem   │ │BoardMember │ ... (12)  │
│  │ Repository │ │ Repository │ │ Repository │           │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘           │
└────────┼──────────────┼──────────────┼──────────────────┘
         │              │              │
         ▼              ▼              ▼
┌─────────────────────────────────────────────────────────┐
│                    Drift Database                        │
│  ┌─────────────────────────────────────────────────┐    │
│  │              SQLite (11 tables)                  │    │
│  │  DailyEntries │ WeeklyBriefs │ Problems │ ...   │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## Test Coverage

**9 Test Files:**

| Test File | Coverage |
|-----------|----------|
| database_test.dart | Table operations, insert/update/delete |
| daily_entry_repository_test.dart | CRUD, date ranges, signals |
| problem_repository_test.dart | Validation, direction changes |
| board_member_repository_test.dart | Roles, anchoring, personas |
| governance_session_repository_test.dart | State machine, transcripts |
| bet_repository_test.dart | Status transitions, expiration |
| user_preferences_repository_test.dart | Settings, onboarding |
| extracted_signal_test.dart | Signal models, JSON serialization |
| signal_extraction_service_test.dart | Claude client, extraction service |

---

## File Statistics

| Category | Count | Lines of Code |
|----------|-------|---------------|
| Source Files | 53 | ~7,500 |
| Test Files | 9 | ~2,300 |
| Total Dart Files | 62 | ~9,800 |

**By Layer:**
- Data Layer: 31 files (~3,500 LOC)
- Services Layer: 6 files (~500 LOC)
- Providers: 4 files (~500 LOC)
- Router: 2 files (~120 LOC)
- UI/Screens: 12 files (~2,900 LOC)

---

## What's Next

### Immediate Priority: Weekly Brief Generation

Implement weekly brief generation using the AI service infrastructure:
1. Create brief generation service (uses same Claude Sonnet client)
2. Implement brief scheduling (Sunday 8pm local time)
3. Add regeneration with modifiers (shorter/actionable/strategic)
4. Generate board micro-review (one sentence per active role)

### Subsequent Steps:
1. Voice Recording - Audio capture + Deepgram integration
2. Governance State Machines - Quick/Setup/Quarterly runners
3. Settings Implementation - All settings sections functional
4. History Screen Enhancement - Combined entries + briefs

---

## Dependencies

**Production:**
- flutter_riverpod: ^2.4.9
- drift: ^2.14.0
- go_router: ^14.2.0
- sqlite3_flutter_libs: ^0.5.18
- path_provider: ^2.1.1
- http: ^1.1.0
- uuid: ^4.2.1
- intl: ^0.19.0
- equatable: ^2.0.5
- json_annotation: ^4.8.1

**Development:**
- drift_dev: ^2.14.0
- build_runner: ^2.4.7
- json_serializable: ^6.7.1
- flutter_lints: ^3.0.1

---

*Last updated: January 2026*
