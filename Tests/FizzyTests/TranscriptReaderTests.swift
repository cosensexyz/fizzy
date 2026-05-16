import XCTest
@testable import FizzyKit

final class TranscriptReaderTests: XCTestCase {
    private var tmpFile: URL!

    override func setUp() {
        super.setUp()
        tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("fizzy-test-\(UUID().uuidString).jsonl")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpFile)
        super.tearDown()
    }

    private func write(_ lines: [String]) {
        let data = lines.joined(separator: "\n").data(using: .utf8)!
        FileManager.default.createFile(atPath: tmpFile.path, contents: data)
    }

    func testExtractsLastAssistantMessage() {
        write([
            #"{"type":"human","message":{"content":[{"type":"text","text":"hello"}]}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"first reply"}]}}"#,
            #"{"type":"human","message":{"content":[{"type":"text","text":"thanks"}]}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"second reply"}]}}"#,
        ])

        let result = TranscriptReader.lastAssistantMessage(at: tmpFile.path)
        XCTAssertEqual(result, "second reply")
    }

    func testReturnsNilForEmptyFile() {
        write([])
        let result = TranscriptReader.lastAssistantMessage(at: tmpFile.path)
        XCTAssertNil(result)
    }

    func testReturnsNilForNonexistentFile() {
        let result = TranscriptReader.lastAssistantMessage(at: "/tmp/does-not-exist-\(UUID()).jsonl")
        XCTAssertNil(result)
    }

    func testReturnsNilWhenNoAssistantMessages() {
        write([
            #"{"type":"human","message":{"content":[{"type":"text","text":"hello"}]}}"#,
        ])
        let result = TranscriptReader.lastAssistantMessage(at: tmpFile.path)
        XCTAssertNil(result)
    }

    func testConcatenatesMultipleTextBlocks() {
        write([
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"part one"},{"type":"tool_use","name":"bash"},{"type":"text","text":"part two"}]}}"#,
        ])
        let result = TranscriptReader.lastAssistantMessage(at: tmpFile.path)
        XCTAssertEqual(result, "part one\npart two")
    }

    func testReturnsFullMessage() {
        let long = String(repeating: "a", count: 2000)
        write([
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"\#(long)"}]}}"#,
        ])
        let result = TranscriptReader.lastAssistantMessage(at: tmpFile.path)
        XCTAssertEqual(result?.count, 2000)
    }

    func testReadsFromLargeFile() {
        let padding = String(repeating: "x", count: TranscriptReader.maxTailBytes)
        write([
            #"{"type":"human","message":{"content":[{"type":"text","text":"\#(padding)"}]}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"found it"}]}}"#,
        ])
        let result = TranscriptReader.lastAssistantMessage(at: tmpFile.path)
        XCTAssertEqual(result, "found it")
    }
}
