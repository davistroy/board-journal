# Boardroom Journal Backend

REST API server for Boardroom Journal, a voice-first career journaling app with AI-powered governance.

## Quick Start

### Local Development with Docker

```bash
# Start all services (PostgreSQL + API server)
docker compose up -d

# View logs
docker compose logs -f backend

# Stop services
docker compose down
```

The API will be available at `http://localhost:8080`.

### Local Development without Docker

1. Start PostgreSQL and create database:
```bash
createdb boardroom_journal
psql boardroom_journal < lib/db/schema.sql
```

2. Set environment variables:
```bash
cp .env.example .env
# Edit .env with your values
```

3. Install dependencies and run:
```bash
dart pub get
dart run bin/server.dart
```

## API Endpoints

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/health` | Health check | No |
| GET | `/version` | API version | No |
| POST | `/auth/oauth/{provider}` | Exchange OAuth code for tokens | No |
| POST | `/auth/refresh` | Refresh access token | No |
| GET | `/auth/session` | Validate session | Yes |
| GET | `/sync?since={timestamp}` | Get changes since timestamp | Yes |
| POST | `/sync` | Push local changes | Yes |
| GET | `/sync/full` | Full data download | Yes |
| GET | `/account` | Get account info | Yes |
| DELETE | `/account` | Delete account (7-day grace) | Yes |
| GET | `/account/export` | Export all data | Yes |
| POST | `/ai/transcribe` | Transcribe audio | Yes |
| POST | `/ai/extract` | Extract signals from transcript | Yes |
| POST | `/ai/generate` | Generate content (briefs, etc.) | Yes |

## Authentication

The API uses JWT tokens for authentication:

1. **Access Token**: 15-minute expiry, included in `Authorization: Bearer <token>` header
2. **Refresh Token**: 30-day expiry, used to obtain new access tokens

### OAuth Flow

1. Client initiates OAuth with Apple/Google
2. Client sends authorization code to `/auth/oauth/{provider}`
3. Server exchanges code for user info
4. Server returns access + refresh tokens

## Sync Protocol

The sync system uses last-write-wins conflict resolution:

### Get Changes
```bash
GET /sync?since=2024-01-15T10:30:00Z
```

### Push Changes
```bash
POST /sync
Content-Type: application/json

{
  "records": [
    {
      "table_name": "daily_entries",
      "record_id": "uuid-here",
      "operation": "INSERT",
      "client_version": 0,
      "data": { ... }
    }
  ]
}
```

## Configuration

See `.env.example` for all configuration options. Required variables:
- `DATABASE_PASSWORD`
- `JWT_SECRET`

## Rate Limiting

Per PRD Section 3D:
- Account creation: 3 per IP per hour
- Auth attempts: 5 failures = 15-minute lockout
- AI endpoints: 100 requests per minute

## Testing

```bash
dart test
```

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment instructions.

## Architecture

```
backend/
├── bin/server.dart       # Entry point
├── lib/
│   ├── config/           # Environment configuration
│   ├── routes/           # API route handlers
│   ├── middleware/       # Auth, rate limiting, etc.
│   ├── db/               # Database connection & queries
│   ├── services/         # Business logic
│   └── models/           # API models
└── test/                 # Tests
```

## License

Proprietary - Boardroom Journal
