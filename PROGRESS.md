# Development Progress

This document tracks the implementation progress of Boardroom Journal.

## Current Status: All Phases Complete (1-12b)

The full MVP implementation is complete. The app includes:
- Complete data layer with 11 Drift tables and sync support
- Three governance state machines (Quick Version, Setup, Quarterly Report)
- Voice recording with Deepgram/Whisper transcription
- Weekly brief auto-generation with Sunday 8pm scheduling
- Complete settings with persona/portfolio editing
- OAuth authentication (Apple, Google, Microsoft)
- Backend API server with PostgreSQL
- Full multi-device sync with conflict resolution
- JSON/Markdown export and import

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
| `/settings/personas` | Persona Editor |
| `/settings/portfolio` | Portfolio Editor |
| `/settings/versions` | Version History |
| `/history` | History |
| `/onboarding/*` | Onboarding flow |

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

### 7. Screen Scaffolds
**PR #10** - UI structure for all screens

| Screen | Status | Notes |
|--------|--------|-------|
| HomeScreen | **Complete** | Real data, all CTAs working |
| RecordEntryScreen | **Complete** | Text entry with word count, voice recording |
| EntryReviewScreen | **Complete** | View, edit, delete entries with signals |
| WeeklyBriefViewerScreen | **Complete** | Full brief display, regeneration, export |
| GovernanceHubScreen | **Complete** | Tab structure with all governance types |
| QuickVersionScreen | **Complete** | Full state machine, vagueness detection |
| SetupScreen | **Complete** | Portfolio + board creation with personas |
| QuarterlyScreen | **Complete** | Full board interrogation flow |
| SettingsScreen | **Complete** | All sections functional |
| HistoryScreen | **Complete** | Combined entries/briefs/sessions, export |

### 8. Text Entry Flow Implementation
**PR #11** - Core daily entry functionality

**Record Entry Screen:**
- Mode selection (Voice / Text entry)
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
- Read mode with entry metadata and signals display
- Edit mode with unsaved changes detection
- Delete with confirmation (soft delete, 30-day retention)

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

### 10. Weekly Brief Generation
**PR #13** - AI-powered brief generation and viewer

**WeeklyBriefGenerationService:**
- Generates executive briefs from week's journal entries
- Target ~600 words, max 800 words
- Zero-entry weeks generate reflection brief (~100 words)
- Board micro-review (one sentence per active role)

**Regeneration Options (combinable):**
| Option | Effect |
|--------|--------|
| Shorter | ~40% reduction, 2 bullets max, omit Open Loops |
| More Actionable | Every bullet has next step, "Suggested Actions" section |
| More Strategic | Career trajectory framing, "Strategic Implications" section |

### 11. Quick Version State Machine
**PR #14** - Governance 15-minute audit implementation

**State Machine Flow:**
```
Initial → SensitivityGate → Q1 (Role Context)
    → Q2 (Paid Problems) → Q3 (Direction Loop for each problem)
    → Q4 (Avoided Decision) → Q5 (Comfort Work)
    → GenerateOutput → Finalized
```

**Features:**
- Sensitivity gate with abstraction mode
- One question at a time
- Anti-vagueness enforcement
- Two-step skip confirmation
- Session persistence and resume
- Direction table with user quotes
- 90-day bet creation with wrong-if

### 12. Setup State Machine (Phase 5)
**PR #15-18** - Portfolio + Board creation with personas

**State Machine Flow:**
```
SensitivityGate → Collect Problems (3-5) → Validate
    → Time Allocation (95-105%) → Portfolio Health
    → Create Core Roles (5) → Create Growth Roles (0-2)
    → Generate Personas → Define Re-Setup Triggers
    → Publish Portfolio + Board
```

**Features:**
- Problem collection with required fields validation
- Time allocation validation with visual feedback
- Portfolio health calculation
- Board role creation (5 core + 0-2 growth based on appreciating problems)
- Persona generation with reset capability
- Re-setup trigger definition
- Portfolio versioning with snapshots

### 13. Quarterly Report (Phase 6)
**PR #15-18** - Full board interrogation and bet tracking

**State Machine Flow:**
```
SensitivityGate → Gate 0 (Require Portfolio)
    → Q1-Q10 (Bet evaluation, commitments, portfolio checks)
    → Core Board Interrogation (5 roles)
    → Growth Board Interrogation (0-2 roles)
    → Generate Report → Finalized
```

**Features:**
- Evidence strength labeling (Strong/Medium/Weak/None)
- Last bet evaluation with status transitions
- Portfolio health trend analysis
- Anchored questions from each board role
- Re-setup trigger status check
- Next bet creation with wrong-if condition

### 14. Voice Recording (Phase 7)
**PR #15-18** - Deepgram transcription with waveform UI

**Audio Services:**
- `AudioRecorderService` - Voice recording with waveform visualization
- Silence timeout: 8 seconds with visual countdown in last 3s
- Duration limits: 15 min max (warning at 12 min, auto-stop at 15 min)

**Transcription Services:**
- Deepgram Nova-2 primary provider
- OpenAI Whisper fallback
- Batch processing (not streaming for MVP)
- Target <2s from stop to transcript display

### 15. History & Export (Phase 8)
**PR #15-18** - Combined history view, JSON/Markdown export

**History Screen:**
- Single reverse-chronological list
- Type indicators (entry, brief, session)
- Preview text and date display
- Pull-to-refresh and pagination
- Governance session detail view in bottom sheet

**Export/Import Services:**
- JSON full backup with all data types
- Markdown human-readable export
- Import with conflict resolution
- GDPR Article 20 compliant

### 16. Settings Implementation (Phase 9)
**PR #15-18** - All settings sections functional

**Settings Sections:**
- Account (OAuth providers, sessions, delete account)
- Privacy (abstraction mode, audio retention, analytics)
- Data (export JSON/Markdown, import, delete all)
- Board (view/edit personas, reset to defaults)
- Portfolio (version history, edit problems, triggers)
- About (version, terms, privacy policy, licenses)

### 17. Brief Scheduling (Phase 10)
**PR #15-18** - Sunday 8pm auto-generation

**Scheduler Features:**
- Uses workmanager for background tasks
- Timezone-aware (device timezone, America/New_York fallback)
- Auto-generates weekly brief Sunday 8pm
- Handles zero-entry weeks gracefully

### 18. Onboarding & Auth (Phase 11)
**PR #15-18** - OAuth sign-in, onboarding flow

**Onboarding Flow:**
- Welcome screen (value proposition)
- Privacy acceptance (terms + privacy summary)
- OAuth sign-in (Apple, Google, Microsoft options)
- First entry experience

**Auth Service:**
- OAuth with Apple Sign-In SDK
- OAuth with Google Sign-In SDK
- Microsoft Sign-In (configuration required)
- Local-only mode option
- Token storage in secure keychain/keystore
- Proactive token refresh (15-min access, 30-day refresh)

### 19. Backend API Server (Phase 12a)
**PR #15-18** - Docker, database, REST endpoints

**Backend Architecture:**
- Dart server with Shelf framework
- PostgreSQL database
- Docker + docker-compose setup
- JWT token management

**API Endpoints:**
| Category | Endpoints |
|----------|-----------|
| Health | `/health`, `/version` |
| Auth | `/auth/oauth/{provider}`, `/auth/refresh`, `/auth/session`, `/auth/logout` |
| Sync | `/sync?since={timestamp}`, `/sync` (POST), `/sync/full` |
| AI | `/ai/transcribe`, `/ai/extract`, `/ai/generate` |
| Account | `/account`, `/account` (DELETE), `/account/export` |

### 20. Client Sync Integration (Phase 12b)
**PR #15-18** - Sync service, conflict resolution, queue

**Sync Features:**
- `SyncService` - Multi-device sync orchestration
- `ConflictResolver` - Last-write-wins with notification
- `SyncQueue` - Offline queue with retry logic
- Auto-sync triggers: App launch, connectivity restored, pull-to-refresh, every 5 min

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           UI Layer                                    │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│  │  Home   │ │ Record  │ │  Brief  │ │Governance│ │Settings │ ...   │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘        │
└───────┼──────────┼──────────┼──────────┼──────────┼─────────────────┘
        │          │          │          │          │
        ▼          ▼          ▼          ▼          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Riverpod Providers (40+)                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                  │
│  │   Stream     │ │   AI/Service │ │  Repository  │                  │
│  │  Providers   │ │  Providers   │ │  Providers   │                  │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘                  │
└─────────┼────────────────┼────────────────┼──────────────────────────┘
          │                │                │
          ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Service Layer                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐        │
│  │   AI Services   │ │Governance State │ │  Sync/Auth/     │        │
│  │ (Claude/Deepgram)│ │   Machines     │ │  Export/Audio   │        │
│  └────────┬────────┘ └────────┬────────┘ └────────┬────────┘        │
└───────────┼──────────────────┼──────────────────┼────────────────────┘
            │                  │                  │
            ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Repository Layer (12)                            │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐        │
│  │DailyEntry  │ │WeeklyBrief │ │BoardMember │ │ Problem    │ ...    │
│  │ Repository │ │ Repository │ │ Repository │ │ Repository │        │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘        │
└────────┼──────────────┼──────────────┼──────────────┼────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Drift Database                                 │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                   SQLite (11 tables)                         │    │
│  │  DailyEntries │ WeeklyBriefs │ Problems │ BoardMembers │ ... │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Backend API Server                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                    │
│  │  Auth       │ │  Sync       │ │  AI Proxy   │                    │
│  │  Routes     │ │  Routes     │ │  Routes     │                    │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘                    │
│         │              │              │                              │
│         ▼              ▼              ▼                              │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                   PostgreSQL Database                        │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Test Coverage

**40 Test Files:**

| Test File | Coverage |
|-----------|----------|
| database_test.dart | Table operations, insert/update/delete |
| daily_entry_repository_test.dart | CRUD, date ranges, signals |
| problem_repository_test.dart | Validation, direction changes |
| board_member_repository_test.dart | Roles, anchoring, personas |
| governance_session_repository_test.dart | State machine, transcripts |
| bet_repository_test.dart | Status transitions, expiration |
| user_preferences_repository_test.dart | Settings, onboarding |
| **weekly_brief_repository_test.dart** | CRUD, regeneration limits, streams |
| **evidence_item_repository_test.dart** | CRUD, strength filtering, session queries |
| **portfolio_health_repository_test.dart** | Upsert, trend detection, growth role checks |
| **portfolio_version_repository_test.dart** | Snapshots, versioning, comparisons |
| **resetup_trigger_repository_test.dart** | Triggers, approaching/past due, annual |
| **enums_test.dart** | BetStatus transitions (100%), BoardRoleType, SignalType, ProblemDirection |
| extracted_signal_test.dart | Signal models, JSON serialization |
| signal_extraction_service_test.dart | Claude client, extraction service |
| weekly_brief_generation_service_test.dart | Brief generation, regeneration options |
| quick_version_service_test.dart | State machine, Q&A flow, session data |
| vagueness_detection_service_test.dart | Heuristics, AI detection, edge cases |
| setup_service_test.dart | Portfolio/board creation flow |
| setup_ai_service_test.dart | Board anchoring, persona generation |
| quarterly_service_test.dart | Full quarterly report flow |
| quarterly_ai_service_test.dart | Board interrogation, evidence |
| auth_service_test.dart | OAuth, token management |
| audio_recorder_service_test.dart | Recording, transcription queue |
| transcription_service_test.dart | Deepgram/Whisper integration |
| export_service_test.dart | JSON/Markdown export |
| import_service_test.dart | Data import/restore |
| sync_service_test.dart | Multi-device sync |
| conflict_resolver_test.dart | Conflict resolution strategies |
| brief_scheduler_service_test.dart | Sunday 8pm scheduling |
| privacy_service_test.dart | Abstraction mode |
| **home_screen_test.dart** | HomeScreen widget tests, navigation, UI elements |
| **record_entry_screen_test.dart** | Text entry, word limits, save flow |
| **governance_hub_screen_test.dart** | Tabs, navigation, portfolio gating |
| **settings_screen_test.dart** | Settings sections, privacy toggle, navigation |
| **history_screen_test.dart** | History list, export, pull-to-refresh |
| **entry_review_screen_test.dart** | Entry viewing, edit mode, delete flow |
| **weekly_brief_viewer_screen_test.dart** | Brief display, regeneration, board review |
| **onboarding_test.dart** | Welcome, Privacy, SignIn screens, navigation flow |

---

## File Statistics

| Category | Count | Lines of Code (approx) |
|----------|-------|------------------------|
| Source Files (lib/) | 139 | ~13,000 |
| Test Files (test/) | 40 | ~7,200 |
| Backend Files (backend/) | 18 | ~1,500 |
| **Total Dart Files** | 197 | ~21,700 |

**By Layer:**
- Data Layer: ~35 files (~4,000 LOC)
- Services Layer: ~25 files (~3,500 LOC)
- Providers: ~10 files (~1,500 LOC)
- Router: 2 files (~200 LOC)
- UI/Screens: ~30 files (~4,000 LOC)
- Widgets: ~15 files (~2,000 LOC)
- Models: ~10 files (~1,000 LOC)
- Repository Tests: 12 files (~2,500 LOC)
- Service Tests: 16 files (~2,500 LOC)
- UI Tests: 8 files (~1,400 LOC) - **~60% UI coverage**
- Enum Tests: 1 file (~400 LOC) - **100% coverage on BetStatus transitions**
- Other Tests: 3 files (~300 LOC)

---

## PRD Acceptance Criteria Status

| # | Requirement | Status |
|---|-------------|--------|
| 1 | Daily entry saved reliably with transcript, editable, stored | ✅ Complete |
| 2 | Weekly brief auto-generated Sunday 8pm, 600-800 words | ✅ Complete |
| 3 | Quick Version runs 5 questions with vagueness gating | ✅ Complete |
| 4 | Setup produces portfolio (3-5 problems), 5-7 board roles, personas | ✅ Complete |
| 5 | Quarterly Report with evidence labels, board interrogation, bet | ✅ Complete |
| 6 | Board roles: 5 core always active, 2 growth when appreciating | ✅ Complete |
| 7 | Export works: Markdown sharing, JSON backup/restore | ✅ Complete |
| 8 | Delete data works: single session + full account | ✅ Complete |
| 9 | Multi-device sync with conflict detection | ✅ Complete |
| 10 | Offline mode preserves recording/editing, queues for sync | ✅ Complete |
| 11 | Onboarding gets users to first entry in <60 seconds | ✅ Complete |
| 12 | Portfolio modification: description/allocation edits without re-setup | ✅ Complete |
| 13 | Dark mode follows system setting | ✅ Complete |

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
- record: ^5.1.2
- flutter_secure_storage: ^9.0.0
- workmanager: ^0.5.2
- google_sign_in: ^6.1.6
- sign_in_with_apple: ^5.0.0

**Development:**
- drift_dev: ^2.14.0
- build_runner: ^2.4.7
- json_serializable: ^6.7.1
- flutter_lints: ^3.0.1
- mockito: ^5.4.4

---

## Post-MVP Considerations

The following features are explicitly out of scope for MVP (per PRD Section 2.2):

- Push notifications/reminders
- Calendar/email integrations
- PDF export
- Web app
- Attachments/file uploads
- Search/filter in History
- Tablet-optimized layouts

---

## Recent Fixes

- **Import Path Correction (Jan 11, 2026):** Fixed incorrect `package:board_journal` imports to `package:boardroom_journal` in 4 test files:
  - `test/services/setup_service_test.dart`
  - `test/services/quarterly_service_test.dart`
  - `test/services/ai/setup_ai_service_test.dart`
  - `test/services/ai/quarterly_ai_service_test.dart`

---

*Last updated: January 11, 2026*
