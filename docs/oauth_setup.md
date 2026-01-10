# OAuth Platform Configuration Guide

This document provides instructions for configuring OAuth providers for Boardroom Journal.

## Apple Sign-In (iOS/macOS)

### Prerequisites
- Apple Developer Program membership
- App ID with "Sign in with Apple" capability

### iOS Configuration

1. **Enable Sign in with Apple Capability**
   - Open Xcode
   - Select the Runner target
   - Go to Signing & Capabilities
   - Click "+ Capability"
   - Add "Sign in with Apple"

2. **Update Info.plist** (if needed for redirect URLs):
   ```xml
   <!-- Already handled by the sign_in_with_apple package -->
   ```

3. **Configure Associated Domains** (for web redirects):
   - Add `applinks:your-domain.com` in Associated Domains capability

### App Store Connect Setup
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app's "Sign in with Apple" configuration
3. Configure return URLs for your backend

---

## Google Sign-In

### Prerequisites
- Google Cloud Console project
- OAuth 2.0 Client IDs for iOS and Android

### iOS Configuration

1. **Create OAuth Client ID**
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Navigate to APIs & Services > Credentials
   - Create OAuth Client ID for iOS
   - Enter Bundle ID: `com.boardroomjournal.app` (or your bundle ID)

2. **Update Info.plist**:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
         <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

3. **Add GoogleService-Info.plist**
   - Download from Google Cloud Console
   - Add to `ios/Runner/`

### Android Configuration

1. **Create OAuth Client ID**
   - Go to Google Cloud Console
   - Create OAuth Client ID for Android
   - Enter Package name: `com.boardroomjournal.app`
   - Enter SHA-1 fingerprint (debug and release)

2. **Generate SHA-1 fingerprint**:
   ```bash
   # Debug
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

   # Release
   keytool -list -v -keystore your-release-key.keystore -alias your-alias
   ```

3. **Add google-services.json**
   - Download from Google Cloud Console
   - Add to `android/app/`

4. **Update android/build.gradle**:
   ```gradle
   dependencies {
       classpath 'com.google.gms:google-services:4.3.15'
   }
   ```

5. **Update android/app/build.gradle**:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

---

## Microsoft Sign-In

### Prerequisites
- Azure AD tenant
- App registration in Azure Portal

### Setup Instructions

1. **Register Application**
   - Go to [Azure Portal](https://portal.azure.com)
   - Navigate to Azure Active Directory > App registrations
   - Click "New registration"
   - Name: "Boardroom Journal"
   - Supported account types: Personal Microsoft accounts and work/school accounts
   - Redirect URIs: Add platform-specific URIs

2. **iOS Redirect URI**:
   ```
   msauth.com.boardroomjournal.app://auth
   ```

3. **Android Redirect URI**:
   ```
   msauth://com.boardroomjournal.app/YOUR_SIGNATURE_HASH
   ```

4. **Add MSAL Package**:
   ```yaml
   # pubspec.yaml
   dependencies:
     msal_flutter: ^latest_version
   ```

5. **iOS Configuration** (Info.plist):
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>msauth.com.boardroomjournal.app</string>
       </array>
     </dict>
   </array>
   <key>LSApplicationQueriesSchemes</key>
   <array>
     <string>msauthv2</string>
     <string>msauthv3</string>
   </array>
   ```

6. **Android Configuration** (AndroidManifest.xml):
   ```xml
   <activity android:name="com.microsoft.identity.client.BrowserTabActivity">
       <intent-filter>
           <action android:name="android.intent.action.VIEW" />
           <category android:name="android.intent.category.DEFAULT" />
           <category android:name="android.intent.category.BROWSABLE" />
           <data
               android:scheme="msauth"
               android:host="com.boardroomjournal.app"
               android:path="/YOUR_SIGNATURE_HASH" />
       </intent-filter>
   </activity>
   ```

---

## Secure Storage Configuration

### iOS (Keychain)
The `flutter_secure_storage` package automatically uses iOS Keychain.

Configuration in `token_storage.dart`:
```dart
IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
)
```

### Android (EncryptedSharedPreferences)
Uses Android Keystore via EncryptedSharedPreferences.

Configuration in `token_storage.dart`:
```dart
AndroidOptions(
  encryptedSharedPreferences: true,
)
```

---

## Backend Token Exchange

For production, OAuth tokens should be exchanged with your backend:

1. **Client receives authorization code/ID token from OAuth provider**
2. **Client sends token to backend**:
   ```
   POST /api/auth/exchange
   {
     "provider": "apple|google|microsoft",
     "id_token": "...",
     "authorization_code": "..." // Apple only
   }
   ```
3. **Backend validates token with provider**
4. **Backend issues JWT access token (15-min) and refresh token (30-day)**
5. **Client stores tokens in secure storage**

### Token Refresh Flow
```
POST /api/auth/refresh
{
  "refresh_token": "..."
}
```

Response:
```json
{
  "access_token": "...",
  "expires_in": 900,
  "refresh_token": "..."
}
```

---

## Testing

### Development Testing
1. Apple Sign-In: Use a real device (simulator limitations)
2. Google Sign-In: Works on simulator with proper configuration
3. Microsoft Sign-In: Works on simulator with proper configuration

### Test Accounts
- Create test accounts in each provider's developer console
- Use sandbox/test environments when available

---

## Troubleshooting

### Apple Sign-In Issues
- Ensure "Sign in with Apple" capability is enabled
- Check that App ID is configured correctly in Apple Developer Portal
- Verify email privacy settings in Apple ID

### Google Sign-In Issues
- Verify SHA-1 fingerprint matches what's in Google Cloud Console
- Check that package name matches exactly
- Ensure google-services.json is up to date

### Microsoft Sign-In Issues
- Verify redirect URIs match exactly
- Check that application permissions are granted
- Ensure signature hash is correct for Android
