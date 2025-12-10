# Authentication Feature

This feature provides authentication functionality for the Stoppr app with multiple sign-in methods:

1. Email/password authentication
2. Google Sign-In
3. Apple Sign-In (iOS only)

## Structure

- **presentation/**
  - **screens/**
    - `email_auth_screen.dart` - UI for email/password sign-in and sign-up
    - `email_auth_test.dart` - Tests for the email authentication screen

## Integration

The authentication feature is integrated with the existing authentication system:

1. It uses the existing `AuthCubit` and `AuthService` from `lib/core/auth/`
2. It's accessible from the onboarding flow via the authentication buttons
3. It supports both sign-in and sign-up functionality with form validation

## Features

### Email Authentication
- Toggle between sign-in and sign-up modes
- Form validation for:
  - Email format validation
  - Password length validation (minimum 6 characters)
- Error handling for Firebase authentication errors
- Loading state indication during authentication
- Password visibility toggle

### Apple Sign-In (iOS Only)
- Utilizes the native iOS authentication flow with Face ID/Touch ID
- Properly configured with entitlements for App Store submission
- System-managed authentication UI that matches iOS design guidelines

## Setup Requirements

### Apple Sign-In
1. Add the `Runner.entitlements` file with the following content:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
```

2. Update the Xcode project to use this entitlements file:
```
cd ios
ruby -e "require 'xcodeproj'; project = Xcodeproj::Project.open('Runner.xcodeproj'); target = project.targets.first; target.build_configurations.each do |config| config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'; end; project.save"
```

3. Ensure your Apple Developer account has Sign in with Apple capability enabled

## Usage

The authentication methods can be accessed from the onboarding flow:

```dart
// Email Authentication
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => EmailAuthScreen(
      onBackPressed: () => Navigator.of(context).pop(),
    ),
  ),
);

// Apple Sign-In (iOS)
context.read<AuthCubit>().signInWithApple();

// Google Sign-In
context.read<AuthCubit>().signInWithGoogle();
```

## Error Handling

Authentication errors are handled in three ways:

1. Form validation errors are displayed inline
2. Firebase authentication errors related to email or password are displayed in the respective form fields
3. General authentication errors are displayed in a SnackBar with a selectable text widget for better visibility and debugging 