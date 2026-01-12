# Boardroom Journal - Complete Deployment Guide

This guide covers local development, staging, and production deployment for both the backend API and mobile apps.

---

## Table of Contents

1. [Quick Start (Local Development)](#1-quick-start-local-development)
2. [Environment Configuration](#2-environment-configuration)
3. [Backend Deployment](#3-backend-deployment)
4. [Database Setup](#4-database-setup)
5. [OAuth Configuration](#5-oauth-configuration)
6. [Mobile App Deployment](#6-mobile-app-deployment)
7. [CI/CD Pipeline](#7-cicd-pipeline)
8. [Monitoring & Observability](#8-monitoring--observability)
9. [Security Checklist](#9-security-checklist)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Quick Start (Local Development)

### Prerequisites

| Tool | Version | Installation |
|------|---------|--------------|
| Flutter | 3.24+ | `brew install --cask flutter` |
| Dart | 3.2+ | Included with Flutter |
| Docker | Latest | [docker.com](https://docker.com) |
| Xcode | Latest | Mac App Store |
| CocoaPods | Latest | `brew install cocoapods` |
| Android Studio | Latest | [developer.android.com](https://developer.android.com/studio) (optional) |

### Step 1: Clone and Setup Flutter

```bash
# Clone the repository
git clone https://github.com/your-org/board-journal.git
cd board-journal

# Install Flutter dependencies
flutter pub get

# Generate database code (required)
dart run build_runner build --delete-conflicting-outputs

# Create platform folders (if not present)
flutter create --platforms=ios,android .

# Install iOS dependencies
cd ios && pod install && cd ..
```

### Step 2: Start Backend Services

```bash
cd backend

# Start PostgreSQL + API server
docker compose up -d

# Verify services are running
docker compose ps

# Test health endpoint
curl http://localhost:8080/health
# Should return: {"status":"healthy"}
```

### Step 3: Run the App

```bash
# List available devices
flutter devices

# Run on iOS Simulator
flutter run -d "iPhone"

# Run on Android Emulator
flutter run -d "emulator"

# Run on physical device
flutter run -d "Your Device Name"
```

### Useful Commands

| Command | Description |
|---------|-------------|
| `flutter pub get` | Install dependencies |
| `dart run build_runner build` | Generate code |
| `dart run build_runner watch` | Continuous code generation |
| `flutter test` | Run all tests |
| `flutter run` | Run the app |
| `docker compose up -d` | Start backend |
| `docker compose down` | Stop backend |
| `docker compose logs -f` | View logs |

---

## 2. Environment Configuration

### Backend Environment Variables

Create `backend/.env` from the example:

```bash
cp backend/.env.example backend/.env
```

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_PASSWORD` | PostgreSQL password | `secure_password_here` |
| `JWT_SECRET` | JWT signing secret (64+ bytes) | `openssl rand -base64 64` |

#### Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Server bind address |
| `PORT` | `8080` | Server port |
| `ENVIRONMENT` | `development` | `development`, `staging`, `production` |

#### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_HOST` | `localhost` | PostgreSQL host |
| `DATABASE_PORT` | `5432` | PostgreSQL port |
| `DATABASE_NAME` | `boardroom_journal` | Database name |
| `DATABASE_USER` | `postgres` | Database user |
| `DATABASE_PASSWORD` | **required** | Database password |
| `DATABASE_POOL_SIZE` | `10` | Connection pool size |

#### JWT Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_SECRET` | **required** | Secret for signing (64+ bytes recommended) |
| `JWT_ACCESS_TOKEN_EXPIRY_MINUTES` | `15` | Access token lifetime |
| `JWT_REFRESH_TOKEN_EXPIRY_DAYS` | `30` | Refresh token lifetime |

#### OAuth Configuration (Optional for Local Dev)

| Variable | Description |
|----------|-------------|
| `APPLE_CLIENT_ID` | Apple Service ID (e.g., `com.boardroomjournal.app`) |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_KEY_ID` | Key ID from Apple Developer Console |
| `APPLE_PRIVATE_KEY` | Base64-encoded .p8 key file |
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth Client Secret |

#### AI Services (Optional for Local Dev)

| Variable | Description |
|----------|-------------|
| `CLAUDE_API_KEY` | Anthropic API key (`sk-ant-...`) |
| `DEEPGRAM_API_KEY` | Deepgram API key for transcription |

#### Rate Limiting

| Variable | Default | Description |
|----------|---------|-------------|
| `RATE_LIMIT_ACCOUNT_CREATION_PER_HOUR` | `3` | Max new accounts per IP per hour |
| `RATE_LIMIT_AUTH_ATTEMPTS_BEFORE_LOCKOUT` | `5` | Failed attempts before lockout |
| `RATE_LIMIT_AUTH_LOCKOUT_MINUTES` | `15` | Lockout duration |
| `MAX_REQUEST_BODY_SIZE` | `10485760` | Max request size (10MB) |

### Flutter App Configuration

The app uses `ApiConfig` to determine the backend URL:

```dart
// lib/services/api/api_config.dart

// Development (default when running locally)
ApiConfig.development()  // http://localhost:8080

// Staging
ApiConfig.staging()      // https://staging-api.boardroomjournal.app

// Production
ApiConfig.production()   // https://api.boardroomjournal.app
```

To switch environments, update the provider or use build flavors (see Mobile App Deployment section).

---

## 3. Backend Deployment

### Option A: Railway (Recommended for Simplicity)

Railway provides one-click deployments with automatic SSL and PostgreSQL.

#### Step 1: Connect Repository

1. Go to [railway.app](https://railway.app)
2. Click "New Project" → "Deploy from GitHub repo"
3. Select your repository
4. Set the root directory to `backend`

#### Step 2: Add PostgreSQL

1. Click "New Service" → "PostgreSQL"
2. Railway automatically sets `DATABASE_URL`

#### Step 3: Configure Environment

Add these environment variables in Railway dashboard:

```bash
# Server
HOST=0.0.0.0
PORT=$PORT  # Railway provides this automatically
ENVIRONMENT=production

# Database (Railway provides these automatically when you add PostgreSQL)
DATABASE_HOST=$PGHOST
DATABASE_PORT=$PGPORT
DATABASE_NAME=$PGDATABASE
DATABASE_USER=$PGUSER
DATABASE_PASSWORD=$PGPASSWORD
DATABASE_POOL_SIZE=20

# JWT (generate secure secret)
JWT_SECRET=<generate-with-openssl-rand-base64-64>

# OAuth
APPLE_CLIENT_ID=com.boardroomjournal.app
APPLE_TEAM_ID=YOUR_TEAM_ID
APPLE_KEY_ID=YOUR_KEY_ID
APPLE_PRIVATE_KEY=<base64-encoded-p8-key>
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=<client-secret>

# AI Services
CLAUDE_API_KEY=sk-ant-...
DEEPGRAM_API_KEY=<deepgram-key>
```

#### Step 4: Run Database Migrations

```bash
# Connect to Railway database and run schema
railway run psql < backend/lib/db/schema.sql
```

#### Step 5: Configure Custom Domain

1. Go to Settings → Domains
2. Add custom domain: `api.boardroomjournal.app`
3. Update DNS CNAME record to Railway's provided domain

### Option B: Render

#### Step 1: Create Web Service

1. Go to [render.com](https://render.com)
2. Click "New" → "Web Service"
3. Connect GitHub repository
4. Configure:
   - **Root Directory:** `backend`
   - **Environment:** Docker
   - **Instance Type:** Starter or higher

#### Step 2: Add PostgreSQL

1. Click "New" → "PostgreSQL"
2. Note the internal connection string

#### Step 3: Configure Environment

Add environment variables in Render dashboard (same as Railway above, but use Render's database credentials).

### Option C: Google Cloud Run

#### Step 1: Build and Push Docker Image

```bash
cd backend

# Build image
docker build -t gcr.io/YOUR_PROJECT/boardroom-journal-api:latest .

# Push to Google Container Registry
gcloud auth configure-docker
docker push gcr.io/YOUR_PROJECT/boardroom-journal-api:latest
```

#### Step 2: Deploy to Cloud Run

```bash
gcloud run deploy boardroom-journal-api \
  --image gcr.io/YOUR_PROJECT/boardroom-journal-api:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "ENVIRONMENT=production,DATABASE_HOST=..." \
  --set-secrets "JWT_SECRET=jwt-secret:latest,DATABASE_PASSWORD=db-password:latest"
```

#### Step 3: Set Up Cloud SQL

1. Create PostgreSQL instance in Cloud SQL
2. Enable Cloud SQL Admin API
3. Configure Cloud Run to connect via Cloud SQL connector

### Option D: Self-Hosted Docker

#### Step 1: Build Docker Image

```bash
cd backend
docker build -t boardroom-journal-backend:latest .
```

#### Step 2: Create Production docker-compose.yml

```yaml
version: '3.8'

services:
  api:
    image: boardroom-journal-backend:latest
    ports:
      - "8080:8080"
    environment:
      HOST: "0.0.0.0"
      PORT: "8080"
      ENVIRONMENT: "production"
      DATABASE_HOST: postgres
      DATABASE_PORT: "5432"
      DATABASE_NAME: boardroom_journal
      DATABASE_USER: boardroom_app
      DATABASE_PASSWORD: ${DATABASE_PASSWORD}
      DATABASE_POOL_SIZE: "20"
      JWT_SECRET: ${JWT_SECRET}
      # ... other env vars
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: boardroom_app
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
      POSTGRES_DB: boardroom_journal
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./lib/db/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U boardroom_app -d boardroom_journal"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  postgres_data:
```

#### Step 3: Set Up Reverse Proxy (nginx)

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

---

## 4. Database Setup

### PostgreSQL Schema

The schema file is at `backend/lib/db/schema.sql`. It includes:

- 11 tables (users, daily_entries, weekly_briefs, problems, etc.)
- Sync triggers for change tracking
- Maintenance functions (expire_overdue_bets, cleanup_soft_deletes)

### Initial Setup

```bash
# Connect to your database
psql -h <host> -U <user> -d <database>

# Run schema migration
\i backend/lib/db/schema.sql
```

### Scheduled Maintenance Jobs

Set up cron jobs or cloud scheduler for these maintenance tasks:

```bash
# Expire overdue bets (run daily at midnight UTC)
0 0 * * * psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT expire_overdue_bets();"

# Process scheduled account deletions (run daily at 1am UTC)
0 1 * * * psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT process_scheduled_deletions();"

# Clean up soft deletes older than 30 days (run weekly on Sunday at 2am UTC)
0 2 * * 0 psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT cleanup_soft_deletes();"
```

### Backup Strategy

**Recommended:**
- Daily automated backups with 30-day retention
- Enable point-in-time recovery (PITR)
- Test restore procedure monthly
- Store backups in a different region

**For managed databases (Railway, Render, Cloud SQL):**
- Backups are typically handled automatically
- Configure retention period in dashboard
- Test restore through provider's interface

---

## 5. OAuth Configuration

### Apple Sign In

#### Step 1: Apple Developer Console Setup

1. Go to [developer.apple.com](https://developer.apple.com)
2. Navigate to Certificates, Identifiers & Profiles

#### Step 2: Create App ID

1. Identifiers → + → App IDs
2. Enable "Sign In with Apple" capability
3. Bundle ID: `com.boardroomjournal.app`

#### Step 3: Create Service ID (for backend verification)

1. Identifiers → + → Services IDs
2. Identifier: `com.boardroomjournal.app.service`
3. Enable "Sign In with Apple"
4. Configure domains and return URLs:
   - **Domains:** `api.boardroomjournal.app`
   - **Return URL:** `https://api.boardroomjournal.app/auth/oauth/apple/callback`

#### Step 4: Create Key

1. Keys → + → Keys
2. Enable "Sign In with Apple"
3. Download the .p8 file (you can only download once!)
4. Note the Key ID

#### Step 5: Set Environment Variables

```bash
APPLE_CLIENT_ID=com.boardroomjournal.app  # Or service ID for web
APPLE_TEAM_ID=YOUR_TEAM_ID                 # Found in Membership details
APPLE_KEY_ID=YOUR_KEY_ID                   # From the key you created
APPLE_PRIVATE_KEY=<base64-encoded-p8-file> # cat key.p8 | base64
```

### Google Sign In

#### Step 1: Google Cloud Console Setup

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create or select a project

#### Step 2: Configure OAuth Consent Screen

1. APIs & Services → OAuth consent screen
2. User Type: External
3. Fill in app information
4. Add scopes: `email`, `profile`, `openid`

#### Step 3: Create OAuth 2.0 Credentials

1. APIs & Services → Credentials
2. Create Credentials → OAuth client ID
3. Application type: iOS (for mobile app)
4. Create another for Web (for backend verification)

#### Step 4: Set Environment Variables

```bash
GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=<client-secret>
```

#### iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

---

## 6. Mobile App Deployment

### iOS App Store

#### Prerequisites

- Apple Developer Program membership ($99/year)
- App Store Connect account
- Xcode with valid signing certificates

#### Step 1: Configure Signing

```bash
# Open project in Xcode
open ios/Runner.xcworkspace
```

1. Select Runner target → Signing & Capabilities
2. Team: Select your Apple Developer account
3. Bundle Identifier: `com.boardroomjournal.app`
4. Enable "Sign in with Apple" capability

#### Step 2: Create App Record

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. My Apps → + → New App
3. Fill in:
   - Platform: iOS
   - Name: Boardroom Journal
   - Primary Language: English
   - Bundle ID: `com.boardroomjournal.app`
   - SKU: `boardroom-journal-1`

#### Step 3: Build for Release

```bash
# Build IPA
flutter build ipa --release

# Output: build/ios/ipa/boardroom_journal.ipa
```

#### Step 4: Upload to App Store Connect

**Option A: Transporter (Recommended)**
1. Download Transporter from Mac App Store
2. Sign in with Apple ID
3. Drag IPA file to upload
4. Click Deliver

**Option B: Xcode**
1. Open Xcode
2. Product → Archive
3. Distribute App → App Store Connect

#### Step 5: Complete App Store Listing

Required assets:
- App Icon (1024x1024)
- Screenshots (iPhone 6.5", 5.5", iPad if supported)
- Description (max 4000 characters)
- Keywords (max 100 characters)
- Privacy Policy URL
- Support URL

Submit for review (typically 1-3 days).

### Google Play Store

#### Prerequisites

- Google Play Developer account ($25 one-time)
- App signing key (keystore)

#### Step 1: Create Signing Key

```bash
keytool -genkey -v \
  -keystore ~/boardroom-journal-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias boardroom
```

**Store this key securely! You need it for all future updates.**

#### Step 2: Configure Signing

Create `android/key.properties`:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=boardroom
storeFile=/path/to/boardroom-journal-key.jks
```

Add to `.gitignore`:
```
android/key.properties
*.jks
```

Update `android/app/build.gradle`:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### Step 3: Build for Release

```bash
# Build App Bundle (recommended)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

#### Step 4: Create App in Play Console

1. Go to [play.google.com/console](https://play.google.com/console)
2. Create app
3. Fill in app details

#### Step 5: Upload and Release

1. Production → Create new release
2. Upload the `.aab` file
3. Complete all required sections:
   - Store listing
   - Content rating
   - Target audience
   - Data safety

Submit for review (typically 1-3 days for new apps).

### Build Flavors (Optional)

For different environments, create build flavors:

```dart
// lib/main_dev.dart
void main() {
  runApp(const MyApp(config: ApiConfig.development()));
}

// lib/main_staging.dart
void main() {
  runApp(const MyApp(config: ApiConfig.staging()));
}

// lib/main_prod.dart
void main() {
  runApp(const MyApp(config: ApiConfig.production()));
}
```

Build with:
```bash
flutter run -t lib/main_dev.dart
flutter build apk -t lib/main_prod.dart
```

---

## 7. CI/CD Pipeline

### GitHub Actions

The project includes CI workflow at `.github/workflows/ci.yml`:

```yaml
# Triggered on push to main/master/claude/** and PRs
# Runs:
#   1. Backend tests (Dart analyze + tests)
#   2. Flutter tests (analyze + test with coverage)
#   3. Build check (APK + iOS no-codesign)
```

### Pre-commit Hooks (Lefthook)

Install and enable:

```bash
# Install
npm install -g @evilmartians/lefthook
# or: brew install lefthook

# Enable in repo
lefthook install
```

Hooks run automatically:
- **pre-commit:** Format check, Flutter analyze, Backend analyze
- **pre-push:** Flutter tests, Backend tests

### Adding App Store Deployment

For automated releases, add deployment jobs:

```yaml
# .github/workflows/deploy-ios.yml
name: Deploy iOS

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter build ipa --release
      - uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: build/ios/ipa/boardroom_journal.ipa
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}
```

---

## 8. Monitoring & Observability

### Health Endpoint

The backend exposes `/health`:

```json
{
  "status": "healthy",
  "timestamp": "2026-01-12T10:30:00Z"
}
```

### Recommended Monitoring Setup

#### Sentry (Error Tracking)

```dart
// Add to pubspec.yaml
dependencies:
  sentry_flutter: ^7.x.x

// Initialize in main.dart
await SentryFlutter.init(
  (options) {
    options.dsn = 'https://xxx@sentry.io/xxx';
    options.environment = 'production';
  },
  appRunner: () => runApp(const MyApp()),
);
```

#### Analytics (Mixpanel/Amplitude)

Key events to track:
- `entry_created` - Daily entry recorded
- `brief_generated` - Weekly brief created
- `governance_started` - Session started
- `governance_completed` - Session completed
- `bet_created` - Bet made
- `bet_evaluated` - Bet resolved

#### Uptime Monitoring

Set up alerts on:
- `/health` endpoint availability
- Response time thresholds (P95 < 500ms)
- Error rate spikes

### Log Aggregation

For production, send logs to:
- CloudWatch (AWS)
- Cloud Logging (GCP)
- Logtail/Papertrail (platform-agnostic)

---

## 9. Security Checklist

### Pre-Launch

- [ ] HTTPS only (no HTTP endpoints)
- [ ] JWT secret is cryptographically random (64+ bytes)
- [ ] Database credentials in secrets manager (not env files in git)
- [ ] Rate limiting enabled and tested
- [ ] CORS restricted to production domains
- [ ] Request body size limits configured
- [ ] Security headers enabled (HSTS, X-Content-Type-Options, X-Frame-Options)
- [ ] Database connections use SSL
- [ ] OAuth redirect URIs restricted to known domains
- [ ] Logs don't contain sensitive data (passwords, tokens, PII)

### API Security

- [ ] All endpoints require authentication (except /health, /auth/*)
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention (parameterized queries)
- [ ] Rate limiting on auth endpoints

### Mobile App Security

- [ ] API keys not hardcoded in app (use build configs)
- [ ] Secure storage for tokens (flutter_secure_storage)
- [ ] Certificate pinning (optional, for high-security)
- [ ] No sensitive data in logs

### Data Protection

- [ ] GDPR compliance (export, delete account)
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Data retention policies documented
- [ ] Soft delete with 30-day retention

---

## 10. Troubleshooting

### Backend Issues

#### Database Connection Failed

```bash
# Check database is running
docker compose ps

# Test connection
psql -h localhost -U boardroom -d boardroom_journal -c "SELECT 1;"

# Check logs
docker compose logs postgres
```

#### JWT Errors

```bash
# Verify secret is set
echo $JWT_SECRET | wc -c  # Should be 64+ characters

# Check token format
# Tokens should be: header.payload.signature
```

#### OAuth Failures

- Verify redirect URIs match exactly (including trailing slashes)
- Check client IDs and secrets are correct
- For Apple: verify team ID and key ID
- Check token expiry hasn't passed

### Flutter Issues

#### Build Failed

```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

#### iOS Signing Errors

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner → Signing & Capabilities
3. Ensure Team is selected
4. Let Xcode resolve signing issues

#### CocoaPods Issues

```bash
cd ios
pod deintegrate
pod cache clean --all
pod install
cd ..
```

### Docker Issues

#### Cannot Connect to Docker Daemon

Docker Desktop isn't running. Start it from Applications.

#### Port Already in Use

```bash
# Find process using port
lsof -i :8080

# Kill it or change port
docker compose down
PORT=8081 docker compose up -d
```

#### Out of Disk Space

```bash
# Clean up Docker
docker system prune -a
docker volume prune
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `ConfigurationError: JWT_SECRET is not set` | Missing env var | Set JWT_SECRET in environment |
| `Connection refused localhost:5432` | PostgreSQL not running | `docker compose up postgres` |
| `Invalid token` | Expired or malformed JWT | Re-authenticate |
| `Rate limit exceeded` | Too many requests | Wait for lockout to expire |
| `CORS error` | Wrong origin | Check CORS configuration |

---

## API Endpoints Reference

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/health` | Health check | No |
| GET | `/version` | API version | No |
| POST | `/auth/oauth/{provider}` | OAuth login (apple/google) | No |
| POST | `/auth/refresh` | Refresh access token | Refresh token |
| GET | `/auth/session` | Validate session | Yes |
| GET | `/sync?since={timestamp}` | Pull changes | Yes |
| POST | `/sync` | Push changes | Yes |
| GET | `/sync/full` | Full data pull | Yes |
| GET | `/account` | Get account info | Yes |
| DELETE | `/account` | Schedule account deletion | Yes |
| GET | `/account/export` | Export all data (GDPR) | Yes |
| POST | `/ai/transcribe` | Voice to text | Yes |
| POST | `/ai/extract` | Extract signals | Yes |
| POST | `/ai/generate` | Generate brief | Yes |

---

## Support

- **Issues:** [github.com/your-org/board-journal/issues](https://github.com/your-org/board-journal/issues)
- **Documentation:** See `docs/` folder
- **Architecture:** See `docs/adr/` for decision records
