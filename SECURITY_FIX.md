# Critical Security Fix - API Keys Exposure

## What Happened
The `.env` file containing all API keys and secrets was being bundled into the app as an asset, making it accessible to anyone who downloads the app from the Play Store or App Store.

## Immediate Actions Required

### 1. ROTATE ALL EXPOSED KEYS IMMEDIATELY

**Critical - Do this FIRST before anything else:**

- [ ] **Stripe**: Rotate `STRIPE_SECRET_API_KEY` and `STRIPE_WEBHOOK_SECRET` (both live and test)
- [ ] **RevenueCat**: Rotate `REVENUECAT_PRIVATE_API_KEY` 
- [ ] **OpenAI**: Rotate `OPENAI_API_KEY`
- [ ] **Replicate**: Rotate `REPLICATE_API_TOKEN`
- [ ] **Gemini**: Rotate `GEMINI_API_KEY`
- [ ] **Mixpanel**: Rotate `MIXPANEL_SECRET`
- [ ] **Mailchimp**: Rotate `MAILCHIMP_API_KEY`
- [ ] **Firebase**: Regenerate service account key if path was exposed

**Public keys (less critical but still rotate):**
- [ ] Superwall public keys
- [ ] RevenueCat public keys (iOS/Android)
- [ ] Stripe public keys
- [ ] Firebase client API keys
- [ ] AppsFlyer keys
- [ ] Crisp Website ID

### 2. Code Changes Made

✅ **Removed `.env` from `pubspec.yaml` assets** - This prevents the file from being bundled into the app

✅ **Updated `main.dart`** - Added error handling for `.env` loading (now loads from file system only, not bundled)

### 3. Server-Side Keys That Should NEVER Be in Client App

These keys should **ONLY** be used in backend/Cloud Functions, never in the Flutter app:

- `STRIPE_SECRET_API_KEY` - Move to Firebase Cloud Functions
- `STRIPE_WEBHOOK_SECRET` - Move to Firebase Cloud Functions  
- `REVENUECAT_PRIVATE_API_KEY` - Move to Firebase Cloud Functions
- `OPENAI_API_KEY` - Move to Firebase Cloud Functions (use for server-side AI calls)
- `REPLICATE_API_TOKEN` - Move to Firebase Cloud Functions
- `GEMINI_API_KEY` - Move to Firebase Cloud Functions
- `MIXPANEL_SECRET` - Move to Firebase Cloud Functions (if needed server-side)
- `MAILCHIMP_API_KEY` - Move to Firebase Cloud Functions
- `FIREBASE_SERVICE_ACCOUNT_KEY_PATH` - Never in client app

### 4. Public Keys That Can Stay in Client App

These are public keys designed to be used in client apps (but still rotate them):

- `SUPERWALL_IOS_API_KEY` / `SUPERWALL_ANDROID_API_KEY` - Public keys, OK in client
- `REVENUECAT_IOS_API_KEY` / `REVENUECAT_ANDROID_API_KEY` - Public keys, OK in client
- `MIXPANEL_API_KEY` - Public key, OK in client
- `CRISP_WEBSITE_ID` - Public identifier, OK in client
- `STRIPE_PUBLIC_API_KEY` - Public key, OK in client
- `FIREBASE_ANDROID_API_KEY` / `FIREBASE_IOS_API_KEY` - Public keys, OK in client
- `APPSFLYER_*` - Public keys, OK in client

### 5. Next Steps for Production Builds

For production builds, you have several options:

**Option A: Build-time environment variables (Recommended)**
- Use `--dart-define` flags during build
- Example: `flutter build apk --dart-define=REVENUECAT_IOS_API_KEY=your_key`
- Update `EnvConfig` to read from `String.fromEnvironment()` for production keys

**Option B: Separate config files**
- Create `config/production.dart` and `config/development.dart`
- Load appropriate config based on build mode
- Keep `.env` for development only

**Option C: Backend proxy for sensitive operations**
- Move all server-side API calls to Firebase Cloud Functions
- Client app only contains public keys
- All sensitive operations happen server-side

### 6. Verification

After rotating keys and deploying:

1. Extract the APK/IPA from Play Store/App Store
2. Decompile and verify `.env` is NOT present in assets
3. Test that app still works with new keys
4. Monitor API usage for any suspicious activity from old keys

## Prevention

- ✅ `.env` is already in `.gitignore` (good)
- ✅ Removed `.env` from `pubspec.yaml` assets (done)
- ⚠️ Add pre-commit hook to prevent committing `.env` files
- ⚠️ Add CI/CD check to verify `.env` is not in assets
- ⚠️ Use separate keys for development and production
- ⚠️ Implement key rotation schedule
