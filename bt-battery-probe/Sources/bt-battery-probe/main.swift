import Foundation
import ArgumentParser

struct BTBatteryProbe: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bt-battery-probe",
        abstract: "BT Battery Monitor — Phase 1 feasibility probe",
        discussion: """
        Tests three battery reading methods:
          --iokit    IOKit IORegistry (Layer 1)
          --ble      CoreBluetooth BLE GATT 0x180F (Layer 2)
          --sandbox  App Sandbox compatibility test (FEAS-02)
        Running with no flags executes all three in sequence.
        """
    )

    @Flag(name: .long, help: "Run IOKit IORegistry probe (FEAS-01)")
    var iokit: Bool = false

    @Flag(name: .long, help: "Run BLE GATT 0x180F probe (FEAS-03)")
    var ble: Bool = false

    @Flag(name: .long, help: "Run App Sandbox compatibility probe (FEAS-02)")
    var sandbox: Bool = false

    mutating func run() throws {
        let runAll = !iokit && !ble && !sandbox

        if iokit || runAll {
            print("\n=== IOKit IORegistry Probe (FEAS-01) ===")
            let results = probeIOKit()
            printIOKitResults(results)
        }

        if ble || runAll {
            print("\n=== BLE GATT 0x180F Probe (FEAS-03) ===")
            runBLEProbe()
        }

        if sandbox || runAll {
            print("\n=== App Sandbox Compatibility Probe (FEAS-02) ===")
            runSandboxProbe()
        }
    }
}

BTBatteryProbe.main()
