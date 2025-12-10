# Flutter Development Guidelines for Claude Code

## Expert Knowledge Areas
- Flutter, Dart, Bloc, Freezed, Flutter Hooks, Firebase
- Always respond in English, even if user speaks French

## Key Principles
- Code variable names/functions/text in English by default unless instructed otherwise
- Don't ask to change anything - implement solutions directly
- **NEVER modify Podfile or config files without explicit permission**
- Write concise, technical Dart code with accurate examples
- Use functional and declarative programming patterns
- Prefer composition over inheritance
- Use descriptive variable names with auxiliary verbs (e.g., isLoading, hasError)
- Structure files: exported widget, subwidgets, helpers, static content, types

## Mixpanel Event Format
- Event names: "Onboarding Progress Card Creation Screen: " + action
- Actions: "Page Viewed" or "Button Tap"
- Properties and events text always in English

## Dart/Flutter Standards
- Use `debugPrint()` for debugging (NEVER use `log()` or `develop.log()`)
- Use `const` constructors for immutable widgets
- Leverage Freezed for immutable state classes and unions
- Use arrow syntax for simple functions and methods
- Prefer expression bodies for one-line getters and setters
- Use trailing commas for better formatting and diffs
- **Always use full package paths for imports**: `'package:stoppr/features/.../file.dart'` instead of relative paths

## Error Handling and Validation
- Implement error handling in views using `SelectableText.rich` instead of SnackBars
- Display errors in `SelectableText.rich` with red color for visibility
- Handle empty states within the displaying screen
- Manage error handling and loading states within Cubit states

## Bloc-Specific Guidelines
- Use Cubit for simple state management, Bloc for complex event-driven state
- Extend states with Freezed for immutability
- Use descriptive and meaningful event names for Bloc
- Handle state transitions and side effects in Bloc's mapEventToState
- Prefer `context.read()` or `context.watch()` for accessing Cubit/Bloc states

## Firebase Integration
- Use Firebase Authentication for user management
- Integrate Firestore for real-time database with structured/normalized data
- Implement Firebase Storage for file uploads/downloads with proper error handling
- Use Firebase Analytics for tracking user behavior and app performance
- Handle Firebase exceptions with detailed error messages and logging
- Secure database rules in Firestore and Storage based on user roles/permissions

## Localizations
- App is localized - always localize labels/texts using localized JSON files

## Performance Optimization
- Use `const` widgets where possible to optimize rebuilds
- Implement list view optimizations (e.g., `ListView.builder`)
- Use `AssetImage` for static images, `cached_network_image` for remote images
- Optimize Firebase queries using indexes and limiting query results

## Key Conventions
1. Use GoRouter or auto_route for navigation and deep linking
2. Optimize for Flutter performance metrics (first meaningful paint, time to interactive)
3. Prefer stateless widgets:
   - Use `BlocBuilder` for widgets that depend on Cubit/Bloc state
   - Use `BlocListener` for side effects (navigation, dialogs)

## UI and Styling
- Use Flutter's built-in widgets and create custom widgets
- Implement responsive design using `LayoutBuilder` or `MediaQuery`
- Use themes for consistent styling across the app
- Use `Theme.of(context).textTheme.titleLarge` instead of `headline6`, `headlineSmall` instead of `headline5`

## Model and Database Conventions
- Include `createdAt`, `updatedAt`, and `isDeleted` fields in Firestore documents
- Use `@JsonSerializable(fieldRename: FieldRename.snake)` for models
- Implement `@JsonKey(includeFromJson: true, includeToJson: false)` for read-only fields

## Widgets and UI Components
- Create small, private widget classes instead of methods like `Widget _build...`
- Implement `RefreshIndicator` for pull-to-refresh functionality
- In TextFields, set appropriate `textCapitalization`, `keyboardType`, and `textInputAction`
- Always include an `errorBuilder` when using `Image.network`
- **Use `Navigation.pushReplacement()` instead of `Navigation.push()`**

## Code Style
- Keep lines no longer than 80 characters
- Add commas before closing brackets for multi-parameter functions
- Use `@JsonValue(int)` for enums that go to the database

## Code Generation
- Use build_runner for generating code from annotations (Freezed, JSON serialization)
- Run `flutter pub run build_runner build --delete-conflicting-outputs` after modifying annotated classes

## Documentation
- Document complex logic and non-obvious code decisions
- Follow official Flutter, Bloc, and Firebase documentation for best practices

## Testing Commands
- To run tests: `flutter test`
- To run build: `flutter build apk` or `flutter build ios`
- To check for issues: `flutter doctor`
- To analyze code: `flutter analyze`