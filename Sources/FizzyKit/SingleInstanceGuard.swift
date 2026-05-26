import AppKit

public enum SingleInstanceGuard {
    public static let activateNotificationName = NSNotification.Name("xyz.cosense.fizzy.activate")

    public static func shouldExit(bundleId: String?, otherInstanceCount: Int) -> Bool {
        guard bundleId != nil else { return false }
        return otherInstanceCount > 0
    }

    public static func enforceSingleInstance() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard shouldExit(bundleId: bundleId, otherInstanceCount: others.count) else { return }
        DistributedNotificationCenter.default().postNotificationName(
            activateNotificationName, object: nil, userInfo: nil,
            deliverImmediately: true
        )
        exit(0)
    }
}
