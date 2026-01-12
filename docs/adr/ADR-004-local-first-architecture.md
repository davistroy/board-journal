# ADR-004: Local-First Architecture

## Status

Accepted

## Context

Boardroom Journal is a voice-first journaling app where users may want to record entries at any time, including when offline (commute, airplane, poor signal areas). We needed an architecture that:
- Never blocks the user from creating entries
- Provides immediate feedback and responsiveness
- Syncs reliably when connectivity returns
- Works well for both single-device and multi-device users

## Decision

Implement **local-first architecture** with SQLite for local storage and PostgreSQL for server-side sync.

### Architecture Overview

```
Client (Flutter)           Server (Dart)
+---------------+          +---------------+
|   SQLite      |  <--->   |  PostgreSQL   |
|   (Drift)     |   sync   |               |
+---------------+          +---------------+
        |
        v
   [Immediate UI]
```

### Key Principles

1. **Local writes first**: All data changes write to SQLite immediately; UI updates instantly.
2. **Background sync**: Changes queue for server sync; sync happens automatically when online.
3. **Offline capable**: Full app functionality without network; sync when possible.
4. **Conflict handling**: Last-write-wins with notification (see ADR-001).

### Sync Status Tracking

Each record includes:
- `syncStatus`: pending | syncing | synced | conflict
- `serverVersion`: Version number from server
- `deletedAtUtc`: Soft delete timestamp (30-day retention)

### Alternatives Considered

1. **Server-first (traditional)**: Rejected - would block users during offline periods; poor UX for journaling.
2. **Pure offline (no sync)**: Rejected - users want multi-device access; data safety requires cloud backup.
3. **Firebase/Firestore**: Rejected - adds vendor lock-in; SQLite provides more control and works better offline.

## Consequences

### Positive
- Zero-latency user experience
- Works completely offline
- User data is always backed up locally
- Multi-device sync when online
- No vendor lock-in

### Negative
- More complex than server-only
- Conflict resolution needed
- Storage used on both client and server
- Must handle schema migrations on both sides

### Implementation Notes

**Client:**
- `lib/data/database/`: Drift ORM with 11 tables
- `lib/services/sync/`: SyncService, SyncQueue, ConflictResolver
- All repositories write locally first

**Server:**
- `backend/lib/db/`: PostgreSQL schema mirroring client
- `backend/lib/routes/sync.dart`: Sync API endpoints
- Delta sync with `since` timestamp

## References

- PRD Section 3B: Multi-Device Sync
- PRD Section 3F: Offline Mode Requirements
- Drift ORM documentation: https://drift.simonbinder.eu/
