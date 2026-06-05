//
//  PaywallView.swift
//  SignatureWidget
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String? = StoreManager.ProductID.yearly
    @State private var isPurchasing  = false
    @State private var showError     = false
    @State private var errorText     = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    plansSection
                    ctaButton
                    footer
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText)
            }
            .task { if store.products.isEmpty { await store.loadProducts() } }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .bottom) {
            LinearGradient.brand
                .frame(height: 280)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 16) {
                AppLogoMarkView()
                    .frame(width: 88, height: 88)

                VStack(spacing: 6) {
                    if TrialManager.isTrialActive {
                        Label("\(TrialManager.trialDaysRemaining) days left in trial", systemImage: "clock")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                    } else {
                        Label("Your trial has ended", systemImage: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    Text("SignatureWidget\nPremium")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Keep your signature in the widget\nalways up to date.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 24)
        }
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: 12) {
            if store.isLoading {
                ProgressView()
                    .padding(.vertical, 32)
            } else if store.products.isEmpty {
                Text(store.errorMessage ?? "Could not load plans.\nCheck your connection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 32)
            } else {
                ForEach(store.products, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: selectedProductID == product.id,
                        isBestValue: product.id == StoreManager.ProductID.yearly
                    ) {
                        selectedProductID = product.id
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        VStack(spacing: 16) {
            Button {
                guard let id = selectedProductID,
                      let product = store.products.first(where: { $0.id == id })
                else { return }
                Task { await executePurchase(product) }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaLabel)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    store.products.isEmpty || isPurchasing
                        ? AnyShapeStyle(Color.secondary.opacity(0.4))
                        : AnyShapeStyle(LinearGradient.brand)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .brandShadow()
            }
            .disabled(store.products.isEmpty || isPurchasing || selectedProductID == nil)
            .padding(.horizontal, 20)

            // Restore
            Button("Restore purchases") {
                Task { await store.restorePurchases() }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.brandIndigo)
        }
        .padding(.top, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Subscriptions renew automatically. Cancel anytime.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                Link("Privacy", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(Color.brandIndigo)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Helpers

    private var ctaLabel: String {
        guard let id = selectedProductID,
              let product = store.products.first(where: { $0.id == id }) else {
            return String(localized: "Subscribe")
        }
        switch id {
        case StoreManager.ProductID.lifetime:
            return String(localized: "Buy for \(product.displayPrice)")
        default:
            return String(localized: "Subscribe for \(product.displayPrice)")
        }
    }

    private func executePurchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let success = try await store.purchase(product)
            if success { dismiss() }
        } catch {
            errorText = String(localized: "Error processing payment. Please try again.")
            showError = true
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.brandIndigo : Color.secondary.opacity(0.3),
                                      lineWidth: isSelected ? 2 : 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(LinearGradient.brand)
                            .frame(width: 13, height: 13)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(planTitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        if isBestValue {
                            Text("Best value")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(LinearGradient.brand)
                                .clipShape(Capsule())
                        }
                    }
                    Text(planSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.brandIndigo : Color.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.brandIndigo : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .shadow(color: isSelected ? Color.brandIndigo.opacity(0.15) : .black.opacity(0.05),
                            radius: isSelected ? 8 : 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private var planTitle: String {
        switch product.id {
        case StoreManager.ProductID.monthly:  return String(localized: "Monthly")
        case StoreManager.ProductID.yearly:   return String(localized: "Annual")
        case StoreManager.ProductID.lifetime: return String(localized: "Lifetime")
        default: return product.displayName
        }
    }

    private var planSubtitle: String {
        switch product.id {
        case StoreManager.ProductID.monthly:  return String(localized: "Billed monthly")
        case StoreManager.ProductID.yearly:   return String(localized: "Billed annually · save ~58%")
        case StoreManager.ProductID.lifetime: return String(localized: "One-time payment, access forever")
        default: return ""
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager.shared)
}
