//
//  TrialManager.swift
//  SignatureWidget
//

import Foundation

/// Shared trial + entitlement state stored in the App Group so both the
/// app and the widget extension can read it without a StoreKit dependency
/// in the extension target.
enum TrialManager {

    // MARK: - Constants

    static let trialDays = 7

    private static let firstLaunchKey = "com.signaturewidget.firstLaunchDate"
    private static let purchasedKey   = "com.signaturewidget.isPurchased"

    // MARK: - App Group UserDefaults

    static var defaults: UserDefaults {
        UserDefaults(suiteName: SignatureSharing.appGroupID) ?? .standard
    }

    // MARK: - First Launch

    /// Call once on app launch. Records the date only if not already stored.
    static func recordFirstLaunchIfNeeded() {
        guard defaults.object(forKey: firstLaunchKey) == nil else { return }
        defaults.set(Date(), forKey: firstLaunchKey)
    }

    static var firstLaunchDate: Date? {
        defaults.object(forKey: firstLaunchKey) as? Date
    }

    // MARK: - Trial Status

    static var trialDaysRemaining: Int {
        guard let launch = firstLaunchDate else { return trialDays }
        let elapsed = Calendar.current.dateComponents([.day], from: launch, to: Date()).day ?? 0
        return max(0, trialDays - elapsed)
    }

    static var isTrialActive: Bool { trialDaysRemaining > 0 }

    // MARK: - Purchase Status

    /// Written by StoreManager after verifying a transaction; read by the widget.
    static var isPurchased: Bool {
        get { defaults.bool(forKey: purchasedKey) }
        set { defaults.set(newValue, forKey: purchasedKey) }
    }

    // MARK: - Access Gate

    /// True when the user may use the widget (trial active OR purchased).
    static var hasAccess: Bool { isTrialActive || isPurchased }
}
