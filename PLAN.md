# Boardroom Journal - Implementation Plan

**Created:** January 10, 2026
**PRD Version:** v5
**Current Status:** Phase 4 Complete (Quick Version State Machine)

---

## Executive Summary

Boardroom Journal is a Flutter mobile app for voice-first career journaling with AI-powered governance. The core data layer, text entry flow, AI signal extraction, weekly brief generation, and Quick Version (15-min audit) are complete. The remaining work focuses on: Setup state machine (portfolio + board creation), Quarterly Report, voice recording, backend/sync, and production readiness features.

This plan divides the remaining work into 9 phases (with Phase 12 split into 12a/12b for context management), each independently testable and deployable, with clear acceptance criteria and dependencies.

---

## Phase Overview Table

| Phase | Name | Key Deliverable | Dependencies | Complexity | Est. Tokens |
|-------|------|-----------------|--------------|------------|-------------|
| 5 | Setup State Machine | Portfolio + Board creation with personas | Phase 4 | High | 50-65K |
| 6 | Quarterly Report | Full board interrogation and bet tracking | Phase 5 | High | 55-70K |
| 7 | Voice Recording | Deepgram transcription with waveform UI | None | Medium | 30-40K |
| 8 | History & Export | Combined history view, JSON/Markdown export | Phase 5 | Low | 20-30K |
| 9 | Settings Implementation | All settings sections functional | Phase 5 | Medium | 30-40K |
| 10 | Brief Scheduling | Sunday 8pm auto-generation | None | Low | 15-25K |
| 11 | Onboarding & Auth | OAuth sign-in, onboarding flow | None | Medium | 35-45K |
| 12a | Backend API Server | Docker, database, REST endpoints | Phase 11 | Medium | 35-45K |
| 12b | Client Sync Integration | Sync service, conflict resolution, queue | Phase 12a | Medium | 35-45K |

---

## Current State Summary

### Completed (Phases 1-4)

| Component | Status | Notes |
|-----------|--------|-------|
| Flutter project setup | Complete | Material 3, Drift ORM, build_runner |
| Database schema (11 tables) | Complete | All sync columns included |
| Repository layer (12 repos) | Complete | Full CRUD + reactive streams |
| Riverpod providers (40+) | Complete | Stream, Future, Repository providers |
| Navigation (go_router) | Complete | All routes defined |
| Home screen | Complete | Real data, all CTAs working |
| Record Entry screen | Complete | Text entry; voice placeholder |
| Entry Review screen | Complete | View, edit, delete with signals |
| Weekly Brief viewer | Complete | Regeneration, export, board micro-review |
| Quick Version state machine | Complete | Full 5-question flow with vagueness detection |
| AI Services | Complete | Signal extraction, brief gen, vagueness detection |

### Incomplete (Phases 5-12)

| Component | Status | Notes |
|-----------|--------|-------|
| Setup (Portfolio + Board) | Scaffold only | State machine not implemented |
| Quarterly Report | Scaffold only | State machine not implemented |
| Voice recording | Placeholder | No audio recording/transcription |
| Settings | UI complete | All features show "coming soon" |
| History screen | Partial | Entries only, no briefs/pagination |
| Brief scheduling | Not started | No Sunday 8pm auto-generation |
| Onboarding | Not started | No OAuth, no privacy acceptance |
| Backend/Sync | Not started | No API server, no multi-device sync |
| Export/Import | Not started | No JSON/Markdown export |

---

## Requirements Matrix

### PRD Section 7 - Acceptance Criteria

| # | Requirement | Status | Phase |
|---|-------------|--------|-------|
| 1 | Daily entry saved reliably with transcript, editable, stored | Complete | 4 |
| 2 | Weekly brief auto-generated Sunday 8pm, 600-800 words | Partial (manual only) | 10 |
| 3 | Quick Version runs 5 questions with vagueness gating | Complete | 4 |
| 4 | Setup produces portfolio (3-5 problems), 5-7 board roles, personas | Not Started | 5 |
| 5 | Quarterly Report with evidence labels, board interrogation, bet | Not Started | 6 |
| 6 | Board roles: 5 core always active, 2 growth when appreciating | Not Started | 5 |
| 7 | Export works: Markdown sharing, JSON backup/restore | Not Started | 8 |
| 8 | Delete data works: single session + full account | Not Started | 9 |
| 9 | Multi-device sync with conflict detection | Not Started | 12b |
| 10 | Offline mode preserves recording/editing, queues for sync | Partial | 12b |
| 11 | Onboarding gets users to first entry in <60 seconds | Not Started | 11 |
| 12 | Portfolio modification: description/allocation edits without re-setup | Not Started | 5 |
| 13 | Dark mode follows system setting | Complete | 4 |

---

## Dependency Graph

```
Phase 5: Setup State Machine
    ├── Phase 6: Quarterly Report (requires portfolio + board)
    ├── Phase 8: History & Export (requires portfolio versions)
    └── Phase 9: Settings (requires board personas for editing)

Phase 7: Voice Recording (independent)
Phase 10: Brief Scheduling (independent)

Phase 11: Onboarding & Auth (independent, but needed for Phase 12a)
    └── Phase 12a: Backend API Server
        └── Phase 12b: Client Sync Integration
```

---

## Risk Assessment

### High Risk
| Risk | Impact | Mitigation |
|------|--------|------------|
| Setup state machine complexity | Could exceed context limits | Break into sub-phases; clear state definitions |
| Quarterly Report length | 15+ questions is context-heavy | Careful state management; persist after each Q |
| Claude API costs at scale | May exceed budget | Monitor usage; implement caching for repeated prompts |

### Medium Risk
| Risk | Impact | Mitigation |
|------|--------|------------|
| Voice recording cross-platform | iOS/Android audio differences | Use proven package (record); extensive testing |
| Deepgram integration | Dependency on external service | Implement Whisper fallback per PRD |
| OAuth complexity | 3 providers to support | Start with one (Apple); add others incrementally |

### Low Risk
| Risk | Impact | Mitigation |
|------|--------|------------|
| Brief scheduling reliability | May miss Sunday 8pm | Use platform-native scheduling; background processing |
| Export format changes | Could break imports | Version export format; validate on import |

---

## Detailed Phase Breakdowns

---

### Phase 5: Setup State Machine

**Objective:** Implement the full Setup workflow that creates a problem portfolio and instantiates 5-7 board members with personas.

**Prerequisites:** Phase 4 complete (Quick Version working)

**Deliverables:**
- `lib/services/governance/setup_state.dart` - State enum and session data model
- `lib/services/governance/setup_service.dart` - State machine orchestration
- `lib/services/ai/setup_ai_service.dart` - AI for portfolio health and board anchoring
- `lib/ui/screens/governance/setup/` - UI components (multi-file):
  - `setup_screen.dart` - Main screen with state routing
  - `sensitivity_gate_view.dart` - Privacy gate (reuse from Quick Version)
  - `problem_form_view.dart` - Single problem input with validation
  - `time_allocation_view.dart` - Slider UI with live sum validation
  - `portfolio_health_view.dart` - Health display
  - `board_roster_view.dart` - Board members with anchoring
  - `persona_preview_view.dart` - Persona display with edit option
  - `setup_output_view.dart` - Final summary with export
- `lib/providers/setup_providers.dart` - Setup-specific providers
- `test/services/setup_service_test.dart` - State machine tests
- `test/services/ai/setup_ai_service_test.dart` - AI service tests

**State Machine Flow:**
```
Initial → SensitivityGate
    → CollectProblem1 → ValidateProblem1
    → CollectProblem2 → ValidateProblem2
    → CollectProblem3 → ValidateProblem3
    → (optional) CollectProblem4 → ValidateProblem4
    → (optional) CollectProblem5 → ValidateProblem5
    → PortfolioCompleteness (3-5 problems required)
    → TimeAllocationValidation (95-105%, yellow 90-110%)
    → CalculatePortfolioHealth
    → CreateCoreRoles (5 roles with anchoring)
    → CreateGrowthRoles (0-2 if appreciating problems exist)
    → CreatePersonas (one per role)
    → DefineReSetupTriggers
    → PublishPortfolio (save version snapshot)
    → Finalized
```

**Problem Field Requirements (per PRD 4.4):**
- Name (required)
- "What breaks if not solved" (required)
- Scarcity signals: 2 items OR "Unknown + why" (required)
- Direction evidence for AI cheaper, Error cost, Trust required (required)
- Classification: Appreciating/Depreciating/Stable + rationale (required)
- Time allocation percentage (required)

**Time Allocation Validation:**
- 95-105%: Green, proceed
- 90-94% or 106-110%: Yellow warning, allow proceed
- <90% or >110%: Red error, block proceed

**Board Role Creation:**
- Core roles (always): Accountability, Market Reality, Avoidance, Long-term Positioning, Devil's Advocate
- Growth roles (if appreciating problems): Portfolio Defender, Opportunity Scout
- Each role anchored to specific problem with specific demand
- AI generates anchoring based on portfolio content

**Acceptance Criteria:**
- [ ] User can create 3-5 problems with all required fields
- [ ] Time allocation validation works with color coding
- [ ] Portfolio health calculated and displayed
- [ ] 5 core board members created and anchored
- [ ] 2 growth board members created if appreciating problems exist
- [ ] Each role has AI-generated persona with name and profile
- [ ] Original personas stored for reset capability
- [ ] Re-setup triggers defined with specific conditions
- [ ] Annual trigger set to 12 months from setup
- [ ] Portfolio version snapshot created on completion
- [ ] Session can be abandoned and resumed
- [ ] All tests pass

**Estimated Complexity:** High (10-15 source files, complex state machine, AI integration)

---

### Phase 6: Quarterly Report

**Objective:** Implement the full Quarterly Report workflow with board interrogation and bet tracking.

**Prerequisites:** Phase 5 complete (Setup working, portfolio exists)

**Deliverables:**
- `lib/services/governance/quarterly_state.dart` - State enum and session data
- `lib/services/governance/quarterly_service.dart` - State machine orchestration
- `lib/services/ai/quarterly_ai_service.dart` - AI for evidence evaluation, report generation
- `lib/ui/screens/governance/quarterly/` - UI components:
  - `quarterly_screen.dart` - Main screen with state routing
  - `bet_evaluation_view.dart` - Last bet CORRECT/WRONG/EXPIRED
  - `commitments_view.dart` - Commitments vs actuals
  - `evidence_input_view.dart` - Evidence with strength labeling
  - `portfolio_health_update_view.dart` - Trend vs previous quarter
  - `board_interrogation_view.dart` - One question at a time per role
  - `trigger_check_view.dart` - Re-setup trigger status
  - `next_bet_view.dart` - New bet with wrong-if condition
  - `quarterly_output_view.dart` - Final report with export
- `lib/providers/quarterly_providers.dart` - Quarterly-specific providers
- `test/services/quarterly_service_test.dart` - State machine tests

**State Machine Flow (per PRD 4.5):**
```
Initial → SensitivityGate
    → Gate0 (require portfolio + board + triggers)
    → Q1 LastBetEvaluation
    → Q2 CommitmentsVsActuals
    → Q3 AvoidedDecision
    → Q4 ComfortWork
    → Q5 PortfolioCheck (direction shifts + allocation changes)
    → Q6 PortfolioHealthUpdate (trend analysis)
    → Q7 ProtectionCheck (if growth roles active)
    → Q8 OpportunityCheck (if growth roles active)
    → Q9 ReSetupTriggerCheck
    → Q10 NextBet
    → CoreBoardInterrogation (5 roles, one question each)
    → GrowthBoardInterrogation (0-2 roles, if active)
    → GenerateReport
    → Finalized
```

**Evidence Enforcement:**
- Decision/Artifact = Strong
- Proxy = Medium
- Calendar-only = Weak (explicitly called out)
- No receipt = None (recorded, not "fixed")

**Eligibility Rules:**
- On-demand, any time
- Warning if <30 days since last report
- Warning is non-blocking

**Acceptance Criteria:**
- [ ] Gate blocks without portfolio/board/triggers
- [ ] Last bet can be evaluated as CORRECT/WRONG
- [ ] Evidence items captured with strength labels
- [ ] Portfolio health trend calculated vs previous quarter
- [ ] Each core role asks their anchored question
- [ ] Each growth role asks (if active)
- [ ] Vagueness gates enforced during board interrogation
- [ ] Re-setup trigger status displayed
- [ ] Flag shown if any trigger is met
- [ ] Next bet created with wrong-if condition
- [ ] Full report generated with all sections
- [ ] <30 day warning shown (non-blocking)
- [ ] All tests pass

**Estimated Complexity:** High (10-12 source files, 15+ state transitions, complex interrogation logic)

---

### Phase 7: Voice Recording

**Objective:** Implement voice recording with Deepgram transcription and waveform visualization.

**Prerequisites:** None (can run in parallel with Phase 5-6)

**Deliverables:**
- `lib/services/audio/audio_recorder_service.dart` - Recording with record package
- `lib/services/audio/waveform_data.dart` - Audio visualization data
- `lib/services/ai/transcription_service.dart` - Deepgram API integration
- `lib/ui/widgets/waveform_widget.dart` - Audio waveform visualization
- `lib/ui/widgets/silence_countdown_widget.dart` - 8-second countdown
- Updated `lib/ui/screens/record_entry/record_entry_screen.dart` - Voice mode
- `lib/providers/audio_providers.dart` - Audio state management
- `test/services/audio/audio_recorder_service_test.dart` - Recording tests
- `test/services/ai/transcription_service_test.dart` - Transcription tests

**Recording Flow (per PRD 4.1):**
```
Idle → Recording (tap record)
    → Transcribing (tap stop OR 8-second silence)
    → EditTranscript (show full transcript)
    → GapCheck → FollowUp (0-3 questions)
    → ConfirmSave → Saved
```

**Features:**
- Max 15 minutes per recording
- Warning at 12 minutes
- Auto-stop at 15 minutes
- 8-second silence timeout with visual countdown in last 3 seconds
- Audio waveform visualization during recording
- Batch transcription (not streaming)
- Target <2 seconds from stop to transcript display
- Audio deleted after successful transcription
- Audio retained if transcription fails

**Deepgram Integration:**
- Nova-2 model
- Retry with exponential backoff (1s, 2s, 4s)
- Fallback to OpenAI Whisper on 3+ failures

**Acceptance Criteria:**
- [ ] Voice recording works on iOS and Android
- [ ] Waveform visualization displays during recording
- [ ] Timer shows recording duration
- [ ] Warning at 12 minutes
- [ ] Auto-stop at 15 minutes
- [ ] 8-second silence triggers countdown
- [ ] Transcription completes in <2 seconds typical
- [ ] Transcript appears with smooth fade-in
- [ ] Recording sounds play on start/stop
- [ ] Audio deleted after successful transcription
- [ ] Failed transcriptions retain audio for retry
- [ ] Whisper fallback works when Deepgram fails
- [ ] Offline recording queues for later transcription
- [ ] All tests pass

**Estimated Complexity:** Medium (7-8 source files, platform-specific audio handling)

---

### Phase 8: History & Export

**Objective:** Complete history screen with combined entries/briefs and implement data export/import.

**Prerequisites:** Phase 5 complete (portfolio versions for export)

**Deliverables:**
- Updated `lib/ui/screens/history/history_screen.dart` - Combined chronological list
- `lib/services/export/export_service.dart` - JSON and Markdown export
- `lib/services/export/import_service.dart` - JSON import with validation
- `lib/models/export_format.dart` - Export data models
- `test/services/export/export_service_test.dart` - Export tests
- `test/services/export/import_service_test.dart` - Import tests

**History Features (per PRD 5.10):**
- Single reverse-chronological list
- Type indicator icons (entry, brief, governance report)
- Preview text (first 50 chars for entries)
- Pull-to-refresh
- Pagination for performance
- Tap to open full view

**Export Format (JSON):**
```json
{
  "version": "1.0",
  "exportedAt": "2026-01-10T12:00:00Z",
  "data": {
    "dailyEntries": [...],
    "weeklyBriefs": [...],
    "problems": [...],
    "portfolioVersions": [...],
    "boardMembers": [...],
    "governanceSessions": [...],
    "bets": [...],
    "evidenceItems": [...],
    "reSetupTriggers": [...],
    "userPreferences": {...}
  }
}
```

**Acceptance Criteria:**
- [ ] History shows entries, briefs, and governance reports
- [ ] Items sorted by date, most recent first
- [ ] Type distinguishable via icon
- [ ] Pull-to-refresh works
- [ ] Pagination loads more items on scroll
- [ ] JSON export includes all user data
- [ ] Markdown export includes human-readable content
- [ ] JSON import validates format before importing
- [ ] Import shows preview of data to be imported
- [ ] Import handles conflicts (overwrite/skip/merge options)
- [ ] All tests pass

**Estimated Complexity:** Low (4-5 source files, straightforward data transformation)

---

### Phase 9: Settings Implementation

**Objective:** Make all settings sections fully functional.

**Prerequisites:** Phase 5 complete (board personas for editing)

**Deliverables:**
- Updated `lib/ui/screens/settings/settings_screen.dart` - Functional settings
- `lib/ui/screens/settings/persona_editor_screen.dart` - Edit board personas
- `lib/ui/screens/settings/portfolio_editor_screen.dart` - Edit portfolio
- `lib/ui/screens/settings/version_history_screen.dart` - View portfolio versions
- `lib/services/settings/privacy_service.dart` - Privacy settings management
- Updated providers for settings state

**Settings Sections:**

**Account:**
- Sign-in methods display (stubbed until auth)
- Active sessions display (stubbed until auth)
- Delete account with 7-day grace period (stubbed until auth)

**Privacy:**
- Abstraction mode toggle (persisted)
- Analytics toggle (persisted)

**Data:**
- Export All Data → triggers JSON export from Phase 8
- Import Data → triggers import from Phase 8
- Delete All Data with confirmation

**Board:**
- View all board personas
- Edit persona (name, background, style, phrase)
- Reset individual persona to default
- Reset all personas to defaults

**Portfolio:**
- Version history (view past versions, compare)
- Edit problems (description, allocation without re-setup)
- Delete problem (min 3 enforced, re-anchoring flow)
- View re-setup triggers

**About:**
- Version number from pubspec
- Terms of Service (web link)
- Privacy Policy (web link)
- Send Feedback (email/form)
- Open Source Licenses (built-in Flutter page)

**Acceptance Criteria:**
- [ ] Abstraction mode toggle persists
- [ ] Analytics toggle persists
- [ ] Delete All Data works with confirmation
- [ ] Board personas editable
- [ ] Individual persona reset works
- [ ] All personas reset works
- [ ] Portfolio version history viewable
- [ ] Two versions comparable side-by-side
- [ ] Problem descriptions editable
- [ ] Time allocations adjustable (95-105% validation)
- [ ] Problem deletion works with min 3 enforcement
- [ ] Deleted problem triggers re-anchoring for affected roles
- [ ] Re-setup triggers viewable with status
- [ ] About section shows correct version
- [ ] All tests pass

**Estimated Complexity:** Medium (6-8 source files, UI-heavy, moderate logic)

---

### Phase 10: Brief Scheduling

**Objective:** Implement automatic weekly brief generation on Sunday 8pm local time.

**Prerequisites:** None (can run in parallel)

**Deliverables:**
- `lib/services/scheduling/brief_scheduler_service.dart` - Scheduling logic
- `lib/services/scheduling/background_task_handler.dart` - Background execution
- Platform-specific configuration for background tasks
- Updated `lib/main.dart` - Initialize scheduler

**Scheduling Approach:**
- Use flutter_background_service or workmanager package
- Schedule for Sunday 8pm in device timezone
- Handle timezone changes gracefully
- Retry on failure with exponential backoff

**Acceptance Criteria:**
- [ ] Brief auto-generates at Sunday 8pm local
- [ ] Handles timezone changes
- [ ] Works when app is in background
- [ ] Works when app is closed (Android)
- [ ] iOS limitations documented (more restricted)
- [ ] Manual trigger still works
- [ ] Failed generation retries automatically
- [ ] User notified of new brief on next app open
- [ ] All tests pass

**Estimated Complexity:** Low (2-3 source files, platform-specific configuration)

---

### Phase 11: Onboarding & Auth

**Objective:** Implement OAuth sign-in and minimal onboarding flow.

**Prerequisites:** None

**Deliverables:**
- `lib/ui/screens/onboarding/` - Onboarding screens:
  - `welcome_screen.dart` - Value proposition (1 screen)
  - `privacy_screen.dart` - Terms and privacy acceptance
  - `signin_screen.dart` - OAuth buttons
- `lib/services/auth/auth_service.dart` - OAuth handling
- `lib/services/auth/token_storage.dart` - Secure token storage
- `lib/providers/auth_providers.dart` - Auth state
- Platform-specific OAuth configuration (iOS, Android)
- Updated router for auth flow

**OAuth Providers:**
- Apple Sign-In (required for iOS App Store)
- Google Sign-In
- Microsoft Sign-In

**Token Management:**
- Access token: 15-minute expiry (JWT)
- Refresh token: 30-day expiry (opaque)
- Stored in Keychain (iOS) / Keystore (Android)
- Proactive refresh when <5 minutes remaining

**Onboarding Flow (per PRD 5.0):**
```
Welcome → Privacy → OAuth → First Entry
```
- 3 screens before sign-in
- Setup deferred until 3-5 entries
- Target: first entry in <60 seconds

**Acceptance Criteria:**
- [ ] Welcome screen shows value proposition
- [ ] Privacy screen requires acceptance before proceeding
- [ ] Apple Sign-In works on iOS
- [ ] Google Sign-In works on both platforms
- [ ] Microsoft Sign-In works on both platforms
- [ ] Tokens stored securely
- [ ] Token refresh works proactively
- [ ] New user reaches first entry in <60 seconds
- [ ] Returning user bypasses onboarding
- [ ] All tests pass

**Estimated Complexity:** Medium (8-10 source files, OAuth complexity)

---

### Phase 12a: Backend API Server

**Objective:** Implement the backend REST API server with authentication and sync endpoints.

**Prerequisites:** Phase 11 complete (auth flow defined, tokens understood)

**Deliverables:**
- `backend/` - Server implementation:
  - `backend/Dockerfile` - Container configuration
  - `backend/docker-compose.yml` - Local development setup
  - `backend/src/server.dart` (or `index.js`) - Main entry point
  - `backend/src/routes/auth.dart` - OAuth callback, token refresh
  - `backend/src/routes/sync.dart` - Sync endpoints
  - `backend/src/routes/account.dart` - Account management
  - `backend/src/routes/ai.dart` - AI proxy endpoints
  - `backend/src/middleware/auth.dart` - JWT validation
  - `backend/src/db/schema.sql` - PostgreSQL schema
  - `backend/src/db/migrations/` - Database migrations
- `backend/tests/` - API tests
- Deployment configuration (Railway/Render/Cloud Run)

**API Endpoints (per PRD 3A.2):**
| Category | Endpoints | Purpose |
|----------|-----------|---------|
| Auth | `POST /auth/oauth/{provider}` | Exchange OAuth code for tokens |
| Auth | `POST /auth/refresh` | Refresh access token |
| Auth | `GET /auth/session` | Validate session |
| Sync | `GET /sync?since={timestamp}` | Get changes since timestamp |
| Sync | `POST /sync` | Push local changes |
| Sync | `GET /sync/full` | Full data download |
| AI | `POST /ai/transcribe` | Proxy to Deepgram |
| AI | `POST /ai/extract` | Proxy to Claude for signals |
| AI | `POST /ai/generate` | Proxy to Claude for briefs |
| Account | `GET /account` | Get account info |
| Account | `DELETE /account` | Delete account (7-day grace) |
| Account | `GET /account/export` | Export all data |

**Database Schema:**
- Mirror of Drift tables with server-side columns
- `users` table for account management
- `sync_log` for change tracking
- Indexes for efficient sync queries

**Security (per PRD 3D):**
- JWT validation on all protected routes
- Rate limiting (3 accounts/IP/hour, 5 failed auth = 15-min lockout)
- Input validation (max 10MB requests)
- HTTPS only, TLS 1.2+

**Acceptance Criteria:**
- [ ] Docker container builds and runs
- [ ] PostgreSQL schema creates successfully
- [ ] OAuth endpoints exchange codes for tokens
- [ ] Token refresh works correctly
- [ ] Sync GET returns changes since timestamp
- [ ] Sync POST accepts and stores changes
- [ ] AI endpoints proxy to external services
- [ ] Account deletion triggers 7-day grace period
- [ ] Rate limiting enforced
- [ ] All API tests pass
- [ ] Deploys to cloud platform successfully

**Estimated Complexity:** Medium (8-10 backend files, straightforward REST patterns)

---

### Phase 12b: Client Sync Integration

**Objective:** Integrate the Flutter client with the backend sync API.

**Prerequisites:** Phase 12a complete (backend API running)

**Deliverables:**
- `lib/services/api/api_client.dart` - HTTP client with auth headers
- `lib/services/api/api_config.dart` - Base URL, timeout configuration
- `lib/services/sync/sync_service.dart` - Sync orchestration
- `lib/services/sync/sync_queue.dart` - Offline change queue
- `lib/services/sync/conflict_resolver.dart` - Last-write-wins with notification
- `lib/providers/sync_providers.dart` - Sync state management
- Updated repositories with sync status tracking
- `lib/ui/widgets/sync_indicator.dart` - Sync status UI
- `test/services/sync/sync_service_test.dart` - Sync tests
- `test/services/sync/conflict_resolver_test.dart` - Conflict tests

**Sync Strategy (per PRD 3B.2):**
- Local-first SQLite (existing)
- Sync triggers:
  - App launch
  - Pull-to-refresh
  - After local changes (debounced)
  - Every 5 minutes while foregrounded
- Last-write-wins conflict resolution
- User notification on conflict

**Sync Queue Priority:**
1. Auth refresh (if needed)
2. Transcription requests
3. Signal extraction requests
4. Local edits (entries, briefs)
5. Server changes download

**Offline Behavior (per PRD 3F):**
- Queue all changes locally when offline
- Process queue when connectivity returns
- Never delete local data on sync failure
- Visual indicator for pending sync items

**Conflict Resolution:**
- Compare `serverVersion` on push
- If mismatch, fetch latest and compare timestamps
- Last-write-wins with notification:
  - "This entry was also edited on your other device. Showing most recent version."
- Log overwritten version for potential recovery

**Acceptance Criteria:**
- [ ] API client handles auth headers correctly
- [ ] Token refresh triggers automatically when <5 min remaining
- [ ] Sync on app launch fetches latest changes
- [ ] Pull-to-refresh triggers sync
- [ ] Local changes queue when offline
- [ ] Queue processes when connectivity returns
- [ ] Periodic sync (5 min) works while foregrounded
- [ ] Conflict detection works correctly
- [ ] User notified of conflicts with clear message
- [ ] Sync indicator shows pending/syncing/synced states
- [ ] Entry-level sync status badges display correctly
- [ ] Multi-device scenario tested end-to-end
- [ ] All tests pass

**Estimated Complexity:** Medium (8-10 source files, careful state management)

---

## Test Coverage Targets

Per PRD Section 10:

| Layer | Target | Current | Notes |
|-------|--------|---------|-------|
| Business logic | 80% | ~70% | State machines need more tests |
| Data layer | 70% | ~60% | Sync logic pending |
| UI | 50% | ~20% | Widget tests needed |
| AI integrations | 60% | ~50% | Mock providers complete |
| Overall | 70% | ~50% | Will improve with each phase |

**Must-Test (100% coverage required):**
- State machines (all transitions)
- Validation rules (time allocation, field limits)
- Bet status transitions
- Conflict resolution

---

## Open Questions

1. **Backend technology choice:** Dart (Shelf/Dart Frog) vs Node.js (Express)? Dart keeps the stack unified but Node.js has more ecosystem support.

2. **OAuth provider priority:** Start with Apple (required for iOS) or Google (more common)? Recommendation: Apple first for App Store compliance.

3. **Voice recording package:** `record` vs `flutter_sound`? Both have tradeoffs for cross-platform audio.

4. **Background brief generation on iOS:** iOS heavily restricts background processing. May need to rely on significant location changes or push notifications as triggers. Acceptable to generate on next app open if background fails?

5. **Backend hosting:** Railway, Render, or Cloud Run for initial deployment? Docker-based for portability.

---

## Execution Notes

### Per-Phase Workflow

1. **Create feature branch:** `phase-N-brief-descriptor`
2. **Implement deliverables** following existing code patterns
3. **Write/update tests** for all new functionality
4. **Run full test suite** - all tests must pass
5. **Update PROGRESS.md** with completed items
6. **Create PR** with summary and test results
7. **Merge to main** after review
8. **Delete feature branch**
9. **Update this PLAN.md** with completion status

### Code Conventions

- Follow existing patterns in codebase
- Use Riverpod for state management
- Use Drift for database operations
- Use go_router for navigation
- AI services go in `lib/services/ai/`
- Governance state machines go in `lib/services/governance/`
- Keep UI components small and focused
- Write tests alongside implementation

### Context Management

Each phase targets ~100K tokens of working context:
- Break large features into sub-tasks
- Commit frequently to preserve progress
- Test incrementally rather than all at end
- Document complex logic with comments

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1 | 2026-01-10 | Split Phase 12 into 12a (Backend) and 12b (Client Sync) to fit 100K token constraint |
| 1.0 | 2026-01-10 | Initial plan created from PRD v5 analysis |

---

*This plan is a living document. Update as implementation progresses.*
