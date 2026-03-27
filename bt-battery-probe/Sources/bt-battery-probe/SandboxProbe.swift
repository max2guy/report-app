import Foundation
import IOKit

private func isRunningInSandbox() -> Bool {
    // The most reliable way to check sandbox status on macOS:
    // APP_SANDBOX_CONTAINER_ID is set by the OS when running under App Sandbox
    if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
        return true
    }
    // Secondary check: sandboxed processes have a home directory inside ~/Library/Containers
    let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
    return home.contains("/Library/Containers/")
}

func runSandboxProbe() {
    let sandboxed = isRunningInSandbox()
    print("[Sandbox] Process sandbox status: \(sandboxed ? "SANDBOXED" : "not sandboxed (unsigned/development build)")")

    print("[Sandbox] Running IOKit probe under current sandbox environment...")
    let results = probeIOKit()

    if results.isEmpty {
        print("[Sandbox] IOKit returned 0 devices under current environment")
    } else {
        print("[Sandbox] IOKit returned \(results.count) device(s):")
        for r in results {
            if let pct = r.batteryPercent {
                print("  \(r.product): \(pct)%")
            } else {
                print("  \(r.product): no battery data")
            }
        }
    }

    if sandboxed {
        if results.isEmpty {
            print("[Sandbox] FEAS-02 result: IOKit is BLOCKED under App Sandbox (0 devices returned)")
            print("[Sandbox] D-09 Decision: Notarization + .dmg direct distribution required (App Store NOT viable for IOKit battery reads)")
        } else {
            print("[Sandbox] FEAS-02 result: IOKit is ACCESSIBLE under App Sandbox (\(results.count) device(s) returned)")
            print("[Sandbox] D-09 Decision: App Store distribution may be viable (verify with Apple review)")
        }
    } else {
        print("[Sandbox] NOTE: This is an UNSIGNED/NON-SANDBOXED build.")
        print("[Sandbox] Run the sandboxed release build to complete FEAS-02:")
        print("[Sandbox]   codesign --sign - --entitlements sandbox.entitlements .build/release/bt-battery-probe")
        print("[Sandbox]   .build/release/bt-battery-probe --sandbox")
        print("[Sandbox] See sandbox test instructions in RESEARCH.md Pattern 4.")
    }
}
