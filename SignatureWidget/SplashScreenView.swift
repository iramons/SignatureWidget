//
//  SplashScreenView.swift
//  SignatureWidget
//

import SwiftUI

// MARK: - Splash Screen

struct SplashScreenView: View {
    @State private var isActive      = false
    @State private var logoScale     = 0.55
    @State private var logoOpacity   = 0.0
    @State private var titleOpacity  = 0.0
    @State private var taglineOpacity = 0.0

    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // Full-screen brand gradient
                LinearGradient.brand
                    .ignoresSafeArea()

                // Subtle noise-like overlay for depth
                RoundedRectangle(cornerRadius: 0)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.04), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    // Logo mark
                    AppLogoMarkView()
                        .frame(width: 130, height: 130)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    VStack(spacing: 6) {
                        Text("SignatureWidget")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .opacity(titleOpacity)

                        Text("Sua assinatura, sempre à mão")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .opacity(taglineOpacity)
                    }
                }
            }
            .onAppear(perform: runAnimation)
        }
    }

    private func runAnimation() {
        // 1 – Logo springs in
        withAnimation(.spring(response: 0.65, dampingFraction: 0.6)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        // 2 – Title fades in
        withAnimation(.easeOut(duration: 0.45).delay(0.35)) {
            titleOpacity = 1.0
        }
        // 3 – Tagline fades in
        withAnimation(.easeOut(duration: 0.45).delay(0.55)) {
            taglineOpacity = 1.0
        }
        // 4 – Transition to app
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeInOut(duration: 0.35)) {
                isActive = true
            }
        }
    }
}

// MARK: - App Logo Mark (reusable)

/// The standalone logo mark — white glass card with a drawn signature.
/// Use at any size; it scales via GeometryReader.
struct AppLogoMarkView: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                // Glass card
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(.white.opacity(0.20))
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(.white.opacity(0.45), lineWidth: 2)

                // Drawn signature
                SignatureLogoCanvas()
                    .padding(size * 0.15)
            }
        }
    }
}

// MARK: - Signature Canvas (logo illustration)

private struct SignatureLogoCanvas: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height

            // ── Main stroke ──
            var main = Path()
            main.move(to: CGPoint(x: w * 0.08, y: h * 0.65))
            main.addCurve(
                to: CGPoint(x: w * 0.35, y: h * 0.38),
                control1: CGPoint(x: w * 0.10, y: h * 0.45),
                control2: CGPoint(x: w * 0.22, y: h * 0.32)
            )
            main.addCurve(
                to: CGPoint(x: w * 0.50, y: h * 0.55),
                control1: CGPoint(x: w * 0.48, y: h * 0.44),
                control2: CGPoint(x: w * 0.54, y: h * 0.60)
            )
            main.addCurve(
                to: CGPoint(x: w * 0.68, y: h * 0.44),
                control1: CGPoint(x: w * 0.46, y: h * 0.50),
                control2: CGPoint(x: w * 0.58, y: h * 0.36)
            )
            main.addCurve(
                to: CGPoint(x: w * 0.92, y: h * 0.55),
                control1: CGPoint(x: w * 0.78, y: h * 0.52),
                control2: CGPoint(x: w * 0.86, y: h * 0.62)
            )

            ctx.stroke(
                main,
                with: .color(.white),
                style: StrokeStyle(lineWidth: w * 0.085, lineCap: .round, lineJoin: .round)
            )

            // ── Underline flourish ──
            var underline = Path()
            underline.move(to: CGPoint(x: w * 0.06, y: h * 0.80))
            underline.addCurve(
                to: CGPoint(x: w * 0.94, y: h * 0.77),
                control1: CGPoint(x: w * 0.35, y: h * 0.74),
                control2: CGPoint(x: w * 0.65, y: h * 0.82)
            )

            ctx.stroke(
                underline,
                with: .color(.white.opacity(0.55)),
                style: StrokeStyle(lineWidth: w * 0.045, lineCap: .round)
            )
        }
    }
}

#Preview {
    SplashScreenView()
}
