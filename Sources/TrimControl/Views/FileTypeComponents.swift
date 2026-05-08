import SwiftUI
import TrimControlCore

struct FileTypesWorkspace: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedGroupID: String

    @FocusState private var focusedChoiceID: String?
    @State private var searchText = ""
    @State private var customExtension = ""

    private var selectedGroup: FileTypeGroup {
        appState.groups.first { $0.id.rawValue == selectedGroupID } ?? appState.groups[0]
    }

    private var filteredChoices: [FileTypeChoice] {
        let choices = appState.choices(in: selectedGroup)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return choices
        }

        return choices.filter { choice in
            choice.title.lowercased().contains(query)
                || choice.displayExtensions.lowercased().contains(query)
                || choice.extensions.contains { $0.lowercased().contains(query) }
                || choice.contentTypes.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            FileTypeHeader(selectedGroup: selectedGroup)

            FileTypeToolbar(
                group: selectedGroup,
                searchText: $searchText,
                customExtension: $customExtension,
                addExtension: addCustomExtension
            )
            .disabled(appState.isWorking)

            Divider()
                .overlay(TrimTokens.Colors.strokeSubtle)

            FileTypeList(
                group: selectedGroup,
                choices: filteredChoices,
                focusedChoiceID: $focusedChoiceID
            )
            .focusedValue(
                \.fileTypeCommandContext,
                FileTypeCommandContext(
                    selectAll: { appState.selectAll(in: selectedGroup) },
                    clearSelection: { appState.clearAll(in: selectedGroup) },
                    toggleFocused: { _ = toggleFocusedChoice() }
                )
            )
            .onMoveCommand(perform: moveFocus)
            .onKeyPress(phases: .down, action: handleKeyPress)

            FooterActionBar()
                .disabled(appState.isWorking)
        }
        .onChange(of: selectedGroupID) { _, _ in
            searchText = ""
            focusedChoiceID = nil
        }
    }

    private func addCustomExtension() {
        appState.addCustomExtension(customExtension, to: selectedGroup)
        customExtension = ""
    }

    private func moveFocus(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            moveFocusedRow(by: -1)
        case .down:
            moveFocusedRow(by: 1)
        default:
            break
        }
    }

    private func moveFocusedRow(by offset: Int) {
        guard !filteredChoices.isEmpty else {
            focusedChoiceID = nil
            return
        }

        guard let currentFocusedChoiceID = focusedChoiceID,
            let currentIndex = filteredChoices.firstIndex(where: { $0.id == currentFocusedChoiceID }) else {
            focusedChoiceID = offset < 0 ? filteredChoices.last?.id : filteredChoices.first?.id
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), filteredChoices.count - 1)
        focusedChoiceID = filteredChoices[nextIndex].id
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        if keyPress.modifiers.contains(.command), keyPress.characters.lowercased() == "a" {
            appState.selectAll(in: selectedGroup)
            return .handled
        }

        guard keyPress.modifiers.isEmpty else {
            return .ignored
        }

        switch keyPress.key {
        case .escape:
            appState.clearAll(in: selectedGroup)
            return .handled
        case .return, .space:
            return toggleFocusedChoice() ? .handled : .ignored
        default:
            return .ignored
        }
    }

    @discardableResult
    private func toggleFocusedChoice() -> Bool {
        guard let choice = focusedChoice else {
            return false
        }

        appState.toggleFileTypeChoice(choice)
        return true
    }

    private var focusedChoice: FileTypeChoice? {
        guard let focusedChoiceID else {
            return nil
        }

        return filteredChoices.first { $0.id == focusedChoiceID }
    }
}

private struct FileTypeHeader: View {
    @EnvironmentObject private var appState: AppState
    let selectedGroup: FileTypeGroup

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: TrimTokens.Spacing.xs) {
                Text("File Types")
                    .font(TrimTokens.Typography.appTitle)
                    .foregroundStyle(TrimTokens.Colors.textPrimary)

                Text(selectedGroup.summary)
                    .font(TrimTokens.Typography.body)
                    .foregroundStyle(TrimTokens.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            SelectionCountLabel(count: appState.selectedFileTypeChoices.count)
        }
        .padding(.horizontal, TrimTokens.Spacing.xxl)
        .padding(.top, TrimTokens.Spacing.xl)
        .padding(.bottom, TrimTokens.Spacing.md)
    }
}

struct ModeSegmentedControl: View {
    @Binding var selectedGroupID: String
    let groups: [FileTypeGroup]

    var body: some View {
        Picker("Mode", selection: $selectedGroupID) {
            ForEach(groups) { group in
                Text(group.shortTitle)
                    .tag(group.id.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
    }
}

private struct SelectionCountLabel: View {
    let count: Int

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.xs) {
            Image(systemName: "checkmark.square")
                .font(.system(size: 11, weight: .semibold))

            Text("\(count) selected")
                .font(TrimTokens.Typography.mono)
        }
        .foregroundStyle(TrimTokens.Colors.textSecondary)
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

struct FileTypeToolbar: View {
    @EnvironmentObject private var appState: AppState
    let group: FileTypeGroup
    @Binding var searchText: String
    @Binding var customExtension: String
    let addExtension: () -> Void

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.md) {
            SearchAddField(
                searchText: $searchText,
                customExtension: $customExtension,
                addExtension: addExtension
            )
            .frame(minWidth: 310, maxWidth: 520)

            Spacer()

            SecondaryButton(action: { appState.selectAll(in: group) }) {
                Label("Select All", systemImage: "checkmark.square")
            }

            SecondaryButton(action: { appState.clearAll(in: group) }) {
                Label("Clear", systemImage: "xmark.square")
            }
        }
        .padding(.horizontal, TrimTokens.Spacing.xxl)
        .padding(.bottom, TrimTokens.Spacing.md)
    }
}

struct SearchAddField: View {
    @Binding var searchText: String
    @Binding var customExtension: String
    let addExtension: () -> Void

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TrimTokens.Colors.textTertiary)

            TextField("Search file types", text: $searchText)
                .textFieldStyle(.plain)
                .font(TrimTokens.Typography.body)

            Rectangle()
                .fill(TrimTokens.Colors.strokeSubtle)
                .frame(width: 1, height: 16)
                .padding(.horizontal, TrimTokens.Spacing.xs)

            TextField("Add extension", text: $customExtension)
                .textFieldStyle(.plain)
                .font(TrimTokens.Typography.mono)
                .onSubmit(addExtension)

            Button(action: addExtension) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(TrimTokens.Colors.accentHover)
            .background {
                RoundedRectangle(cornerRadius: TrimTokens.Radius.sm, style: .continuous)
                    .fill(TrimTokens.Colors.accentSoft)
                    .overlay {
                        RoundedRectangle(cornerRadius: TrimTokens.Radius.sm, style: .continuous)
                            .stroke(TrimTokens.Colors.strokeFocused.opacity(0.5), lineWidth: 1)
                    }
            }
            .help("Add extension")
        }
        .padding(.leading, TrimTokens.Spacing.md)
        .padding(.trailing, TrimTokens.Spacing.xs)
        .frame(height: 32)
        .background {
            RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                .fill(TrimTokens.Colors.surfacePrimary.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                        .stroke(TrimTokens.Colors.strokeSubtle, lineWidth: 1)
                }
        }
    }
}

struct FileTypeList: View {
    @EnvironmentObject private var appState: AppState
    let group: FileTypeGroup
    let choices: [FileTypeChoice]
    let focusedChoiceID: FocusState<String?>.Binding

    var body: some View {
        ScrollView {
            LazyVStack(spacing: TrimTokens.Spacing.sm) {
                if choices.isEmpty {
                    EmptyStateView(searchGroupTitle: group.shortTitle)
                        .padding(.top, 72)
                } else {
                    ForEach(choices) { choice in
                        FileTypeRow(
                            choice: choice,
                            group: group,
                            status: appState.status(for: choice),
                            isSelected: appState.isSelected(choice),
                            focusedChoiceID: focusedChoiceID,
                            toggle: { appState.toggleFileTypeChoice(choice) },
                            remove: { appState.removeCustomFileType(choice) },
                            refresh: { appState.refreshStatus() }
                        )
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

struct FileTypeRow: View {
    let choice: FileTypeChoice
    let group: FileTypeGroup
    let status: DefaultStatus
    let isSelected: Bool
    let focusedChoiceID: FocusState<String?>.Binding
    let toggle: () -> Void
    let remove: () -> Void
    let refresh: () -> Void

    @State private var isHovering = false

    private var isFocused: Bool {
        focusedChoiceID.wrappedValue == choice.id
    }

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.md) {
            Toggle(
                "",
                isOn: Binding(
                    get: { isSelected },
                    set: { _ in toggle() }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()
            .controlSize(.small)
            .help(isSelected ? "Included in defaults" : "Excluded from defaults")

            HStack(spacing: TrimTokens.Spacing.md) {
                IconTile(
                    systemImage: symbolName,
                    isSelected: isSelected || isFocused,
                    size: 34
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: TrimTokens.Spacing.sm) {
                        Text(choice.title)
                            .font(TrimTokens.Typography.headline)
                            .foregroundStyle(TrimTokens.Colors.textPrimary)
                            .lineLimit(1)

                        if choice.isCustom {
                            Text("Custom")
                                .font(TrimTokens.Typography.caption.weight(.medium))
                                .foregroundStyle(TrimTokens.Colors.accentHover)
                                .padding(.horizontal, TrimTokens.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(TrimTokens.Colors.accentSoft, in: Capsule())
                        }
                    }

                    HStack(spacing: TrimTokens.Spacing.xs) {
                        ForEach(extensionTags.prefix(3), id: \.self) { item in
                            ExtensionTag(text: item)
                        }

                        if extensionTags.count > 3 {
                            Text("+\(extensionTags.count - 3)")
                                .font(TrimTokens.Typography.mono)
                                .foregroundStyle(TrimTokens.Colors.textTertiary)
                        }

                        Text(shortDescription)
                            .font(TrimTokens.Typography.caption)
                            .foregroundStyle(TrimTokens.Colors.textTertiary)
                            .lineLimit(1)
                            .padding(.leading, TrimTokens.Spacing.xs)
                    }
                }

                Spacer(minLength: TrimTokens.Spacing.lg)

                StatusChip(status: status)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: toggleFromRow)

            Menu {
                Button(isSelected ? "Exclude from defaults" : "Include in defaults", action: toggle)

                if choice.isCustom {
                    Button(role: .destructive, action: remove) {
                        Label("Remove custom extension", systemImage: "minus.circle")
                    }
                }

                Divider()

                Button(action: refresh) {
                    Label("Refresh status", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(TrimTokens.Colors.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .opacity(isHovering || isSelected || isFocused ? 1 : 0.65)
            .help("More actions")
        }
        .padding(.horizontal, TrimTokens.Spacing.md)
        .frame(minHeight: TrimTokens.Heights.row)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous))
        .focusable()
        .focused(focusedChoiceID, equals: choice.id)
        .onHover { hovering in
            withAnimation(TrimTokens.Motion.fast) {
                isHovering = hovering
            }
        }
        .opacity(isSelected ? 1 : 0.78)
        .animation(TrimTokens.Motion.normal, value: isSelected)
        .animation(TrimTokens.Motion.fast, value: isHovering)
        .animation(TrimTokens.Motion.normal, value: isFocused)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(choice.title), \(choice.displayExtensions), \(status.label)")
        .accessibilityValue(isSelected ? "Included in defaults" : "Excluded from defaults")
    }

    private func toggleFromRow() {
        focusedChoiceID.wrappedValue = choice.id
        toggle()
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
            .fill(fillColor)
            .overlay {
                RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused ? 1.5 : 1)
            }
    }

    private var fillColor: Color {
        if isSelected {
            return TrimTokens.Colors.accentSoft.opacity(0.6)
        }

        if isHovering {
            return TrimTokens.Colors.surfaceSecondary
        }

        return TrimTokens.Colors.surfacePrimary
    }

    private var borderColor: Color {
        if isFocused {
            return TrimTokens.Colors.accentHover
        }

        if isSelected {
            return TrimTokens.Colors.strokeFocused.opacity(0.45)
        }

        return TrimTokens.Colors.strokeSubtle
    }

    private var extensionTags: [String] {
        choice.extensions.isEmpty ? ["UTI"] : choice.extensions.map { ".\($0)" }
    }

    private var shortDescription: String {
        if choice.isCustom {
            return "User-defined extension saved in preferences"
        }

        if choice.id.hasPrefix("com.subdepthtech.trimcontrol") {
            return "TrimControl-owned companion type"
        }

        if choice.contentTypes.count > 1 {
            return "\(choice.contentTypes.count) LaunchServices identifiers"
        }

        return group.shortTitle == "Source" ? "System source-code type" : "System content type"
    }

    private var symbolName: String {
        let title = choice.title.lowercased()
        let extensions = Set(choice.extensions.map { $0.lowercased() })

        if choice.isCustom {
            return "plus.rectangle.on.folder"
        }

        if title.contains("alias") {
            return "doc.on.doc"
        }
        if title.contains("mdx") {
            return "cube.transparent"
        }
        if title.contains("quarto") {
            return "q.circle"
        }
        if title.contains("r markdown") || title == "r source" {
            return "r.circle"
        }
        if extensions.contains("prompt") {
            return "quote.bubble"
        }
        if extensions.contains("plan") {
            return "checklist"
        }
        if extensions.contains("todo") {
            return "checkmark.square"
        }
        if extensions.contains("prd") {
            return "doc.badge.gearshape"
        }
        if extensions.contains("runbook") {
            return "book.pages"
        }
        if extensions.contains("sop") {
            return "shield.checkered"
        }
        if extensions.contains("spec") {
            return "chevron.left.forwardslash.chevron.right"
        }
        if extensions.contains("dashboard") {
            return "chart.bar.doc.horizontal"
        }
        if group.id == .textConfigData {
            return "curlybraces"
        }
        if group.id == .scriptsSource {
            return "chevron.left.forwardslash.chevron.right"
        }

        return "doc.plaintext"
    }
}

struct StatusChip: View {
    let status: DefaultStatus

    var body: some View {
        TrimStatusChip(tone: tone, label: status.label, systemImage: systemImage)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            ))
            .animation(TrimTokens.Motion.fast, value: status)
    }

    private var systemImage: String {
        switch status {
        case .all:
            return "checkmark.circle.fill"
        case .partial:
            return "circle.lefthalf.filled"
        case .none:
            return "circle"
        }
    }

    private var tone: TrimStatusTone {
        switch status {
        case .all:
            return .success
        case .partial:
            return .warning
        case .none:
            return .neutral
        }
    }
}

struct ExtensionTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(TrimTokens.Typography.mono)
            .foregroundStyle(TrimTokens.Colors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, TrimTokens.Spacing.xs)
            .frame(height: 20)
            .background {
                RoundedRectangle(cornerRadius: TrimTokens.Radius.sm, style: .continuous)
                    .fill(TrimTokens.Colors.surfaceTertiary.opacity(0.8))
                    .overlay {
                        RoundedRectangle(cornerRadius: TrimTokens.Radius.sm, style: .continuous)
                            .stroke(TrimTokens.Colors.strokeSubtle.opacity(0.8), lineWidth: 1)
                    }
            }
    }
}

struct IconTile: View {
    let systemImage: String
    var nsImage: NSImage?
    var isSelected = false
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.15)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? TrimTokens.Colors.accentHover : TrimTokens.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .background {
            RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                .fill(isSelected ? TrimTokens.Colors.accentSoft : TrimTokens.Colors.surfaceTertiary)
                .overlay {
                    RoundedRectangle(cornerRadius: TrimTokens.Radius.md, style: .continuous)
                        .stroke(
                            isSelected
                                ? TrimTokens.Colors.strokeFocused.opacity(0.45)
                                : TrimTokens.Colors.strokeSubtle,
                            lineWidth: 1
                        )
                }
        }
    }
}

struct FooterActionBar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(TrimTokens.Colors.strokeSubtle)

            HStack(spacing: TrimTokens.Spacing.md) {
                PrimaryButton(action: appState.applyAllDefaults) {
                    Label("Apply all defaults", systemImage: "sparkle")
                }

                SecondaryButton(action: appState.applySelectedDefaults) {
                    Label("Apply selected", systemImage: "checkmark.circle")
                }

                SecondaryButton(role: .destructive, action: appState.removeSelectedDefaults) {
                    Label("Remove selected", systemImage: "minus.circle")
                }

                Menu {
                    Button {
                        appState.verifySamples()
                    } label: {
                        Label("Verify samples", systemImage: "checkmark.seal")
                    }

                    Button {
                        appState.openTestFile()
                    } label: {
                        Label("Open test file", systemImage: "play.rectangle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: TrimTokens.Heights.control, height: TrimTokens.Heights.control)
                        .foregroundStyle(TrimTokens.Colors.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("More actions")
                .accessibilityLabel("More actions")

                Spacer(minLength: TrimTokens.Spacing.lg)

                HStack(spacing: TrimTokens.Spacing.xs) {
                    StatusDot(color: appState.isWorking ? TrimTokens.Colors.warning : TrimTokens.Colors.success)

                    Text(appState.lastMessage)
                        .font(TrimTokens.Typography.caption)
                        .foregroundStyle(TrimTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .frame(maxWidth: 260, alignment: .leading)
                }

                ToolbarIconButton(systemImage: "arrow.clockwise", help: "Refresh LaunchServices status") {
                    appState.refreshStatus()
                }
            }
            .padding(.horizontal, TrimTokens.Spacing.xxl)
            .frame(height: TrimTokens.Heights.footer)
            .background(.regularMaterial)
        }
    }
}

struct EmptyStateView: View {
    let searchGroupTitle: String

    var body: some View {
        VStack(spacing: TrimTokens.Spacing.md) {
            IconTile(systemImage: "magnifyingglass", isSelected: true, size: 42)

            VStack(spacing: TrimTokens.Spacing.xs) {
                Text("No matching file types")
                    .font(TrimTokens.Typography.headline)
                    .foregroundStyle(TrimTokens.Colors.textPrimary)

                Text("Adjust the search or add a custom extension for \(searchGroupTitle).")
                    .font(TrimTokens.Typography.body)
                    .foregroundStyle(TrimTokens.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
