# PRD v3 — Boardroom Journal (MVP)

**Date:** Jan 9, 2026  
**Platforms:** Mobile (iOS + Android)  
**Exports:** Markdown only (MVP)

## Locked assumptions
- Default persona tone: **warm-direct blunt**
- Weekly brief auto-generates: **Sunday 8:00pm local** (use device timezone; America/New_York default)
- Daily entry cap: **hard cap 3/day, no override**

---

## 1) Product Definition

### 1.1 One-sentence pitch
A voice-first journal that turns your week into a one-page executive brief and runs a receipts-based career governance system using a five-role AI board with distinct personas.

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
- OAuth sign-in: Apple / Google / Microsoft
- Voice capture + transcription + edit
- Store text transcripts + generated artifacts
- Career Governance module:
  - **Quick Version (15-min audit)**
  - **Setup (Problem Portfolio + Board Roles + Personas)**
  - **Quarterly Board Report**
- Weekly brief auto-gen + manual regen
- Markdown export (share sheet)

### 2.2 MVP out-of-scope
- Reminders/notifications
- Attachments, links, file uploads
- Web app
- Calendar/email integrations
- PDF export

---

## 3) Information Architecture

### 3.1 Primary objects
- **DailyEntry**: transcriptRaw, transcriptEdited, extractedSignals, createdAt
- **WeeklyBrief**: weekRange, briefMarkdown, boardMicroReviewMarkdown, generatedAt
- **ProblemPortfolio**: problems[3–5], portfolioRisk, version, updatedAt
- **BoardMember** (x5): roleType, personaProfile, anchoredProblemId, anchoredDemand
- **GovernanceSession**: type (Quick/Setup/Quarterly), transcriptQandA, outputMarkdown, createdAt
- **Bet**: prediction, wrongIf, createdAt, dueDate (+90 days), status

### 3.2 “Receipts” in MVP = Evidence statements (not files)
EvidenceItem: type (Decision/Artifact/Calendar/Proxy/None), text, strengthFlag (Strong/Medium/Weak/None)

---

## 4) Workflow State Machines (MVP)

Below are the exact conversational state machines. These are the “do not screw up” mechanics.

---

### 4.1 Daily Journal Entry — State Machine

**Goal:** Save a DailyEntry with a clean transcript and minimal structured extraction.

**States**
1. **Idle**
2. **Recording**
3. **Transcribing (streaming or post)**
4. **Edit Transcript**
5. **Gap Check**
6. **Follow-up Q (1..3)**
7. **Confirm & Save**
8. **Saved**
9. **Error / Recovery**

**Transitions & rules**
- Idle → Recording (tap record)
- Recording → Transcribing (tap stop OR silence timeout **[NEED INPUT: default silence timeout; assumed 8s]**)
- Transcribing → Edit Transcript (show transcript; allow edits)
- Edit Transcript → Gap Check
- Gap Check:
  - If missing any of: wins, blockers, risks, avoided decision, comfort work → ask up to **3** follow-ups max.
  - Follow-ups are **one at a time**.
- Follow-up Q → Gap Check (after each answer)
- Gap Check → Confirm & Save (when complete or follow-up limit reached)
- Confirm & Save → Saved

**Anti-annoyance policy**
- If user explicitly says “skip” → stop follow-ups, save anyway.
- If user answers “none” for Avoided Decision/Comfort Work → accept and record “none”.

**Save requirements**
- Must save transcriptEdited (even if identical to raw)
- Must store extractedSignals (best-effort)
- Audio deletion after successful transcription (default)

---

### 4.2 Weekly Brief Generation — State Machine

**Goal:** Produce one-page weekly executive brief + optional board micro-review.

**States**
1. **Scheduled Trigger** (Sunday 8pm) OR **Manual Trigger**
2. **Collect Week Entries**
3. **Summarize**
4. **Render One-Page Brief**
5. **Optional Micro-Review**
6. **Publish**
7. **User Edit / Regen**
8. **Finalized**

**Rules**
- Week range = Mon 00:00 → Sun 23:59 in device timezone.
- Output must obey strict caps:
  - Headline: max 2 sentences
  - Wins/Blockers/Risks: max 3 bullets each
  - Open Loops: max 5 bullets
  - Next Week Focus: top 3
  - Avoided Decision + Comfort Work: 1 each (or “none”)
- Regen options: “shorter”, “more actionable”, “more strategic”
- User edits should persist; regen must preserve edits unless “Start over” chosen

---

### 4.3 Quick Version (15-min Audit) — State Machine

**Goal:** Run the exact 5-question audit, enforce concreteness, output the required summary + 90-day bet.

**States**
0. **Sensitivity Gate**
1. **Q1 Role Context**
2. **Q2 Paid Problems (3)**
3. **Q3 Problem Direction Loop** (for each problem)
4. **Q4 Avoided Decision**
5. **Q5 Comfort Work**
6. **Generate Output**
7. **Finalize**

**Enforcement mechanism: “Vague → Concrete Example”**
At every Q state:
- Run **Vagueness Check** on answer.
- If vague → transition to **ClarifyExample**: “Give one concrete example.”
- Only return to main Q state after example is provided.

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

**Goal:** Create a portfolio (3–5 problems fully specified) and instantiate the five board members with personas anchored to specific problems.

**States**
0. **Sensitivity Gate**
1. **Collect Problem #1**
2. **Validate Problem #1 Fields**
3. **Repeat for Problem #2..#5**
4. **Portfolio Completeness Gate**
5. **Create Board Roles (anchored)**
6. **Create Personas (one per role)**
7. **Portfolio Risk**
8. **Publish Portfolio + Board**

**Required fields per problem (hard gate)**
- Name
- What breaks if not solved
- Scarcity signals: pick **2** OR Unknown + why
- Direction evidence (quotes) for:
  - AI cheaper?
  - Error cost?
  - Trust required?
- Classification + one-sentence rationale
- If unclear: “Stable (uncertain)” + evidence to clarify next quarter

**Persona creation (MVP)**
For each of the five roles:
- Generate personaName + personaProfile defaults
- Tie to one problem (anchoredProblemId)
- Define anchoredDemandOrQuestion (specific, not generic)

---

### 4.5 Quarterly Board Report — State Machine

**Goal:** Produce a completed board report with gates, evidence strength calls, anchored role questions, and falsifiable next bet.

**States**
0. **Gate 0: Require Portfolio + Board**
1. **Q1 Last Bet**
2. **Q2 Commitments vs Actuals**
3. **Q3 Avoided Decision**
4. **Q4 Comfort Work**
5. **Q5 Portfolio Check**
6. **Q6 Next Bet**
7. **Board Role Interrogation**
8. **Generate Report**
9. **Finalize**

**Evidence enforcement**
- When user claims progress, require an EvidenceItem.
- Label evidence strength:
  - Decision/Artifact = Strong
  - Proxy = Medium
  - Calendar-only = Weak (explicitly called out)
  - No receipt = None (and that’s recorded, not “fixed”)

**Anchored role interrogation**
Each of the five board members asks **their anchored question** (one at a time) and pushes back if vague.

---

## 5) Screen-by-Screen UX (MVP)

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
- Record/Stop
- Live transcript display
- Minimal controls: pause/cancel/save
- After stop: edit transcript view
- “Save” always available (no hostage-taking)

**Acceptance criteria**
- Save an entry in <60 seconds end-to-end in normal conditions
- If transcription fails, user can retry or save raw notes as text
- Audio deleted after successful transcription (default)

---

### 5.3 Entry Review
- Transcript editable
- “Detected signals” preview (wins/blockers/risks/avoided decision/comfort work/actions)
- Quick “fix” option: edit extracted bullets (not mandatory)

**Acceptance criteria**
- Users can correct extraction without editing the whole transcript
- If user edits transcript, extraction can be re-run on demand

---

### 5.4 Weekly Brief Viewer
- One-page executive brief (collapsed by default)
- Optional “Board Micro-Review”
- Buttons: Regenerate (shorter/actionable/strategic), Export Markdown, Edit

**Acceptance criteria**
- Default view fits on one screen with minimal scrolling
- Regeneration respects caps and preserves edits unless “Start over”

---

### 5.5 Governance Hub
Tabs:
- Quick Version
- Setup (Portfolio)
- Quarterly
- Board (roles + personas)

**Acceptance criteria**
- If no portfolio exists:
  - Quarterly tab is locked with explanation + “Run Setup”
- Board tab shows five members and their anchored problem links

---

### 5.6 Quick Version Runner
- One question at a time
- “Answer” input: voice or text
- Vague response triggers forced “concrete example” follow-up
- End screen: audit output markdown + Export

**Acceptance criteria**
- Cannot proceed past vagueness gate without example  
- **[NEED INPUT]** Optional: allow two-step skip but record “refused example”

---

### 5.7 Setup Runner
- Stepper UI: Problem 1..N → Board roles/personas → Portfolio risk
- Hard gating prevents moving forward with missing required fields
- Final screen: Portfolio markdown + Board roster + Export

**Acceptance criteria**
- Exactly 3–5 problems stored
- Each problem contains required fields
- Board members anchored to specific problems and demands

---

### 5.8 Quarterly Runner
- One question at a time
- Evidence strength labeling displayed (“Calendar-only = weak”)
- Board members ask anchored questions (MVP: after the 6 prompts)

**Acceptance criteria**
- Generated report contains every required section filled
- Bets always include “wrong if”
- Missing receipts are explicitly recorded

---

### 5.9 Settings
- Account
- Privacy: audio retention default delete; delete data
- Persona tone baseline: warm-direct blunt (editable)
- Export defaults

**Acceptance criteria**
- “Delete everything” fully removes user content and artifacts
- Clear explanation of what’s stored (text transcripts + outputs)

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
- **[NEED INPUT]** privacy statement wording (“never used to train”, “not shared”, etc.)
- Sensitive-mode: user can mark a session “abstracted,” and the system automatically:
  - strips names/emails
  - replaces entities with placeholders (“my manager”, “client A”)

---

## 7) Acceptance Criteria Summary (MVP “Definition of Done”)
1) **Daily entry** saved reliably with transcript, editable, stored.  
2) **Weekly brief** auto-generated Sunday 8pm, one-page format, strict caps.  
3) **Quick Version** runs exactly 5 questions, one at a time, with vagueness gating and required final output.  
4) **Setup** produces portfolio (3–5 problems), board roles anchored, personas created; gating enforced.  
5) **Quarterly** produces a fully completed board report with evidence strength labels, anchored questions, and falsifiable next bet.  
6) **Markdown export** works for weekly + governance outputs.  
7) **Delete data** works (single session + full account).  

---

## 8) Implementation Notes (opinionated)
- Implement governance runners as **finite state machines**, not a free-form chat thread.
- Validate outputs with a **schema + rule checker**. If caps/sections are violated, auto-regenerate with correction instructions.
- Start extraction simple (wins/blockers/risks/actions/avoided decision/comfort work) and iterate.

---

## 9) Remaining “Need Input” Items (optional, not blockers)
- **[NEED INPUT]** Silence timeout default (assumed 8 seconds)
- **[NEED INPUT]** Whether users can “skip” vagueness gates (recommended: allow two-step skip but record as “refused example”)
- **[NEED INPUT]** Product privacy statement wording
