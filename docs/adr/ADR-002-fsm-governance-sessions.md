# ADR-002: Finite State Machine for Governance Sessions

## Status

Accepted

## Context

Boardroom Journal's governance sessions (Quick Version, Setup, Quarterly Report) are multi-step workflows with:
- Specific question sequences
- Validation at each step
- Conditional branching (e.g., growth roles only appear if appreciating problems exist)
- Vagueness detection gates that can block progress
- Session persistence for resume capability

We needed an architecture that:
- Makes the flow logic explicit and testable
- Supports session persistence and resume
- Handles complex conditional logic cleanly
- Is easy to extend for new session types

## Decision

Implement governance sessions as **explicit finite state machines (FSM)**.

### Implementation Pattern

```dart
enum QuickVersionState {
  initial,
  sensitivityGate,
  question1,
  validating1,
  question2,
  // ... etc
  finalized,
  error,
}

class QuickVersionService {
  QuickVersionState _state;

  Future<void> transition(QuickVersionEvent event) async {
    switch (_state) {
      case QuickVersionState.question1:
        if (event is AnswerSubmitted) {
          await _validateAnswer(event.answer);
          _state = QuickVersionState.question2;
        }
        break;
      // ... etc
    }
  }
}
```

### Key Features
- Each state is an explicit enum value
- Transitions are explicit switch statements
- Session data persisted after each transition
- Vagueness gates are special validation states
- FSM state saved to database for resume

### Alternatives Considered

1. **Free-form chat**: Rejected - governance sessions have specific structure; free-form would make vagueness detection and validation harder.
2. **Simple step counter**: Rejected - doesn't handle conditional branching or validation states cleanly.
3. **Workflow library (e.g., flutter_bloc)**: Rejected - adds dependency; FSM pattern is simple enough to implement directly.

## Consequences

### Positive
- States and transitions are explicit and testable
- Easy to reason about session flow
- Session persistence is straightforward (just save state enum)
- Conditional logic is clear in transition table
- 100% test coverage of state transitions achievable

### Negative
- More boilerplate than free-form approach
- State enum grows with complexity
- Changes to flow require updating enum and transitions

### Implementation Notes
- State machines: `lib/services/governance/quick_version_service.dart`, `setup_service.dart`, `quarterly_service.dart`
- Tests: `test/services/quick_version_service_test.dart`, etc. - all transitions tested

## References

- PRD Section 4.3, 4.4, 4.5: Governance Session Specifications
- `lib/services/governance/`: Implementation files
