import XCTest

final class ForbiddenPatternsTests: XCTestCase {
  func testNoForbiddenPatternsPresent() throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: fm.currentDirectoryPath)

    let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil)!
    var violations: [String] = []

    let forbiddenPatterns = [
      "UserDefaults\\.synchronize\\(\\)",
      "try\\?\\s+context\\.save\\(",
      "try\\?\\s+modelContext\\.save\\(",  // catch try? modelContext.save()
      "\\bLinearGradient\\b",
      "\\bRadialGradient\\b",
      "\\bAngularGradient\\b",
      "\\bMeshGradientView\\b"
    ]

    while let file = enumerator.nextObject() as? String {
      guard file.hasSuffix(".swift") else { continue }
      // ignore tests
      if file.contains("Tests") { continue }

      let path = root.appendingPathComponent(file)
      if let content = try? String(contentsOf: path) {
        for pat in forbiddenPatterns {
          if content.range(of: pat, options: .regularExpression) != nil {
            violations.append("\(file): \(pat)")
          }
        }
      }
    }

    XCTAssertTrue(violations.isEmpty, "Found forbidden patterns: \(violations.joined(separator: ", "))")
  }
}
