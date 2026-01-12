# Backend Deployment

For comprehensive deployment instructions, see the main **[DEPLOY.md](../DEPLOY.md)** in the project root.

This document provides backend-specific quick reference.

---

## Quick Reference

### Local Development

```bash
# Start PostgreSQL + API server
docker compose up -d

# View logs
docker compose logs -f

# Stop
docker compose down
```

### Build Docker Image

```bash
docker build -t boardroom-journal-backend:latest .
```

### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_PASSWORD` | PostgreSQL password |
| `JWT_SECRET` | JWT signing secret (64+ bytes) |

### All Environment Variables

See `backend/.env.example` for the complete list with documentation.

### API Endpoints

| Method | Endpoint | Auth |
|--------|----------|------|
| GET | `/health` | No |
| GET | `/version` | No |
| POST | `/auth/oauth/{provider}` | No |
| POST | `/auth/refresh` | Refresh token |
| GET | `/auth/session` | Yes |
| GET | `/sync?since={timestamp}` | Yes |
| POST | `/sync` | Yes |
| GET | `/sync/full` | Yes |
| GET | `/account` | Yes |
| DELETE | `/account` | Yes |
| GET | `/account/export` | Yes |
| POST | `/ai/transcribe` | Yes |
| POST | `/ai/extract` | Yes |
| POST | `/ai/generate` | Yes |

### Database Schema

Schema file: `lib/db/schema.sql`

Tables:
- `users` - User accounts
- `refresh_tokens` - JWT refresh tokens
- `rate_limit_auth` - Auth rate limiting
- `rate_limit_account_creation` - Account creation rate limiting
- `daily_entries` - Journal entries
- `weekly_briefs` - Generated weekly briefs
- `problems` - Portfolio problems
- `portfolio_versions` - Portfolio snapshots
- `board_members` - AI board roles
- `governance_sessions` - Governance session records
- `bets` - 90-day predictions
- `evidence_items` - Evidence for claims
- `resetup_triggers` - Re-setup trigger tracking
- `user_preferences` - User settings
- `sync_log` - Change tracking for sync

### Maintenance Functions

```sql
-- Expire overdue bets (run daily)
SELECT expire_overdue_bets();

-- Process scheduled account deletions (run daily)
SELECT process_scheduled_deletions();

-- Clean up soft deletes older than 30 days (run weekly)
SELECT cleanup_soft_deletes();
```

---

For full deployment instructions including Railway, Render, Cloud Run, OAuth setup, and mobile app deployment, see **[DEPLOY.md](../DEPLOY.md)**.
