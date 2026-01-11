# Boardroom Journal - Complete Setup & Deployment Guide

This guide assumes you're reasonably smart but new to mobile app development. Every step is explained in detail, and I've marked what Claude can do for you vs. what you need to do yourself.

---

## Table of Contents
1. [Understanding the Big Picture](#1-understanding-the-big-picture)
2. [Installing Required Software](#2-installing-required-software)
3. [Setting Up the Flutter App](#3-setting-up-the-flutter-app)
4. [Setting Up the Backend Server](#4-setting-up-the-backend-server)
5. [Getting API Keys for AI Features](#5-getting-api-keys-for-ai-features)
6. [Running the App on Your Phone](#6-running-the-app-on-your-phone)
7. [Running Tests](#7-running-tests)
8. [Publishing to App Stores](#8-publishing-to-app-stores)

---

## 1. Understanding the Big Picture

### What is this app made of?

Boardroom Journal has two main parts:

1. **The Mobile App (Frontend)** - This is what users see and interact with on their iPhone or Android phone. It's built with Flutter, a framework that lets you write one codebase and run it on both iOS and Android.

2. **The Server (Backend)** - This runs on a computer somewhere (your laptop for testing, or a cloud server for production) and handles:
   - Storing data that syncs across devices
   - Processing AI requests (voice transcription, generating briefs)
   - User authentication (login/logout)

### What is Docker?

Docker is a tool that packages software into "containers" - think of it like a shipping container that has everything the software needs to run. Instead of manually installing a database, configuring it, setting passwords, etc., Docker does all of this automatically.

**Why use it?** Without Docker, you'd need to:
1. Download and install PostgreSQL (a database)
2. Create a database user
3. Set a password
4. Create the database tables
5. Hope you didn't make any typos

With Docker, you just run one command and it does all of this for you.

### What files matter?

| File/Folder | What it is |
|-------------|------------|
| `lib/` | The main app code (Dart/Flutter) |
| `backend/` | The server code |
| `pubspec.yaml` | Lists all the packages the app needs (like a shopping list) |
| `backend/docker-compose.yml` | Instructions for Docker to set up the server |
| `android/` | Android-specific project files (doesn't exist yet - we'll create it) |
| `ios/` | iOS-specific project files (doesn't exist yet - we'll create it) |

---

## 2. Installing Required Software

### 2.1 Install Xcode (Required for iOS)

**What is it?** Xcode is Apple's official tool for building iOS apps. You need it even if you're just testing.

**Steps:**
1. Open the **App Store** on your Mac (the blue icon with an "A")
2. Search for "Xcode"
3. Click **Get** (it's free but large - about 12GB)
4. Wait for it to download and install (can take 30-60 minutes)
5. Open Xcode once after installing - it will ask to install "additional components" - click **Install**
6. Open Terminal (press Cmd+Space, type "Terminal", press Enter) and run:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
   It will ask for your Mac password. Type it and press Enter (you won't see the characters - that's normal).

**How to verify it worked:**
```bash
xcode-select -p
```
Should show: `/Applications/Xcode.app/Contents/Developer`

---

### 2.2 Install Homebrew (Package Manager)

**What is it?** Homebrew is like an app store for developer tools, but you use it from the Terminal. It makes installing things much easier.

**Steps:**
1. Open Terminal
2. Paste this command and press Enter:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Follow the prompts (press Enter when asked, enter your password when asked)
4. **Important:** After it finishes, it will show you two commands to run (starting with `echo` and `eval`). Copy and run both of them.

**How to verify it worked:**
```bash
brew --version
```
Should show something like: `Homebrew 4.x.x`

---

### 2.3 Install Flutter

**What is it?** Flutter is Google's toolkit for building mobile apps. It includes the Dart programming language.

**Steps:**
1. Open Terminal and run:
   ```bash
   brew install --cask flutter
   ```
2. After it finishes, run:
   ```bash
   flutter doctor
   ```

This command checks if everything is set up correctly. You'll see a list with checkmarks (✓) and X marks (✗). Don't worry about all the X marks yet - we'll fix the important ones.

**What you need to see (at minimum):**
- ✓ Flutter (Channel stable, version 3.x.x)
- ✓ Xcode (or partially configured - we'll fix this)

---

### 2.4 Install CocoaPods (Required for iOS)

**What is it?** CocoaPods manages iOS library dependencies. Flutter needs it to build iOS apps.

**Steps:**
```bash
brew install cocoapods
```

**Verify:**
```bash
pod --version
```

---

### 2.5 Install Docker Desktop

**What is it?** Docker Desktop is the app that runs Docker on your Mac. It puts a little whale icon in your menu bar.

**Steps:**
1. Go to: https://www.docker.com/products/docker-desktop/
2. Click **Download for Mac**
3. Choose **Apple Chip** if you have an M1/M2/M3 Mac, or **Intel Chip** for older Macs
   - Not sure which? Click the Apple menu (top-left) → **About This Mac** → Look for "Chip" or "Processor"
4. Open the downloaded `.dmg` file
5. Drag Docker to your Applications folder
6. Open Docker from Applications
7. It will ask for permission to install components - click **OK** and enter your password
8. Wait for Docker to start (the whale icon in the menu bar will stop animating when it's ready)

**Verify:**
```bash
docker --version
docker compose version
```

---

### 2.6 Install Android Studio (Optional - only if you want to test on Android)

**Steps:**
1. Go to: https://developer.android.com/studio
2. Download and install
3. Open Android Studio
4. Go through the setup wizard - accept all defaults
5. When it finishes, go to **More Actions** → **SDK Manager**
6. Make sure "Android SDK" is installed

---

### 2.7 Check Everything with Flutter Doctor

Run this command to see your setup status:
```bash
flutter doctor -v
```

**What matters for iOS testing:**
- ✓ Flutter
- ✓ Xcode (needs to show full path and version)
- ✓ CocoaPods

Don't worry about Android or VS Code warnings if you're only testing on iOS.

---

## 3. Setting Up the Flutter App

### 3.1 Navigate to the Project

Open Terminal and go to the project folder:
```bash
cd /path/to/board-journal
```

Replace `/path/to/` with where you actually cloned the repository. For example, if it's on your Desktop:
```bash
cd ~/Desktop/board-journal
```

---

### 3.2 Install Flutter Dependencies

**What this does:** Downloads all the packages listed in `pubspec.yaml` that the app needs.

```bash
flutter pub get
```

You should see messages about resolving dependencies and then "Got dependencies!"

---

### 3.3 Generate Database Code

**What this does:** The app uses a database library called Drift. Drift uses code generation - you write simple table definitions, and it generates the complex database code automatically. This step runs that generation.

```bash
dart run build_runner build --delete-conflicting-outputs
```

This takes 30-60 seconds. You'll see messages about generating files. When it's done, you'll see "Succeeded after" with a time.

**If you see errors:**
> **Ask Claude:** "Run the build_runner for me and fix any errors"

---

### 3.4 Create iOS and Android Project Files

**What this does:** Flutter needs platform-specific folders to build for iOS and Android. These aren't in the repository (they're auto-generated and contain machine-specific paths), so we create them.

```bash
flutter create --platforms=ios,android .
```

Note the `.` at the end - that's important! It means "in the current directory."

You should see messages about creating files in `ios/` and `android/` folders.

---

### 3.5 Install iOS Dependencies (CocoaPods)

**What this does:** iOS uses CocoaPods to manage native libraries. This command downloads and links them.

```bash
cd ios
pod install
cd ..
```

This can take 2-5 minutes the first time. You'll see messages about installing pods.

**If you see errors about versions:**
```bash
cd ios
pod repo update
pod install
cd ..
```

---

## 4. Setting Up the Backend Server

### 4.1 Start Docker Desktop

Make sure Docker is running (you should see the whale icon in your menu bar at the top of the screen). If it's not running, open Docker from your Applications folder.

---

### 4.2 Create the Environment File

The backend needs a configuration file with settings.

> **Ask Claude:** "Create the backend .env file for local development"

Or do it manually:
```bash
cd backend
cp .env.example .env
```

Then open `.env` in a text editor and fill in values (the example file has comments explaining each one).

---

### 4.3 Start the Backend

This one command starts both the database and the API server:

```bash
cd backend
docker compose up -d
```

**What this does:**
- Downloads PostgreSQL (database) if you don't have it
- Starts PostgreSQL in a container
- Creates the database and tables
- Starts the API server
- The `-d` means "detached" - it runs in the background

**First time:** This downloads images, which can take 5-10 minutes.

**Verify it's running:**
```bash
docker compose ps
```

You should see two containers with "running" status.

**Test the API:**
```bash
curl http://localhost:8080/health
```

Should return: `{"status":"healthy"}`

---

### 4.4 Useful Docker Commands

| Command | What it does |
|---------|--------------|
| `docker compose up -d` | Start the backend |
| `docker compose down` | Stop the backend |
| `docker compose logs -f` | Watch the logs (Ctrl+C to stop) |
| `docker compose logs api` | See just the API server logs |
| `docker compose ps` | See what's running |
| `docker compose restart` | Restart everything |

---

## 5. Getting API Keys for AI Features

The app uses external AI services that require API keys. Without these, the app works but AI features (voice transcription, signal extraction, weekly briefs) won't function.

### 5.1 Anthropic Claude API Key (For AI features)

**What it's for:** Analyzing journal entries, extracting signals, generating weekly briefs, running governance sessions.

**Steps:**
1. Go to: https://console.anthropic.com/
2. Create an account or sign in
3. Go to **API Keys** in the left sidebar
4. Click **Create Key**
5. Give it a name like "Boardroom Journal Dev"
6. Copy the key (starts with `sk-ant-`)

**Important:** You'll only see the key once. Save it somewhere safe (like a password manager).

**Add to your environment:**
```bash
export ANTHROPIC_API_KEY="sk-ant-your-key-here"
```

Or add it to the backend's `.env` file as `CLAUDE_API_KEY=sk-ant-your-key-here`

**Cost:** You get $5 free credit. After that, it costs roughly $15 per million input tokens (about 750,000 words). For testing, you'll spend pennies.

---

### 5.2 Deepgram API Key (For voice-to-text)

**What it's for:** Converting voice recordings to text.

**Steps:**
1. Go to: https://console.deepgram.com/
2. Create an account
3. Go to **API Keys**
4. Create a new key
5. Copy it

**Add to backend .env:**
```
DEEPGRAM_API_KEY=your-key-here
```

**Cost:** $200 free credit for new accounts. Voice transcription costs about $0.0043 per minute.

---

### 5.3 Apple Developer Account (For Sign in with Apple)

**What it's for:** Letting users log in with their Apple ID.

**Do you need this for testing?** No - you can skip this for local testing. The app will work without authentication for basic testing.

**For production:** $99/year from https://developer.apple.com/programs/

---

## 6. Running the App on Your Phone

### Option A: Run on iPhone Simulator (Easiest)

The simulator is a virtual iPhone that runs on your Mac. No physical device needed.

**Steps:**
1. Open Terminal and navigate to the project:
   ```bash
   cd /path/to/board-journal
   ```

2. See available simulators:
   ```bash
   flutter devices
   ```
   You should see something like "iPhone 15 Pro (simulator)"

3. Run the app:
   ```bash
   flutter run
   ```
   If you have multiple devices, it will ask you to choose. Pick the iOS simulator.

4. Wait for it to build (first time takes 2-5 minutes)

5. The simulator should open automatically with the app running

**Useful controls while running:**
- Press `r` in Terminal → Hot reload (updates UI without restarting)
- Press `R` in Terminal → Hot restart (restarts the app)
- Press `q` in Terminal → Quit

---

### Option B: Run on Physical iPhone

This is more complex because Apple requires code signing.

**Prerequisites:**
- iPhone connected via USB cable (or same WiFi network after initial setup)
- Apple ID (free one is fine for testing)

**Step 1: Open the project in Xcode**
```bash
open ios/Runner.xcworkspace
```

**Important:** Open `.xcworkspace`, not `.xcodeproj`. The workspace includes the CocoaPods dependencies.

**Step 2: Configure signing**
1. In Xcode, click on **Runner** in the left sidebar (the top item with the blue app icon)
2. Click on the **Runner** target in the middle panel
3. Go to the **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. For **Team**, click the dropdown:
   - If you see your name, select it
   - If you see "Add an Account...", click it and sign in with your Apple ID
6. Xcode will generate certificates automatically

**Step 3: Trust your computer on iPhone**
1. Connect your iPhone via USB
2. On your iPhone, tap **Trust** when prompted
3. Enter your iPhone passcode

**Step 4: Trust the developer on iPhone**
(First time only)
1. On your iPhone, go to **Settings** → **General** → **VPN & Device Management**
2. Tap on your Apple ID under "Developer App"
3. Tap **Trust**

**Step 5: Run the app**

Either:
- In Xcode: Select your iPhone from the device dropdown (top of window), click the Play button
- Or in Terminal:
  ```bash
  flutter run -d "Your iPhone Name"
  ```

**Troubleshooting:**
- "Unable to install app" → Make sure you trusted the developer on your iPhone
- "Device is locked" → Unlock your iPhone
- "No provisioning profile" → Xcode signing isn't configured correctly

---

### Option C: Run on Android Emulator

**Step 1: Create an emulator in Android Studio**
1. Open Android Studio
2. Click **More Actions** → **Virtual Device Manager**
3. Click **Create Device**
4. Choose a phone (e.g., Pixel 7)
5. Download a system image (choose the latest)
6. Finish the wizard

**Step 2: Start the emulator**
In Virtual Device Manager, click the Play button next to your device.

**Step 3: Run the app**
```bash
flutter run -d "emulator-name"
```

Or just `flutter run` and select the Android option when prompted.

---

### Option D: Run on Physical Android Phone

1. On your Android phone:
   - Go to **Settings** → **About Phone**
   - Tap **Build Number** 7 times to enable Developer Mode
   - Go back to **Settings** → **Developer Options**
   - Enable **USB Debugging**

2. Connect via USB and accept the debugging prompt

3. Run:
   ```bash
   flutter devices  # Should show your phone
   flutter run -d "your-phone-name"
   ```

---

## 7. Running Tests

Tests verify that the code works correctly. You should run them before making changes.

### Run All Tests
```bash
flutter test
```

This runs all tests in the `test/` folder and shows pass/fail results.

### Run Specific Test File
```bash
flutter test test/data/database/database_test.dart
```

### Run Tests with Details
```bash
flutter test --reporter expanded
```

Shows each individual test as it runs.

### Run Backend Tests
```bash
cd backend
dart test
```

> **Ask Claude:** "Run the tests and fix any failures"

---

## 8. Publishing to App Stores

This section is for when you're ready to release the app publicly. Skip this for testing.

### 8.1 iOS App Store

**Prerequisites:**
- Apple Developer account ($99/year)
- App Store Connect account (included with developer account)
- App icons and screenshots
- Privacy policy URL

**Overview of the process:**
1. Create app record in App Store Connect
2. Configure signing for distribution (different from development)
3. Build the app for release
4. Upload to App Store Connect
5. Fill in metadata (description, screenshots, etc.)
6. Submit for review (takes 1-3 days)

**Step 1: Create App Record**
1. Go to https://appstoreconnect.apple.com/
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - Platform: iOS
   - Name: Boardroom Journal
   - Primary language: English
   - Bundle ID: (you'll create this in Xcode)
   - SKU: boardroom-journal-001 (any unique identifier)

**Step 2: Configure Distribution Signing**

In Xcode:
1. Open `ios/Runner.xcworkspace`
2. Select **Runner** → **Signing & Capabilities**
3. Uncheck "Automatically manage signing"
4. For Release configuration, select your Distribution provisioning profile

Or keep automatic signing (simpler for first release).

**Step 3: Build for Release**
```bash
flutter build ipa
```

This creates `build/ios/ipa/boardroom_journal.ipa`

**Step 4: Upload to App Store Connect**

You have two options:

**Option A: Transporter App (Simpler)**
1. Download **Transporter** from the Mac App Store (free app from Apple)
2. Open Transporter
3. Sign in with your Apple ID (the one with developer account)
4. Drag the `.ipa` file into Transporter
5. Click **Deliver**
6. Wait for upload and processing

**Option B: Xcode Upload**
1. In Xcode, go to **Product** → **Archive**
2. Wait for the archive to build
3. Click **Distribute App**
4. Choose **App Store Connect**
5. Follow the prompts

**Step 5: Complete App Store Listing**
1. In App Store Connect, go to your app
2. Fill in all required fields:
   - Description
   - Keywords
   - Support URL
   - Marketing URL (optional)
   - Screenshots (required for each screen size)
   - App icon
   - Age rating
   - Privacy policy URL
3. Click **Submit for Review**

---

### 8.2 Google Play Store

**Prerequisites:**
- Google Play Developer account ($25 one-time fee)
- App icons and screenshots
- Privacy policy URL

**Step 1: Create Developer Account**
1. Go to: https://play.google.com/console/
2. Pay $25 registration fee
3. Complete identity verification (takes 1-2 days)

**Step 2: Create Signing Key**

You need a keystore file to sign your app. **Keep this safe - you need the same key for all future updates!**

```bash
keytool -genkey -v -keystore ~/boardroom-journal-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias boardroom
```

You'll be prompted for:
- Keystore password (remember this!)
- Your name, organization, location
- Key password (can be same as keystore password)

**Step 3: Configure Signing**

Create `android/key.properties`:
```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=boardroom
storeFile=/Users/YOUR_USERNAME/boardroom-journal-key.jks
```

**IMPORTANT:** Add `key.properties` to `.gitignore` so you don't commit passwords!

**Step 4: Build for Release**
```bash
flutter build appbundle
```

This creates `build/app/outputs/bundle/release/app-release.aab`

**Step 5: Upload to Play Console**
1. Go to https://play.google.com/console/
2. Click **Create app**
3. Fill in app details
4. Go to **Production** → **Create new release**
5. Upload the `.aab` file
6. Fill in release notes
7. Complete all the required sections (content rating, data safety, etc.)
8. Submit for review

---

## Quick Reference: Claude Prompts

Here are prompts you can give Claude to help with specific tasks:

| Task | Prompt |
|------|--------|
| Set up backend environment | "Create the backend .env file for local development" |
| Fix build errors | "Run the build_runner and fix any errors" |
| Run and fix tests | "Run the tests and fix any failures" |
| iOS signing issues | "Help me fix Xcode signing errors for device: [paste error]" |
| Configure API keys | "Help me add the API keys to the project" |
| Debug app crash | "The app crashes with this error: [paste error]" |
| Prepare for release | "Help me prepare the app for App Store release" |

---

## Troubleshooting Common Issues

### "Command not found: flutter"

Homebrew installed Flutter but your terminal doesn't know where it is.

**Fix:**
```bash
echo 'export PATH="$PATH:/opt/homebrew/bin"' >> ~/.zshrc
source ~/.zshrc
```

### "CocoaPods not installed"

```bash
brew install cocoapods
```

### iOS build fails with "Signing" error

1. Open Xcode: `open ios/Runner.xcworkspace`
2. Click Runner in sidebar
3. Go to Signing & Capabilities
4. Make sure a Team is selected
5. Let Xcode fix any issues it detects

### "Unable to find bundled Java version"

Android Studio's Java is needed:
```bash
flutter config --android-studio-dir="/Applications/Android Studio.app"
```

### Docker "Cannot connect to Docker daemon"

Docker Desktop isn't running. Open it from Applications.

### Backend won't start

Check the logs:
```bash
cd backend
docker compose logs
```

Then ask Claude: "The backend shows this error: [paste error]"

### Simulator is slow

The iOS Simulator uses a lot of CPU. Some tips:
- Close other apps
- Use a simpler device (iPhone SE instead of iPhone 15 Pro Max)
- Use a physical device instead

---

## Summary: The Minimum Steps to Test

Here's the absolute minimum to get the app running on an iOS simulator:

```bash
# 1. Install software (one-time)
# - Install Xcode from App Store
# - Install Homebrew, then: brew install --cask flutter && brew install cocoapods

# 2. Set up the project
cd /path/to/board-journal
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter create --platforms=ios .
cd ios && pod install && cd ..

# 3. Run the app
flutter run
```

For full functionality with AI features, also:
1. Start the backend: `cd backend && docker compose up -d`
2. Get an Anthropic API key and add it to `.env`
3. Get a Deepgram API key and add it to `.env`
