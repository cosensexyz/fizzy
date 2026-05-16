import Foundation

public enum TranscriptReader {
    static let maxTailBytes = 65_536

    public static func lastAssistantMessage(at path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }

        let fileSize = handle.seekToEndOfFile()
        guard fileSize > 0 else { return nil }

        let readStart = fileSize > UInt64(maxTailBytes) ? fileSize - UInt64(maxTailBytes) : 0
        handle.seek(toFileOffset: readStart)
        var data = handle.availableData
        guard !data.isEmpty else { return nil }

        if readStart > 0, let idx = data.firstIndex(of: 0x0A) {
            data.removeSubrange(data.startIndex...idx)
            guard !data.isEmpty else { return nil }
        }

        guard let tail = String(data: data, encoding: .utf8) else { return nil }

        let lines = tail.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines.reversed() {
            guard let text = extractAssistantText(from: String(line)) else { continue }
            return text
        }
        return nil
    }

    private static func extractAssistantText(from line: String) -> String? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["type"] as? String == "assistant",
              let message = obj["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]]
        else { return nil }

        let texts = content.compactMap { block -> String? in
            guard block["type"] as? String == "text" else { return nil }
            return block["text"] as? String
        }
        guard !texts.isEmpty else { return nil }
        return texts.joined(separator: "\n")
    }
}
