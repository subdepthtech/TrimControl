import Foundation

public enum DefaultStatus: String, Codable, Sendable {
    case all
    case partial
    case none

    public var label: String {
        switch self {
        case .all:
            return "All defaulted"
        case .partial:
            return "Partial"
        case .none:
            return "Not defaulted"
        }
    }
}

public struct GroupDefaultStatus: Identifiable, Hashable, Sendable {
    public let groupID: FileTypeGroupID
    public let matchedCount: Int
    public let totalCount: Int

    public var id: FileTypeGroupID { groupID }

    public var status: DefaultStatus {
        if matchedCount == totalCount {
            return .all
        }

        if matchedCount == 0 {
            return .none
        }

        return .partial
    }
}

public struct DefaultOperationResult: Hashable, Sendable {
    public let contentType: String
    public let status: OSStatus
    public let previousHandler: String?
    public let newHandler: String?

    public var succeeded: Bool {
        status == noErr
    }
}

public struct ExtensionVerification: Hashable, Sendable {
    public let extensionName: String
    public let resolvedAppPath: String?
    public let expectedAppPath: String

    public var matchesExpectedApp: Bool {
        guard let resolvedAppPath else {
            return false
        }

        return URL(fileURLWithPath: resolvedAppPath).standardizedFileURL.path
            == URL(fileURLWithPath: expectedAppPath).standardizedFileURL.path
    }
}
