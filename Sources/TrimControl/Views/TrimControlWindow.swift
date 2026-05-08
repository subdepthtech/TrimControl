import AppKit
import SwiftUI
import TrimControlCore

enum SidebarGroup: String, CaseIterable, Identifiable {
    case workspace
    case tools
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workspace:
            return "Workspace"
        case .tools:
            return "Tools"
        case .settings:
            return "Settings"
        }
    }
}

enum SidebarDestination: String, CaseIterable, Identifiable {
    case fileTypes
    case defaultOpeners
    case verifySamples
    case presets
    case general
    case advanced

    var id: String { rawValue }

    var group: SidebarGroup {
        switch self {
        case .fileTypes, .defaultOpeners:
            return .workspace
        case .verifySamples, .presets:
            return .tools
        case .general, .advanced:
            return .settings
        }
    }

    var title: String {
        switch self {
        case .fileTypes:
            return "File Types"
        case .defaultOpeners:
            return "Default Openers"
        case .verifySamples:
            return "Verify Samples"
        case .presets:
            return "Presets"
        case .general:
            return "General"
        case .advanced:
            return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .fileTypes:
            return "Markdown, text, source"
        case .defaultOpeners:
            return "External app routing"
        case .verifySamples:
            return "Check sample files"
        case .presets:
            return "Import and export"
        case .general:
            return "Backend and Neovim"
        case .advanced:
            return "Custom command"
        }
    }

    var systemImage: String {
        switch self {
        case .fileTypes:
            return "doc.on.doc"
        case .defaultOpeners:
            return "app.badge"
        case .verifySamples:
            return "checkmark.seal"
        case .presets:
            return "square.and.arrow.up.on.square"
        case .general:
            return "rectangle.terminal"
        case .advanced:
            return "slider.horizontal.3"
        }
    }
}

struct TrimControlWindow: View {
    @EnvironmentObject private var appState: AppState
    @SceneStorage("trimcontrol.selectedGroupID") private var selectedGroupID = FileTypeGroupID.markdownVault.rawValue
    @SceneStorage("trimcontrol.sidebarDestination") private var selectedDestinationID = SidebarDestination.fileTypes.rawValue

    private var selectedGroup: FileTypeGroup {
        appState.groups.first { $0.id.rawValue == selectedGroupID } ?? appState.groups[0]
    }

    private var selectedDestination: Binding<SidebarDestination> {
        Binding(
            get: { SidebarDestination(rawValue: selectedDestinationID) ?? .fileTypes },
            set: { selectedDestinationID = $0.rawValue }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(selection: selectedDestination, selectedGroup: selectedGroup)
                .frame(width: 236)

            Rectangle()
                .fill(TrimTokens.Colors.strokeSubtle.opacity(0.72))
                .frame(width: 1)

            Group {
                switch selectedDestination.wrappedValue {
                case .fileTypes:
                    FileTypesWorkspace(selectedGroupID: $selectedGroupID)
                case .defaultOpeners:
                    DefaultOpenersView()
                case .verifySamples:
                    VerifySamplesWorkspace()
                case .presets:
                    PresetsWorkspace()
                case .general:
                    TerminalBackendSurface()
                case .advanced:
                    AdvancedSettingsWorkspace()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(TrimTokens.Colors.background.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                if selectedDestination.wrappedValue == .fileTypes {
                    ModeSegmentedControl(
                        selectedGroupID: $selectedGroupID,
                        groups: appState.groups
                    )
                    .frame(width: 320)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                primaryToolbarActions
            }
        }
        .onChange(of: appState.pendingNavigationDestination) { _, newValue in
            guard let newValue,
                let destination = SidebarDestination(rawValue: newValue) else {
                return
            }

            withAnimation(TrimTokens.Motion.normal) {
                selectedDestinationID = destination.rawValue
            }

            appState.pendingNavigationDestination = nil
        }
    }

    @ViewBuilder
    private var primaryToolbarActions: some View {
        switch selectedDestination.wrappedValue {
        case .fileTypes:
            Button {
                appState.refreshStatus()
            } label: {
                Label("Refresh status", systemImage: "arrow.clockwise")
            }
            .help("Refresh LaunchServices status")
        case .defaultOpeners:
            Button(role: .destructive) {
                appState.resetAllExternalOpeners()
            } label: {
                Label("Reset all", systemImage: "arrow.counterclockwise")
            }
            .help("Reset all openers to system defaults")
        case .verifySamples:
            Button {
                appState.verifySamples()
            } label: {
                Label("Verify samples", systemImage: "checkmark.seal")
            }
            .help("Verify representative file extensions")
            .disabled(appState.isWorking)
        case .presets:
            Button {
                appState.importPreset()
            } label: {
                Label("Import preset", systemImage: "square.and.arrow.down")
            }
            .help("Import a TrimControl preset")
            .disabled(appState.isWorking)

            Button {
                appState.exportPreset()
            } label: {
                Label("Export preset", systemImage: "square.and.arrow.up")
            }
            .help("Export a TrimControl preset")
            .disabled(appState.isWorking)
        case .general, .advanced:
            Button {
                appState.openTestFile()
            } label: {
                Label("Open test file", systemImage: "play.rectangle")
            }
            .help("Open a temporary test file with the selected terminal backend")
            .disabled(appState.isWorking)
        }
    }
}

private struct AppSidebar: View {
    @EnvironmentObject private var appState: AppState

    @Binding var selection: SidebarDestination
    let selectedGroup: FileTypeGroup

    var body: some View {
        VStack(alignment: .leading, spacing: TrimTokens.Spacing.lg) {
            appIdentity

            SidebarStatusPanel()

            VStack(alignment: .leading, spacing: TrimTokens.Spacing.sm) {
                ForEach(SidebarGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: TrimTokens.Spacing.xs) {
                        SectionLabel(title: group.title)

                        ForEach(SidebarDestination.allCases.filter { $0.group == group }) { destination in
                            SidebarNavigationRow(
                                destination: destination,
                                isSelected: selection == destination
                            ) {
                                withAnimation(TrimTokens.Motion.normal) {
                                    selection = destination
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: TrimTokens.Spacing.md)

            HStack(spacing: TrimTokens.Spacing.sm) {
                ToolbarIconButton(systemImage: "questionmark.circle", help: "Show project help") {
                    appState.lastMessage = "Project docs live in README.md."
                }

                ToolbarIconButton(systemImage: "gearshape", help: "Open Settings") {
                    withAnimation(TrimTokens.Motion.normal) {
                        selection = .general
                    }
                }

                Spacer()

                StatusDot(color: appState.isWorking ? TrimTokens.Colors.warning : TrimTokens.Colors.success)
                    .help(appState.isWorking ? "Working" : "Ready")
            }
        }
        .padding(.top, 22)
        .padding(.horizontal, TrimTokens.Spacing.lg)
        .padding(.bottom, TrimTokens.Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var appIdentity: some View {
        HStack(spacing: TrimTokens.Spacing.sm) {
            SidebarAppIcon(size: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text("TrimControl")
                    .font(TrimTokens.Typography.headline)
                    .foregroundStyle(TrimTokens.Colors.textPrimary)

                Text("Native defaults utility")
                    .font(TrimTokens.Typography.caption)
                    .foregroundStyle(TrimTokens.Colors.textTertiary)
            }
        }
    }
}

private struct SidebarAppIcon: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            } else {
                Image(systemName: "text.alignleft")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(TrimTokens.Colors.accentHover)
            }
        }
        .frame(width: size, height: size)
        .background {
            RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                .fill(TrimTokens.Colors.surfaceTertiary.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                        .stroke(TrimTokens.Colors.strokeFocused.opacity(0.45), lineWidth: 1)
                }
        }
        .help("TrimControl")
    }

    private var appIcon: NSImage? {
        if let resourceURL = Bundle.main.url(forResource: "TrimControl", withExtension: "icns") {
            return NSImage(contentsOf: resourceURL)
        }

        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }
}

private struct SidebarStatusPanel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: TrimTokens.Spacing.xs) {
            HStack(spacing: TrimTokens.Spacing.xs) {
                StatusDot(color: appState.isWorking ? TrimTokens.Colors.warning : TrimTokens.Colors.success)

                Text(appState.selectedTerminalBackendDisplayName)
                    .font(TrimTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(TrimTokens.Colors.textPrimary)
                    .lineLimit(1)
            }

            Text(appState.neovimPath)
                .font(TrimTokens.Typography.mono)
                .foregroundStyle(TrimTokens.Colors.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, TrimTokens.Spacing.sm)
        .padding(.horizontal, TrimTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                .fill(TrimTokens.Colors.surfaceSecondary.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                        .stroke(TrimTokens.Colors.strokeSubtle, lineWidth: 1)
                }
        }
    }
}

private struct SidebarNavigationRow: View {
    let destination: SidebarDestination
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: TrimTokens.Spacing.sm) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? TrimTokens.Colors.accentHover : TrimTokens.Colors.textSecondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.title)
                        .font(TrimTokens.Typography.headline)
                        .foregroundStyle(TrimTokens.Colors.textPrimary)

                    Text(destination.subtitle)
                        .font(TrimTokens.Typography.caption)
                        .foregroundStyle(TrimTokens.Colors.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, TrimTokens.Spacing.sm)
            .padding(.vertical, TrimTokens.Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(alignment: .leading) {
                        if isSelected {
                            Capsule()
                                .fill(TrimTokens.Colors.accentHover)
                                .frame(width: 3)
                                .padding(.vertical, 7)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(TrimTokens.Motion.fast) {
                isHovering = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return TrimTokens.Colors.accentSoft.opacity(0.92)
        }

        return isHovering ? TrimTokens.Colors.surfaceSecondary.opacity(0.72) : .clear
    }
}
