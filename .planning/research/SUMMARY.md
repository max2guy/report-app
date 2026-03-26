# Research Summary: BT Battery Monitor

**Domain:** macOS native menu bar app -- Bluetooth device battery monitoring
**Researched:** 2026-03-27
**Overall confidence:** MEDIUM (web search/fetch tools were unavailable; findings based on training data with cutoff ~May 2025)

## Executive Summary

Building a macOS menu bar app to monitor Bluetooth device battery levels is technically feasible using Apple's system frameworks with zero third-party dependencies. The stack is Swift + SwiftUI (MenuBarExtra for macOS 13+) with a three-layer Bluetooth strategy: IOKit IORegistry for broadest battery coverage, CoreBluetooth for BLE GATT Battery Service (0x180F) for devices IOKit misses, and IOBluetooth for device enumeration and metadata.

The critical risk is that the user's specific mechanical keyboard may not expose battery data through any standard protocol. Many budget/mid-range BT mechanical keyboards use proprietary battery reporting (like the FN+B LED color system described in PROJECT.md) rather than standard BLE or HID battery profiles. This must be validated on day one before any significant development effort. Running `ioreg -r -c IOBluetoothDevice | grep -i battery` with the keyboard connected will immediately answer whether IOKit-based reading is viable.

The second major risk is App Sandbox compatibility with IOKit IORegistry reads. During development (unsigned/debug builds), IOKit access works freely. Under App Sandbox (required for Mac App Store), certain IORegistry paths may be blocked. This must also be tested early. If sandboxed IOKit fails, the distribution strategy shifts to notarized direct distribution outside the App Store.

The overall architecture is simple by design: a menu-bar-only agent app (no Dock icon, no main window) using MVVM with a service layer. SwiftUI MenuBarExtra provides the menu bar presence, @Observable or ObservableObject drives reactivity, and UserDefaults handles persistence. No database, no third-party libraries, no server component.

## Key Findings

**Stack:** Swift + SwiftUI MenuBarExtra + IOKit/CoreBluetooth/IOBluetooth. Zero third-party deps.
**Architecture:** Menu-bar-only agent app, MVVM, three-layer Bluetooth service strategy.
**Critical pitfall:** Target keyboard may not expose battery via any standard API -- must validate day one.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Feasibility Validation** - Prove battery reading works before building the app
   - Addresses: IOKit battery reading, sandbox compatibility, target device support
   - Avoids: Weeks of wasted work if the target device cannot report battery (Pitfall 1)
   - Deliverable: Working CLI/script that reads battery from connected BT devices

2. **Menu Bar Shell + IOKit Integration** - Get the core app running with IOKit battery data
   - Addresses: MenuBarExtra setup, device list UI, IOKit battery reading integration
   - Avoids: MenuBarExtra style/behavior issues discovered late (Pitfall 4)
   - Deliverable: Menu bar app showing battery for devices macOS already tracks

3. **BLE Battery Service + Device Selection** - Extend coverage with CoreBluetooth
   - Addresses: BLE GATT 0x180F scanning, per-device monitoring toggle, merge strategy
   - Avoids: Framework conflicts between IOKit and CoreBluetooth (Pitfall 6)
   - Deliverable: Additional device coverage, user can select which devices to monitor

4. **Polish + Distribution** - Launch-ready quality
   - Addresses: Launch at login (SMAppService), color coding, sleep/wake handling, notarization
   - Avoids: Energy impact issues (Pitfall 7), login item API confusion (Pitfall 13)
   - Deliverable: Distributable .app or .dmg

**Phase ordering rationale:**
- Phase 1 MUST come first: it is a go/no-go gate. If the target keyboard does not expose battery data, the project scope narrows to "nicer UI for devices macOS already supports" rather than "third-party device battery monitor."
- IOKit before CoreBluetooth: IOKit is simpler (passive registry read vs. active BLE connection management) and covers more devices. If IOKit alone satisfies the use case, BLE may become optional.
- Distribution last: no point polishing what may not be feasible.

**Research flags for phases:**
- Phase 1: CRITICAL -- needs empirical testing, not just research. Research cannot determine if a specific keyboard model exposes battery.
- Phase 3: May need deeper research into BLE device reconnection patterns and CoreBluetooth + sandbox behavior.
- Phase 4: Standard patterns, unlikely to need research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (Swift/SwiftUI/MenuBarExtra) | HIGH | Well-established, official Apple frameworks, no ambiguity |
| IOKit battery reading approach | HIGH | Pattern used by existing tools (ioreg, system utilities) |
| CoreBluetooth BLE GATT | HIGH | Standard Bluetooth SIG protocol, well-documented |
| Target device compatibility | LOW | Cannot determine if specific keyboard exposes battery without testing |
| Sandbox + IOKit interaction | MEDIUM | Generally works but specific paths may be blocked; needs empirical test |
| MenuBarExtra maturity | MEDIUM | Relatively new (macOS 13, 2022); may have quirks on older versions |
| Version numbers (Swift/Xcode) | MEDIUM | Training data may be stale for exact current versions |

## Gaps to Address

- **Target device battery protocol:** Cannot be resolved through research alone. Requires hands-on testing with `ioreg` and BLE scanning tools (LightBlue or nRF Connect).
- **Exact macOS 15/16 (Sequoia) IOKit behavior:** Training data may not cover recent changes to IOKit access policies.
- **MenuBarExtra `.window` style on macOS 13 vs 14+:** Conflicting information on whether `.window` style requires macOS 14. Needs verification.
- **Swift 6 strict concurrency impact:** If the project uses Swift 6 (likely with current Xcode), strict sendability checking may affect IOKit C API bridging patterns.
- **Exact Xcode/Swift versions as of March 2026:** Could not verify current release versions.
