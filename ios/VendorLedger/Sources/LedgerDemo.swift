import Foundation
// Release builds cannot enable simulator fixtures or bypass StoreKit.
enum LedgerDemo {
    static var isEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--preview-demo")
        #else
        return false
        #endif
    }
    static var script: String? {
        #if DEBUG
        guard isEnabled,
              let path = Bundle.main.path(forResource:"preview-demo",ofType:"js",inDirectory:"Web"),
              let fixture = try? String(contentsOfFile:path,encoding:.utf8) else { return nil }
        let args = ProcessInfo.processInfo.arguments
        let i = args.firstIndex(of:"--preview-story")
        let story = i.flatMap { args.indices.contains($0+1) ? Int(args[$0+1]) : nil } ?? 1
        return "window.__ledgerPreviewStory = \(min(3,max(1,story)));\n" + fixture
        #else
        return nil
        #endif
    }
}
