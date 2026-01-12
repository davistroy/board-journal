# ADR-001: Sync Conflict Resolution Strategy

## Status

Accepted

## Context

Boardroom Journal supports multi-device sync, which creates the possibility of edit conflicts when the same entry is modified on different devices while offline.

We needed to choose a conflict resolution strategy that:
- Minimizes data loss risk
- Is simple for users to understand
- Can be implemented reliably without complex merge logic
- Works well for the journal entry use case (prose text, not structured data)

## Decision

We use **last-write-wins** conflict resolution with **user notification**.

### Implementation Details

1. **Detection**: Server tracks `serverVersion` for each record. Client sends local version when pushing changes.
2. **Resolution**: When versions conflict, the most recent `updatedAt` timestamp wins.
3. **Notification**: User receives a message: "This entry was also edited on your other device. Showing most recent version."
4. **Logging**: Overwritten versions are logged for potential manual recovery.

### Alternatives Considered

1. **Manual conflict resolution UI**: Rejected - too complex for journal entries; users wouldn't want to diff paragraph changes.
2. **CRDT-based merging**: Rejected - overkill for prose text; character-level merging could produce nonsensical content.
3. **Automatic merging**: Rejected - journal entries are prose, not structured data; merging could lose narrative coherence.

## Consequences

### Positive
- Simple to implement and understand
- No merge UI needed
- Works reliably in all cases
- Fast sync without complex reconciliation

### Negative
- Potential data loss if same entry edited on multiple devices offline
- User must manually re-add content from overwritten version if needed

### Mitigations
- Users rarely edit the same entry on multiple devices simultaneously
- Daily entries are date-specific, reducing collision likelihood
- Notifications make users aware conflicts occurred
- Server logs allow manual recovery if needed

## References

- PRD Section 3B.2: Multi-Device Sync Strategy
- `lib/services/sync/conflict_resolver.dart`: Implementation
