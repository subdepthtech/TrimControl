import SwiftUI
import TrimControlCore

struct VerifySamplesWorkspace: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        UtilityWorkspace {
            UtilityHeader(
                title: "Verify Samples",
                subtitle: "Check representative file extensions against the current TrimControl bundle."
            )

            UtilityPanel {
                VStack(alignment: .leading, spacing: TrimTokens.Spacing.md) {
                    UtilityMessageStrip(message: appState.lastMessage)

                    VStack(spacing: TrimTokens.Spacing.sm) {
                        ForEach(appState.groups) { group in
                            let status = appState.groupStatuses[group.id]
                            UtilityStatusRow(
                                systemImage: group.systemImage,
                                title: group.title,
                                detail: status.map { "\($0.matchedCount)/\($0.totalCount) content types defaulted" }
                                    ?? "Status not loaded",
                                status: status?.status ?? .none
                            )
                        }
                    }
                }
            }
        }
        .disabled(appState.isWorking)
    }
}

struct PresetsWorkspace: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        UtilityWorkspace {
            UtilityHeader(
                title: "Presets",
                subtitle: "Import or export File Types selections and custom extensions."
            )

            UtilityPanel {
                VStack(alignment: .leading, spacing: TrimTokens.Spacing.md) {
                    HStack(spacing: TrimTokens.Spacing.md) {
                        PresetMetric(title: "Selected file types", value: "\(appState.selectedFileTypeChoices.count)")
                        PresetMetric(title: "Custom extensions", value: "\(appState.customFileTypes.count)")
                        PresetMetric(title: "External opener rules", value: "\(appState.externalOpenerRules.count)")
                    }

                    Divider()
                        .overlay(TrimTokens.Colors.strokeSubtle)

                    UtilityMessageStrip(message: appState.lastMessage)
                }
            }
        }
        .disabled(appState.isWorking)
    }
}

struct AdvancedSettingsWorkspace: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        UtilityWorkspace {
            UtilityHeader(
                title: "Advanced",
                subtitle: "Custom Command backend details and local launcher preset."
            )

            UtilityPanel {
                VStack(alignment: .leading, spacing: TrimTokens.Spacing.md) {
                    UtilityStatusRow(
                        systemImage: TerminalBackendID.customCommand.systemImage,
                        title: appState.customCommandName.isEmpty ? "Custom Command" : appState.customCommandName,
                        detail: appState.customCommandExecutablePath.isEmpty
                            ? "No executable selected"
                            : appState.customCommandExecutablePath,
                        status: appState.selectedTerminalBackendID == .customCommand ? .all : .none
                    )

                    VStack(alignment: .leading, spacing: TrimTokens.Spacing.xs) {
                        SectionLabel(title: "Arguments")

                        if appState.customCommandArguments.isEmpty {
                            Text("No arguments configured")
                                .font(TrimTokens.Typography.caption)
                                .foregroundStyle(TrimTokens.Colors.textTertiary)
                        } else {
                            HStack(spacing: TrimTokens.Spacing.xs) {
                                ForEach(Array(appState.customCommandArguments.enumerated()), id: \.offset) { _, argument in
                                    ExtensionTag(text: argument.isEmpty ? "empty" : argument)
                                }
                            }
                        }
                    }

                    UtilityMessageStrip(message: appState.lastMessage)
                }
            }
        }
        .disabled(appState.isWorking)
    }
}

private struct UtilityWorkspace<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrimTokens.Spacing.lg) {
                content()
            }
            .padding(TrimTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollContentBackground(.hidden)
    }
}

private struct UtilityHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: TrimTokens.Spacing.xs) {
            Text(title)
                .font(TrimTokens.Typography.appTitle)
                .foregroundStyle(TrimTokens.Colors.textPrimary)

            Text(subtitle)
                .font(TrimTokens.Typography.body)
                .foregroundStyle(TrimTokens.Colors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UtilityPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(TrimTokens.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: TrimTokens.Radius.lg, style: .continuous)
                    .fill(TrimTokens.Colors.surfacePrimary)
                    .overlay {
                        RoundedRectangle(cornerRadius: TrimTokens.Radius.lg, style: .continuous)
                            .stroke(TrimTokens.Colors.strokeSubtle, lineWidth: 1)
                    }
            }
    }
}

private struct UtilityStatusRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let status: DefaultStatus

    var body: some View {
        HStack(spacing: TrimTokens.Spacing.md) {
            IconTile(systemImage: systemImage, isSelected: status == .all, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(TrimTokens.Typography.headline)
                    .foregroundStyle(TrimTokens.Colors.textPrimary)

                Text(detail)
                    .font(TrimTokens.Typography.caption)
                    .foregroundStyle(TrimTokens.Colors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            StatusChip(status: status)
        }
        .padding(.horizontal, TrimTokens.Spacing.md)
        .frame(minHeight: TrimTokens.Heights.row)
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

private struct UtilityMessageStrip: View {
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

private struct PresetMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: TrimTokens.Spacing.xs) {
            Text(title)
                .font(TrimTokens.Typography.caption)
                .foregroundStyle(TrimTokens.Colors.textTertiary)

            Text(value)
                .font(TrimTokens.Typography.appTitle)
                .foregroundStyle(TrimTokens.Colors.textPrimary)
        }
        .padding(TrimTokens.Spacing.md)
        .frame(minWidth: 150, alignment: .leading)
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
