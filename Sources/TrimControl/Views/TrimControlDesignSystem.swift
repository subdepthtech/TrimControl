import AppKit
import SwiftUI

enum TrimTokens {
    enum Colors {
        static let background = Color.adaptive(light: 0xF5F7FB, dark: 0x0B0E13)
        static let sidebar = Color.adaptive(light: 0xEEF3F9, dark: 0x0D1218)
        static let surfacePrimary = Color.adaptive(light: 0xFFFFFF, dark: 0x11161D)
        static let surfaceSecondary = Color.adaptive(light: 0xF2F5F9, dark: 0x161C24)
        static let surfaceTertiary = Color.adaptive(light: 0xE8EDF5, dark: 0x1B2330)
        static let strokeSubtle = Color.adaptive(light: 0xD8DEE8, dark: 0x232A36)
        static let strokeFocused = Color.adaptive(light: 0x2563EB, dark: 0x3B82F6)
        static let accent = Color.adaptive(light: 0x2563EB, dark: 0x2F80FF)
        static let accentHover = Color.adaptive(light: 0x1D4ED8, dark: 0x60A5FA)
        static let accentSoft = Color.adaptive(light: 0xDBEAFE, dark: 0x0F2442)
        static let success = Color.adaptive(light: 0x16A34A, dark: 0x22C55E)
        static let warning = Color.adaptive(light: 0xD97706, dark: 0xF59E0B)
        static let danger = Color.adaptive(light: 0xDC2626, dark: 0xEF4444)
        static let textPrimary = Color.adaptive(light: 0x111827, dark: 0xE5E7EB)
        static let textSecondary = Color.adaptive(light: 0x4B5563, dark: 0x9CA3AF)
        static let textTertiary = Color.adaptive(light: 0x6B7280, dark: 0x6B7280)
        static let shadow = Color.black.opacity(0.28)
    }

    enum Typography {
        static let appTitle = Font.system(size: 20, weight: .semibold, design: .default)
        static let sectionTitle = Font.system(size: 11, weight: .semibold, design: .default)
        static let headline = Font.system(size: 13, weight: .semibold, design: .default)
        static let body = Font.system(size: 12, weight: .regular, design: .default)
        static let caption = Font.system(size: 11, weight: .regular, design: .default)
        static let mono = Font.system(size: 11, weight: .regular, design: .monospaced)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 14
    }

    enum Heights {
        static let control: CGFloat = 28
        static let compactControl: CGFloat = 24
        static let row: CGFloat = 58
        static let footer: CGFloat = 66
    }

    enum Motion {
        static let fast = Animation.easeOut(duration: 0.12)
        static let normal = Animation.easeOut(duration: 0.16)
        static let press = Animation.easeOut(duration: 0.08)
    }
}

enum TrimButtonRole {
    case primary
    case secondary
    case destructive
    case utility
}

struct PrimaryButton<Label: View>: View {
    private let action: () -> Void
    private let label: () -> Label

    @State private var isHovering = false

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(TrimControlButtonStyle(role: .primary, isHovering: isHovering))
        .onHover { hovering in
            withAnimation(TrimTokens.Motion.fast) {
                isHovering = hovering
            }
        }
    }
}

struct SecondaryButton<Label: View>: View {
    private let role: TrimButtonRole
    private let action: () -> Void
    private let label: () -> Label

    @State private var isHovering = false

    init(
        role: TrimButtonRole = .secondary,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(TrimControlButtonStyle(role: role, isHovering: isHovering))
        .onHover { hovering in
            withAnimation(TrimTokens.Motion.fast) {
                isHovering = hovering
            }
        }
    }
}

struct ToolbarIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: TrimTokens.Heights.control, height: TrimTokens.Heights.control)
        }
        .buttonStyle(TrimControlButtonStyle(role: .utility, isHovering: isHovering, isIconOnly: true))
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering in
            withAnimation(TrimTokens.Motion.fast) {
                isHovering = hovering
            }
        }
    }
}

private struct TrimControlButtonStyle: ButtonStyle {
    let role: TrimButtonRole
    let isHovering: Bool
    var isIconOnly = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TrimTokens.Typography.body.weight(.medium))
            .foregroundStyle(foregroundColor)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, isIconOnly ? 0 : 11)
            .frame(minHeight: TrimTokens.Heights.control)
            .background {
                RoundedRectangle(cornerRadius: TrimTokens.Radius.sm, style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
                    .overlay {
                        RoundedRectangle(cornerRadius: TrimTokens.Radius.sm, style: .continuous)
                            .stroke(strokeColor, lineWidth: 1)
                    }
            }
            .shadow(color: shadowColor, radius: role == .primary ? 4 : 1, x: 0, y: role == .primary ? 2 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(TrimTokens.Motion.press, value: configuration.isPressed)
            .animation(TrimTokens.Motion.fast, value: isHovering)
    }

    private var foregroundColor: Color {
        guard isEnabled else {
            return TrimTokens.Colors.textTertiary
        }

        switch role {
        case .primary:
            return .white
        case .destructive:
            return TrimTokens.Colors.danger
        case .secondary, .utility:
            return TrimTokens.Colors.textPrimary
        }
    }

    private func fillColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return TrimTokens.Colors.surfaceSecondary.opacity(0.7)
        }

        switch role {
        case .primary:
            if isPressed {
                return TrimTokens.Colors.strokeFocused
            }
            return isHovering ? TrimTokens.Colors.accentHover : TrimTokens.Colors.accent
        case .destructive:
            return isHovering
                ? TrimTokens.Colors.danger.opacity(0.16)
                : TrimTokens.Colors.surfaceSecondary.opacity(0.9)
        case .secondary, .utility:
            if isPressed {
                return TrimTokens.Colors.surfaceTertiary
            }
            return isHovering
                ? TrimTokens.Colors.surfaceTertiary.opacity(0.95)
                : TrimTokens.Colors.surfaceSecondary.opacity(0.85)
        }
    }

    private var strokeColor: Color {
        switch role {
        case .primary:
            return TrimTokens.Colors.accentHover.opacity(0.65)
        case .destructive:
            return isHovering ? TrimTokens.Colors.danger.opacity(0.55) : TrimTokens.Colors.strokeSubtle
        case .secondary, .utility:
            return isHovering ? TrimTokens.Colors.strokeFocused.opacity(0.45) : TrimTokens.Colors.strokeSubtle
        }
    }

    private var shadowColor: Color {
        guard isEnabled else {
            return .clear
        }

        switch role {
        case .primary:
            return TrimTokens.Colors.accent.opacity(0.24)
        case .secondary, .destructive, .utility:
            return TrimTokens.Colors.shadow.opacity(isHovering ? 0.16 : 0.08)
        }
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(TrimTokens.Typography.sectionTitle)
            .foregroundStyle(TrimTokens.Colors.textSecondary)
            .tracking(0.4)
    }
}

struct StatusDot: View {
    var color = TrimTokens.Colors.success

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.35), radius: 5, x: 0, y: 0)
    }
}

enum TrimStatusTone {
    case success
    case warning
    case danger
    case accent
    case neutral

    var foregroundColor: Color {
        switch self {
        case .success:
            return TrimTokens.Colors.success
        case .warning:
            return TrimTokens.Colors.warning
        case .danger:
            return TrimTokens.Colors.danger
        case .accent:
            return TrimTokens.Colors.accentHover
        case .neutral:
            return TrimTokens.Colors.textTertiary
        }
    }

    var fillColor: Color {
        switch self {
        case .success:
            return TrimTokens.Colors.success.opacity(0.12)
        case .warning:
            return TrimTokens.Colors.warning.opacity(0.12)
        case .danger:
            return TrimTokens.Colors.danger.opacity(0.12)
        case .accent:
            return TrimTokens.Colors.accentSoft.opacity(0.72)
        case .neutral:
            return TrimTokens.Colors.surfaceTertiary.opacity(0.75)
        }
    }
}

struct TrimStatusChip: View {
    let tone: TrimStatusTone
    let label: String
    var systemImage: String?
    var showsDot = false

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.xs) {
            if showsDot {
                Circle()
                    .fill(tone.foregroundColor)
                    .frame(width: 6, height: 6)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(label)
                .font(TrimTokens.Typography.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(tone == .neutral ? TrimTokens.Colors.textSecondary : tone.foregroundColor)
        .padding(.horizontal, TrimTokens.Spacing.sm)
        .frame(height: 22)
        .background {
            Capsule()
                .fill(tone.fillColor)
                .overlay {
                    Capsule()
                        .stroke(tone.foregroundColor.opacity(0.22), lineWidth: 1)
                }
        }
    }
}

extension Color {
    static func adaptive(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        Color(nsColor: .adaptive(light: light, dark: dark, alpha: alpha))
    }
}

private extension NSColor {
    static func adaptive(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua, .vibrantDark, .vibrantLight])
            let darkAppearance = match == .darkAqua || match == .vibrantDark
            return NSColor.hex(darkAppearance ? dark : light, alpha: alpha)
        }
    }

    static func hex(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}
