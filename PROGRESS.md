# Development Progress

This document tracks the implementation progress of Boardroom Journal.

## Current Status: Quick Version State Machine Complete

The data layer, state management, navigation, core entry flow, AI signal extraction, weekly brief generation, and Quick Version (15-min audit) are complete. Users can create text entries, have signals automatically extracted, generate weekly briefs, and run Quick Version audits with anti-vagueness enforcement, problem direction evaluation, and 90-day bet creation.

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

**40+ Providers:**
- 12 Repository Providers (singletons)
- 18 Stream Providers (reactive data)
- 10 Future Providers (one-time fetches)

**Key providers:**
```dart
dailyEntriesStreamProvider      // Watch all entries
weeklyBriefsStreamProvider      // Watch all briefs
activeBoardMembersStreamProvider // Watch active board
hasPortfolioProvider            // Check portfolio exists
shouldShowSetupPromptProvider   // Show prompt after 3-5 entries
totalEntryCountProvider         // Entry count for stats
briefByIdProvider               // Fetch brief by ID
latestBriefProvider             // Get most recent brief
entriesForWeekProvider          // Get entries for a week
weeklyBriefGenerationServiceProvider // Brief generation service
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
- "Generate Brief" button when no briefs exist
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
| EntryReviewScreen | **Complete** | View, edit, delete entries with signals |
| WeeklyBriefViewerScreen | **Complete** | Full brief display, regeneration, export |
| GovernanceHubScreen | Scaffold | Tab structure with 3 tabs |
| QuickVersionScreen | **Complete** | Full state machine, vagueness detection |
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
  - Extracted signals display
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

**Features per PRD Section 3A.1:**
- Claude Sonnet 4.5 for daily operations (signal extraction)
- Claude Opus 4.5 configured for governance (future use)
- Exponential backoff retry (1s, 2s, 4s)
- Graceful error handling

**Configuration:**
- Set `ANTHROPIC_API_KEY` environment variable
- Service degrades gracefully if not configured
- Signals can be extracted later via re-extract button

### 10. Weekly Brief Generation
**PR #13** - AI-powered brief generation and viewer

**WeeklyBriefGenerationService (`lib/services/ai/`):**
- Generates executive briefs from week's journal entries
- System prompt enforcing PRD Section 4.2 structure:
  - Headline (max 2 sentences)
  - Wins/Blockers/Risks (max 3 bullets each)
  - Open Loops (max 5 bullets)
  - Next Week Focus (exactly 3 items)
  - Avoided Decision + Comfort Work (1 each or "none")
- Target ~600 words, max 800 words
- Zero-entry weeks generate reflection brief (~100 words)
- Board micro-review (one sentence per active role)

**Regeneration Options (combinable):**
| Option | Effect |
|--------|--------|
| Shorter | ~40% reduction, 2 bullets max, omit Open Loops |
| More Actionable | Every bullet has next step, "Suggested Actions" section |
| More Strategic | Career trajectory framing, "Strategic Implications" section |

**WeeklyBriefViewerScreen (full implementation):**
- Display brief markdown content
- Week range header with calendar icon
- Collapsible board micro-review section (remembers preference)
- Regeneration counter ("X of 5 remaining")
- Regeneration dialog with checkbox options
- Edit mode for manual edits (unsaved changes detection)
- Export to Markdown (clipboard)
- Export to JSON (clipboard)
- Empty state with "Generate Brief" button

**New Providers:**
```dart
weeklyBriefGenerationServiceProvider  // Brief generation service
briefByIdProvider                     // Fetch brief by ID
latestBriefProvider                   // Get most recent brief
entriesForWeekProvider                // Get entries for a week
remainingRegenerationsProvider        // Remaining regen count
watchBriefByIdProvider                // Stream for specific brief
```

**Features per PRD Section 4.2:**
- Manual brief generation on-demand
- 5 regenerations per brief (tracked)
- Board micro-review included by default
- User edits preserved (unless "Start over")
- Zero-entry weeks handled gracefully

### 11. Quick Version State Machine
**PR #14** - Governance 15-minute audit implementation

**State Machine Architecture (`lib/services/governance/`):**
- `QuickVersionState` - Enum defining all states (sensitivityGate → Q1-Q5 → generateOutput → finalized)
- `QuickVersionSessionData` - Complete session state with transcript, problems, answers
- `QuickVersionService` - Orchestrates state machine, persistence, AI calls
- `QuickVersionQA` - Individual question/answer entries in transcript
- `IdentifiedProblem` - Problem with direction evaluation data

**AI Services:**
- `VaguenessDetectionService` - Detects vague answers using heuristics + AI
- `QuickVersionAIService` - Problem parsing, direction evaluation, output generation
- Uses Claude Opus 4.5 for governance per PRD Section 3A.1

**State Machine Flow (per PRD Section 4.3):**
```
Initial → SensitivityGate → Q1 (Role Context)
    → Q2 (Paid Problems) → Q3 (Direction Loop for each problem)
    → Q4 (Avoided Decision) → Q5 (Comfort Work)
    → GenerateOutput → Finalized
```

**Vagueness Detection (per PRD Section 6.3):**
- Heuristic checks for dates, proper nouns, metrics, specific verbs
- AI-assisted detection for ambiguous cases
- Triggers "concrete example" follow-up for vague answers
- Max 2 skips per session; third gate cannot be skipped
- Skip records "[example refused]" for future reference

**Problem Direction Evaluation (per PRD Section 4.3):**
For each of 3 problems:
- "Is AI getting cheaper at this?"
- "What's the cost of errors?"
- "Is trust/access required?"
- AI evaluates direction: Appreciating / Depreciating / Stable
- One-sentence rationale with user quotes

**Generated Output:**
- Problem direction table (markdown format)
- 2-sentence honest assessment
- Avoided decision + cost
- 90-day bet with wrong-if condition
- Bet automatically saved to database

**UI Components (`lib/ui/`):**
| Component | Features |
|-----------|----------|
| QuickVersionScreen | State routing, progress bar, abandon confirmation |
| SensitivityGateView | Abstraction mode toggle, remember preference |
| QuickVersionQuestionView | Question display, text input, skip button, progress |
| QuickVersionOutputView | Results display, export to markdown, share |

**New Providers (`lib/providers/quick_version_providers.dart`):**
```dart
quickVersionServiceProvider       // Main service
quickVersionSessionProvider       // Session state notifier
hasInProgressQuickVersionProvider // Check for resumable session
quickVersionWeeklyCountProvider   // Rate limit visibility
rememberedAbstractionModeProvider // User's saved preference
vaguenessDetectionServiceProvider // Vagueness checker
quickVersionAIServiceProvider     // AI service
```

**Features per PRD Section 4.3 & 5.6:**
- Sensitivity gate with abstraction mode
- One question at a time
- Anti-vagueness enforcement
- Two-step skip confirmation
- Session persistence and resume
- Direction table with user quotes
- 90-day bet creation with wrong-if
- Export to markdown/share

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                        UI Layer                          │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│  │  Home   │ │ Record  │ │  Brief  │ │Settings │ ...    │
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
│  │  SignalExtraction │ WeeklyBrief │ (Governance) │     │
│  └────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────┐
│                   Repository Layer                       │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐           │
│  │DailyEntry  │ │WeeklyBrief │ │BoardMember │ ... (12)  │
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

**12 Test Files:**

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
| weekly_brief_generation_service_test.dart | Brief generation, regeneration options |
| quick_version_service_test.dart | State machine, Q&A flow, session data |
| vagueness_detection_service_test.dart | Heuristics, AI detection, edge cases |

---

## File Statistics

| Category | Count | Lines of Code |
|----------|-------|---------------|
| Source Files | 65 | ~10,500 |
| Test Files | 12 | ~3,200 |
| Total Dart Files | 77 | ~13,700 |

**By Layer:**
- Data Layer: 31 files (~3,500 LOC)
- Services Layer: 12 files (~1,800 LOC)
- Providers: 5 files (~1,100 LOC)
- Router: 2 files (~120 LOC)
- UI/Screens: 15 files (~4,000 LOC)

---

## What's Next

### Immediate Priority: Setup State Machine

Implement Setup (Portfolio + Board) per PRD Section 4.4:
1. Problem collection (3-5 problems with required fields)
2. Time allocation validation (95-105%, 90-110% with warning)
3. Portfolio health calculation
4. Board role creation (5 core + 0-2 growth roles)
5. Persona generation with reset capability
6. Re-setup trigger definition
7. Portfolio versioning

### Subsequent Steps:
1. **Quarterly Report** - Full report with board interrogation (depends on Setup)
2. **Voice Recording** - record_audio package, Deepgram integration, waveform UI
3. **Brief Scheduling** - Sunday 8pm automatic generation
4. **Settings Implementation** - All settings sections functional
5. **History Screen Enhancement** - Combined entries + briefs

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
- share_plus: ^7.2.1

**Development:**
- drift_dev: ^2.14.0
- build_runner: ^2.4.7
- json_serializable: ^6.7.1
- flutter_lints: ^3.0.1

---

*Last updated: January 10, 2026*
