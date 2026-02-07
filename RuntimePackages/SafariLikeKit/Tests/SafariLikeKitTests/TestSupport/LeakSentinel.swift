import XCTest

@MainActor
final class LeakSentinel {
    private final class WeakBox {
        weak var value: AnyObject?
        let typeName: String
        let note: String?

        init(_ value: AnyObject, typeName: String, note: String?) {
            self.value = value
            self.typeName = typeName
            self.note = note
        }
    }

    private var boxes: [WeakBox] = []

    func track(_ object: AnyObject, note: String? = nil) {
        boxes.append(WeakBox(object, typeName: String(describing: type(of: object)), note: note))
    }

    func assertDeallocatedEventually(
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            autoreleasepool { }
            if boxes.allSatisfy({ $0.value == nil }) {
                return
            }
            await Task.yield()
        }

        autoreleasepool { }
        for box in boxes {
            if let stillAlive = box.value {
                let note = box.note.map { " (\($0))" } ?? ""
                XCTFail("LeakSentinel: expected deallocation of \(box.typeName)\(note), but it is still alive: \(stillAlive)", file: file, line: line)
            }
        }
    }
}
