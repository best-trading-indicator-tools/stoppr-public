# Flutter iOS Development Commands
.PHONY: help clean-fast clean-pods flutter-clean build run test pod-install open-sim list-sims run-iphone15 reset-ios reset-quick clean-pods-reset deep-clean fix-flutter-path setup-android-emulator flutter-run-android-xs list-android-emulators flutter-run-iphonex flutter-run-physical-android flutter-run-ipad-pro-11 flutter-run-ipad-pro-13 flutter-run-ipad-air-11 list-ipad-sims open-ipad-sim flutter-run-android-emulator-adb flutter-clean-run-android-emulator-adb android-run-legacy-superwall

help: ## Show this help
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build the app in debug mode
	flutter build ios --debug

build-release: ## Build the app in release mode
	flutter build ios --release

run: ## Run the app in debug mode
	xcrun simctl boot "iPhone 16" && open -a Simulator && flutter run -d "iPhone 16"

flutter-run-iphone16: ## Reliable run and debug with built-in Flutter lifecycle management
	@echo "🚀 Running app with development profile..."
	xcrun simctl boot "iPhone 16" 
	open -a Simulator
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@echo "🔎 Searching for the most recent Runner.app in DerivedData..."
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		echo "⚠️  XCODE_DERIVED_DATA_PATH not set. Using default location."; \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		echo "⚠️  Runner.app not found in DerivedData. Running without --use-application-binary."; \
		flutter run -d "iPhone 16"; \
	else \
		echo "✅ Found Runner.app at: $$RUNNER_APP"; \
		flutter run -d "iPhone 16" --use-application-binary=$$RUNNER_APP; \
	fi
	@echo "✅ Flutter session completed"

flutter-run-iphone15: ## Reliable run and debug on iPhone 15 with built-in Flutter lifecycle management
	@echo "🚀 Running app on iPhone 15 with development profile..."
	xcrun simctl boot "iPhone 15" 
	open -a Simulator
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@echo "🔎 Searching for the most recent Runner.app in DerivedData..."
	flutter run -d "iPhone 15" --use-application-binary=/Users/dave/Library/Developer/Xcode/DerivedData/Runner-gvtwhrhavedxigglghhdabacpllf/Build/Products/Debug-iphonesimulator/Runner.app
	@echo "✅ Flutter session completed"


flutter-run-iphone15-pro: ## Reliable run and debug on iPhone 15 Pro with built-in Flutter lifecycle management
	@echo "🚀 Running app on iPhone 15 Pro with development profile..."
	xcrun simctl boot "iPhone 15 Pro" 
	open -a Simulator
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPhone 15 Pro"; \
	else \
		flutter run -d "iPhone 15 Pro" --use-application-binary=$$RUNNER_APP; \
	fi
	@echo "✅ Flutter session completed"

flutter-run-iphonex: ## Reliable run and debug on iPhone XS (same size as iPhone X) with built-in Flutter lifecycle management
	@echo "🚀 Running app on iPhone XS (same size as iPhone X) with development profile..."
	xcrun simctl boot "iPhone XS" 
	open -a Simulator
	@sleep 2
	@echo "⚙️ Configuring StoreKit sandbox for automatic purchase approval..."
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPhone XS" --no-enable-impeller; \
	else \
		flutter run -d "iPhone XS" --use-application-binary=$$RUNNER_APP --no-enable-impeller; \
	fi
	@echo "✅ Flutter session completed"

flutter-run-ipadair: ## Reliable run and debug on iPad Air (5th generation) with built-in Flutter lifecycle management
	@echo "🚀 Running app on iPad Air (5th generation) with development profile..."
	xcrun simctl boot "iPad Air 5th Gen Test" 
	open -a Simulator
	@sleep 2
	@echo "⚙️ Configuring StoreKit sandbox for automatic purchase approval..."
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPad Air 5th Gen Test"; \
	else \
		flutter run -d "iPad Air 5th Gen Test" --use-application-binary=$$RUNNER_APP; \
	fi
	@echo "✅ Flutter session completed"

flutter-run-iphone16: ## Reliable run and debug on iPhone 16 with built-in Flutter lifecycle management
	@echo "🚀 Running app on iPhone 16 with development profile..."
	xcrun simctl boot "iPhone 16" 
	open -a Simulator
	@sleep 2
	@echo "⚙️ Configuring StoreKit sandbox for automatic purchase approval..."
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPhone 16" --no-enable-impeller; \
	else \
		flutter run -d "iPhone 16" --use-application-binary=$$RUNNER_APP --no-enable-impeller; \
	fi
	@echo "✅ Flutter session completed"

flutter-run-iphonex-storekit: ## Reliable run and debug on iPhone XS (same size as iPhone X) with built-in Flutter lifecycle management
	@echo "🚀 Running app on iPhone XS (same size as iPhone X) with development profile..."
	xcrun simctl boot "iPhone XS" 
	open -a Simulator
	@sleep 2
	@echo "⚙️ Configuring StoreKit sandbox for automatic purchase approval..."
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme RunnerStorekit -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPhone XS" --no-enable-impeller; \
	else \
		flutter run -d "iPhone XS" --use-application-binary=$$RUNNER_APP --no-enable-impeller; \
	fi
	@echo "✅ Flutter session completed"


flutter-run-step-2: ## Reliable run and debug on iPhone XS (same size as iPhone X) with built-in Flutter lifecycle management
	@echo "🚀 Running app on iPhone XS (same size as iPhone X) with development profile..."
	xcrun simctl boot "iPhone XS" 
	open -a Simulator
	@sleep 2
	@echo "⚙️ Configuring StoreKit sandbox for automatic purchase approval..."
	@echo "📱 Building and running with development profile..."	
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPhone XS"; \
	else \
		flutter run -d "iPhone XS" --use-application-binary=$$RUNNER_APP; \
	fi
	@echo "✅ Flutter session completed"


kill-stoppr-android: ## Kill the Stoppr app
	xcrun simctl terminate booted com.stoppr.sugar.app

run-release: ## Run the app in release mode
	flutter run --release

test: ## Run all tests
	flutter test ()

pod-install: ## Install iOS pods
	cd ios && pod install --repo-update && cd ..
	@echo "🔗 Creating symbolic links for Firebase plugins..."

open-sim: ## Open iOS Simulator with iPhone 15 Pro
	xcrun simctl boot "iPhone 16" 
	open -a Simulator

run-iphone15: ## Run app specifically on iPhone 15 Pro
	flutter run -d "iPhone 15 Pro"

check: ## Run Flutter doctor
	flutter doctor -v

devices: ## List all connected devices
	flutter devices

clean-xcode: ## Clean Xcode derived data
	rm -rf ~/Library/Developer/Xcode/DerivedData

setup: ## Initial setup after cloning
	cd ios && rm -rf Pods && rm -f Podfile.lock && rm -f "Podfile 2.lock"  && cd ..
	flutter pub get
	cd ios && pod install --repo-update && cd ..
	@echo "🔗 Creating symbolic links for Firebase plugins..."

format: ## Format all Dart files
	dart format lib/

analyze: ## Analyze Dart code
	flutter analyze

delete-conflicting-outputs: ## Watch for changes
	flutter pub run build_runner watch --delete-conflicting-outputs

list-sims: ## List available iOS simulators
	xcrun simctl list devices


reset-quick: ## Quick reset: clean Flutter and regenerate localization files
	@echo "🧹 Quick Flutter reset..."
	flutter clean
	flutter pub get
	@echo "🔄 Regenerating localization and generated files..."
	dart run build_runner build --delete-conflicting-outputs
	@echo "✅ Quick reset complete! Localization files regenerated."

reset-ios: ## Complete reset: clean Flutter, remove derived data, pods, and setup again
	@echo "🧹 Starting complete reset..."
	osascript -e 'tell application "Xcode" to quit'
	flutter clean
	@echo "🧹 Removing Flutter plugin files..."
	rm -f .flutter-plugins*
	rm -f .flutter-plugins-dependencies*
	@echo "🧹 Removing duplicate Flutter plugin files with numeric suffixes..."
	find . -maxdepth 1 -name ".flutter-plugins [0-9]*" -type f -delete 2>/dev/null || true
	find . -maxdepth 1 -name ".flutter-plugins-dependencies [0-9]*" -type f -delete 2>/dev/null || true
	@echo "🗑️ Removing iOS build artifacts..."
	cd ios && rm -f Flutter/*.podspec Flutter/Flutter*.podspec Flutter/flutter_export_environment*.sh Flutter/Generated*.xcconfig Podfile*.lock && cd ..
	@echo "🧹 Cleaning caches and derived data..."
	rm -rf ~/Library/Developer/Xcode/DerivedData/*
	rm -rf ~/.pub-cache/bin/*
	rm -rf ~/.cocoapods/repos/*
	rm -rf ~/Library/Caches/CocoaPods/*
	rm -f flutter_*.log
	rm -rf firebase-debug*.log
	rm -rf tools/firebase_cloud/functions/firebase-debug*.log
	cd ios && rm -rf Pods Pods* .symlinks Flutter/Flutter.framework && rm -f Podfile.lock Podfile*.lock && pod deintegrate && pod cache clean --all && cd ..
	@echo "🔄 Reinstalling dependencies..."
	flutter pub cache repair
	sleep 5
	flutter pub get
	cd ios && pod install --repo-update && cd ..	
	@echo "🧹 Removing StreakWidgetExtension Pod framework reference..."
	sed -i '' -e '/0C92FBC361457E916F272E21 \\* Pods_StreakWidgetExtension.framework in Frameworks */d' -e '/19609375A236EFBD258FF83E \\* Pods_StreakWidgetExtension.framework */d' ios/Runner.xcodeproj/project.pbxproj
	@echo "📱 Resetting simulators..."
	xcrun simctl shutdown all && xcrun simctl erase all
	@echo "🧼 Removing all generated Dart files..."
	@echo "🧹 Removing duplicate generated files with numeric suffixes..."
	# First remove numbered duplicates of generated files
	find lib -type f \( -name "*\.freezed\ [0-9]*.dart" -o -name "*\.g\ [0-9]*.dart" \) -delete 2>/dev/null || true
	# Then remove regular generated files
	find lib -type f \( -name "*.freezed.dart" -o -name "*.g.dart" \) -delete 2>/dev/null || true
	@echo "🧹 Removing duplicate Flutter build files with numeric suffixes..."
	# Only delete files with spaces followed by numbers in build/generated directories
	find ios/Flutter -path "*/build/*" -name "*\ [0-9]*" -type f -delete 2>/dev/null || true
	find ios/Flutter -path "*/generated/*" -name "*\ [0-9]*" -type f -delete 2>/dev/null || true
	@echo "🔄 Waiting for file system to sync..."
	@echo "🧹 Removing numbered duplicates in Android build..."
	find android/app/build -type f -name "* [0-9]*" -delete 2>/dev/null || true
	find android/app/build -type d -name "* [0-9]*" -exec rm -rf {} \; 2>/dev/null || true
	sleep 2
	@echo "🔧 Regenerating all Dart files cleanly..."
	dart run build_runner build --delete-conflicting-outputs
	open ios/Runner.xcworkspace
	@echo "✨ Reset complete! Project is fresh and clean."

big-clean: ## Big clean: clean Flutter, remove derived data, pods, and setup again
	@echo "🧹 Starting complete reset..."
	osascript -e 'tell application "Xcode" to quit'
	flutter clean
	@echo "🧹 Removing Flutter plugin files..."
	rm -f .flutter-plugins*
	rm -f .flutter-plugins-dependencies*
	@echo "🧹 Removing duplicate Flutter plugin files with numeric suffixes..."
	find . -maxdepth 1 -name ".flutter-plugins [0-9]*" -type f -delete 2>/dev/null || true
	find . -maxdepth 1 -name ".flutter-plugins-dependencies [0-9]*" -type f -delete 2>/dev/null || true
	@echo "🗑️ Removing iOS build artifacts..."
	cd ios && rm -f Flutter/*.podspec Flutter/Flutter*.podspec Flutter/flutter_export_environment*.sh Flutter/Generated*.xcconfig Podfile*.lock && cd ..
	@echo "🧹 Cleaning caches and derived data..."
	rm -rf ~/Library/Developer/Xcode/DerivedData/*
	rm -rf ~/.pub-cache/bin/*
	rm -rf ~/.cocoapods/repos/*
	rm -rf ~/Library/Caches/CocoaPods/*
	rm -f flutter_*.log
	rm -rf firebase-debug*.log
	rm -rf tools/firebase_cloud/functions/firebase-debug*.log
	cd ios && rm -rf Pods Pods* .symlinks Flutter/Flutter.framework && rm -f Podfile.lock Podfile*.lock && pod deintegrate && pod cache clean --all && cd ..
	@echo "🔄 Reinstalling dependencies..."
	flutter pub cache repair
	rm -rf node_modules
	rm -rf .dart_tool
	rm -rf .flutter-plugins

release: ## Build the app in release mode
	flutter pub get && flutter clean && cd ios && rm -rf Pods Podfile.lock .symlinks && rm -rf ~/Library/Developer/Xcode/DerivedData/* && pod cache clean --all && pod deintegrate && pod setup && pod install --repo-update && flutter build ios --release --verbose

xcodebuild: ## Build the app in release mode
	xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -allowProvisioningUpdates

ipafile: ## Create an IPA file
	cxcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportOptionsPlist exportOptions.plist -exportPath build/Runner.ipa

build-testflight-full: ## Build for TestFlight distribution without cleaning
	source .env.appstore
	@echo "🚀 Building app for TestFlight distribution (quick mode)..."
	@echo "📦 Building iOS archive (this will take a few minutes)..."
	flutter build ipa --export-options-plist=ios/exportOptions.plist
	@echo "📱 Opening archive in Xcode for distribution..."
	@if [ -z "$(APPSTORE_API_KEY)" ] || [ -z "$(APPSTORE_API_ISSUER)" ]; then \
		echo "⚠️ Error: APPSTORE_API_KEY and APPSTORE_API_ISSUER environment variables must be set"; \
		echo "📝 Example: export APPSTORE_API_KEY=your_key_id export APPSTORE_API_ISSUER=your_issuer_id"; \
		echo "📱 Opening archive in Xcode for manual upload..."; \
		open build/ios/archive/Runner.xcarchive; \
	else \
		echo "📤 Uploading to App Store Connect..."; \
		xcrun altool --upload-app -f build/ios/ipa/Runner.ipa -t ios --apiKey $(APPSTORE_API_KEY) --apiIssuer $(APPSTORE_API_ISSUER); \
		echo "✅ Upload complete! The build should appear in App Store Connect shortly."; \
	fi


build-testflight: ## Build for TestFlight distribution without cleaning DISABLE_CRASHLYTICS_UPLOAD=1 make build-testflight
	@echo "🚀 Building app for TestFlight distribution (quick mode)..."
	@echo "📦 Building iOS archive (this will take a few minutes)..."
	DISABLE_CRASHLYTICS_UPLOAD=1 flutter build ipa --export-options-plist=ios/exportOptions.plist
	@echo "📱 Opening archive in Xcode for distribution..."
	open build/ios/archive/Runner.xcarchive

# ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
flutter-run-android-xs: ## Run on Android emulator (Pixel 4) similar size to iPhone XS
	@echo "🚀 Running app on Pixel 4 (similar size to iPhone XS)..."
	@echo "🔧 Ensuring Android SDK is available..."
	@if [ ! -f "$$ANDROID_SDK_ROOT/emulator/emulator" ]; then \
		echo "⚠️ Android emulator not found. Please run 'make setup-android-emulator' first."; \
		exit 1; \
	fi; \
	echo "📱 Starting Pixel 4 emulator..."; \
	"$$ANDROID_SDK_ROOT/emulator/emulator" -avd Pixel_4 -no-boot-anim -no-snapshot-load & \
	EMU_PID=$$!; \
	echo "⏳ Waiting for emulator to boot..."; \
	"$$ANDROID_SDK_ROOT/platform-tools/adb" -s emulator-5554 wait-for-device; \
	sleep 15; \
	echo "📦 Building APK with Gradle..."; \
	flutter pub get && cd android && ./gradlew assembleDebug && cd .. || { echo "❌ Gradle build failed"; exit 1; }; \
	echo "📱 Installing APK on emulator..."; \
	"$$ANDROID_SDK_ROOT/platform-tools/adb" -s emulator-5554 install -r ./android/app/build/outputs/apk/debug/app-debug.apk || { echo "❌ APK install failed"; exit 1; }; \
	echo "🚀 Launching app..."; \
	"$$ANDROID_SDK_ROOT/platform-tools/adb" -s emulator-5554 shell am start -n com.stoppr.sugar.app/.MainActivity || { echo "❌ Launch failed"; exit 1; }; \
	echo "🔗 Attaching Flutter for hot reload..."; \
	flutter attach -d emulator-5554

list-android-emulators: ## List available Android emulators
	@if [ -f "$$ANDROID_SDK_ROOT/emulator/emulator" ]; then \
		echo "📱 Available Android emulators:"; \
		"$$ANDROID_SDK_ROOT/emulator/emulator" -list-avds; \
	else \
		echo "⚠️ Android emulator not found. Please run 'make setup-android-emulator' first."; \
	fi

reset-android: ## Reset Android build environment and rebuild
	@echo "🧹 Starting Android reset..."
	flutter clean
	rm -rf build/
	rm -rf .dart_tool/
	rm -rf android/.gradle/
	rm -rf android/app/build/
	@echo "🔄 Reinstalling dependencies..."
	flutter pub get
	@echo "🧼 Removing all generated Dart files..."
	rm -f lib/core/auth/cubit/auth_state.freezed*.dart
	rm -f lib/core/auth/models/app_user.freezed*.dart lib/core/auth/models/app_user.g*.dart
	rm -f lib/features/onboarding/domain/models/questionnaire_answers_model.freezed*.dart lib/features/onboarding/domain/models/questionnaire_answers_model.g*.dart
	rm -f lib/features/onboarding/domain/models/questionnaire_model.freezed*.dart lib/features/onboarding/domain/models/questionnaire_model.g*.dart
	@echo "🧹 Removing duplicate generated files with numeric suffixes..."
	find lib -type f \( -name "*\.freezed\ [0-9]*.dart" -o -name "*\.g\ [0-9]*.dart" \) -delete 2>/dev/null || true
	find lib -type f \( -name "*.freezed.dart" -o -name "*.g.dart" \) -delete 2>/dev/null || true
	@echo "🧹 Removing duplicate Android files with numeric suffixes..."
	find android -name "*\ [0-9]*" -type f -delete 2>/dev/null || true
	find android -name "*\ [0-9]*" -type d -exec rm -rf {} \; 2>/dev/null || true
	@echo "🧼 Generating Dart files..."
	flutter pub run build_runner build --delete-conflicting-outputs
	@echo "🧹 Cleaning Android Gradle..."
	cd android && ./gradlew clean && cd ..
	@echo "✨ Reset complete! Project is fresh and clean."

build-android-aap: ## Reset Android build environment and rebuild
	@echo "🧹 Starting Android reset..."
	flutter clean
	rm -rf build/
	rm -rf .dart_tool/
	rm -rf android/.gradle/
	rm -rf android/app/build/
	@echo "🔄 Reinstalling dependencies..."
	flutter pub get
	@echo "🧼 Generating Dart files..."
	flutter pub run build_runner build --delete-conflicting-outputs
	@echo "🧹 Cleaning Android Gradle..."
	rm -rf android/app/build/
	@echo "🚀 Building Android bundle..."
	cd android && ./gradlew bundleRelease && cd ..
	@echo "✅ Bundle should be at android/app/build/outputs/bundle/release/app-release.aab"

flutter-run-android-existing-build: ## Run on connected physical Android device
	adb -s R7AXC0MT90Y install -r android/app/build/outputs/apk/debug/app-debug.apk
	adb -s R7AXC0MT90Y shell am start -n com.stoppr.sugar.app/.MainActivity
	flutter attach -d R7AXC0MT90Y
	adb -s R7AXC0MT90Y logcat -v time | grep -E "(flutter|Stoppr|FLUTTER)"
# flutter run -d R7AXC0MT90Y
	
flutter-aap-bundle: ## Build AAP bundle
	flutter clean
	flutter pub get
	flutter pub run build_runner build --delete-conflicting-outputs
	cd android && ./gradlew clean --info && cd ..
	cd android && ./gradlew bundleRelease && cd ..
#flutter build appbundle

# iPad-specific commands
list-ipad-sims: ## List available iPad simulators only
	@echo "📱 Available iPad simulators:"
	xcrun simctl list devices | grep -A 20 -- "-- iOS" | grep "iPad"

open-ipad-sim: ## Open iOS Simulator with iPad Pro 11-inch
	xcrun simctl boot "iPad Pro 11-inch (M4)" 
	open -a Simulator

flutter-run-ipad-pro-11: ## Run app on iPad Pro 11-inch
	@echo "🚀 Running app on iPad Pro 11-inch with development profile..."
	xcrun simctl boot "iPad Pro 11-inch (M4)" 
	open -a Simulator
	@sleep 2
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPad Pro 11-inch (M4)"; \
	else \
		flutter run -d "iPad Pro 11-inch (M4)" --use-application-binary=$$RUNNER_APP; \
	fi
	@echo "✅ Flutter session completed"

flutter-run-ipad-pro-13: ## Run app on iPad Pro 13-inch
	@echo "🚀 Running app on iPad Pro 13-inch with development profile..."
	xcrun simctl boot "iPad Pro 13-inch (M4)" 
	open -a Simulator
	@sleep 2
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPad Pro 13-inch (M4)"; \
	else \
		flutter run -d "iPad Pro 13-inch (M4)" --use-application-binary=$$RUNNER_APP; \
	fi
	@echo "✅ Flutter session completed"

flutter-run-ipad-air-11: ## Run app on iPad Air 11-inch
	@echo "🚀 Running app on iPad Air 11-inch with development profile..."
	xcrun simctl boot "iPad Air 11-inch (M3)" 
	open -a Simulator
	@sleep 2
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPad Air 11-inch (M3)"; \
	else \
		flutter run -d "iPad Air 11-inch (M3)" --use-application-binary=$$RUNNER_APP; \
	fi
	@echo "✅ Flutter session completed"

unfreeze-xcode: ## Unfreeze Xcode
	killall Xcode || true
	killall -9 com.apple.dt.Xcode || true
	killall -9 com.apple.CoreSimulator.CoreSimulatorService || true
	@echo "🧹 Cleaning Xcode caches and derived data..."
	rm -rf ~/Library/Developer/Xcode/DerivedData
	rm -rf ~/Library/Caches/com.apple.dt.Xcode
	rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*
	@echo "🔄 Resetting iOS and Watch simulators..."
	xcrun simctl shutdown all 2>/dev/null || true
	xcrun simctl erase all
	@echo "🧼 Cleaning project specific files..."
	rm -rf ios/Pods
	rm -rf ios/.symlinks
	rm -rf ios/Flutter/Flutter.framework
	rm -rf ios/Flutter/Flutter.podspec
	rm -rf ios/build
	@echo "✨ Done! Now try reopening Xcode (wait 30 seconds before opening)"


# $ANDROID_SDK_ROOT/emulator/emulator -avd Pixel_4 -no-boot-anim
# $ANDROID_SDK_ROOT/emulator/emulator -avd Pixel_6_Pro -no-boot-anim
# $ANDROID_SDK_ROOT/emulator/emulator -avd Pixel_3_XL -no-boot-anim
flutter-run-android-emulator-adb: ## Build, install and run on Android emulator with adb (bypasses Flutter APK detection issues)
	@echo "🚀 Starting Android build and deployment with adb..."
	cd android && ./gradlew clean && cd ..
	@echo "📦 Building APK with Gradle..."
	cd android && ./gradlew assembleDebug && cd ..
	@echo "📱 Installing APK on emulator..."
	adb -s emulator-5554 install -r ./android/app/build/outputs/apk/debug/app-debug.apk
	@echo "🚀 Launching app..."
	adb -s emulator-5554 shell am start -n com.stoppr.sugar.app/.MainActivity
	@echo "🔗 Attaching Flutter for hot reload support..."
	flutter attach -d emulator-5554
	@echo "✅ Flutter session completed"

# $ANDROID_SDK_ROOT/emulator/emulator -avd Pixel_4 -no-boot-anim
flutter-clean-run-android-emulator-adb: ## Clean, build, install and run on Android emulator with adb (for when you need a full rebuild)
	@echo "🚀 Starting Android clean build and deployment with adb..."
	@echo "🧹 Cleaning project..."
	flutter clean
	flutter pub get
	
	@echo "📦 Building APK with Gradle..."
	cd android && ./gradlew assembleDebug && cd ..
	@echo "📱 Installing APK on emulator..."
	adb -s emulator-5554 install -r ./android/app/build/outputs/apk/debug/app-debug.apk
	@echo "🚀 Launching app..."
	adb -s emulator-5554 shell am start -n com.stoppr.sugar.app/.MainActivity
	@echo "🔗 Attaching Flutter for hot reload support..."
	flutter attach -d emulator-5554
	@echo "✅ Flutter session completed"

android-run-legacy-superwall: ## Temporarily pin superwallkit_flutter 2.0.8, build & run on emulator, then restore
	@echo "🔄 Backing up pubspec.yaml..."
	cp pubspec.yaml pubspec.yaml.bak
	@echo "📌 Pinning superwallkit_flutter to 2.0.8 for Android build..."
	sed -i '' -e 's/^\s*superwallkit_flutter:.*/  superwallkit_flutter: 2.0.8/' pubspec.yaml
	flutter pub get
	@echo "🚀 Building & deploying with legacy superwall version..."
	make flutter-run-android-emulator-adb
	@echo "🔙 Restoring original pubspec.yaml..."
	mv pubspec.yaml.bak pubspec.yaml
	flutter pub get
	@echo "✅ Android run with legacy Superwall complete and pubspec.yaml restored"


# Git Extreme Reset - WARNING: This will delete your local Git history for this project!
# It will then re-initialize Git, commit all current files to a new branch, and push that branch.
# NOTE: Requires GITHUB_TOKEN environment variable to be set for authentication
git-extreme-reset:
	@echo "WARNING: This will DELETE your local .git folder (all local history, branches, etc.)."
	@echo "Your current working files will NOT be deleted."
	@read -p "Are you absolutely sure you want to continue? (yes/No): " confirm; \
	if [ "$$confirm" != "yes" ]; then \
		echo "Operation cancelled by user."; \
		exit 1; \
	fi
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "ERROR: GITHUB_TOKEN environment variable is not set."; \
		echo "Please set it with: export GITHUB_TOKEN=your_token_here"; \
		echo "Or provide the remote URL manually after git init."; \
		exit 1; \
	fi
	@echo "Proceeding with extreme reset..."
	@rm -rf .git
	@echo "Local .git folder removed."
	@git init
	@echo "Initialized new Git repository."
	@read -p "Enter your GitHub repository URL (e.g., https://github.com/username/repo.git): " repo_url; \
	if [ -z "$$repo_url" ]; then \
		echo "No repository URL entered. Skipping remote setup."; \
		echo "You can add it later with: git remote add origin <url>"; \
	else \
		echo "Adding remote origin..."; \
		git remote add origin https://$$GITHUB_TOKEN@$$(echo $$repo_url | sed 's|https://||'); \
		echo "Added remote origin."; \
	fi
	@read -p "Enter the name for the new branch (e.g., main-reset-YYYYMMDD): " new_branch_name; \
	if [ -z "$$new_branch_name" ]; then \
		echo "No branch name entered. Aborting."; \
		exit 1; \
	fi
	@git checkout -b $$new_branch_name
	@echo "Switched to new branch: $$new_branch_name."
	@git add .
	@echo "Added all files to staging."
	@git commit -m "Extreme Reset: Re-initialized repository with current files on branch $$new_branch_name"
	@echo "Committed files to $$new_branch_name."
	@if git remote get-url origin > /dev/null 2>&1; then \
		git push -u origin $$new_branch_name; \
		echo "Pushed $$new_branch_name to origin."; \
	else \
		echo "No remote configured. Skipping push."; \
		echo "Configure remote and push manually: git remote add origin <url> && git push -u origin $$new_branch_name"; \
	fi
	@echo "Git extreme reset complete. New branch '$$new_branch_name' created."
	@echo "Consider creating a Pull Request on GitHub for '$$new_branch_name'."

# Update dependencies and sync with Firebase
update-all: pub-get-force pod-install-force firebase-cli-login firebase-sync
	@echo "All dependencies updated and synced with Firebase."

reset-iphone-xs: ## Delete and recreate iPhone XS simulator
	@echo "🗑️ Deleting existing iPhone XS simulator..."
	-xcrun simctl list devices | grep "iPhone XS" | grep -v "unavailable" | cut -d "(" -f 2 | cut -d ")" -f 1 | xargs -I {} xcrun simctl delete {}
	@echo "🔄 Creating new iPhone XS simulator..."
	xcrun simctl create "iPhone XS" com.apple.CoreSimulator.SimDeviceType.iPhone-XS com.apple.CoreSimulator.SimRuntime.iOS-18-4
	@echo "✅ iPhone XS simulator has been reset successfully!"

flutter-run-android-pixel6pro: ## Run on Android emulator (Pixel 6 Pro)
	@echo "🚀 Running app on Pixel 6 Pro..."
	@echo "🔧 Ensuring Android SDK is available..."
	@if [ ! -f "$$ANDROID_SDK_ROOT/emulator/emulator" ]; then \
		echo "⚠️ Android emulator not found. Please run 'make setup-android-emulator' first."; \
		exit 1; \
	fi; \
	echo "📱 Starting Pixel 6 Pro emulator..."; \
	"$$ANDROID_SDK_ROOT/emulator/emulator" -avd Pixel_6_Pro -no-boot-anim -no-snapshot-load & \
	EMU_PID=$$!; \
	echo "⏳ Waiting for emulator to boot..."; \
	"$$ANDROID_SDK_ROOT/platform-tools/adb" -s emulator-5556 wait-for-device; \
	sleep 15; \
	echo "📦 Building APK with Gradle..."; \
	flutter pub get && cd android && ./gradlew assembleDebug && cd .. || { echo "❌ Gradle build failed"; exit 1; }; \
	echo "📱 Installing APK on emulator..."; \
	"$$ANDROID_SDK_ROOT/platform-tools/adb" -s emulator-5556 install -r ./android/app/build/outputs/apk/debug/app-debug.apk || { echo "❌ APK install failed"; exit 1; }; \
	echo "🚀 Launching app..."; \
	"$$ANDROID_SDK_ROOT/platform-tools/adb" -s emulator-5556 shell am start -n com.stoppr.sugar.app/.MainActivity || { echo "❌ Launch failed"; exit 1; }; \
	echo "🔗 Attaching Flutter for hot reload..."; \
	flutter attach -d emulator-5556



flutter-run-iphonex-ios185: ## Reliable run and debug on iPhone XS iOS 18.5 for testing video player fixes
	@echo "🚀 Running app on iPhone XS iOS 18.5 for video player testing..."
	xcrun simctl boot "iPhone XS iOS 18.5" 
	open -a Simulator
	@sleep 2
	@echo "📱 Building and running with development profile..."
	cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -allowProvisioningUpdates && cd ..
	@echo "🔍 Locating built app..."
	@sleep 3
	@if [ -z "$$XCODE_DERIVED_DATA_PATH" ]; then \
		DERIVED_DATA_PATH=$$HOME/Library/Developer/Xcode/DerivedData; \
	else \
		DERIVED_DATA_PATH=$$XCODE_DERIVED_DATA_PATH; \
	fi; \
	RUNNER_APP=$$(find $$DERIVED_DATA_PATH -name "Runner.app" -path "*/Debug-iphonesimulator/*" -type d | head -1); \
	if [ -z "$$RUNNER_APP" ]; then \
		flutter run -d "iPhone XS iOS 18.5" --no-enable-impeller; \
	else \
		flutter run -d "iPhone XS iOS 18.5" --use-application-binary=$$RUNNER_APP --no-enable-impeller; \
	fi
	@echo "✅ Flutter session completed"