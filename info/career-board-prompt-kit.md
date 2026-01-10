# Career Board Prompt Kit

**Designed to catch drift early by forcing receipts and decisions.**

## Start where you are:

- **15 minutes to test** → Quick Version
- **Set up the system** → Setup
- **Running quarterly** → The Quarterly

---

## Quick Version

Use this first. If it surfaces something, consider the full setup.

```
You are running a 15-minute career audit. Ask ONE question at a time. Wait for my answer.

Rule: If my answer is vague, stop and ask for one concrete example before continuing.

BEFORE WE START: Any sensitive details? If yes, I'll use abstractions ("my manager," "the Q2 project").

1. What do I do? (Role, context–2 sentences)

2. Name 3 problems I'm paid to solve–not tasks, but problems where my judgment matters.

3. For each problem, ask:
   - Is AI making this faster/cheaper to produce?
   - Is the cost of getting it wrong rising or falling?
   - Does it require trust, judgment, or context that doesn't transfer easily?

Then output:
| Problem | AI cheaper? | Error cost? | Trust required? | Direction |
Direction labels: Appreciating / Depreciating / Stable.
With one sentence explaining the classification based on what I said.

4. What decision have I been avoiding? Not "I could do more"–a specific conversation, risk, or commitment I haven't made. (Not just busywork–something I chose because it felt safe.)

OUTPUT:
• 2-sentence honest assessment
• The avoided decision + cost of continued avoidance
• One prediction I can verify in 90 days
• What evidence would prove that prediction wrong?
```

---

## Setup

Use once. Produces your problem portfolio and board roles.

### Output structure:

```
PROBLEM PORTFOLIO

Problem 1: [Name]
• What breaks: [What goes wrong if this isn't solved well]
• Scarcity signals (pick 2):
  - People escalate this to me when it's high-stakes
  - Others can do it, but I'm faster/more trusted
  - I'm the only one who can do it reliably
  - Unknown – [why]
• Direction:
  - AI making it cheaper: [quote my words]
  - Error cost rising/falling: [quote]
  - Trust/context required: [quote]
  - Classification: Appreciating / Depreciating / Stable / Stable (uncertain) – [reason]

[Repeat for 3-5 problems]

Portfolio risk: [One sentence–where I'm most exposed]

BOARD ROLES (anchored to problems)

1. Accountability – anchored to Problem [X]: [specific thing to demand receipts on]
2. Market Reality – anchored to Problem [X]: [specific direction label to challenge]
3. Avoidance – anchored to Problem [X]: [specific decision/conversation to probe]
4. Long-term Positioning – anchored to Problem [X]: [specific 5-year question]
5. Devil's Advocate – anchored to Problem [X]: [specific case against current path]
```

### Example:

```
PROBLEM PORTFOLIO

Problem 1: Cross-team coordination
• What breaks: Projects stall when dependencies aren't surfaced early
• Scarcity signals:
  - People escalate this to me when it's high-stakes
  - Others can do it, but I'm faster/more trusted
• Direction:
  - AI making it cheaper: "No–AI doesn't sit in the room and read politics"
  - Error cost rising: "Yes–more teams, more tools, more surface area for failure"
  - Trust/context required: "Yes–I know who actually decides vs. who just talks"
  - Classification: Appreciating – coordination failures are getting more expensive and AI can't do the human-reading part

Problem 2: Analysis quality
• What breaks: Leadership makes bad calls when models are wrong
• Scarcity signals:
  - Others can do it, but I'm faster/more trusted
  - Unknown – haven't tested if junior analysts + AI can match my output
• Direction:
  - AI making it cheaper: "Yes–I use Claude to build models 3x faster now"
  - Error cost rising: "Flat–same stakes as before"
  - Trust/context required: "Less than I thought–the model structure is transferable"
  - Classification: Depreciating – production is getting commoditized; I'm competing with AI-assisted juniors

Portfolio risk: 30% of time on depreciating skill. Exposed if I don't shift toward decision-translation.

BOARD ROLES

1. Accountability – Problem 2: "You said you'd shift hours from model-building. Show me the calendar."
2. Market Reality – Problem 2: "You labeled this 'depreciating' but you're still spending 30% here. Why?"
3. Avoidance – Problem 1: "You mentioned the timeline conversation. Have you had it?"
4. Long-term Positioning – Problem 1: "If coordination is appreciating, what are you doing to own more of it?"
5. Devil's Advocate – Problem 1: "What if your coordination skill is org-specific and doesn't transfer?"
```

### The prompt:

```
You are helping me set up career governance. Ask ONE question at a time. Wait for my answer.

Rule: If my answer is vague, stop and ask for one concrete example before continuing.

BEFORE WE START: Any sensitive details? I'll use abstractions if needed.

PART 1: PROBLEM PORTFOLIO

Help me identify 3-5 problems I'm paid to solve–recurring problems where my judgment determines outcomes.

For each problem, get:
1. What breaks if it isn't solved well
2. Scarcity signals (have me pick 2, or "Unknown + why"):
   - People escalate to me when high-stakes
   - Others can do it, but I'm faster/more trusted
   - I'm the only one who can do it reliably
3. Direction–ask the three questions, then output a table:
   | AI cheaper? | Error cost? | Trust required? |
   Quote my words for each cell. Then classify with one sentence.
   If direction is unclear, label "Stable (uncertain)" and note what evidence next quarter would clarify it.

GATE: Do not move to Part 2 until 3-5 problems have all fields. Push back on vague answers.

PART 2: BOARD ROLES

Create 5 roles. Each must be anchored to a specific problem from my portfolio:
• Accountability – what to demand receipts on
• Market Reality – what direction label to challenge
• Avoidance – what decision to probe
• Long-term Positioning – what 5-year question to ask
• Devil's Advocate – what case against current path

GATE: Each role must reference a specific problem and specific issue. No generic lines.

OUTPUT: PROBLEM PORTFOLIO + BOARD ROLES in the format shown, ending with "Portfolio risk."
```

---

## The Quarterly

Use once per quarter. Paste your Portfolio and Board Roles.

### Receipt Taxonomy:

| Type | Examples | Strength |
|------|----------|----------|
| Decision | Approved plan, documented outcome | Strong |
| Artifact | Shipped doc, merged PR, sent analysis | Strong |
| Calendar | Meeting held, time blocked | Weak alone |
| Proxy | Feedback received, metric moved | Medium |

**Rule:** Calendar-only is weak unless tied to artifact or decision.

### Output structure:

```
QUARTERLY BOARD REPORT – [Quarter, Year]

LAST BET
• Bet: [What I predicted]
• "Wrong if": [What I said would disprove it]
• Result: Happened / Didn't / Partial – [evidence]

COMMITMENTS VS. ACTUALS
• Said: [Commitment]
• Did: [Receipts only–format: "Receipt type – artifact/decision – where it exists"]
• Gap: [What didn't happen]

AVOIDED DECISION
• What: [Specific conversation/risk/conflict]
• Why avoiding: [The discomfort]
• Cost: [What gets worse]

COMFORT WORK
• What: [Something I chose because it let me avoid risk–not just busywork]
• Avoided: [The harder thing]

PORTFOLIO CHECK
• [Problem]: Direction still accurate? Any shift?

NEXT BET
• Bet: [Falsifiable prediction]
• Wrong if: [What would disprove it]
• 90-day checkpoint: [Date]
```

### The prompt:

```
You are running my quarterly board meeting. Produce a BOARD REPORT with every field filled.

I will paste my PROBLEM PORTFOLIO, BOARD ROLES, and [if not Q1] last quarter's bet.

GATE 0: If I haven't pasted my PROBLEM PORTFOLIO and BOARD ROLES, stop and ask me to paste them before continuing.

Rule: If my answer is vague, stop and ask for one concrete example or receipt before continuing.

RECEIPT HIERARCHY:
• Decision/Artifact = strong
• Calendar-only = weak (note it)
• Proxy = medium

GATES:
1. Receipts: Challenge vague claims. Quote the receipt type.
2. Avoided decision: Must be specific–a conversation, risk, conflict.
3. Comfort work: Must be something I chose to avoid risk (not just chores). If I say "email" or "meetings," ask: "What harder thing were you avoiding by doing that?"
4. Bet: Must be falsifiable + include "wrong if."

PROCESS (6 questions):
1. Last bet–what happened? Evidence?
2. Commitments–what receipts?
3. Avoided decision–what, why, cost?
4. Comfort work–what, and what were you avoiding?
5. Portfolio–any direction shifts?
6. Next bet + what would prove it wrong?

Have board roles ask their anchored questions. Be direct.

OUTPUT: Completed BOARD REPORT.
```

---

## FAQ

**If I don't have receipts:**
That's the answer. "No receipt" is data—we're mapping reality, not grading you.

**If I feel defensive:**
Good. Defensive usually means you're near the avoided decision.

---

*Source: [Notion - Career Board Prompt Kit](https://www.notion.so/product-templates/Career-Board-Prompt-Kit-2dd5a2ccb5268096b9a3d33c073e3d36)*
