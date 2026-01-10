# Boardroom Journal

A voice-first journal that turns your week into an executive brief (600-800 words) and runs a receipts-based career governance system using a 5-7 role AI board (5 core + 2 conditional growth roles) with distinct personas.

## Tech Stack

- **Mobile:** Flutter with Drift ORM
- **Platforms:** iOS + Android (phone-optimized; tablet deferred)
- **AI/LLM:** Claude Opus 4.5 (governance) / Sonnet 4.5 (daily operations)
- **Speech-to-Text:** Deepgram Nova-2
- **Local Storage:** SQLite via Drift
- **Sync:** Custom multi-device sync API
- **Export:** Markdown + JSON

## Core Loop

**Daily capture → Weekly brief → Board governance sessions (Quick / Setup / Quarterly) → portfolio + bets updated → repeat**

## Features

### Daily Journal Entry
- Voice capture with batch transcription (< 2s target)
- Text entry as first-class alternative
- Editable transcripts with 7 extracted signal types:
  - Wins (completed accomplishments)
  - Blockers (current obstacles)
  - Risks (potential future problems)
  - Avoided Decision (decisions being put off)
  - Comfort Work (feels productive but doesn't advance goals)
  - Actions (forward commitments)
  - Learnings/Insights (realizations and reflections)
- Smart follow-up questions to fill gaps (max 3, skippable)
- **Limits:** 10 entries/day (soft), 15 min per recording, 7500 words per entry
- Entries editable indefinitely (no time-based locking)

### Weekly Brief
- Auto-generates Sunday 8pm local time
- Executive summary (target ~600 words, max 800):
  - Headline (max 2 sentences)
  - Wins/Blockers/Risks (max 3 bullets each)
  - Open Loops (max 5 bullets)
  - Next Week Focus (top 3)
  - Avoided Decision + Comfort Work (1 each)
- **Board Micro-Review:** One sentence from each active board role (5-7 sentences)
- Zero-entry weeks get a reflection brief with prompts
- Regeneration options: shorter, more actionable, more strategic (5 per brief)
- Export: Markdown or JSON with metadata

### Career Governance

#### Quick Version (15-min Audit)
5-question audit with anti-vagueness enforcement:
1. Role Context
2. Paid Problems (3)
3. Problem Direction Loop (AI cheaper? Error cost? Trust required?)
4. Avoided Decision
5. Comfort Work

Outputs: 2-sentence honest assessment, avoided decision + cost, 90-day prediction with falsifiable "wrong-if" criteria.

#### Setup (Portfolio + Board)
- Define 3-5 career problems with time allocation (must sum to 95-105%)
- Portfolio health metrics (appreciating/depreciating/stable percentages)
- 5 core board members + 2 growth roles (if appreciating problems exist)
- Each board member anchored to a specific problem with specific demand
- Customizable personas (reset to defaults available)
- Re-setup triggers defined with 12-month mandatory refresh
- **Deferred until 3-5 entries** (journaling works without Setup)

#### Portfolio Modification
- Edit problem descriptions and time allocations without full re-setup
- Delete problems (minimum 3 enforced)
- Direction changes require re-setup
- Deleted problems trigger AI-powered re-anchoring for affected board roles

#### Quarterly Report
- On-demand (warning if < 30 days since last)
- Evidence-based review with strength labels (Strong/Medium/Weak/None)
- Last bet evaluation
- Commitments vs actuals
- Portfolio health trend vs. previous quarter
- Core board interrogation (5 roles)
- Growth board interrogation (0-2 roles if active)
- Re-setup trigger check
- Next quarter bet with falsifiable criteria

### Board Roles

**Core Roles (always active):**
| Role | Function |
|------|----------|
| Accountability | Demands receipts for stated commitments |
| Market Reality | Challenges direction classifications |
| Avoidance | Probes avoided decisions |
| Long-term Positioning | Asks 5-year strategic questions |
| Devil's Advocate | Argues against user's strongest assumptions |

**Growth Roles (active when appreciating problems exist):**
| Role | Function |
|------|----------|
| Portfolio Defender | Protects and compounds strengths |
| Opportunity Scout | Identifies adjacent opportunities |

### Bet Tracking
- Status: OPEN → CORRECT / WRONG / EXPIRED
- Auto-expiration at due date (no grace period)
- In-app prompts for evaluation (no push notifications for MVP)
- Retroactive evaluation encouraged during quarterly review

## Onboarding

Minimal 3-screen flow:
1. Welcome (value proposition)
2. Privacy acceptance
3. OAuth sign-in
4. → First entry

Setup deferred until 3-5 entries completed.

## Authentication

OAuth sign-in: Apple / Google / Microsoft (email-based account linking)

## Offline Support

**Works offline:**
- Voice recording (queued for transcription)
- Text entry (queued for extraction)
- View/edit past entries and briefs
- View portfolio and board

**Requires online:**
- Transcription, extraction, brief generation
- Governance sessions
- Account actions

## Privacy & Security

- **No AI training:** Journal data never used to train models
- **Audio:** Deleted immediately after successful transcription
- **Storage:** Text transcripts and generated artifacts only
- **Encryption:** At rest (platform APIs + SQLCipher) and in transit (TLS 1.2+)
- **Abstraction Mode:** Auto-strips names/companies with placeholders
- **Data export:** Full JSON export (GDPR Article 20 compliant)
- **Delete account:** 7-day grace period, full purge within 30 days
- **Analytics:** Privacy-focused, opt-out available, no PII tracked

## Settings

- **Account:** OAuth providers, active sessions, delete account
- **Privacy:** Abstraction mode defaults, audio retention, analytics opt-out
- **Data:** Export (JSON/Markdown), import, delete all
- **Board:** View/edit personas, reset to defaults
- **Portfolio:** Version history, edit problems, re-setup triggers
- **About:** Version, Terms, Privacy Policy, Support, Open Source Licenses

## MVP Out-of-Scope

- Push notifications / reminders
- Attachments, links, file uploads
- Web app
- Calendar/email integrations
- PDF export
- Tablet-optimized layouts
- History search/filter

## Technical Notes

- Governance runners: Finite state machines (not free-form chat)
- Output validation: Schema + rule checker for caps/sections
- One-question-at-a-time enforcement
- Vagueness detection with concrete example requirements
- Three-tier error handling: auto-retry → queue & notify → user action required
- Multi-device sync with last-write-wins conflict resolution
- Dark mode follows system setting

## Rate Limits (Soft—Warning Only)

| Feature | Limit |
|---------|-------|
| Entries | 10/day |
| Brief regeneration | 5/brief |
| Voice recording | 15 min/entry |
| Entry length | 7500 words |

Limits show usage count but do not block. Rely on user self-regulation.

## Development Setup

### Prerequisites

- Flutter SDK 3.2.0+ ([install guide](https://docs.flutter.dev/get-started/install))
- Dart SDK (included with Flutter)

### Getting Started

```bash
# Install dependencies
flutter pub get

# Generate Drift database code
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Run the app
flutter run
```

### AI Configuration

Signal extraction and weekly brief generation require a Claude API key. Set the environment variable before running:

```bash
# Set API key (required for AI features)
export ANTHROPIC_API_KEY=your-api-key-here

# Then run the app
flutter run
```

Without the API key, the app works normally but AI features are unavailable:
- Entries can be created and reviewed (signals will be empty)
- Re-extract signals later from Entry Review when API is configured
- Weekly briefs can't be generated (button shows error message)
- All other features work offline

### Project Structure

```
lib/
├── main.dart                 # App entry point with ProviderScope
├── router/
│   └── router.dart           # go_router configuration
├── providers/
│   ├── database_provider.dart    # Database singleton
│   ├── repository_providers.dart # Repository + stream providers
│   └── ai_providers.dart         # AI service providers
├── services/
│   └── ai/                   # AI service layer
│       ├── claude_client.dart        # Claude API client
│       ├── signal_extraction_service.dart  # Signal extraction
│       ├── weekly_brief_generation_service.dart  # Brief generation
│       └── models/           # AI data models
├── ui/
│   ├── screens/              # App screens
│   │   ├── home/             # Home screen (main hub)
│   │   ├── record_entry/     # Voice/text entry capture
│   │   ├── entry_review/     # Entry editing with signal display
│   │   ├── weekly_brief/     # Brief viewer
│   │   ├── governance/       # Governance hub + runners
│   │   ├── settings/         # App settings
│   │   └── history/          # Entry/report history
│   └── widgets/              # Reusable widgets
│       └── signal_list_widget.dart  # Signal display widget
└── data/
    ├── data.dart             # Barrel export for data layer
    ├── database/
    │   ├── database.dart     # Drift database configuration
    │   ├── database.g.dart   # Generated code (run build_runner)
    │   ├── converters/       # Type converters for enums
    │   └── tables/           # Drift table definitions
    ├── enums/                # Domain enums
    └── repositories/         # Data access layer (12 repos)
```

### Code Generation

After modifying Drift tables, regenerate the database code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For continuous generation during development:

```bash
dart run build_runner watch
```

## Documentation

- **[PROGRESS.md](PROGRESS.md)** — Development progress and completed milestones
- **[PRD.md](PRD.md)** — Full product requirements (v5)
- **[CLAUDE.md](CLAUDE.md)** — Development guidelines for Claude Code

---

*Built with Claude Code*
