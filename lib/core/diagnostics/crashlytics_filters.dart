// Summary: Centralizes which non-actionable errors we suppress from Crashlytics
// for purchases and restores already tracked/handled by Superwall/RevenueCat.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Filters for deciding whether an error should be reported to Crashlytics.
class CrashlyticsFilters {
  CrashlyticsFilters._();

  /// RevenueCat purchase errors that are expected/transient and already
  /// tracked by Superwall, so we skip reporting them to Crashlytics.
  static final Set<PurchasesErrorCode> suppressedPurchaseErrors =
      UnmodifiableSetView({
    PurchasesErrorCode.purchaseCancelledError,
    PurchasesErrorCode.purchaseNotAllowedError,
    PurchasesErrorCode.purchaseInvalidError,
    PurchasesErrorCode.networkError,
  });

  /// RevenueCat restore errors that are expected/transient and already
  /// tracked by Superwall, so we skip reporting them to Crashlytics.
  static final Set<PurchasesErrorCode> suppressedRestoreErrors =
      UnmodifiableSetView({
    PurchasesErrorCode.invalidReceiptError,
    PurchasesErrorCode.missingReceiptFileError,
    PurchasesErrorCode.networkError,
  });

  /// Returns true when a purchase error should be reported to Crashlytics.
  static bool shouldReportPurchaseError(
    PurchasesErrorCode code, {
    required bool isDebugMode,
  }) =>
      !isDebugMode && !suppressedPurchaseErrors.contains(code);

  /// Returns true when a restore error should be reported to Crashlytics.
  static bool shouldReportRestoreError(
    PurchasesErrorCode code, {
    required bool isDebugMode,
  }) =>
      !isDebugMode && !suppressedRestoreErrors.contains(code);
}


