# PRD Assessment: Boardroom Journal (MVP)

**Assessment Date:** January 10, 2026
**PRD Version Reviewed:** v3
**Assessor:** Claude (Automated Review)

---

## Executive Summary

This PRD demonstrates strong product thinking with well-designed conversational state machines and clear anti-annoyance patterns. The core loop is coherent and the governance system is thoughtfully structured.

However, the document contains significant gaps that must be resolved before development begins. This assessment identifies **32 discrete items** requiring resolution, organized into four priority tiers.

### Gap Summary by Category

| Category | Critical | High | Medium | Low | Total |
|----------|----------|------|--------|-----|-------|
| Core Product Definition | 2 | 1 | 0 | 0 | 3 |
| Technical Specifications | 3 | 3 | 2 | 1 | 9 |
| User Experience | 1 | 2 | 2 | 1 | 6 |
| Data Architecture | 1 | 2 | 1 | 0 | 4 |
| Security & Privacy | 2 | 1 | 1 | 0 | 4 |
| Error Handling | 1 | 1 | 1 | 0 | 3 |
| Non-Functional Requirements | 0 | 1 | 1 | 1 | 3 |
| **Total** | **10** | **11** | **8** | **3** | **32** |

---

## Priority Definitions

| Priority | Definition | Timeline |
|----------|------------|----------|
| **Critical** | Blocks development start; must resolve before sprint 1 | Immediate |
| **High** | Blocks feature completion; must resolve before feature development | Before feature sprint |
| **Medium** | Causes implementation ambiguity; resolve during development | During development |
| **Low** | Nice-to-have clarity; can resolve post-MVP | Post-MVP |

---

## Critical Priority Items

### C1. Board Roles Not Defined

**Impact:** The entire governance system references "five board members" and "five roles" but never specifies what these roles are. This is fundamental to the product's core value proposition.

**PRD References:** Lines 58, 173-204, 230-232, 295, 324

**Questions to Resolve:**

1. What are the names/titles of the five board roles?
   - Are they functional roles (e.g., "CFO", "CTO", "CHRO")?
   - Are they archetype roles (e.g., "Devil's Advocate", "Optimist", "Pragmatist")?
   - Are they domain roles (e.g., "Career Strategist", "Skills Advisor", "Network Coach")?

2. What is the specific mandate/responsibility of each role?
   - What types of questions does each role focus on?
   - What perspective does each role bring to governance sessions?
   - Are there topics only certain roles address?

3. How do roles differ in their interaction style?
   - Do different roles have different "pushback" thresholds?
   - Do roles have different evidence requirements?
   - Are some roles more supportive vs challenging?

4. What are the default persona profiles for each role?
   - What personality traits define each default persona?
   - What communication style does each persona use?
   - What are example names for each persona?

5. How are roles anchored to problems?
   - Can multiple roles anchor to the same problem?
   - What happens if there are only 3 problems but 5 roles?
   - Is the anchoring algorithm defined or user-selected?

6. What are example "anchored demands" for each role type?
   - Provide 2-3 examples per role
   - Define the format/structure of an anchored demand
   - How specific must demands be?

---

### C2. LLM Provider & Integration Strategy

**Impact:** The entire product depends on LLM capabilities for extraction, brief generation, governance conversations, and vagueness detection. No guidance on implementation.

**PRD References:** Lines 352-398 (Prompt Assembly Strategy)

**Questions to Resolve:**

1. Which LLM provider will be used?
   - OpenAI (GPT-4, GPT-4o)?
   - Anthropic (Claude)?
   - Google (Gemini)?
   - Multiple providers with fallback?

2. What model(s) will be used for each function?
   - Daily entry signal extraction: which model?
   - Weekly brief generation: which model?
   - Governance conversations: which model?
   - Vagueness detection: which model (or heuristic)?

3. What are the cost constraints?
   - Maximum cost per daily entry?
   - Maximum cost per weekly brief?
   - Maximum cost per governance session?
   - Monthly cost cap per user?

4. How will deterministic outputs be achieved?
   - Temperature settings for each function?
   - Use of structured output modes (JSON mode, function calling)?
   - Seed values for reproducibility?
   - Output validation and retry strategy?

5. What is the latency budget?
   - Maximum acceptable latency for signal extraction?
   - Maximum acceptable latency for brief generation?
   - Maximum acceptable latency per governance question?
   - Streaming vs batch responses?

6. What is the fallback strategy?
   - Behavior when LLM service is unavailable?
   - Retry logic and backoff strategy?
   - Graceful degradation options?
   - User notification approach?

7. How will prompts be managed?
   - Version control for prompts?
   - A/B testing capability?
   - Prompt update deployment process?

---

### C3. Transcription Service Specification

**Impact:** Voice capture is the primary input modality. Without transcription specs, cannot estimate costs, latency, or build recording UX.

**PRD References:** Lines 34, 78-108, 254-266

**Questions to Resolve:**

1. Which transcription service will be used?
   - OpenAI Whisper (API or self-hosted)?
   - Deepgram?
   - AssemblyAI?
   - Google Speech-to-Text?
   - Apple/Android native APIs?
   - Combination (native for streaming, cloud for accuracy)?

2. Streaming vs batch transcription?
   - Real-time display during recording (requires streaming)?
   - Post-recording transcription acceptable?
   - Hybrid approach (streaming preview, batch final)?

3. What languages are supported in MVP?
   - English only?
   - Multiple languages?
   - Language auto-detection?
   - Accent/dialect handling?

4. What is the accuracy requirement?
   - Minimum Word Error Rate (WER) target?
   - Handling of technical jargon and proper nouns?
   - Custom vocabulary support?

5. Audio specifications?
   - Recording format (WAV, M4A, MP3)?
   - Sample rate requirements?
   - Mono vs stereo?
   - Maximum recording duration?
   - File size limits?

6. What is the silence timeout default?
   - PRD assumes 8 seconds — is this correct?
   - Should this be user-configurable?
   - How is "silence" defined (dB threshold)?

7. Offline recording capability?
   - Can users record without network?
   - Store-and-forward when network returns?
   - Local transcription fallback?

---

### C4. Data Storage Architecture

**Impact:** No specification of where data lives. Critical for privacy compliance, sync strategy, and technical architecture.

**PRD References:** Lines 55-64, 105-107

**Questions to Resolve:**

1. Where is user data stored?
   - Cloud-only (which provider)?
   - Local-first with cloud sync?
   - Hybrid (some local, some cloud)?

2. What database technology?
   - Cloud: PostgreSQL? MongoDB? Firebase?
   - Local: SQLite? Realm? Core Data?
   - Sync: Custom? Firebase? Supabase?

3. What is the data residency strategy?
   - US-only servers acceptable?
   - EU data residency for GDPR?
   - User-selectable region?

4. How is data encrypted?
   - Encryption at rest (algorithm, key management)?
   - Encryption in transit (TLS version)?
   - End-to-end encryption for transcripts?
   - Client-side encryption before upload?

5. What is the backup strategy?
   - Backup frequency?
   - Retention period?
   - Point-in-time recovery capability?
   - User-accessible backups/exports?

6. What are the data retention policies?
   - How long are transcripts retained?
   - How long are governance sessions retained?
   - Automatic deletion options?
   - Legal hold capabilities?

---

### C5. Privacy Policy & Legal Compliance

**Impact:** App stores require privacy policy. GDPR/CCPA compliance is legally mandatory. Cannot ship without this.

**PRD References:** Lines 342-349, 392-398, 407

**Questions to Resolve:**

1. What data is sent to third parties?
   - Transcription service: audio sent? Text only?
   - LLM provider: what context is sent?
   - Analytics: what events/data?
   - Crash reporting: what data included?

2. What is the data processing legal basis?
   - Consent-based?
   - Legitimate interest?
   - Contract performance?

3. What user rights must be supported?
   - Right to access (data export)?
   - Right to deletion (and timeline)?
   - Right to portability (format)?
   - Right to rectification?

4. What is the privacy statement wording for:
   - "Your data is never used to train AI models"?
   - "Your data is not shared with third parties"?
   - Audio deletion policy?
   - Third-party data processing disclosure?

5. What compliance frameworks apply?
   - GDPR (EU users)?
   - CCPA (California users)?
   - HIPAA (if health-adjacent)?
   - SOC 2 (enterprise customers)?

6. What is the data processing agreement status?
   - DPA with LLM provider?
   - DPA with transcription service?
   - DPA with cloud infrastructure?

7. How does "abstracted" sensitive mode work legally?
   - Is placeholder replacement sufficient for compliance?
   - Who/what performs the abstraction?
   - Is original data retained or destroyed?

---

### C6. Authentication Flow Details

**Impact:** OAuth sign-in is listed as MVP scope but no flow details. Cannot implement without specifics.

**PRD References:** Lines 33, 341

**Questions to Resolve:**

1. What OAuth scopes are requested from each provider?
   - Apple: name, email only?
   - Google: profile, email only?
   - Microsoft: profile, email only?

2. What user data is collected at sign-up?
   - Display name (from OAuth or user-entered)?
   - Email (required or optional)?
   - Timezone (auto-detect or user-select)?

3. How are sessions managed?
   - Session token duration?
   - Refresh token strategy?
   - Concurrent session limit?

4. What is the account recovery flow?
   - Lost access to OAuth provider?
   - Email-based recovery option?
   - Support escalation path?

5. What is the account deletion flow?
   - Soft delete with recovery period?
   - Hard delete timeline?
   - Data export before deletion?

6. Is biometric authentication supported?
   - Face ID / Touch ID on iOS?
   - Fingerprint on Android?
   - Required or optional?
   - For app unlock or re-authentication?

---

### C7. Onboarding Flow Definition

**Impact:** No first-run experience defined. Critical for user retention and product understanding.

**PRD References:** Not addressed

**Questions to Resolve:**

1. What is the first-run experience?
   - Splash/welcome screens?
   - Feature tour/tutorial?
   - Skip option available?

2. How is the core loop introduced?
   - Animated explanation?
   - Sample entry walkthrough?
   - Interactive tutorial?

3. When is Setup prompted?
   - Immediately after onboarding?
   - After first entry?
   - After first week?
   - User-initiated only?

4. What are the onboarding steps?
   - Account creation (OAuth)
   - Timezone confirmation
   - Microphone permission
   - Notification permission (even if not MVP, OS may require)
   - Tutorial/walkthrough
   - First action prompt

5. How long should onboarding take?
   - Target time to first entry?
   - Maximum onboarding screens?

6. What empty states are shown?
   - Home with no entries?
   - Weekly brief area with no briefs?
   - Governance hub with no portfolio?

---

### C8. Error Handling & Recovery Specifications

**Impact:** State machines reference "Error / Recovery" state but provide no details. Will cause inconsistent error handling.

**PRD References:** Lines 86-87, 409

**Questions to Resolve:**

1. What errors can occur in Daily Entry flow?
   - Microphone permission denied
   - Recording failure (hardware)
   - Transcription service unavailable
   - Transcription timeout
   - Save to storage failed
   - Network lost mid-transcription

2. What is the recovery strategy for each error?
   - Automatic retry (how many times)?
   - User-prompted retry?
   - Fallback behavior?
   - Data preservation strategy?

3. What errors can occur in governance sessions?
   - LLM service unavailable
   - Response timeout
   - Invalid/unparseable response
   - Session state corruption

4. How is partial progress preserved?
   - Auto-save frequency?
   - Resume from last good state?
   - Manual save points?

5. What is the user notification strategy?
   - Toast messages?
   - Modal dialogs?
   - Inline error states?
   - Error codes for support?

6. What logging/telemetry is captured for errors?
   - Error type and frequency
   - User context (sanitized)
   - Recovery success rate
   - Support escalation triggers

---

### C9. Weekly Brief Generation Edge Cases

**Impact:** Weekly brief is a core feature. Edge cases will cause user confusion and support tickets.

**PRD References:** Lines 111-135, 279-288

**Questions to Resolve:**

1. What if user has zero entries for a week?
   - Generate empty brief with message?
   - Skip generation entirely?
   - Notify user?

2. What if Sunday 8pm generation fails?
   - Automatic retry logic?
   - Retry schedule?
   - User notification?
   - Manual generation fallback?

3. What if user is in a different timezone than usual?
   - Traveling user scenario
   - Does brief generate at "home" 8pm or current 8pm?
   - How is timezone change detected?

4. Can users manually trigger generation before Sunday?
   - "Generate now" button?
   - Does this replace scheduled generation?
   - Can they generate mid-week preview?

5. What if user has entries from previous week that weren't included?
   - Late entries (Monday 00:01 after brief generated)
   - Edited entries after brief generation
   - Regeneration includes new data?

6. How are regeneration options implemented?
   - "Shorter" — reduce word count by what %?
   - "More actionable" — specific prompt changes?
   - "More strategic" — specific prompt changes?
   - Maximum regeneration attempts?

7. How are user edits preserved during regeneration?
   - Which fields are edit-locked?
   - How is "Start over" different from "Regenerate"?
   - Edit history preserved?

---

### C10. Success Metrics & KPIs

**Impact:** Cannot measure MVP success without defined metrics. Critical for go/no-go decisions.

**PRD References:** Not addressed

**Questions to Resolve:**

1. What are the primary success metrics?
   - Daily Active Users (DAU) target?
   - Weekly Active Users (WAU) target?
   - User retention (D1, D7, D30)?

2. What are the engagement metrics?
   - Average entries per user per week?
   - Weekly brief view rate?
   - Governance session completion rate?
   - Export usage rate?

3. What are the quality metrics?
   - Entry completion rate (started vs saved)?
   - Brief regeneration rate (proxy for quality)?
   - Governance session abandonment rate?
   - Vagueness gate trigger rate?

4. What are the technical metrics?
   - Transcription accuracy (sampled)?
   - Brief generation success rate?
   - App crash rate?
   - Average latency by operation?

5. What are the MVP launch criteria?
   - Minimum beta user count?
   - Maximum critical bug count?
   - Minimum feature completion?

6. What are the post-launch decision points?
   - Metrics threshold for continued investment?
   - Pivot indicators?
   - Scale indicators?

---

## High Priority Items

### H1. Multi-Device Sync Strategy

**Impact:** Users expect mobile apps to sync across devices. Without spec, cannot design data layer.

**PRD References:** Not addressed (mobile iOS + Android implies multi-device)

**Questions to Resolve:**

1. Is multi-device sync supported in MVP?
   - Same platform (two iPhones)?
   - Cross-platform (iPhone + Android)?
   - Defer to post-MVP?

2. What is the sync architecture?
   - Real-time sync?
   - Periodic sync?
   - Manual sync trigger?

3. How are conflicts resolved?
   - Last-write-wins?
   - Merge strategy?
   - User-prompted resolution?

4. What is the sync latency target?
   - Seconds? Minutes?
   - Acceptable for entries?
   - Acceptable for governance state?

5. What happens during sync failures?
   - Offline indicator?
   - Retry strategy?
   - Data integrity guarantees?

---

### H2. Offline Capabilities

**Impact:** Mobile apps must handle intermittent connectivity. No offline strategy defined.

**PRD References:** Not addressed

**Questions to Resolve:**

1. What features work offline?
   - Voice recording (store locally)?
   - View existing entries?
   - View existing briefs?
   - Start governance session?

2. What features require connectivity?
   - Transcription?
   - Brief generation?
   - Governance Q&A?

3. How is offline state communicated?
   - Visual indicator?
   - Feature degradation messaging?
   - Queue indicator for pending actions?

4. How is data synced when connectivity returns?
   - Automatic background sync?
   - User-prompted sync?
   - Conflict handling?

---

### H3. Performance Requirements

**Impact:** No SLAs defined. Developers will make arbitrary tradeoffs without guidance.

**PRD References:** Line 263 mentions "<60 seconds" for entry but no other performance specs

**Questions to Resolve:**

1. What are the latency targets by operation?
   - App launch to usable: ___ seconds
   - Tap record to recording: ___ ms
   - Recording stop to transcript display: ___ seconds
   - Entry save: ___ seconds
   - Brief generation: ___ seconds
   - Governance question response: ___ seconds

2. What are the reliability targets?
   - Transcription success rate: ___%
   - Brief generation success rate: ___%
   - App crash rate: < ___% of sessions

3. What are the capacity targets?
   - Maximum concurrent users?
   - Maximum entries per user?
   - Maximum transcript length?

4. What are the resource constraints?
   - Battery usage targets?
   - Storage usage limits?
   - Network data usage?

---

### H4. Board Micro-Review Definition

**Impact:** Referenced multiple times but never defined. Developers won't know what to build.

**PRD References:** Lines 56, 121, 281

**Questions to Resolve:**

1. What is the Board Micro-Review?
   - A summary from the board's perspective?
   - Quick feedback on the week?
   - Preview of governance concerns?

2. What content does it contain?
   - Which board members contribute?
   - What format (bullets, prose)?
   - What length (word/bullet count)?

3. How is it generated?
   - Same time as weekly brief?
   - Requires portfolio to exist?
   - Different prompt/model?

4. Why is it optional?
   - User can toggle off?
   - Only shown if portfolio exists?
   - Collapsible section?

5. What is the UX for viewing it?
   - Inline in brief?
   - Separate tab/section?
   - Expandable accordion?

---

### H5. Portfolio Risk Definition

**Impact:** Field exists in data model but never defined. Cannot implement without specification.

**PRD References:** Lines 57, 187

**Questions to Resolve:**

1. What does portfolioRisk represent?
   - Overall career risk level?
   - Concentration risk?
   - Depreciation risk?

2. What values can it have?
   - Numeric score (1-10)?
   - Categorical (Low/Medium/High/Critical)?
   - Multi-dimensional?

3. How is it calculated?
   - Algorithm based on problem classifications?
   - User-assessed?
   - AI-assessed during Setup?

4. How is it displayed?
   - Visual indicator (color, icon)?
   - Numeric display?
   - Trend over time?

5. What actions does it drive?
   - Warnings/alerts?
   - Recommendations?
   - Governance triggers?

---

### H6. Sensitivity Gate Implementation

**Impact:** Referenced at start of governance flows but never explained. Blocks governance implementation.

**PRD References:** Lines 143, 177

**Questions to Resolve:**

1. What triggers the Sensitivity Gate?
   - Always shown at session start?
   - Based on prior session content?
   - User preference setting?

2. What options does the gate present?
   - "Normal mode" vs "Abstracted mode"?
   - Content warning acknowledgment?
   - Specific sensitivity settings?

3. What does "abstracted mode" do technically?
   - Real-time entity replacement?
   - Post-processing replacement?
   - What entities are replaced (names, companies, titles)?

4. How are placeholders generated?
   - Consistent per entity ("Manager" always = same person)?
   - Random each time?
   - User-defined placeholders?

5. Is abstraction reversible?
   - Can user see original after session?
   - Is original stored at all?
   - Legal implications?

---

### H7. Vagueness Detection Implementation

**Impact:** Core enforcement mechanism but only heuristic guidance provided. Needs specification.

**PRD References:** Lines 152-157, 382-389

**Questions to Resolve:**

1. Is vagueness detection model-based or rule-based?
   - LLM classification?
   - Keyword/pattern matching?
   - Hybrid approach?

2. What are the exact trigger conditions?
   - PRD lists: no named instance + generic qualifiers + no timeline/stakeholder/outcome
   - Are all three required (AND) or any (OR)?
   - What is the full list of "generic qualifiers"?

3. How is false positive rate managed?
   - Threshold tuning?
   - User feedback mechanism?
   - Override capability?

4. What is the skip behavior?
   - PRD suggests "two-step skip" — what are the two steps?
   - What is recorded when user skips?
   - Does skip affect outputs?

5. Is vagueness detection consistent across sessions?
   - Same answer = same classification?
   - User-specific calibration?

---

### H8. Daily Entry Cap Mechanics

**Impact:** Hard cap stated but mechanics unclear. Will cause user frustration if poorly implemented.

**PRD References:** Line 10

**Questions to Resolve:**

1. What time does the cap reset?
   - Midnight device timezone?
   - Midnight account timezone?
   - Rolling 24-hour window?

2. What happens when user hits the cap?
   - What message is shown?
   - Is record button disabled or shows error on tap?
   - Is there a countdown to reset?

3. What is the rationale for 3/day?
   - Should this be communicated to users?
   - Is it based on research/testing?

4. Are there any exceptions?
   - Edit doesn't count as new entry?
   - Deleted entry frees a slot?
   - Admin override for testing?

5. How is cap enforced technically?
   - Client-side only?
   - Server-side validation?
   - Race condition handling?

---

### H9. Quote Enforcement Implementation

**Impact:** "Quote user words" is required in outputs but no technical spec for extraction.

**PRD References:** Lines 161-162, 375-376

**Questions to Resolve:**

1. How are verbatim quotes extracted?
   - LLM-based extraction?
   - Fuzzy matching to transcript?
   - Exact string matching?

2. What if user's words don't fit the required format?
   - Force verbatim even if grammatically awkward?
   - Allow light editing for clarity?
   - Show both original and clarified?

3. How are quotes validated?
   - Verify quote exists in source transcript?
   - Similarity threshold for fuzzy matching?
   - Fallback if quote not found?

4. How are quotes formatted in output?
   - Quotation marks?
   - Italics?
   - Attribution?

5. What if user gave no relevant statement?
   - "No direct statement" placeholder?
   - Paraphrase allowed?
   - Skip the field?

---

### H10. Data Model Relationships

**Impact:** Objects defined but relationships unclear. Database schema cannot be designed.

**PRD References:** Lines 55-64

**Questions to Resolve:**

1. What are the foreign key relationships?
   - WeeklyBrief → DailyEntry (which entries included?)
   - GovernanceSession → ProblemPortfolio (which version?)
   - Bet → GovernanceSession (which session created it?)
   - Bet → Problem (which problem does it relate to?)
   - BoardMember → Problem (anchoredProblemId)

2. What is the cascade delete behavior?
   - Delete Problem → Delete anchored BoardMember?
   - Delete Portfolio → Delete all Problems?
   - Delete Entry → Regenerate Brief?

3. What are the cardinality constraints?
   - One Portfolio per user? Or versioned history?
   - Exactly 5 BoardMembers always?
   - 3-5 Problems exactly, or at least 3?

4. How is historical data handled?
   - Old portfolios archived?
   - Old bets preserved after resolution?
   - Deleted entries truly deleted or soft-deleted?

---

### H11. Accessibility Requirements

**Impact:** App store guidelines and legal requirements. Often overlooked until too late.

**PRD References:** Not addressed

**Questions to Resolve:**

1. What WCAG level is targeted?
   - WCAG 2.1 Level A (minimum)?
   - WCAG 2.1 Level AA (recommended)?

2. What screen reader support is required?
   - VoiceOver (iOS)?
   - TalkBack (Android)?
   - Full app navigable via screen reader?

3. What are the voice-specific accessibility considerations?
   - Alternative text input for all voice features?
   - Captioning of any audio playback?

4. What are the visual accessibility requirements?
   - Minimum contrast ratios?
   - Dynamic text size support?
   - Color-blind friendly palette?

5. What are the motor accessibility requirements?
   - Minimum touch target sizes?
   - Gesture alternatives?
   - Switch control support?

---

## Medium Priority Items

### M1. Tech Stack Specification

**Questions to Resolve:**

1. What is the mobile framework?
   - React Native?
   - Flutter?
   - Native (Swift/Kotlin)?

2. What is the backend stack?
   - Node.js? Python? Go?
   - Serverless (Lambda/Cloud Functions)?
   - Container-based?

3. What is the infrastructure platform?
   - AWS? GCP? Azure?
   - Multi-cloud?

4. What are the CI/CD requirements?
   - Build pipeline?
   - Testing requirements?
   - Deployment strategy?

---

### M2. Analytics & Telemetry

**Questions to Resolve:**

1. What analytics platform?
   - Mixpanel? Amplitude? Firebase Analytics?

2. What events should be tracked?
   - Define event taxonomy
   - Required properties per event
   - PII handling in analytics

3. What is the crash reporting strategy?
   - Crashlytics? Sentry? Bugsnag?
   - What data is included?

---

### M3. Governance Session Abandonment

**Questions to Resolve:**

1. What happens if user closes app mid-session?
   - Auto-save current state?
   - Resume prompt on return?
   - Discard partial progress?

2. How long is partial session preserved?
   - 24 hours?
   - Until next session start?
   - User must explicitly discard?

3. Can user explicitly abandon?
   - "Exit without saving" option?
   - Confirmation dialog?
   - Partial save option?

---

### M4. Entry Editing After Save

**Questions to Resolve:**

1. Can users edit entries after saving?
   - Edit transcript?
   - Edit extracted signals?
   - Time limit on edits?

2. How do edits affect weekly brief?
   - Regeneration required?
   - Automatic update?
   - Manual sync?

3. Is edit history preserved?
   - Version history?
   - Diff view?
   - Restore previous version?

---

### M5. Text Input for Daily Entries

**Questions to Resolve:**

1. Is text-only entry supported?
   - Full feature parity with voice?
   - Different UX flow?

2. How does Gap Check work for text?
   - Same follow-up questions?
   - Inline prompts?
   - Skip gap check for text?

3. Are text and voice entries distinguished?
   - Visual indicator?
   - Different processing?
   - Combined in weekly brief?

---

### M6. Bet Resolution Flow

**Questions to Resolve:**

1. How are bets resolved?
   - Prompted at 90-day mark?
   - User-initiated resolution?
   - Part of Quarterly session?

2. What resolution options exist?
   - Correct / Wrong / Partially Correct / Inconclusive?
   - Evidence required for resolution?

3. What happens after resolution?
   - Bet archived?
   - Impacts portfolio risk?
   - Displayed in reports?

---

### M7. Export Format Specifications

**Questions to Resolve:**

1. What exactly is exported in Markdown?
   - Single entry?
   - Weekly brief?
   - Governance session output?
   - All of the above?

2. What is the Markdown format/template?
   - Heading structure?
   - Metadata inclusion?
   - Frontmatter (YAML)?

3. What share targets are supported?
   - Native share sheet only?
   - Specific app integrations?
   - Copy to clipboard?

---

### M8. Notification Permission Handling

**Questions to Resolve:**

1. Even if reminders are out of scope, do we need notification permission?
   - For weekly brief ready notification?
   - For governance session reminders (future)?

2. When is permission requested?
   - Onboarding?
   - First relevant feature use?
   - Never in MVP?

3. How is permission denial handled?
   - Feature degradation?
   - Re-prompt strategy?

---

## Low Priority Items

### L1. Entry Timestamp Display

**Questions to Resolve:**

1. How are entry times displayed?
   - Relative ("2 hours ago")?
   - Absolute ("3:45 PM")?
   - Both?

2. What timezone is displayed?
   - Creation timezone?
   - Current device timezone?

3. How are entries grouped?
   - By day?
   - By week?
   - Flat list?

---

### L2. Settings Persistence

**Questions to Resolve:**

1. Where are settings stored?
   - Local only?
   - Synced to cloud?

2. What is the default state for each setting?
   - Audio retention: delete (per PRD)
   - Persona tone: warm-direct blunt (per PRD)
   - Others?

3. Are settings migrated on app update?
   - Migration strategy?
   - Default handling for new settings?

---

### L3. History View Specifications

**Questions to Resolve:**

1. How is history organized?
   - Entries tab vs Reports tab (per PRD)?
   - Combined timeline?
   - Search capability?

2. What filtering/sorting is available?
   - By date range?
   - By type?
   - By content search?

3. What are the pagination/loading strategies?
   - Infinite scroll?
   - Page-based?
   - Initial load count?

---

## Appendix A: PRD "NEED INPUT" Items

These items are explicitly called out in the PRD as needing input:

| Item | Location | Current Assumption | Recommendation |
|------|----------|-------------------|----------------|
| Silence timeout default | Line 90 | 8 seconds | Reduce to 2-3 seconds; make configurable |
| Skip vagueness gates | Line 312 | Two-step skip, record "refused example" | Accept recommendation; implement as specified |
| Privacy statement wording | Line 394 | None | Draft with legal counsel; critical for launch |

---

## Appendix B: Acceptance Criteria Improvements

The following acceptance criteria need to be made measurable:

| Current Criteria | Improvement Needed |
|-----------------|-------------------|
| "fast and painless" (line 24) | Define: <30 sec entry, <3 taps to start |
| "short, readable, and sharp" (line 25) | Define: <500 words, Flesch-Kincaid grade <10 |
| "Save an entry in <60 seconds" (line 263) | Specify: network conditions, entry length, device type |

---

## Appendix C: Recommended Supplementary Documents

Based on this assessment, the following additional documents should be created:

1. **Technical Architecture Document** — Addresses C2, C3, C4, M1
2. **Security & Privacy Specification** — Addresses C5, C6, H6
3. **UX Flow Specifications** — Addresses C7, H4, M3, M4
4. **Data Model Schema** — Addresses C4, H10, M6
5. **API Specification** — Defines all backend endpoints
6. **Test Plan** — Defines QA approach and coverage requirements

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-10 | Claude | Initial assessment |
