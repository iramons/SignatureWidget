//
//  DesignSystem.swift
//  SignatureWidget
//

import SwiftUI

// MARK: - Brand Colors

extension Color {
    /// Primary brand indigo #6366F1
    static let brandIndigo  = Color(red: 99/255,  green: 102/255, blue: 241/255)
    /// Secondary brand purple #8B5CF6
    static let brandPurple  = Color(red: 139/255, green: 92/255,  blue: 246/255)
    /// Light violet tint #A78BFA
    static let brandViolet  = Color(red: 167/255, green: 139/255, blue: 250/255)
    /// Soft background tint (5 % indigo)
    static let brandSubtle  = Color(red: 99/255,  green: 102/255, blue: 241/255).opacity(0.08)
}

// MARK: - Brand Gradients

extension LinearGradient {
    /// Main brand gradient: indigo → purple (top-leading → bottom-trailing)
    static let brand = LinearGradient(
        colors: [.brandIndigo, .brandPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Subtle tinted background gradient
    static let brandSubtle = LinearGradient(
        colors: [Color.brandIndigo.opacity(0.12), Color.brandPurple.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Reusable Modifiers

extension View {
    /// Coloured drop shadow that matches the brand palette
    func brandShadow(radius: CGFloat = 14, y: CGFloat = 6) -> some View {
        self.shadow(color: Color.brandIndigo.opacity(0.30), radius: radius, x: 0, y: y)
    }

    /// Rounded card surface
    func cardSurface(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
            )
    }
}
