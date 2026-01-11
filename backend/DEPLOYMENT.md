# Boardroom Journal Backend - Deployment Guide

## Production Deployment

This guide covers deploying the Boardroom Journal backend to production.

### Prerequisites

- Docker and Docker Compose (or Kubernetes)
- PostgreSQL 15+ database
- Domain name with SSL certificate
- OAuth credentials (Apple, Google)
- API keys (Anthropic, Deepgram)

### Option 1: Docker Deployment

#### 1. Build the Docker Image

```bash
docker build -t boardroom-journal-backend:latest .
```

#### 2. Configure Environment

Create a production environment file:

```bash
# Server
HOST=0.0.0.0
PORT=8080
ENVIRONMENT=production

# Database (use managed PostgreSQL like AWS RDS, GCP Cloud SQL)
DATABASE_HOST=your-db-host.rds.amazonaws.com
DATABASE_PORT=5432
DATABASE_NAME=boardroom_journal
DATABASE_USER=boardroom_app
DATABASE_PASSWORD=<secure-password>
DATABASE_POOL_SIZE=20

# JWT (generate with: openssl rand -base64 64)
JWT_SECRET=<64-byte-random-string>
JWT_ACCESS_TOKEN_EXPIRY_MINUTES=15
JWT_REFRESH_TOKEN_EXPIRY_DAYS=30

# Apple OAuth
APPLE_CLIENT_ID=com.boardroomjournal.app
APPLE_TEAM_ID=YOUR_TEAM_ID
APPLE_KEY_ID=YOUR_KEY_ID
APPLE_PRIVATE_KEY=<base64-encoded-p8-key>

# Google OAuth
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=<client-secret>

# AI Services
CLAUDE_API_KEY=sk-ant-...
DEEPGRAM_API_KEY=<deepgram-key>

# Rate Limiting
RATE_LIMIT_ACCOUNT_CREATION_PER_HOUR=3
RATE_LIMIT_AUTH_ATTEMPTS_BEFORE_LOCKOUT=5
RATE_LIMIT_AUTH_LOCKOUT_MINUTES=15
MAX_REQUEST_BODY_SIZE=10485760
```

#### 3. Run the Container

```bash
docker run -d \
  --name boardroom-journal-api \
  --env-file .env.production \
  -p 8080:8080 \
  --restart unless-stopped \
  boardroom-journal-backend:latest
```

#### 4. Set Up Reverse Proxy (nginx)

```nginx
upstream boardroom_api {
    server 127.0.0.1:8080;
}

server {
    listen 443 ssl http2;
    server_name api.boardroomjournal.app;

    ssl_certificate /etc/letsencrypt/live/api.boardroomjournal.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.boardroomjournal.app/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;

    # Pass real IP to backend
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $host;

    # Request limits
    client_max_body_size 10M;

    location / {
        proxy_pass http://boardroom_api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Option 2: Kubernetes Deployment

#### Deployment Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: boardroom-journal-api
  labels:
    app: boardroom-journal-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: boardroom-journal-api
  template:
    metadata:
      labels:
        app: boardroom-journal-api
    spec:
      containers:
      - name: api
        image: boardroom-journal-backend:latest
        ports:
        - containerPort: 8080
        envFrom:
        - secretRef:
            name: boardroom-journal-secrets
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: boardroom-journal-api
spec:
  selector:
    app: boardroom-journal-api
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

### Database Setup

#### 1. Create PostgreSQL Database

```sql
CREATE DATABASE boardroom_journal;
CREATE USER boardroom_app WITH ENCRYPTED PASSWORD '<password>';
GRANT ALL PRIVILEGES ON DATABASE boardroom_journal TO boardroom_app;
```

#### 2. Run Schema Migration

```bash
psql -h <db-host> -U boardroom_app -d boardroom_journal -f lib/db/schema.sql
```

#### 3. Set Up Scheduled Jobs

Create a cron job or cloud scheduler for maintenance tasks:

```bash
# Expire overdue bets (run daily at midnight)
0 0 * * * psql -c "SELECT expire_overdue_bets();" boardroom_journal

# Process scheduled deletions (run daily)
0 1 * * * psql -c "SELECT process_scheduled_deletions();" boardroom_journal

# Clean up soft deletes (run weekly)
0 2 * * 0 psql -c "SELECT cleanup_soft_deletes();" boardroom_journal
```

### OAuth Configuration

#### Apple Sign In

1. Create App ID in Apple Developer Console
2. Enable "Sign In with Apple" capability
3. Create Service ID for web authentication
4. Create and download private key (.p8 file)
5. Set environment variables:
   - `APPLE_CLIENT_ID`: Service ID (e.g., com.boardroomjournal.app)
   - `APPLE_TEAM_ID`: Your team ID
   - `APPLE_KEY_ID`: Key ID from downloaded key
   - `APPLE_PRIVATE_KEY`: Base64-encoded .p8 file contents

#### Google Sign In

1. Create project in Google Cloud Console
2. Configure OAuth consent screen
3. Create OAuth 2.0 Client ID
4. Set environment variables:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`

### Monitoring

#### Health Check

The `/health` endpoint returns:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

#### Recommended Monitoring

- Set up alerts on `/health` endpoint
- Monitor database connection pool usage
- Track API response times (P50, P95, P99)
- Monitor rate limiting triggers
- Set up log aggregation (CloudWatch, Stackdriver, etc.)

### Security Checklist

- [ ] HTTPS only (no HTTP)
- [ ] Database credentials in secrets manager
- [ ] JWT secret is cryptographically random (64+ bytes)
- [ ] Rate limiting enabled
- [ ] Request body size limits configured
- [ ] CORS restricted to production domains
- [ ] Security headers enabled (via nginx)
- [ ] Database connections use SSL
- [ ] Logs don't contain sensitive data
- [ ] OAuth redirect URIs restricted

### Backup Strategy

1. **Database**: Daily automated backups with 30-day retention
2. **Point-in-time recovery**: Enable for production databases
3. **Backup verification**: Test restore monthly

### Scaling Considerations

- The API is stateless and can be horizontally scaled
- Use Redis for rate limiting in multi-instance deployments
- Consider read replicas for database scaling
- AI endpoints may need separate rate limiting/queuing

### Troubleshooting

#### Database Connection Issues

```bash
# Test connection
psql -h <host> -U <user> -d boardroom_journal -c "SELECT 1;"

# Check connection pool
docker logs boardroom-journal-api | grep "Database"
```

#### JWT Issues

```bash
# Verify JWT secret is set
docker exec boardroom-journal-api env | grep JWT_SECRET
```

#### OAuth Issues

- Verify redirect URIs match exactly
- Check client IDs/secrets are correct
- For Apple: Verify team ID and key ID
