# Changelog

All notable changes to Boardroom Journal will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Phase 14: Technical Debt Remediation
  - Security hardening (production guards, Apple JWKS verification, client secret generation)
  - Code quality improvements (AuthService split into focused services, widget extraction)
  - Performance optimizations (batch sync, timer disposal audit, UUID v4 tokens)
  - Developer experience (E2E tests, pre-commit hooks, coverage thresholds, ADRs)
- Integration test suite (`integration_test/app_test.dart`)
- Architecture Decision Records (`docs/adr/`)
- Pre-commit hooks via Lefthook (`lefthook.yml`)

### Changed
- AuthService refactored into facade pattern with:
  - `oauth_service.dart` - OAuth provider flows
  - `token_refresh_service.dart` - Token lifecycle management
  - `session_manager.dart` - Session state management
- RecordEntryScreen reduced from 1317 to 314 lines (widgets extracted)
- GovernanceHubScreen reduced from 1002 to 56 lines (widgets extracted)
- CI pipeline now includes backend tests and coverage thresholds

### Fixed
- Token generation now uses cryptographic randomness (UUID v4)
- All timers properly disposed in service cleanup
- Silent exceptions now logged for debugging

## [1.0.0] - 2026-01-11

### Added
- Phase 13: Frontend Visual Overhaul
  - Custom "Boardroom Executive" design system
  - Fraunces + Inter typography pairing
  - Signal cards with distinctive styling
  - Smooth animations and transitions
- Phase 12b: Client Sync Integration
  - Multi-device sync with conflict resolution
  - Offline queue with automatic retry
  - Sync status indicators
- Phase 12a: Backend API Server
  - Docker containerized Dart backend
  - PostgreSQL database schema
  - OAuth token exchange endpoints
  - Sync API with conflict detection
- Phase 11: Onboarding & Authentication
  - Apple Sign-In (iOS App Store compliant)
  - Google Sign-In
  - Microsoft Sign-In (placeholder)
  - Local-only mode
  - Token refresh with proactive renewal
- Phase 10: Brief Scheduling
  - Sunday 8pm auto-generation
  - Background task support (WorkManager)
  - Timezone-aware scheduling
- Phase 9: Settings Implementation
  - Account management
  - Privacy controls (abstraction mode, analytics)
  - Board persona editing
  - Portfolio version history
- Phase 8: History & Export
  - Combined history view (entries, briefs, reports)
  - JSON and Markdown export
  - Import with conflict handling
- Phase 7: Voice Recording
  - Deepgram Nova-2 transcription
  - Whisper fallback
  - Waveform visualization
  - Silence detection with countdown
- Phase 6: Quarterly Report
  - Full board interrogation
  - Evidence-based review
  - Bet evaluation (CORRECT/WRONG/EXPIRED)
  - Portfolio health trends
- Phase 5: Setup State Machine
  - Portfolio creation (3-5 problems)
  - 5 core + 2 growth board roles
  - AI-generated personas
  - Re-setup triggers

### Technical Foundation
- Flutter 3.24.0 with Dart 3.2.0+
- Drift ORM with SQLite
- Riverpod state management
- go_router navigation
- 1761 tests (1718 Flutter + 43 backend)

---

*Built with Claude Code*
