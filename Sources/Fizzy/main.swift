import AppKit
import FizzyKit

SingleInstanceGuard.enforceSingleInstance()

let app = NSApplication.shared
let delegate = FizzyApp()
app.delegate = delegate
app.run()
