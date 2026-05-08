import Foundation

public enum OpenFailureMessage {
    public static func userMessage(for error: Error) -> String {
        "Could not open the selected files. Open Settings to check your terminal backend, Neovim path, and app permissions."
    }

    public static func logMessage(for error: Error) -> String {
        let nsError = error as NSError
        return "TrimControl failed to open selected files (domain \(nsError.domain), code \(nsError.code))."
    }
}
