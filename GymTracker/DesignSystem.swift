import SwiftUI
import UIKit

// MARK: - Theme
// One gradient identity per domain, used consistently across the app:
// nutrition = warm, training = electric, weight = cool, success = fresh.

enum Theme {
    static let nutritionColors: [Color] = [.orange, .pink]
    static let trainingColors: [Color] = [.blue, .indigo]
    static let weightColors: [Color] = [.teal, .cyan]
    static let successColors: [Color] = [.green, .mint]

    static var nutrition: LinearGradient { gradient(nutritionColors) }
    static var training: LinearGradient { gradient(trainingColors) }
    static var weight: LinearGradient { gradient(weightColors) }
    static var success: LinearGradient { gradient(successColors) }

    static func gradient(_ colors: [Color]) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Meal {
    var colors: [Color] {
        switch self {
        case .breakfast: return [.orange, .yellow]
        case .lunch: return [.yellow, .orange]
        case .dinner: return [.indigo, .purple]
        case .snacks: return [.green, .mint]
        }
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func confirm() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Card

extension View {
    /// The app's standard floating card.
    func card() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Pressable Button

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// A prominent full-width gradient call-to-action label.
struct GradientButtonLabel: View {
    let title: String
    let systemImage: String
    let colors: [Color]

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gradient(colors))
            .clipShape(Capsule())
            .shadow(color: (colors.last ?? .blue).opacity(0.35), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Gradient Icon

struct GradientIcon: View {
    let systemName: String
    let colors: [Color]
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.gradient(colors))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
    }
}

// MARK: - Activity Ring

struct ActivityRing: View {
    var progress: Double
    var colors: [Color]
    var lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke((colors.first ?? .blue).opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.002))
                .stroke(
                    AngularGradient(
                        colors: colors + [colors.first ?? .blue],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: (colors.last ?? .blue).opacity(0.35), radius: 5)
        }
        .animation(.spring(response: 0.9, dampingFraction: 0.85), value: progress)
    }
}

// MARK: - Gradient Bar

struct GradientBar: View {
    var progress: Double
    var colors: [Color]
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill((colors.first ?? .blue).opacity(0.12))
                if progress > 0 {
                    Capsule()
                        .fill(Theme.gradient(colors))
                        .frame(width: max(proxy.size.width * min(progress, 1), height))
                }
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: progress)
    }
}
