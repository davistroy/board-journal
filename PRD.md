# PRD v5 — Boardroom Journal (MVP)

**Date:** Jan 10, 2026
**Platforms:** Mobile (iOS + Android)
**Exports:** Markdown + JSON (MVP)

## Locked assumptions
- **Mobile framework:** Flutter with Drift ORM
- Default persona tone: **warm-direct blunt**
- Weekly brief auto-generates: **Sunday 8:00pm local** (use device timezone; America/New_York fallback only for rare edge cases where device timezone cannot be determined)
- Daily entry cap: **soft cap 10/day with usage visibility** (warning only, no blocking or friction)
- Weekly brief length: **target ~600 words, maximum 800 words**
- Silence timeout for voice recording: **8 seconds default** (visual countdown in last 3 seconds)
- Transcription approach: **batch processing** (not streaming for MVP)
- **Entry limits:** max 15 minutes per recording (~2500 words), max 7500 words per entry including follow-ups
- **Device support:** Phone form factor for MVP (tablets work but not optimized; tablet optimization deferred to post-MVP)
- **Dark mode:** Follow system setting (automatic light/dark based on device preference)

---

## 1) Product Definition

### 1.1 One-sentence pitch
A voice-first journal that turns your week into an executive brief (600-800 words) and runs a receipts-based career governance system using a 5-7 role AI board (5 core + 2 conditional growth roles) with distinct personas.

### 1.2 Core loop
**Daily capture → Weekly brief → Board governance sessions (Quick / Setup / Quarterly) → portfolio + bets updated → repeat.**

### 1.3 MVP outcomes (non-negotiable)
- Daily entries are fast and painless.
- Weekly brief is **short, readable, and sharp**.
- Governance sessions enforce **one-question-at-a-time + anti-vagueness gates**.
- Outputs include **quotes** and **falsifiable bets**.

---

## 2) Scope

### 2.1 MVP in-scope
- OAuth sign-in: Apple / Google / Microsoft (email-based account linking)
- Voice capture + batch transcription + edit
- Text entry as first-class alternative to voice
- Store text transcripts + generated artifacts
- Career Governance module:
  - **Quick Version (15-min audit)**
  - **Setup (Problem Portfolio + Board Roles + Personas)**
  - **Quarterly Report**
- Weekly brief auto-gen + manual regen (5 regenerations per brief)
- Markdown export (via system share)
- JSON export/import (full data backup/restore)
- Multi-device sync with custom sync API
- Offline support for core journaling features

### 2.2 MVP out-of-scope
- Reminders/notifications
- Attachments, links, file uploads
- Web app
- Calendar/email integrations
- PDF export

---

## 3) Information Architecture

### 3.1 Primary objects
- **DailyEntry**: transcriptRaw, transcriptEdited, extractedSignals[7 types], createdAtUTC, createdAtTimezone, entryType (voice/text)
- **WeeklyBrief**: weekRange, briefMarkdown, boardMicroReviewMarkdown, generatedAt, regenCount
- **ProblemPortfolio**: problems[3–5], portfolioRisk, version, updatedAt
- **PortfolioVersion**: version, problems, directions, allocations, health, boardAnchoring, createdAt
- **BoardMember** (x5-7): roleType, personaProfile, originalPersonaProfile, anchoredProblemId, anchoredDemand, isGrowthRole
- **PortfolioHealth**: appreciatingPct, depreciatingPct, stablePct, riskStatement, opportunityStatement
- **GovernanceSession**: type (Quick/Setup/Quarterly), transcriptQandA, outputMarkdown, abstractionMode, createdAt
- **Bet**: prediction, wrongIf, createdAt, dueDate (+90 days), status (OPEN/CORRECT/WRONG/EXPIRED)

### 3.2 "Receipts" in MVP = Evidence statements (not files)
EvidenceItem: type (Decision/Artifact/Calendar/Proxy/None), text, strengthFlag (Strong/Medium/Weak/None)

### 3.3 Board Role Definitions

The board consists of **5 core roles (always active) plus 2 growth roles (activated when appreciating problems exist), for 5-7 total members**. Each role is **anchored to a specific problem** from the user's portfolio with a **specific demand** (the "anchored demand").

#### 3.3.1 Core Roles (Always Active)

| Role | Function | Anchors To | Interaction Style |
|------|----------|------------|-------------------|
| **Accountability** | Demands receipts for stated commitments | A specific promise the user made | Direct, evidence-focused. Asks "Show me the proof." |
| **Market Reality** | Challenges direction classifications | A classification that might be wishful thinking | Skeptical, data-driven. Asks "Is this actually true?" |
| **Avoidance** | Probes avoided decisions | A conversation/risk the user is dodging | Persistent, uncomfortable. Asks "Have you actually done this?" |
| **Long-term Positioning** | Asks 5-year strategic questions | An appreciating problem | Forward-looking, strategic. Asks "What are you doing to own more of this?" |
| **Devil's Advocate** | Argues against the user's path | The user's strongest assumption | Contrarian, challenging. Asks "What if you're wrong about this?" |

#### 3.3.2 Growth Roles (Anchor to Appreciating Problems)

| Role | Function | Anchors To | Interaction Style |
|------|----------|------------|-------------------|
| **Portfolio Defender** | Protects and compounds strengths | Highest-appreciating problem | Protective, growth-focused. Asks "What would cause you to lose this edge?" |
| **Opportunity Scout** | Identifies adjacent opportunities | Highest-appreciating problem | Exploratory, curious. Asks "What adjacent skill would 2x this value?" |

#### 3.3.3 Role Activation Rules

- **Core roles (5)**: Always active for all users with a portfolio
- **Growth roles (2)**: Activate when portfolio contains at least one problem classified as "Appreciating"
- **Minimum roles**: 5 (core only if no appreciating problems)
- **Maximum roles**: 7 (all roles if appreciating problems exist)

#### 3.3.4 Anchoring Mechanism

Each role must be anchored to:
1. **A specific problem** from the portfolio (by problemId)
2. **A specific demand/question** derived from that problem's context

**Anchoring constraints:**
- Multiple roles CAN anchor to the same problem (especially if only 3 problems exist)
- No two roles should anchor to the **same specific issue** within a problem
- Growth roles MUST anchor to appreciating problems only
- Anchoring is **AI-generated** during Setup based on portfolio content, not user-selected

**Example anchored demands by role:**

| Role | Problem | Anchored Demand |
|------|---------|-----------------|
| Accountability | Analysis quality | "You said you'd shift hours from model-building. Show me the calendar." |
| Market Reality | Analysis quality | "You labeled this 'depreciating' but you're still spending 30% here. Why?" |
| Avoidance | Cross-team coordination | "You mentioned the timeline conversation. Have you had it?" |
| Long-term Positioning | Decision translation | "If translation is appreciating, what are you doing to become the go-to person?" |
| Devil's Advocate | Cross-team coordination | "What if your coordination skill is org-specific and doesn't transfer?" |
| Portfolio Defender | Cross-team coordination | "Coordination is appreciating. What would cause you to lose your edge?" |
| Opportunity Scout | Decision translation | "Translation is appreciating. What adjacent skill would 2x its value?" |

#### 3.3.5 Default Persona Profiles

Each role has a default persona that can be customized. Personas define communication style within the role's function.

**Default persona tone:** warm-direct blunt (per locked assumptions)

**Persona generation rules:**
- Generate a personaName (e.g., "Maya Chen" for Accountability)
- PersonaProfile includes: brief background, communication style, signature phrases
- All personas share the baseline tone but differ in focus area
- Users can edit persona names and profiles in Settings

**Example persona profile (Accountability role):**
```
Name: Maya Chen
Background: Former operations executive who built her career on "receipts over rhetoric"
Style: Warm but relentless. Won't let vague claims slide. Asks follow-up questions until evidence is produced.
Signature phrase: "I believe you believe that. Now show me the artifact."
```

#### 3.3.6 Portfolio Health Metrics

The portfolio tracks aggregate health based on problem classifications and time allocation:

```
PORTFOLIO HEALTH
• Total appreciating: [X]% (sum of time allocation for appreciating problems)
• Total depreciating: [X]% (sum of time allocation for depreciating problems)
• Total stable/uncertain: [X]%
• Portfolio risk: [One sentence—where most exposed]
• Portfolio opportunity: [One sentence—where under-investing in appreciation]
```

#### 3.3.7 Re-Setup Triggers

The system tracks conditions that should trigger a portfolio refresh:

| Trigger Type | Examples | Action |
|--------------|----------|--------|
| Role change | Promotion, new job, new team | Full re-setup |
| Scope change | Major project ends, new responsibility | Full re-setup |
| Direction shift | Problem reclassified in 2+ quarterly reviews | Update problem + re-anchor affected roles |
| Time drift | 20%+ shift in allocation vs. setup | Review portfolio health |
| Annual | 12 months since last setup | Full re-setup (mandatory) |

---

## 3A) Technical Architecture

### 3A.1 AI/LLM Provider Strategy

#### Primary Providers
- **LLM Provider:** Claude (Anthropic) with tiered model selection
  - **Claude Opus 4.5** for governance features:
    - Quarterly Reports
    - Setup analysis and board anchoring
    - Complex reasoning and strategic questions
    - Rationale: Highest quality for high-stakes governance decisions
  - **Claude Sonnet 4.5** for daily operations:
    - Signal extraction from entries
    - Weekly brief generation
    - Follow-up questions during journaling
    - Board micro-reviews
    - Rationale: Excellent quality with faster response times and lower cost
  - Rationale for Claude: Excels at maintaining consistent personas, nuanced conversation, and following complex system prompts. Strong at "warm-direct blunt" tone. Enterprise-grade privacy with no training on API data.

- **Speech-to-Text:** Deepgram Nova-2
  - Excellent accuracy, fast processing
  - Competitive pricing (~$0.0043/min)
  - Strong privacy practices
  - Good business vocabulary recognition

#### Processing Approach
- **Cloud APIs primary** with offline recording queue
- Users can capture voice entries offline, which queue for transcription when connectivity returns
- Batch processing after recording stops (not streaming for MVP)
- Target <2 seconds from recording stop to transcript display

#### Cost Targets
- Target **$0.50-1.00 per active user per month** (quality-first approach)
- Allows longer voice entries, more governance sessions, unlimited regenerations
- Requires higher price point ($14.99+) or accepting lower margins

#### Rate Limits (Soft Limits—Warning Only)

Soft limits show usage count but do not block or add friction. Rely on user self-regulation.

| Feature | Limit | Notes |
|---------|-------|-------|
| Entries | 10/day | Usage indicator shown, no blocking |
| Brief regeneration | 5/brief | Counter shown to user |
| Quick Version sessions | 7/week | Informational only |
| Setup sessions | 13/quarter | Informational only |
| Quarterly sessions | 13/quarter | Informational only |
| Voice recording | 15 min/entry | Warning at 12 min, stop at 15 min |
| Entry length | 7500 words | Warning at 6000 words |

System-wide circuit breaker if costs spike 3x normal.

#### Fallback Strategy
1. **Transcription fails:** Retry Deepgram with exponential backoff (1s, 2s, 4s)
2. **Deepgram fails 3+ times:** Fallback to OpenAI Whisper API
3. **LLM fails:** Save raw transcript, queue AI processing for later
4. All previously generated content cached and available offline

### 3A.2 Backend Architecture

#### API Design
REST API with clear resource-based endpoints:

| Category | Endpoints |
|----------|-----------|
| Auth | `/auth/oauth/{provider}`, `/auth/refresh`, `/auth/session` |
| Sync | `/sync?since={timestamp}`, `/sync` (POST), `/sync/full` |
| AI Processing | `/ai/transcribe`, `/ai/extract`, `/ai/generate` |
| Account | `/account`, `/account` (DELETE), `/account/export` |

#### Infrastructure
- **Container-based (Docker)** - Start on home server for development, migrate to cloud platform (Railway, Render, Cloud Run) for production
- Same Docker containers work in both environments

#### API Versioning
- URL path versioning: `/api/v1/sync`, `/api/v2/sync`
- Support current + previous version
- 6-month deprecation notice before removing old version
- Return 426 Upgrade Required if app version too old

#### Authentication Tokens
- **Access token:** JWT, 15-minute expiry
- **Refresh token:** Opaque, 30-day expiry, stored in Keychain/Keystore
- Proactive refresh when <5 minutes remaining
- Reactive refresh on 401
- Concurrent requests during refresh: Queue requests, use single refresh call, replay with new token

---

## 3B) Data Architecture

### 3B.1 Local Storage
- **SQLite** via Drift ORM (Flutter)
- Battle-tested, performant, works identically on iOS and Android
- Type safety and migration support via Drift
- Drift provides reactive queries and compile-time SQL verification

### 3B.2 Multi-Device Sync
- Custom sync API supporting all data types (entries, briefs, portfolio, bets)
- Timestamp-based sync with **last-write-wins** for simplicity
- Sync triggers: App launch + pull-to-refresh + after local changes
- **Conflict resolution:** Last-write-wins with conflict detection and notification
  - Detect when conflict occurred
  - Notify user: "This entry was also edited on your other device. Showing most recent version."
  - Log overwritten version for recovery if needed

### 3B.3 Schema Migrations
- Sequential versioned migrations with ORM support
- Each schema change gets version number and migration script
- Migrations run sequentially (v1→v2→v3→v4 even if user jumps from v1 to v4)
- Test migrations against production-like data before release
- Never delete migration files

### 3B.4 Backup/Restore
- **Full JSON export/import** for MVP
- "Export All Data" produces JSON file with all entries, briefs, portfolio, bets
- "Import Data" restores from JSON backup
- Works across platforms, user owns their data
- Complements markdown export (which is for sharing, not backup)

### 3B.5 Storage Limits
| Type | Limit | Notes |
|------|-------|-------|
| Text data | 100MB cap | Supports ~80 years of use |
| Pending audio | 500MB | For failed transcriptions, auto-delete oldest when exceeded |
| Entry count | No limit | |

---

## 3C) Privacy and Compliance

### 3C.1 Core Commitments
- **"Your journal entries, transcripts, and data are never used to train AI models—not by us, not by our service providers."** Display prominently in onboarding.
- No selling or sharing data for advertising—ever

### 3C.2 Third-Party Data Sharing
Explicit disclosure with data minimization:
| Provider | What They Receive |
|----------|-------------------|
| Deepgram | Audio for transcription only |
| Anthropic (Claude) | Text prompts for AI processing |
| Auth providers | Email/name for authentication |

Display in privacy policy AND summarize during onboarding.

### 3C.3 Data Retention
| Data Type | Retention |
|-----------|-----------|
| Audio | Deleted immediately after successful transcription |
| User content (entries, briefs, portfolio) | Retained indefinitely until user deletes |
| Deleted content | Hard delete within 30 days (soft delete for 30-day "undo" window) |
| Account deletion | All data purged within 30 days, confirmation email sent |
| Backend logs | 90 days for debugging, no PII in logs |

### 3C.4 User Data Rights (GDPR Article 20 Compliant)
- **Complete data export** in machine-readable format
- Full JSON export: All entries, transcripts, extracted signals, briefs, governance sessions, portfolio, board config, bets
- Markdown export: Human-readable versions
- Request via in-app Settings: One-tap "Export All My Data"
- Delivery: Immediate download

### 3C.5 Jurisdiction
- Host backend in US
- Comply with GDPR via Standard Contractual Clauses with all providers
- Disclose in privacy policy: "Data is processed in the United States under GDPR-compliant data processing agreements."

---

## 3D) Security

### 3D.1 Encryption at Rest
| Platform | Approach |
|----------|----------|
| iOS | Data Protection API (NSFileProtectionComplete), keys in Secure Enclave |
| Android | EncryptedSharedPreferences + SQLCipher, keys in Android Keystore |
| Cloud | AES-256 encryption at rest, KMS-managed keys |

Auth tokens stored in keychain/keystore only.

### 3D.2 Encryption in Transit
- Minimum TLS 1.2, preferred TLS 1.3
- Reject TLS 1.1 and below
- Certificate pinning for your backend API
- No pinning for third-party APIs (they rotate certs)
- Pin backup certificates for rotation
- Pinning failure: Refuse connection, show error

### 3D.3 API Security
**Input validation:**
- Server-side validation required
- Sanitize before AI processing
- Max 10MB requests
- Enforce character limits

**Request integrity:**
- HTTPS only
- Reject missing required headers
- CORS for known origins only

**Abuse prevention:**
- Account creation rate limiting: 3/IP/hour
- Failed auth lockout: 5 failures = 15-minute lockout
- Anomaly detection for unusual patterns

**Third-party API keys:**
- Store in environment variables only
- Proxy all third-party calls through backend (never expose keys to client)

### 3D.4 Audit Logging
**Environment-configurable logging levels:**

| Mode | Logs | Retention |
|------|------|-----------|
| Development | Verbose with content (request/response bodies, entry content, AI prompts, stack traces) | 7 days |
| Production | Security-focused, no content (login events, session changes, deletions, API errors without user data) | 90 days |

Production mode is DEFAULT. CI/CD checks enforce production config. Warning banner in dev logs.

---

## 3E) Error Handling

### 3E.1 Error Classification

| Tier | Type | Examples | User Experience |
|------|------|----------|-----------------|
| Tier 1 | Auto-Retry (invisible) | Network timeouts, rate limits, transient 5xx errors | User sees nothing |
| Tier 2 | Queue & Notify (pending status) | Prolonged outage, provider outage, LLM unavailable | "Transcribing in background..." |
| Tier 3 | User Action Required | Auth expired, storage full, corrupted audio | Modal with clear options |

### 3E.2 Recovery Procedures

**Tier 1:**
- Retry 3x with exponential backoff (1s, 2s, 4s)
- Escalate to Tier 2 on exhaustion

**Tier 2:**
- Deepgram → Whisper fallback for transcription
- Queue operations for later processing
- Check queue on app launch, connectivity change, and every 5 minutes while foregrounded

**Tier 3:**
- Auth expired: Modal prompting re-authentication
- Storage warnings: Clear indication with cleanup options
- Corrupted audio: Offer [Retry] [Type Instead] [Discard]

**Always preserve user data until explicitly discarded.**

### 3E.3 User-Facing Messages
Calm, actionable messages with clear next steps:

| Situation | Message |
|-----------|---------|
| Tier 2 pending | "Transcribing in background..." or "Your entry is saved. AI processing will complete when online." |
| Auth expired | "Your session has ended. Please sign in to continue." |
| Corrupted audio | "We couldn't process this recording. [Retry] [Type Instead] [Discard]" |

Never blame the user. Always confirm data is safe when true.

### 3E.4 Data Preservation
Checkpoint-based preservation at every state transition:

| Stage | Preservation |
|-------|--------------|
| Recording | Save audio locally immediately |
| Transcription fails | Audio retained until success or user discards |
| Transcript received | Save before extraction |
| User edits | Auto-save every 5 seconds |
| Generated outputs | Save only after complete success |
| Orphan cleanup | Audio files without linked entries deleted after 7 days |

---

## 3F) Offline Behavior

### 3F.1 Offline Feature Support

**Works offline (full functionality):**
- Voice recording (queue for transcription)
- Text entry (queue for extraction)
- View past entries/briefs (cached)
- Edit entries (sync when online)
- View portfolio/board

**Requires online:**
- Transcription
- Signal extraction
- Brief generation
- Governance sessions
- Account actions

### 3F.2 Sync Behavior

**Triggers:**
- Connectivity restored
- App launched
- Pull-to-refresh
- Every 5 minutes while foregrounded

**Priority queue:**
1. Auth refresh
2. Transcription
3. Extraction
4. Local edits
5. Server changes

**Status UI:**
- Subtle sync indicator
- Entry-level status badges
- Badge for pending items

**Error handling:**
- Retry with exponential backoff
- Never delete local data on sync failure

---

## 4) Workflow State Machines (MVP)

Below are the exact conversational state machines. These are the “do not screw up” mechanics.

---

### 4.1 Daily Journal Entry — State Machine

**Goal:** Save a DailyEntry with a clean transcript and minimal structured extraction.

**States**
1. **Idle**
2. **Recording** (audio waveform visualization + timer)
3. **Transcribing (batch processing)** — waveform freezes, spinner shown, target <2s
4. **Edit Transcript** — full transcript appears at once with smooth fade-in
5. **Gap Check**
6. **Follow-up Q (1..3)**
7. **Confirm & Save**
8. **Saved**
9. **Error / Recovery**

**Transitions & rules**
- Idle → Recording (tap record OR tap "Type Instead" to skip to Edit Transcript with empty text)
- Recording → Transcribing (tap stop OR 8-second silence timeout with visual countdown in last 3s)
- Transcribing → Edit Transcript (show transcript; allow edits)
- Edit Transcript → Gap Check
- Gap Check:
  - If missing any of: wins, blockers, risks, avoided decision, comfort work, actions, learnings → ask up to **3** follow-ups max.
  - Follow-ups are **one at a time**.
- Follow-up Q → Gap Check (after each answer)
- Gap Check → Confirm & Save (when complete or follow-up limit reached)
- Confirm & Save → Saved

**Text entry alternative**
- "Record Entry" screen offers both: [Record Voice] and [Type Instead]
- Text entries skip transcription entirely, go straight to Edit Transcript
- Same extraction and signal detection applies to both

**Anti-annoyance policy**
- If user explicitly says "skip" → stop follow-ups, save anyway.
- If user answers "none" for Avoided Decision/Comfort Work → accept and record "none".

**Entry limits**
- Max 15 minutes per voice recording (warning at 12 min, auto-stop at 15 min)
- Max ~2500 words per transcript
- Max 7500 words per entry including all follow-ups
- Limits are soft—show warning, allow save

**Save requirements**
- Must save transcriptEdited (even if identical to raw)
- Must store extractedSignals (best-effort)
- Audio deletion after successful transcription (default)
- Audio retained if transcription fails until success or user discards
- Orphaned audio (no user action for 7 days) auto-deleted

**Partial transcription handling**
- If partial transcript received: Save and display it
- Clear visual indicator: "Partial transcript—some audio couldn't be processed"
- User options: [Retry Full Audio] [Complete Manually] [Keep As-Is]

**Network vs service failure differentiation**
- Network failure (no internet, timeout, DNS): "No internet connection. Your recording is saved and will be transcribed when you're back online."
- Service failure (HTTP 5xx, 429): "Transcription service temporarily unavailable. We'll automatically retry shortly."

---

### 4.2 Weekly Brief Generation — State Machine

**Goal:** Produce executive brief (600-800 words) + board micro-review.

**States**
1. **Scheduled Trigger** (Sunday 8pm in current device timezone) OR **Manual Trigger**
2. **Collect Week Entries**
3. **Summarize**
4. **Render Brief** (target ~600 words, max 800 words)
5. **Generate Board Micro-Review**
6. **Publish**
7. **User Edit / Regen**
8. **Finalized**

**Rules**
- Week range = Mon 00:00 → Sun 23:59 based on entry's original local time at creation (entries stored with UTC + timezone)
- Brief follows user across timezones (generates at 8pm on device's current clock)
- Output length: Target ~600 words, minimum 200 words, maximum 800 words (hard cap for validator)
- **Zero-entry weeks:** Generate minimal reflection brief (~100 words) acknowledging no entries, with gentle encouragement for the coming week. Example: "No entries this week. Sometimes we're too busy living to document. A few questions to consider for next week: [reflection prompts based on portfolio]."
- Output must obey strict section caps:
  - Headline: max 2 sentences
  - Wins/Blockers/Risks: max 3 bullets each
  - Open Loops: max 5 bullets
  - Next Week Focus: top 3
  - Avoided Decision + Comfort Work: 1 each (or "none")

**Board Micro-Review (included by default)**
- Quick "board voice" commentary on the week
- One sentence from each active board role (5-7 sentences total)
- Each role comments on something from this week's entries relevant to their focus
- Variable length based on week's content (more entries = more to say)
- ~100 words total
- Purpose: Lightweight weekly accountability without running full governance session
- Show by default, users can collapse; remember collapse preference

**Regeneration options (combinable multi-select checkboxes)**
| Option | Prompt Modification |
|--------|---------------------|
| Shorter | 2 bullets max per section, 1-sentence headline, omit open loops (~40% reduction) |
| More Actionable | Every bullet includes verb/next step, add "Suggested Actions" section, reframe blockers as "To unblock: [action]" |
| More Strategic | Connect to portfolio health, add "Strategic Implications" section, career trajectory framing |

**Regeneration limits**
- 5 regenerations per brief
- Counter shown: "Regenerations: 2 of 5 remaining"
- Resets each week
- At limit: Button disabled, message "You've used all 5. You can still edit directly."
- "Start over" = discard edits, counts as 1 regen
- "Regenerate with options" = apply modifiers, counts as 1 regen
- Manual editing always available

**User edits**
- Edits persist; regen preserves edits unless "Start over" chosen

---

### 4.3 Quick Version (15-min Audit) — State Machine

**Goal:** Run the exact 5-question audit, enforce concreteness, output the required summary + 90-day bet.

**States**
0. **Sensitivity Gate** (privacy reminder with abstraction mode option)
1. **Q1 Role Context**
2. **Q2 Paid Problems (3)**
3. **Q3 Problem Direction Loop** (for each problem)
4. **Q4 Avoided Decision**
5. **Q5 Comfort Work**
6. **Generate Output**
7. **Finalize**

**Sensitivity Gate behavior**
- Brief screen before starting: "Governance sessions discuss your career in detail. Would you like to enable Abstraction Mode?"
- Toggle for Abstraction Mode (default off):
  - ON: Replaces names/companies with placeholders in user's answers AND generated outputs
  - OFF: Keeps full detail
- "Remember my choice" checkbox
- Show once per session type until "Remember my choice" selected
- Preference changeable in Settings → Privacy → "Abstraction Mode defaults"
- Non-blocking, quick checkpoint (<5 seconds for returning users)

**Enforcement mechanism: "Vague → Concrete Example"**
At every Q state:
- Run **Vagueness Check** on answer.
- If vague → transition to **ClarifyExample**: "Give one concrete example."
- Only return to main Q state after example is provided.

**Vagueness skip option**
- Allow skip with two-step confirmation
- Flow: AI asks for example → Skip → Confirmation "Skipping reduces value. Are you sure?" → Record "[example refused]" and continue
- Board can reference refusal pattern in future sessions
- Max 2 skips per session—third gate cannot be skipped
- Respects autonomy while maintaining accountability

**Q3 Direction Loop output**
For each problem, produce:
| Problem | AI cheaper? | Error cost? | Trust required? | Direction |
- Cells must **quote user words**.
- Direction label: Appreciating / Depreciating / Stable
- One sentence justification tied to the quotes.

**Final output (strict)**
- 2-sentence honest assessment
- avoided decision + cost
- one 90-day prediction + wrong-if evidence

---

### 4.4 Setup (Problem Portfolio + Board Roles + Personas) — State Machine

**Goal:** Create a portfolio (3–5 problems fully specified), calculate portfolio health, instantiate 5-7 board members with personas anchored to specific problems, and define re-setup triggers.

**States**
0. **Sensitivity Gate** (same behavior as Quick Version—privacy reminder with abstraction mode option)
1. **Collect Problem #1**
2. **Validate Problem #1 Fields**
3. **Repeat for Problem #2..#5**
4. **Portfolio Completeness Gate**
5. **Time Allocation Validation**
6. **Calculate Portfolio Health**
7. **Create Core Board Roles (5, anchored)**
8. **Create Growth Board Roles (0-2, if appreciating problems exist)**
9. **Create Personas (one per role)**
10. **Define Re-Setup Triggers**
11. **Publish Portfolio + Board + Triggers**

**Required fields per problem (hard gate)**
- Name
- What breaks if not solved
- Scarcity signals: pick **2** OR Unknown + why
- Direction evidence (quotes) for:
  - AI cheaper?
  - Error cost?
  - Trust required?
- Classification + one-sentence rationale
- If unclear: "Stable (uncertain)" + evidence to clarify next quarter
- **Time allocation**: percentage of work week (must sum to ~100% across all problems)

**Time allocation validation rules**
| Range | Behavior |
|-------|----------|
| 95-105% | Valid, proceed |
| 90-94% or 106-110% | Yellow warning banner, "Continue Anyway" enabled |
| <90% or >110% | Red error banner, "Continue" disabled, suggest adjustments |

**Time allocation input UX**
- Slider with 5% increments, tap +/- buttons for 1% adjustments
- Alternative: Direct text entry (whole numbers only)
- Always whole numbers, no decimals
- Live sum displayed with color coding (green/yellow/red)
- Real-time validation on every change
- No auto-normalization—user stays in control

**Portfolio Health calculation**
After all problems captured:
- Sum time allocation by direction (appreciating / depreciating / stable)
- Generate portfolio risk statement (where most exposed)
- Generate portfolio opportunity statement (where under-investing in appreciation)

**Board Role creation (MVP)**

*Core roles (always created):*
| Role | Anchor Logic |
|------|--------------|
| Accountability | Anchor to a specific commitment user made |
| Market Reality | Anchor to a direction classification that might be wrong |
| Avoidance | Anchor to a decision/conversation user is clearly dodging |
| Long-term Positioning | Anchor to an appreciating problem |
| Devil's Advocate | Anchor to user's strongest assumption |

*Growth roles (created if appreciating problems exist):*
| Role | Anchor Logic |
|------|--------------|
| Portfolio Defender | Anchor to highest-appreciating problem |
| Opportunity Scout | Anchor to highest-appreciating problem |

**Persona creation (MVP)**
For each role:
- Generate personaName + personaProfile defaults
- Tie to one problem (anchoredProblemId)
- Define anchoredDemandOrQuestion (specific, not generic)
- Flag isGrowthRole = true for Defender and Scout
- Store original generated personas permanently for reset capability

**Persona customization (editable fields)**
| Field | Limits | Required |
|-------|--------|----------|
| Name | 1-50 characters | Yes |
| Background | 10-300 characters | Yes |
| Communication style | 10-200 characters | Yes |
| Signature phrase | 0-100 characters | No |

**Not editable:** Role type, anchored problem, anchored demand

**Persona reset**
- Per-role: "Reset [Name] to default" restores original generated persona
- All roles: "Reset all personas to defaults"
- Confirmation required before reset

**Re-Setup Triggers (generated based on portfolio)**
Define 2-3 specific conditions, including:
- Role/scope change condition
- Market signal that would shift a direction classification
- Time allocation threshold indicating dangerous drift
- Annual mandatory re-setup date (12 months from setup)

**Portfolio versioning**
- Each Setup/re-setup completion snapshots the portfolio
- Stores: problems, directions, allocations, health, board anchoring
- Version number increments, timestamp recorded
- Access via Settings → Portfolio → "Version History"
- View any past version (read-only)
- Compare two versions side-by-side to see changes
- No restore for MVP—run re-setup to make changes
- Re-setup regenerates ALL board anchoring from scratch (user customized names/styles preserved, only anchored demands change)

**Portfolio modification (without full re-setup)**

Users can make limited edits to their portfolio without triggering a full re-setup:

| Change Type | Allowed Without Re-setup | Notes |
|-------------|--------------------------|-------|
| Problem description | Yes | Edit text, no structural change |
| Time allocation | Yes | Adjust percentages (must stay 95-105%) |
| Direction classification | No | Requires re-setup (affects governance logic) |
| Add problem | No | Requires re-setup |
| Delete problem | Yes (with constraints) | See deletion rules below |

**Problem deletion rules**
- Users can delete problems from their portfolio
- Minimum 3 problems enforced—cannot delete below 3
- Deletion prompt: "Deleting this problem will affect board roles anchored to it. Continue?"
- When a problem with anchored board roles is deleted:
  1. AI auto-regenerates new anchored demands for affected roles
  2. User shown: "These board roles need new focus areas: [list]. Here are suggested updates:"
  3. User can accept suggestions or trigger full re-setup
  4. Customized persona names/styles preserved; only anchored demands change
- Portfolio version snapshot created after deletion

---

### 4.5 Quarterly Report — State Machine

**Goal:** Produce a completed quarterly report with gates, evidence strength calls, anchored role questions (including growth roles), portfolio health update, and falsifiable next bet.

**Eligibility rules**
- Quarterly Reports can be generated on-demand at any time
- If <30 days since last report: Show warning "It's been less than 30 days since your last quarterly report. For best results, allow more time for entries to accumulate. Continue anyway?"
- User can proceed despite warning (not blocked)
- No calendar quarter alignment required

**States**
0. **Sensitivity Gate** (same behavior as Quick Version)
1. **Gate 0: Require Portfolio + Board + Triggers**
2. **Q1 Last Bet Evaluation**
3. **Q2 Commitments vs Actuals**
4. **Q3 Avoided Decision**
5. **Q4 Comfort Work**
6. **Q5 Portfolio Check** (direction shifts + time allocation changes)
7. **Q6 Portfolio Health Update** (appreciating/depreciating trend)
8. **Q7 Protection Check** (Portfolio Defender section, if growth roles active)
9. **Q8 Opportunity Check** (Opportunity Scout section, if growth roles active)
10. **Q9 Re-Setup Trigger Check**
11. **Q10 Next Bet**
12. **Core Board Role Interrogation** (5 roles)
13. **Growth Board Role Interrogation** (0-2 roles, if active)
14. **Generate Report**
15. **Finalize**

**Evidence enforcement**
- When user claims progress, require an EvidenceItem.
- Label evidence strength:
  - Decision/Artifact = Strong
  - Proxy = Medium
  - Calendar-only = Weak (explicitly called out)
  - No receipt = None (and that's recorded, not "fixed")

**Anchored role interrogation**

*Core roles (always):*
Each of the five core board members asks **their anchored question** (one at a time) and pushes back if vague.

*Growth roles (if active):*
- **Portfolio Defender** asks about protection and compounding of appreciating skills
- **Opportunity Scout** asks about adjacent exploration and next opportunities to pursue

**Portfolio Health Update**
Compare current quarter's appreciating/depreciating percentages to previous quarter:
- Trend: Improving / Declining / Stable
- Flag if depreciating percentage increased by >10%

**Re-Setup Trigger Check**
Review each defined trigger condition:
- If any trigger is met → flag "Schedule re-setup" in report
- If annual trigger approaching (within 30 days) → flag reminder

---

### 4.6 Bet Tracking — System Behavior

**Bet status values**
| Status | Description | Display |
|--------|-------------|---------|
| OPEN | Active bet, due date not reached | Neutral |
| CORRECT | User verified prediction came true | Green |
| WRONG | User verified prediction was wrong | Red (not judgmental) |
| EXPIRED | Due date passed without evaluation | Gray |

No "partially correct"—forces clear accountability.

**Status transition rules**
| Transition | Allowed |
|------------|---------|
| OPEN → CORRECT | Yes (user action) |
| OPEN → WRONG | Yes (user action) |
| OPEN → EXPIRED | Yes (automatic at due date) |
| EXPIRED → CORRECT | Yes (retroactive evaluation) |
| EXPIRED → WRONG | Yes (retroactive evaluation) |
| CORRECT ↔ WRONG | No |
| Any → OPEN | No |

**Auto-expiration behavior**
- Auto-transition to EXPIRED at midnight on due date
- No grace period
- Prompts (in-app only for MVP—no push notifications):
  - 7 days before: Visual indicator on bet
  - On due date: In-app prompt when app opened
  - After expiration: "Evaluate Now?" prompt
- Expired bets appear in "Needs Evaluation" section
- Quarterly report tracks evaluation rates
- No punishment—just transparency

**Retroactive evaluation**
- Encouraged during quarterly review
- Once evaluated, that's your record

---

## 5) Screen-by-Screen UX (MVP)

### 5.0 Onboarding Flow

**Goal:** Get new users to their first entry quickly with minimal friction. Setup is deferred.

**States**
1. **Welcome Screen** — Value proposition (1 screen)
2. **Privacy Acceptance** — Terms and privacy policy summary
3. **OAuth Sign-in** — Apple / Google / Microsoft
4. **First Entry Experience** — Direct to Record Entry screen

**Design principles**
- Minimal screens (3 before sign-in)
- No Setup required immediately
- Value proposition: "Turn your week into an executive brief"
- Privacy summary shown (link to full policy)

**Setup deferral**
- Users can start journaling immediately without completing Setup
- After 3-5 entries, prompt: "Ready to set up your board of directors?"
- Setup CTA shown on Home screen until completed
- All features except Quarterly Report work without Setup

**First entry guidance**
- Brief tooltip on first Record Entry: "Just talk about your day. We'll extract the important signals."
- No tutorial required—learn by doing

**Acceptance criteria**
- New user can reach first entry in <60 seconds
- Privacy/terms accepted before account creation
- Setup prompt appears after 3-5 entries
- Users can dismiss Setup prompt (re-shows weekly until completed)

---

### 5.1 Home
**Primary actions**
- Record Entry (big button)
- Weekly Brief (latest)
- Run 15-min Audit (Quick Version)
- Governance (Portfolio + Quarterly)

**Secondary**
- History (Entries / Reports)

**Acceptance criteria**
- Record Entry is one tap away from app open
- Latest Weekly Brief visible if exists
- If no portfolio exists, Governance shows “Set up your system” CTA

---

### 5.2 Record Entry
- [Record Voice] and [Type Instead] options
- During recording: Audio waveform visualization + timer
- After stop: "Transcribing..." spinner (<2s target), then full transcript appears
- Minimal controls: pause/cancel/save
- After transcription: edit transcript view
- "Save" always available (no hostage-taking)

**Acceptance criteria**
- Save an entry in <60 seconds end-to-end in normal conditions
- Voice-first UX (record button prominent) but text always available
- If transcription fails, user can retry, type instead, or discard
- Audio deleted after successful transcription (default)
- Offline: Recording works, queued for transcription when online

---

### 5.3 Entry Review
- Transcript editable
- "Detected signals" preview showing all 7 signal types:
  1. Wins (completed accomplishments)
  2. Blockers (current obstacles)
  3. Risks (potential future problems)
  4. Avoided Decision (decisions being put off)
  5. Comfort Work (feels productive but doesn't advance goals)
  6. Actions (forward commitments)
  7. Learnings/Insights (realizations and reflections)
- Quick "fix" option: edit extracted bullets (not mandatory)

**Re-extraction behavior**
- Transcript edits do NOT auto-trigger re-extraction
- After transcript edit, show prompt: "Transcript updated. Re-extract signals?"
- User chooses: [Re-extract] or [Keep Current Signals]
- If user has manually edited signals AND requests re-extraction:
  - Show warning with diff: "Re-extracting will replace your manual edits. Changes: [diff view]"
  - User confirms or cancels
  - If confirmed, manual edits are overwritten with fresh extraction

**Entry locking**
- No time-based locking—entries remain editable indefinitely
- Version history preserved in database for audit trail

**Acceptance criteria**
- Users can correct extraction without editing the whole transcript
- Transcript edits prompt (not auto-trigger) re-extraction
- Manual signal edits are warned before overwrite

---

### 5.4 Weekly Brief Viewer
- Executive brief (600-800 words)
- Board Micro-Review section (shown by default, collapsible, remembers preference)
- Buttons: Regenerate (combinable options: shorter/actionable/strategic), Export (Markdown/JSON), Edit
- Regeneration counter: "Regenerations: X of 5 remaining"

**Export formats**
- Markdown and JSON export available
- Format requirements (exact structure defined during implementation):
  - Include metadata: generation date, week range, entry count
  - Include signal counts by type
  - Include board micro-review content
- Formats documented in code, not PRD (allows iteration)

**Acceptance criteria**
- Default view fits on one screen with minimal scrolling
- Regeneration respects caps and preserves edits unless "Start over"
- 5 regenerations per brief maximum
- At limit: Regenerate button disabled with message "You've used all 5. You can still edit directly."
- Export includes metadata and is well-structured

---

### 5.5 Governance Hub
Tabs:
- Quick Version
- Setup (Portfolio)
- Quarterly
- Board (roles + personas)

**Acceptance criteria**
- If no portfolio exists:
  - Quarterly tab is locked with explanation + "Run Setup"
- Board tab shows 5-7 members and their anchored problem links
- Growth roles (Portfolio Defender, Opportunity Scout) visually distinguished
- If no appreciating problems exist, growth roles show as "Inactive—no appreciating problems"
- Portfolio Health summary visible on Setup tab
- Re-Setup Triggers visible with status (met/not met)

---

### 5.6 Quick Version Runner
- Sensitivity Gate first (abstraction mode option with "Remember my choice")
- One question at a time
- "Answer" input: voice or text
- Vague response triggers "concrete example" follow-up
- Skip option with two-step confirmation (max 2 skips per session)
- End screen: audit output markdown + Export

**Acceptance criteria**
- Vagueness gates require example OR two-step skip confirmation
- Skip records "[example refused]" for future reference
- Third vagueness gate in session cannot be skipped
- Abstraction mode (if enabled) replaces names/companies with placeholders

---

### 5.7 Setup Runner
- Sensitivity Gate first (abstraction mode option)
- Stepper UI: Problem 1..N → Time Allocation Validation → Portfolio Health → Board roles/personas → Re-Setup Triggers
- Hard gating prevents moving forward with missing required fields
- Time allocation: Slider (5% increments) + tap +/- buttons (1% adjustments), or direct text entry
- Live sum display with color coding (green 95-105% / yellow 90-94% or 106-110% / red outside)
- Final screen: Portfolio markdown + Portfolio Health + Board roster + Triggers + Export

**Acceptance criteria**
- Exactly 3–5 problems stored
- Each problem contains required fields including time allocation
- Time allocations must be 95-105% to proceed (90-110% with warning)
- Portfolio Health calculated and displayed
- 5 core board members always created and anchored
- 2 growth board members created if any appreciating problems exist
- Board members anchored to specific problems and demands (no generic anchoring)
- Original generated personas stored for reset capability
- Re-Setup Triggers defined with specific conditions
- Annual re-setup date automatically set to 12 months from setup
- Portfolio version snapshot created on completion

---

### 5.8 Quarterly Runner
- One question at a time
- Evidence strength labeling displayed ("Calendar-only = weak")
- Core board members ask anchored questions (5 roles)
- Growth board members ask anchored questions (0-2 roles, if active)
- Portfolio Health trend displayed
- Re-Setup Trigger status checked

**Acceptance criteria**
- Generated report contains every required section filled
- Bets always include "wrong if"
- Missing receipts are explicitly recorded
- Portfolio Health Update shows trend vs. previous quarter
- Protection Check section completed (if growth roles active)
- Opportunity Check section completed (if growth roles active)
- Re-Setup Trigger Check shows status of each trigger
- If any trigger is met, report flags "Schedule re-setup"

---

### 5.9 Settings

**Account**
- Sign-in methods (linked OAuth providers)
- Add sign-in method / Remove sign-in method (cannot remove last one)
- Active sessions (all logged-in devices) with "Log out everywhere" option
- Delete Account (two-step confirmation with 7-day grace period)

**Privacy**
- Abstraction Mode defaults (per session type)
- Audio retention: Default delete after transcription
- Analytics: ON by default with clear opt-out
- Data retention info display

**Data**
- Export All My Data (JSON—immediate download)
- Export Markdown (human-readable)
- Import Data (restore from JSON backup)
- Delete All Data (with confirmation)

**Board**
- View/edit persona customizations (name, background, style, phrase)
- Reset individual persona to default
- Reset all personas to defaults

**Portfolio**
- Version History (view past versions, compare side-by-side)
- Re-Setup Triggers status
- Edit problems (description, time allocation)
- Delete problem (with anchoring update flow)

**About**
- App version number
- Terms of Service (link to web)
- Privacy Policy (link to web)
- Support / Send Feedback (opens email or feedback form)
- Open Source Licenses (list of third-party libraries)

**Acceptance criteria**
- "Delete everything" fully removes user content and artifacts within 30 days
- 7-day grace period for account deletion with cancel option
- Clear explanation of what's stored (text transcripts + outputs, never audio long-term)
- Export includes all user data (GDPR Article 20 compliant)
- About section displays current app version

---

### 5.10 History

**Layout:** Single reverse-chronological list with type indicators

**Display**
- All entries and reports in one unified list
- Most recent items at top
- Each item shows:
  - Type indicator icon (journal entry vs governance report)
  - Date/time
  - Preview text (first ~50 characters for entries, title for reports)
  - Entry count badge for weekly briefs

**Item types**
| Type | Icon | Preview |
|------|------|---------|
| Daily Entry | Journal icon | First line of transcript |
| Weekly Brief | Brief icon | Week date range |
| Quick Version | Audit icon | "15-min Audit" + date |
| Setup | Setup icon | "Portfolio Setup v[N]" |
| Quarterly Report | Report icon | "Q[N] Report" + date |

**Interaction**
- Tap item to open full view
- Pull-to-refresh syncs latest
- Infinite scroll / pagination for performance

**Search/Filter (MVP)**
- No search for MVP (defer to post-MVP)
- No filters for MVP (single unified list)

**Acceptance criteria**
- All entries and reports appear in chronological order
- Type is immediately distinguishable via icon
- List loads quickly with pagination

---

## 6) Prompt Assembly Strategy (to keep outputs tight and deterministic)

This is where most apps fail. You need deterministic structure.

### 6.1 Prompt layers (in order)
1. **System Policy Layer**
   - One-question-at-a-time enforcement
   - Vague → require concrete example
   - Quote user words in specified cells
   - Output must obey strict templates and caps
   - Respect “abstractions allowed” for sensitive details
2. **Workflow Layer** (Quick / Setup / Quarterly / Weekly / Journal extraction)
   - Contains the exact sequence, gates, evidence taxonomy, and required output format
3. **Board Role Layer** (for governance sessions)
   - Role contract + persona profile + anchored problem reference + anchored demand
   - Core roles (5): Accountability, Market Reality, Avoidance, Long-term Positioning, Devil's Advocate
   - Growth roles (0-2): Portfolio Defender, Opportunity Scout (only if appreciating problems exist)
4. **User Context Layer**
   - Active portfolio + board roles + last bet + last quarter report (if present)
5. **Session Input**
   - The user’s latest answer only (for one-question-at-a-time)
6. **Retrieval (optional, controlled)**
   - Only bring in relevant prior transcript snippets (e.g., last bet statement), never dump everything

### 6.2 Hard constraints to implement
- **Strict output schemas**: markdown templates with headings + bullet caps enforced by a validator.
- **Quote enforcement**: wherever “quote my words” is required, pull verbatim spans.
- **Gatekeeper** (validator):
  - Vagueness detection (heuristic + model)
  - Completeness checks for Setup fields
  - Bullet count and length checks for weekly brief

### 6.3 Vagueness detection (practical definition)
Trigger “concrete example required” if:
- answer lacks a named instance (project, meeting, decision, deliverable) **and**
- uses generic qualifiers (“stuff”, “things”, “helped”, “a lot”, “various”, “some”, “improve”) **and**
- no timeline or stakeholder or observable outcome is present

If triggered, ask exactly:
> “Give one concrete example (who/what/when/result).”

### 6.4 Privacy guardrails
- Default: audio deleted after transcription success
- Store: text transcripts + outputs
- **Privacy statement (display prominently in onboarding):**
  > "Your journal entries, transcripts, and data are never used to train AI models—not by us, not by our service providers. We don't sell or share your data for advertising—ever."
- Abstraction mode: user can enable before governance sessions, and the system automatically:
  - Strips names/emails/company names/project names
  - Replaces entities with placeholders ("my manager", "Company A", "Project X")
  - Applies to user's answers AND generated outputs
  - All-or-nothing for MVP (no selective abstraction)

---

## 7) Acceptance Criteria Summary (MVP "Definition of Done")
1) **Daily entry** saved reliably with transcript (or typed text), editable indefinitely, stored. Offline recording supported. Max 15 min recording, 7500 words total.
2) **Weekly brief** auto-generated Sunday 8pm (device timezone), 600-800 words, strict caps, board micro-review included. Zero-entry weeks get reflection brief.
3) **Quick Version** runs exactly 5 questions, one at a time, with vagueness gating (2 skips max) and required final output.
4) **Setup** produces portfolio (3–5 problems with time allocation 95-105%), portfolio health metrics, 5-7 board roles anchored to specific problems with specific demands, personas created (with reset capability), re-setup triggers defined, version snapshot created; gating enforced. Setup deferred until 3-5 entries.
5) **Quarterly Report** produces a fully completed report with evidence strength labels, anchored questions from all active roles (5-7), portfolio health trend, protection/opportunity checks (if growth roles active), re-setup trigger status, bet evaluation, and falsifiable next bet. On-demand with <30 day warning.
6) **Board roles** correctly implement the 5+2 role system: 5 core roles always active, 2 growth roles active when appreciating problems exist.
7) **Export** works: Markdown for sharing, JSON for backup/restore. Includes metadata.
8) **Delete data** works (single session + full account with 7-day grace period).
9) **Multi-device sync** works with conflict detection and notification.
10) **Offline mode** preserves all recording/editing capabilities, queues for sync.
11) **Onboarding** gets users to first entry in <60 seconds with minimal friction.
12) **Portfolio modification** allows problem description/allocation edits without re-setup; direction changes require re-setup.
13) **Dark mode** follows system setting automatically.

---

## 8) Implementation Notes (opinionated)
- Implement governance runners as **finite state machines**, not a free-form chat thread.
- Validate outputs with a **schema + rule checker**. If caps/sections are violated, auto-regenerate with correction instructions.
- Start extraction with 7 signals: wins, blockers, risks, avoided decision, comfort work, actions, learnings/insights.
- Use batch transcription (not streaming) for MVP—simpler, more reliable.
- Implement three-tier error handling: auto-retry → queue & notify → user action required.
- Store original generated personas permanently for reset functionality.

### 8.1 Companion Documents

The following documents are maintained separately from this PRD:

| Document | Purpose | Status |
|----------|---------|--------|
| **Prompt Templates** | Actual LLM prompts for all workflows | Create during development, version controlled |
| **Brand Guide** | App icon, color palette, typography | Create during design phase |
| **App Store Listing** | Marketing copy, screenshots, keywords | Create at launch prep |

These are linked from this PRD but maintained as separate files for easier iteration.

---

## 9) Glossary

### Core Concepts

**Comfort Work**
Tasks that feel productive but don't meaningfully advance high-priority goals. Examples: reorganizing files, attending optional meetings, polishing work that's done, researching instead of deciding, responding to low-priority emails. Include in onboarding tooltips and help section.

**Receipts**
Concrete evidence that backs up your claims. "Receipts over rhetoric" means proving progress with artifacts and actions, not just words.

| Receipt Type | Strength |
|--------------|----------|
| Decisions made | Strong |
| Artifacts created | Strong |
| Calendar evidence | Medium |
| Proxy evidence | Medium |
| No receipt | Recorded as such |

**Appreciating Problem**
A skill or problem-solving area that's becoming MORE valuable over time. Criteria:
- AI can't easily do it (or won't for a while)
- Errors are costly (high stakes)
- Trust/access required (relationship-dependent)

Examples: strategic decision-making, high-stakes negotiations, relationship-building.

**Depreciating Problem**
A skill or problem-solving area that's becoming LESS valuable over time. Criteria:
- AI is getting better at it
- Errors are low-impact
- No special access/trust needed

Examples: routine analysis, standardized reporting, data entry.

**Stable Problem**
Direction is unclear—revisit classification next quarter.

**Anchored Demand**
The specific question or challenge a board role focuses on, tied directly to one of your portfolio problems. AI-generated during Setup based on portfolio content. Makes each board member relevant to your specific situation.

Example: Accountability role anchored to "Analysis quality" with demand "Show me the calendar."

### Signal Types (Extracted from Entries)

| Signal | Definition |
|--------|------------|
| **Wins** | Completed accomplishments (done) |
| **Blockers** | Current obstacles (now) |
| **Risks** | Potential future problems (upcoming) |
| **Avoided Decision** | Decisions being put off |
| **Comfort Work** | Tasks that feel productive but don't advance goals |
| **Actions** | Forward commitments (to do) |
| **Learnings/Insights** | Realizations and reflections |

Key distinctions: Blockers = now vs. Risks = future. Wins = done vs. Actions = to do.

---

## 10) Testing Strategy

### 10.1 Coverage Targets

| Layer | Target | Notes |
|-------|--------|-------|
| Business logic | 80% | State machines, validation rules |
| Data layer | 70% | Sync, migrations, storage |
| UI | 50% | Critical flows only |
| AI integrations | 60% | Mock providers for unit tests |
| Overall | 70% | Balanced coverage |

### 10.2 Must-Test (100% Coverage Required)

- State machines (all transitions)
- Validation rules (time allocation, field limits)
- Encryption operations
- Token refresh logic
- Conflict resolution
- Bet status transitions

### 10.3 AI Output Validation

**Layer 1: Unit tests with mocked AI**
- Deterministic, runs in CI
- Mock AI responses with known outputs

**Layer 2: Golden set validation**
- 20-30 test entries with expected extractions
- Run monthly and after prompt changes
- Threshold: >80% accuracy

**Layer 3: Output structure validation**
- Run on every AI response
- Validate schema and required fields
- Check word/bullet count caps

**Layer 4: Prompt regression testing**
- Run before deploying prompt changes
- Compare outputs to baseline

**Acceptable variation:**
- Wording differences: OK
- Missing signal: Flag if >20% of golden set
- Wrong signal: Flag any occurrence

### 10.4 Test Infrastructure

- Mock AI providers for unit tests
- In-memory SQLite for data layer tests
- Jest or Vitest for business logic

---

## 11) Analytics and Telemetry

### 11.1 Privacy-First Approach

- ON by default with clear opt-out in Settings
- Anonymized user ID (no PII)
- Aggregated reporting only
- Privacy-focused provider (Mixpanel, Amplitude, or PostHog)

### 11.2 Events Tracked

| Event | Properties |
|-------|------------|
| Entry created | Type (voice/text), word count |
| Brief generated | Regen count |
| Governance started | Session type |
| Feature used | Feature name, duration |
| Error occurred | Error type, screen |
| App opened | Session duration |

**NOT tracked:** Content, PII, location.

### 11.3 Key Metrics (Product Health)

**Engagement targets:**
- DAU/MAU: >25%
- Entries/week: >2
- Session duration: 3-5 minutes
- Feature adoption: >50%

**Retention targets:**
- Week 1: >40%
- Week 4: >25%
- Brief view rate: >70%
- Governance completion: >80%

**Quality targets:**
- Transcription accuracy: >98%
- Extraction accuracy: >80%
- Error rate: <2%

**Business targets:**
- Conversion (trial→paid): >10%
- Monthly churn: <5%
- NPS: >40

---

## 12) Accessibility Requirements

### 12.1 Screen Reader Support (VoiceOver/TalkBack)

- All buttons: Accessible labels
- All text: Readable in logical order
- All images: Alt text
- All inputs: Associated labels
- Logical focus order, no trapped focus

**Voice recording accessibility:**
- Screen reader pauses during recording
- Audio feedback on start/stop (recording sounds—see 12.4)
- Clear state indication

**Testing:** All flows tested with VoiceOver + TalkBack before release. Accessibility audit pre-launch.

### 12.2 Color Contrast (WCAG 2.1 AA Compliance)

| Element | Minimum Ratio |
|---------|---------------|
| Normal text | 4.5:1 |
| Large text | 3:1 |
| UI components | 3:1 against background |
| Focus indicators | 3:1 contrast |

Don't rely on color alone to convey information. Test with contrast checker tools during design.

### 12.3 Alternative Input Methods

**Text entry:** First-class alternative to voice (not secondary).

**Keyboard navigation:**
- Full navigation support
- Tab order logical
- Enter activates focused element
- Escape closes modals
- External Bluetooth keyboard supported

**Switch control:**
- All elements focusable
- No gesture-only interactions
- No time-limited actions (except opt-in silence timeout)

**Voice Control:**
- Speakable button names
- Compatible with iOS Voice Control and Android Voice Access

**Other:**
- Haptic feedback (optional, can disable in settings—patterns deferred to implementation)
- No CAPTCHA required

### 12.4 Sound Design

**MVP scope:** Recording sounds only

| Action | Sound | Notes |
|--------|-------|-------|
| Recording start | Subtle "bloop" or click | Confirms recording began |
| Recording stop | Distinct "bleep" or double-click | Confirms recording ended |

**No other sounds for MVP.** All other feedback via visual + haptic.

**User control:**
- Sounds follow device mute/silent mode
- No separate in-app sound toggle for MVP

---

## 13) Document History

### v5 (Jan 10, 2026)
Addressed 27 remaining questions from assessment. Key updates:

**Technical decisions:**
- Specified Flutter with Drift ORM as mobile framework
- Specified Claude Opus 4.5 for governance, Sonnet 4.5 for daily operations
- Added entry limits (15 min recording, 7500 words max)
- Clarified soft rate limits as warning-only (no blocking)

**UX additions:**
- Added Section 5.0 Onboarding Flow (minimal 3-screen flow, Setup deferred)
- Added Section 5.10 History (single chronological list)
- Added About section to Settings
- Added dark mode (follows system setting)
- Specified phone-only MVP (tablet deferred)

**Workflow clarifications:**
- Removed push notifications from bet tracking (in-app only for MVP)
- Added zero-entry week handling for briefs (reflection brief)
- Added Quarterly Report eligibility rules (on-demand with <30 day warning)
- Added portfolio modification rules (edits without re-setup, deletion with re-anchoring)
- Added entry editing behavior (manual re-extraction, no locking)
- Added export format requirements

**Companion documents:**
- Documented separate prompt templates, brand guide, App Store listing docs

### v4 (Jan 10, 2026)
Comprehensive update addressing 90 questions. Added technical architecture, data architecture, security, privacy, error handling, offline behavior, glossary, testing, analytics, accessibility.

### v3 and earlier
Initial specifications and iterations.
