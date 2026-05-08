import SwiftUI
import TrimControlCore

struct TerminalBackendSurface: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCustomCommandExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrimTokens.Spacing.lg) {
                TerminalBackendHeader(
                    selectedBackendName: appState.selectedTerminalBackendDisplayName,
                    neovimPath: appState.neovimPath,
                    statusTitle: appState.isWorking ? "Working" : "Ready",
                    statusColor: appState.isWorking ? TrimTokens.Colors.warning : TrimTokens.Colors.success
                )

                TerminalBackendSelectionGrid(selectedBackendID: appState.selectedTerminalBackendID) { backendID in
                    appState.selectTerminalBackend(backendID)
                }

                NeovimPathCard(
                    path: Binding(
                        get: { appState.neovimPath },
                        set: { appState.setNeovimPath($0) }
                    ),
                    onChoose: appState.chooseNeovim
                )

                CustomCommandCard(isExpanded: $isCustomCommandExpanded)
                    .environmentObject(appState)

                TerminalMessageStrip(message: appState.lastMessage)
            }
            .padding(TrimTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            isCustomCommandExpanded = appState.selectedTerminalBackendID == .customCommand
                || !appState.customCommandExecutablePath.isEmpty
                || !appState.customCommandArguments.isEmpty
        }
        .onChange(of: appState.selectedTerminalBackendID) { _, backendID in
            if backendID == .customCommand {
                withAnimation(TrimTokens.Motion.normal) {
                    isCustomCommandExpanded = true
                }
            }
        }
    }
}

private struct TerminalBackendHeader: View {
    let selectedBackendName: String
    let neovimPath: String
    let statusTitle: String
    let statusColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: TrimTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: TrimTokens.Spacing.sm) {
                SectionLabel(title: "Terminal Backend")

                HStack(spacing: TrimTokens.Spacing.sm) {
                    Image(systemName: "rectangle.terminal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(TrimTokens.Colors.accent)
                        .frame(width: 30, height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                                .fill(TrimTokens.Colors.accentSoft)
                                .overlay {
                                    RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                                        .stroke(TrimTokens.Colors.strokeFocused.opacity(0.45), lineWidth: 1)
                                }
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedBackendName)
                            .font(TrimTokens.Typography.headline)
                            .foregroundStyle(TrimTokens.Colors.textPrimary)

                        Text(neovimPath)
                            .font(TrimTokens.Typography.mono)
                            .foregroundStyle(TrimTokens.Colors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Spacer(minLength: TrimTokens.Spacing.lg)

            TerminalStatusChip(title: statusTitle, color: statusColor)
        }
    }
}

private struct TerminalMessageStrip: View {
    let message: String

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.sm) {
            StatusDot()

            Text(message)
                .font(TrimTokens.Typography.caption)
                .foregroundStyle(TrimTokens.Colors.textSecondary)
                .lineLimit(2)
                .textSelection(.enabled)

            Spacer(minLength: TrimTokens.Spacing.md)
        }
        .padding(.vertical, TrimTokens.Spacing.sm)
        .padding(.horizontal, TrimTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                .fill(TrimTokens.Colors.surfaceSecondary.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                        .stroke(TrimTokens.Colors.strokeSubtle, lineWidth: 1)
                }
        }
    }
}

private struct TerminalBackendSelectionGrid: View {
    let selectedBackendID: TerminalBackendID
    let onSelect: (TerminalBackendID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 210), spacing: TrimTokens.Spacing.sm, alignment: .top),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: TrimTokens.Spacing.sm) {
            HStack {
                SectionLabel(title: "Built-in Terminals")

                Spacer()

                Text(selectionSummary)
                    .font(TrimTokens.Typography.caption)
                    .foregroundStyle(TrimTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: TrimTokens.Spacing.sm) {
                ForEach(TerminalBackendID.builtInBackends) { backend in
                    TerminalBackendOptionCard(
                        backend: backend,
                        isSelected: selectedBackendID == backend
                    ) {
                        onSelect(backend)
                    }
                }
            }
        }
    }

    private var selectionSummary: String {
        selectedBackendID == .customCommand ? "Custom command selected" : "Direct backend selected"
    }
}

private struct TerminalBackendOptionCard: View {
    let backend: TerminalBackendID
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: TrimTokens.Spacing.sm) {
                IconTile(systemImage: backend.systemImage, isSelected: isSelected || isHovering, size: 30)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: TrimTokens.Spacing.xs) {
                        Text(backend.displayName)
                            .font(TrimTokens.Typography.headline)
                            .foregroundStyle(TrimTokens.Colors.textPrimary)
                            .lineLimit(1)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(TrimTokens.Colors.accentHover)
                        }
                    }

                    Text(backend.shortDescription)
                        .font(TrimTokens.Typography.caption)
                        .foregroundStyle(TrimTokens.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(cardBackground)
            .contentShape(RoundedRectangle(cornerRadius: TrimTokens.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(backend.displayName)
        .onHover { hovering in
            withAnimation(TrimTokens.Motion.fast) {
                isHovering = hovering
            }
        }
        .animation(TrimTokens.Motion.normal, value: isSelected)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: TrimTokens.Radius.lg, style: .continuous)
            .fill(
                isSelected
                    ? TrimTokens.Colors.accentSoft
                    : (isHovering ? TrimTokens.Colors.surfaceTertiary : TrimTokens.Colors.surfaceSecondary)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TrimTokens.Radius.lg, style: .continuous)
                    .stroke(
                        isSelected
                            ? TrimTokens.Colors.strokeFocused.opacity(0.85)
                            : (isHovering ? TrimTokens.Colors.strokeFocused.opacity(0.35) : TrimTokens.Colors.strokeSubtle),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
    }
}

private struct NeovimPathCard: View {
    @Binding var path: String
    let onChoose: () -> Void

    var body: some View {
        TerminalPanel {
            VStack(alignment: .leading, spacing: TrimTokens.Spacing.sm) {
                HStack {
                    SectionLabel(title: "Neovim")

                    Spacer()

                    Text("Executable")
                        .font(TrimTokens.Typography.caption)
                        .foregroundStyle(TrimTokens.Colors.textTertiary)
                }

                HStack(spacing: TrimTokens.Spacing.sm) {
                    TokenTextField(
                        placeholder: "Neovim path",
                        text: $path,
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        monospaced: true
                    )

                    SecondaryButton(action: onChoose) {
                        Label("Choose", systemImage: "folder")
                    }
                    .help("Choose Neovim executable")
                }
            }
        }
    }
}

private struct CustomCommandCard: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isExpanded: Bool

    var body: some View {
        TerminalPanel {
            VStack(alignment: .leading, spacing: TrimTokens.Spacing.md) {
                Button {
                    withAnimation(TrimTokens.Motion.normal) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: TrimTokens.Spacing.sm) {
                        IconTile(
                            systemImage: TerminalBackendID.customCommand.systemImage,
                            isSelected: appState.selectedTerminalBackendID == .customCommand,
                            size: 30
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: TrimTokens.Spacing.sm) {
                                Text("Advanced Custom Command")
                                    .font(TrimTokens.Typography.headline)
                                    .foregroundStyle(TrimTokens.Colors.textPrimary)

                                if appState.selectedTerminalBackendID == .customCommand {
                                    TerminalStatusChip(title: "Selected", color: TrimTokens.Colors.accentHover)
                                }
                            }

                            Text(customCommandSummary)
                                .font(TrimTokens.Typography.caption)
                                .foregroundStyle(TrimTokens.Colors.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(TrimTokens.Colors.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(TrimTokens.Motion.normal, value: isExpanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()
                        .overlay(TrimTokens.Colors.strokeSubtle)

                    CustomCommandEditor()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var customCommandSummary: String {
        let executable = appState.customCommandExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if executable.isEmpty {
            return "Executable path not set"
        }

        return executable
    }
}

private struct CustomCommandEditor: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: TrimTokens.Spacing.md) {
            HStack(spacing: TrimTokens.Spacing.sm) {
                SecondaryButton(action: { appState.selectTerminalBackend(.customCommand) }) {
                    Label("Use Custom Command", systemImage: "checkmark.circle")
                }
                .help("Use the custom command backend")

                SecondaryButton(action: appState.applyTridentCustomCommandPreset) {
                    Label("Trident preset", systemImage: "terminal")
                }
                .help("Load the Trident custom command preset")

                Spacer()

                TerminalStatusChip(
                    title: "\(appState.customCommandArguments.count) args",
                    color: TrimTokens.Colors.textTertiary
                )
            }

            VStack(alignment: .leading, spacing: TrimTokens.Spacing.sm) {
                FieldCaption("Name")
                TokenTextField(
                    placeholder: "Name",
                    text: Binding(
                        get: { appState.customCommandName },
                        set: { appState.setCustomCommandName($0) }
                    ),
                    systemImage: "tag",
                    monospaced: false
                )
            }

            VStack(alignment: .leading, spacing: TrimTokens.Spacing.sm) {
                FieldCaption("Executable Path")

                HStack(spacing: TrimTokens.Spacing.sm) {
                    TokenTextField(
                        placeholder: "Executable path",
                        text: Binding(
                            get: { appState.customCommandExecutablePath },
                            set: { appState.setCustomCommandExecutablePath($0) }
                        ),
                        systemImage: "terminal",
                        monospaced: true
                    )

                    SecondaryButton(action: appState.chooseCustomCommandExecutable) {
                        Label("Choose", systemImage: "folder")
                    }
                    .help("Choose custom command executable")
                }
            }

            CustomCommandArgumentList()

            Text("Placeholders: {nvim}, {files}")
                .font(TrimTokens.Typography.caption)
                .foregroundStyle(TrimTokens.Colors.textTertiary)
                .textSelection(.enabled)
        }
    }
}

private struct CustomCommandArgumentList: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: TrimTokens.Spacing.sm) {
            HStack {
                FieldCaption("Arguments")

                Spacer()

                ToolbarIconButton(
                    systemImage: "plus",
                    help: "Add argument",
                    action: appState.addCustomCommandArgument
                )
            }

            if appState.customCommandArguments.isEmpty {
                EmptyArgumentsView(onAdd: appState.addCustomCommandArgument)
            } else {
                VStack(spacing: TrimTokens.Spacing.xs) {
                    ForEach(Array(appState.customCommandArguments.enumerated()), id: \.offset) { index, _ in
                        CustomCommandArgumentRow(index: index)
                            .environmentObject(appState)
                    }
                }
            }
        }
    }
}

private struct CustomCommandArgumentRow: View {
    @EnvironmentObject private var appState: AppState
    let index: Int

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.sm) {
            Text("\(index + 1)")
                .font(TrimTokens.Typography.mono)
                .foregroundStyle(TrimTokens.Colors.textTertiary)
                .frame(width: 22, alignment: .trailing)

            TokenTextField(
                placeholder: "Argument",
                text: Binding(
                    get: {
                        appState.customCommandArguments.indices.contains(index)
                            ? appState.customCommandArguments[index]
                            : ""
                    },
                    set: { appState.updateCustomCommandArgument(at: index, value: $0) }
                ),
                systemImage: "text.quote",
                monospaced: true
            )

            ToolbarIconButton(
                systemImage: "minus.circle",
                help: "Remove argument",
                action: { appState.removeCustomCommandArgument(at: index) }
            )
        }
    }
}

private struct EmptyArgumentsView: View {
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.md) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TrimTokens.Colors.textTertiary)

            Text("No arguments configured.")
                .font(TrimTokens.Typography.caption)
                .foregroundStyle(TrimTokens.Colors.textSecondary)

            Spacer()

            SecondaryButton(action: onAdd) {
                Label("Add argument", systemImage: "plus")
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                .fill(TrimTokens.Colors.surfaceSecondary.opacity(0.7))
                .overlay {
                    RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                        .stroke(TrimTokens.Colors.strokeSubtle, lineWidth: 1)
                }
        }
    }
}

private struct TokenTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String?
    var monospaced = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isFocused ? TrimTokens.Colors.accentHover : TrimTokens.Colors.textTertiary)
                    .frame(width: 16)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(monospaced ? TrimTokens.Typography.mono : TrimTokens.Typography.body)
                .foregroundStyle(TrimTokens.Colors.textPrimary)
                .focused($isFocused)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(minHeight: TrimTokens.Heights.control)
        .background {
            RoundedRectangle(cornerRadius: TrimTokens.Radius.sm, style: .continuous)
                .fill(TrimTokens.Colors.surfaceSecondary.opacity(isFocused ? 1 : 0.86))
                .overlay {
                    RoundedRectangle(cornerRadius: TrimTokens.Radius.sm, style: .continuous)
                        .stroke(
                            isFocused
                                ? TrimTokens.Colors.strokeFocused.opacity(0.95)
                                : TrimTokens.Colors.strokeSubtle,
                            lineWidth: 1
                        )
                }
        }
        .animation(TrimTokens.Motion.fast, value: isFocused)
    }
}

private struct TerminalPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TrimTokens.Spacing.md) {
            content()
        }
        .padding(TrimTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: TrimTokens.Radius.lg, style: .continuous)
                .fill(TrimTokens.Colors.surfaceSecondary.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: TrimTokens.Radius.lg, style: .continuous)
                        .stroke(TrimTokens.Colors.strokeSubtle, lineWidth: 1)
                }
        }
    }
}

private struct TerminalStatusChip: View {
    let title: String
    let color: Color

    var body: some View {
        TrimStatusChip(tone: tone, label: title, showsDot: true)
    }

    private var tone: TrimStatusTone {
        if color == TrimTokens.Colors.success {
            return .success
        }
        if color == TrimTokens.Colors.warning {
            return .warning
        }
        if color == TrimTokens.Colors.danger {
            return .danger
        }
        if color == TrimTokens.Colors.accentHover || color == TrimTokens.Colors.accent {
            return .accent
        }
        return .neutral
    }
}

private struct FieldCaption: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(TrimTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(TrimTokens.Colors.textSecondary)
    }
}

private extension TerminalBackendID {
    var shortDescription: String {
        switch self {
        case .appleTerminal:
            return "System terminal"
        case .iTerm2:
            return "iTerm session"
        case .ghostty:
            return "Ghostty executable"
        case .wezTerm:
            return "WezTerm start"
        case .alacritty:
            return "Alacritty executable"
        case .customCommand:
            return "Advanced launcher"
        }
    }
}
