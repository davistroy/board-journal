# Boardroom Journal

A voice-first journal that turns your week into a one-page executive brief and runs a receipts-based career governance system using a five-role AI board with distinct personas.

## Platforms

- Mobile: iOS + Android
- Export: Markdown

## Core Loop

**Daily capture → Weekly brief → Board governance sessions (Quick / Setup / Quarterly) → portfolio + bets updated → repeat**

## Features

### Daily Journal Entry
- Voice capture with transcription
- Editable transcripts with extracted signals (wins, blockers, risks, avoided decisions, comfort work)
- Smart follow-up questions to fill gaps (max 3, skippable)
- Hard cap: 3 entries per day

### Weekly Brief
- Auto-generates Sunday 8pm local time
- One-page executive summary with strict caps:
  - Headline (max 2 sentences)
  - Wins/Blockers/Risks (max 3 bullets each)
  - Open Loops (max 5 bullets)
  - Next Week Focus (top 3)
  - Avoided Decision + Comfort Work (1 each)
- Regeneration options: shorter, more actionable, more strategic

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
- Define 3-5 career problems with required fields
- Create 5 AI board members with distinct personas
- Each board member anchored to a specific problem

#### Quarterly Board Report
- Evidence-based review with strength labels (Strong/Medium/Weak/None)
- Last bet evaluation
- Commitments vs actuals
- Board member interrogation with anchored questions
- Next quarter bet with falsifiable criteria

## Authentication

OAuth sign-in: Apple / Google / Microsoft

## MVP Out-of-Scope

- Reminders/notifications
- Attachments, links, file uploads
- Web app
- Calendar/email integrations
- PDF export

## Privacy

- Audio deleted after successful transcription (default)
- Only text transcripts and generated artifacts stored
- "Delete everything" option available
- Sensitive-mode: auto-strips names/emails with placeholders

## Technical Notes

- Governance runners implemented as finite state machines
- Schema + rule validation for output caps/sections
- One-question-at-a-time enforcement
- Vagueness detection with concrete example requirements
