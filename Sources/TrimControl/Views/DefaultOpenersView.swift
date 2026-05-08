import AppKit
import SwiftUI
import TrimControlCore

struct DefaultOpenersView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""

    private var filteredRules: [ExternalOpenerRule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return appState.externalOpenerRules
        }

        return appState.externalOpenerRules.filter { rule in
            rule.categoryName.lowercased().contains(query)
                || rule.displayExtensions.lowercased().contains(query)
                || rule.selectedAppSummary.lowercased().contains(query)
                || rule.extensions.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            DefaultOpenersHeader(
                customRuleCount: appState.externalOpenerRules.filter { $0.status == .custom }.count,
                ruleCount: appState.externalOpenerRules.count
            )

            DefaultOpenersSearchBar(searchText: $searchText)
                .padding(.horizontal, TrimTokens.Spacing.xxl)
                .padding(.bottom, TrimTokens.Spacing.md)

            Divider()
                .overlay(TrimTokens.Colors.strokeSubtle)

            ExternalOpenerCategoryList(rules: filteredRules)
        }
    }
}

struct DefaultOpenersHeader: View {
    let customRuleCount: Int
    let ruleCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: TrimTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: TrimTokens.Spacing.xs) {
                Text("Default Openers")
                    .font(TrimTokens.Typography.appTitle)
                    .foregroundStyle(TrimTokens.Colors.textPrimary)

                Text("Apps TrimControl uses for files that should not open in Neovim.")
                    .font(TrimTokens.Typography.body)
                    .foregroundStyle(TrimTokens.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: TrimTokens.Spacing.lg)

            HStack(spacing: TrimTokens.Spacing.sm) {
                DefaultOpenersMetric(label: "Custom", value: "\(customRuleCount)")
                DefaultOpenersMetric(label: "Rules", value: "\(ruleCount)")
            }
        }
        .padding(.horizontal, TrimTokens.Spacing.xxl)
        .padding(.top, TrimTokens.Spacing.xl)
        .padding(.bottom, TrimTokens.Spacing.md)
    }
}

struct ExternalOpenerCategoryList: View {
    let rules: [ExternalOpenerRule]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: TrimTokens.Spacing.sm) {
                if rules.isEmpty {
                    DefaultOpenersEmptyState()
                        .padding(.top, 72)
                } else {
                    ForEach(rules) { rule in
                        ExternalOpenerRow(rule: rule)
                    }
                }
            }
            .padding(.horizontal, TrimTokens.Spacing.xxl)
            .padding(.top, TrimTokens.Spacing.md)
            .padding(.bottom, TrimTokens.Spacing.xxl)
        }
        .scrollContentBackground(.hidden)
    }
}

struct ExternalOpenerRow: View {
    @EnvironmentObject private var appState: AppState

    let rule: ExternalOpenerRule

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.md) {
            IconTile(systemImage: categorySymbol, isSelected: isHovering || rule.status == .custom, size: 36)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: TrimTokens.Spacing.sm) {
                    Text(rule.categoryName)
                        .font(TrimTokens.Typography.headline)
                        .foregroundStyle(TrimTokens.Colors.textPrimary)
                        .lineLimit(1)

                    OpenerStatusChip(status: rule.status)
                }

                ExtensionChipGroup(extensions: rule.extensions)
            }

            Spacer(minLength: TrimTokens.Spacing.lg)

            HStack(spacing: TrimTokens.Spacing.sm) {
                AppIconTile(rule: rule)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.selectedAppSummary)
                        .font(TrimTokens.Typography.body.weight(.medium))
                        .foregroundStyle(TrimTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Text(rule.usesSystemDefault ? "Native macOS routing" : rule.selectedAppBundleIdentifier ?? "Bundle identifier missing")
                        .font(TrimTokens.Typography.caption)
                        .foregroundStyle(TrimTokens.Colors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(width: 160, alignment: .leading)
            }

            UseSystemDefaultToggle(
                isOn: rule.usesSystemDefault,
                setIsOn: { appState.setExternalOpenerUsesSystemDefault($0, for: rule) }
            )
            .frame(width: 96, alignment: .leading)

            Menu {
                Button {
                    appState.chooseExternalOpener(for: rule)
                } label: {
                    Label("Choose app…", systemImage: "app.badge")
                }

                Button(role: .destructive) {
                    appState.resetExternalOpener(rule)
                } label: {
                    Label("Reset to system default", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(TrimTokens.Colors.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("More actions for \(rule.categoryName)")
            .accessibilityLabel("More actions for \(rule.categoryName)")
        }
        .padding(.horizontal, TrimTokens.Spacing.md)
        .padding(.vertical, TrimTokens.Spacing.sm)
        .frame(minHeight: 72)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous))
        .onHover { hovering in
            withAnimation(TrimTokens.Motion.fast) {
                isHovering = hovering
            }
        }
        .animation(TrimTokens.Motion.fast, value: isHovering)
        .animation(TrimTokens.Motion.normal, value: rule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rule.categoryName), \(rule.displayExtensions), \(rule.selectedAppSummary)")
        .accessibilityValue(accessibilityStatus)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
            .fill(isHovering ? TrimTokens.Colors.surfaceSecondary : TrimTokens.Colors.surfacePrimary)
            .overlay {
                RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                    .stroke(
                        isHovering ? TrimTokens.Colors.strokeFocused.opacity(0.36) : TrimTokens.Colors.strokeSubtle,
                        lineWidth: 1
                    )
            }
    }

    private var categorySymbol: String {
        switch rule.categoryName {
        case "PDF Documents":
            return "doc.richtext"
        case "Images":
            return "photo"
        case "Videos":
            return "film"
        case "Audio":
            return "waveform"
        case "Archives":
            return "archivebox"
        case "Spreadsheets":
            return "tablecells"
        case "Presentations":
            return "rectangle.on.rectangle"
        case "Documents":
            return "doc.text"
        case "Web Files":
            return "safari"
        case "Code Files":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc"
        }
    }

    private var accessibilityStatus: String {
        switch rule.status {
        case .systemDefault:
            return "System default"
        case .custom:
            return "Custom app"
        case .missingApp:
            return "Missing app"
        case .needsPermission:
            return "Needs permission"
        }
    }
}

struct AppIconTile: View {
    let rule: ExternalOpenerRule

    var body: some View {
        IconTile(
            systemImage: rule.usesSystemDefault ? "gearshape" : "app.badge",
            nsImage: iconImage,
            isSelected: rule.usesSystemDefault,
            size: 34
        )
        .help(rule.selectedAppSummary)
    }

    private var iconImage: NSImage? {
        if let path = rule.selectedAppIconPath,
            FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }

        if let bundleIdentifier = rule.selectedAppBundleIdentifier,
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        return nil
    }
}

struct ExtensionChipGroup: View {
    let extensions: [String]

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.xs) {
            ForEach(extensions.prefix(6), id: \.self) { extensionName in
                ExtensionTag(text: ".\(extensionName)")
            }

            if extensions.count > 6 {
                Text("+\(extensions.count - 6)")
                    .font(TrimTokens.Typography.mono)
                    .foregroundStyle(TrimTokens.Colors.textTertiary)
            }
        }
        .lineLimit(1)
    }
}

struct OpenerStatusChip: View {
    let status: ExternalOpenerStatus

    var body: some View {
        TrimStatusChip(tone: tone, label: title, systemImage: systemImage)
    }

    private var title: String {
        switch status {
        case .systemDefault:
            return "System default"
        case .custom:
            return "Custom"
        case .missingApp:
            return "Missing app"
        case .needsPermission:
            return "Needs permission"
        }
    }

    private var systemImage: String {
        switch status {
        case .systemDefault:
            return "gearshape"
        case .custom:
            return "checkmark.circle.fill"
        case .missingApp:
            return "exclamationmark.triangle"
        case .needsPermission:
            return "lock"
        }
    }

    private var tone: TrimStatusTone {
        switch status {
        case .systemDefault:
            return .accent
        case .custom:
            return .success
        case .missingApp, .needsPermission:
            return .warning
        }
    }
}

struct UseSystemDefaultToggle: View {
    let isOn: Bool
    let setIsOn: (Bool) -> Void

    var body: some View {
        Toggle(
            "System",
            isOn: Binding(
                get: { isOn },
                set: setIsOn
            )
        )
        .toggleStyle(.switch)
        .controlSize(.mini)
        .font(TrimTokens.Typography.caption)
        .foregroundStyle(TrimTokens.Colors.textSecondary)
        .help("Use macOS system default")
    }
}

private struct DefaultOpenersSearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TrimTokens.Colors.textTertiary)

            TextField("Search categories, extensions, or apps", text: $searchText)
                .textFieldStyle(.plain)
                .font(TrimTokens.Typography.body)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TrimTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, TrimTokens.Spacing.md)
        .frame(width: 360, height: 32)
        .background {
            RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                .fill(TrimTokens.Colors.surfacePrimary.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                        .stroke(TrimTokens.Colors.strokeSubtle, lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DefaultOpenersMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.xs) {
            Text(value)
                .font(TrimTokens.Typography.mono)
                .foregroundStyle(TrimTokens.Colors.textPrimary)

            Text(label)
                .font(TrimTokens.Typography.caption)
                .foregroundStyle(TrimTokens.Colors.textTertiary)
        }
        .padding(.horizontal, TrimTokens.Spacing.sm)
        .frame(height: TrimTokens.Heights.control)
        .background {
            Capsule()
                .fill(TrimTokens.Colors.surfaceSecondary.opacity(0.82))
                .overlay {
                    Capsule()
                        .stroke(TrimTokens.Colors.strokeSubtle, lineWidth: 1)
                }
        }
    }
}

private struct DefaultOpenersEmptyState: View {
    var body: some View {
        VStack(spacing: TrimTokens.Spacing.md) {
            IconTile(systemImage: "magnifyingglass", size: 42)

            Text("No opener categories found")
                .font(TrimTokens.Typography.headline)
                .foregroundStyle(TrimTokens.Colors.textPrimary)

            Text("Try a different category, extension, or app name.")
                .font(TrimTokens.Typography.caption)
                .foregroundStyle(TrimTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
