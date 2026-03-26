# Feature Landscape

**Domain:** macOS Bluetooth Battery Monitoring (Menu Bar App)
**Researched:** 2026-03-27
**Confidence:** MEDIUM (based on training data; web verification unavailable)

## Competitive Landscape

Key competitors analyzed from training data:
- **AirBuddy 2** — Premium Apple-ecosystem focused ($9.99), deep AirPods/Beats integration
- **Bluetooth Battery Monitor** (Intuitibits) — Lightweight menu bar utility, broad device support
- **coconutBattery** — Mac/iPhone/iPad battery health focus, BT devices secondary
- **Magic Battery** — Free/paid, Apple peripherals focused
- **Tooth Fairy** — Menu bar BT connection manager with battery display
- **macOS native** — System Settings > Bluetooth shows battery for supported devices

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Menu bar battery percentage display | Core value proposition. Every competitor does this. | Med | Need NSStatusItem with dynamic text/icon |
| Menu bar battery icon (visual level) | Users glance at menu bar, need visual cue without reading numbers | Low | 4-5 icon states (full/high/med/low/critical) |
| Connected device list | Users need to see which devices are tracked | Low | IOBluetooth device enumeration |
| Click-to-show popover/dropdown | Menu bar click must reveal device details | Med | NSPopover or NSMenu with custom views |
| Per-device battery level | Each device shown with its own battery % | Med | Core data retrieval logic |
| Device type icons | Distinguish keyboard vs mouse vs headphones vs gamepad | Low | SF Symbols or custom icons per device class |
| Auto-refresh battery levels | Battery must update without manual action | Low | Timer-based polling, 60-300s interval |
| Launch at login | Utility apps must survive reboot | Low | SMAppService (modern) or Login Items |
| Persist device selection | Remember which devices user chose to monitor | Low | UserDefaults |
| Graceful handling of disconnected devices | Show "disconnected" state, not crash or stale data | Low | Monitor kIOBluetoothDeviceNotification |

## Differentiators

Features that set this product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Non-Apple BT device support** | PROJECT'S CORE DIFFERENTIATOR. macOS native + most competitors only show Apple devices. Supporting mechanical keyboards via BLE GATT/HID is the reason this app exists. | High | Requires IOKit/CoreBluetooth deep dive. BLE Battery Service (0x180F) or HID battery report parsing. Not all devices expose this. |
| Low battery notification | Alert before device dies. AirBuddy and BT Battery Monitor have this. Explicitly deferred to v2 per PROJECT.md but still a key differentiator. | Med | UNUserNotificationCenter, configurable threshold |
| Configurable menu bar display | Choose which device shows in menu bar (not just popover) | Low | User picks "primary" device for menu bar |
| Battery history/trend | See battery drain over time. coconutBattery does this for Mac/iPhone. | High | Requires persistent storage, chart rendering |
| Multiple device battery in menu bar | Show 2-3 device batteries simultaneously in menu bar | Med | Multiple NSStatusItems or compact layout |
| Custom polling interval | Let user set refresh rate (power vs freshness tradeoff) | Low | Settings UI + timer adjustment |
| Device nickname/alias | Rename "BT Keyboard 5.0" to "My Keychron K2" | Low | UserDefaults mapping |
| Menu bar color coding | Green/yellow/red based on battery level | Low | NSAttributedString or colored SF Symbols |
| Keyboard shortcut to check battery | Quick-glance without clicking menu bar | Low | Global hotkey registration |
| Widget support | macOS Sonoma+ desktop/notification center widget | Med | WidgetKit extension, separate target |
| Battery level spoken announcement | VoiceOver/accessibility: speak battery level | Low | NSSpeechSynthesizer or accessibility API |
| Estimated time remaining | "~4 hours left" based on drain rate | High | Requires history data + drain rate calculation |
| Device auto-discovery | Automatically detect and offer to monitor new BT devices | Low | CoreBluetooth scanning |
| Export/share battery data | Export history as CSV or share screenshot | Low | Only useful if history feature exists |

## Anti-Features

Features to deliberately NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Battery charging control | Read-only monitoring only. Charging control requires hardware-level access, is dangerous, and out of scope per PROJECT.md | Display charging state if available, nothing more |
| Windows/Linux support | macOS-native APIs (IOKit, CoreBluetooth) are the core. Cross-platform would require complete rewrite with different BT stacks | Stay macOS-only, use native APIs fully |
| Bluetooth connection management | Scope creep. ToothFairy/AirBuddy already do this well. Connecting/disconnecting devices is a different product | Show connection status, but don't manage it |
| Audio routing/switching | AirBuddy territory. Complex, unrelated to battery monitoring | Not even tangentially related to core value |
| Device firmware updates | Massive scope, device-specific, manufacturer responsibility | Out of scope entirely |
| Always-on overlay/HUD | Intrusive, un-Mac-like. Menu bar is the right macOS pattern | Menu bar + popover is the native macOS way |
| Complex settings/preferences sprawl | Utility apps die from settings bloat. Keep it simple | Minimal settings: launch at login, polling interval, device selection |
| Subscription pricing model | Utility apps should be one-time purchase or free. Users hate subscriptions for simple tools | Free or one-time purchase if monetizing |
| Analytics/telemetry | Privacy-sensitive (BT device data). Users of utility apps are often power users who notice and resent telemetry | No analytics. No network calls except optional update check |
| Web dashboard/cloud sync | A menu bar battery monitor has no business being cloud-connected | Local-only. No accounts, no sync |

## Feature Dependencies

```
Device Discovery --> Device List Display --> Per-device Battery Level
                                         --> Device Selection (which to monitor)
                                         --> Device Type Icons

Battery Level Reading --> Menu Bar Display (icon + %)
                     --> Color Coding
                     --> Low Battery Notification (v2)
                     --> Battery History (future)
                     --> Estimated Time Remaining (future, requires History)

Device Selection --> Persist Selection (UserDefaults)
                --> Menu Bar Primary Device Choice

Launch at Login (independent, no dependencies)

Auto-refresh Timer --> Battery Level Reading (triggers refresh)
```

## MVP Recommendation

### Phase 1: Core (must ship with these)

Prioritize table stakes that deliver the core value proposition:

1. **Connected device list detection** — foundation for everything
2. **Per-device battery level reading** — the actual value
3. **Menu bar icon + percentage display** — the UI for the value
4. **Click popover with all devices** — detail view
5. **Device type icons** — visual clarity
6. **Auto-refresh** — liveness
7. **Launch at login** — persistence
8. **Device selection** — user control

### Phase 2: Differentiator (the reason this app exists)

9. **Non-Apple BT device support via BLE GATT / HID** — this is the whole point. If this doesn't work, reconsider the project. Needs deep technical research.

### Phase 3: Polish

10. **Menu bar color coding** — low effort, high visual value
11. **Device nicknames** — quality of life
12. **Configurable polling interval** — power user need
13. **Configurable menu bar display** — which device shows

### Defer to v2

- **Low battery notifications** — explicitly deferred per PROJECT.md
- **Battery history/trends** — high complexity, nice-to-have
- **Estimated time remaining** — requires history data first
- **Widget support** — separate target, additional complexity
- **Keyboard shortcut** — nice but not critical

## Key Insight: The Real Challenge

The entire feature set is straightforward EXCEPT for the core differentiator: reading battery from non-Apple BT devices. macOS exposes battery for Apple devices (Magic Keyboard, AirPods, etc.) via IOKit `kIOPSCurrentCapacityKey` easily. For third-party BLE devices:

- **BLE devices with Battery Service (UUID 0x180F):** CoreBluetooth can read the standard GATT Battery Level characteristic. This works IF the device advertises it.
- **HID devices:** Some keyboards/mice report battery via HID Usage Page (Generic Desktop, Battery Strength). IOKit HID API can read this.
- **Devices that don't expose battery at all:** Nothing can be done. The app should clearly communicate "battery info unavailable" rather than showing stale/wrong data.

This technical constraint directly shapes what features are possible and must be researched deeply before Phase 2.

## Sources

- Training data knowledge of AirBuddy 2, coconutBattery, Bluetooth Battery Monitor, Magic Battery, Tooth Fairy (MEDIUM confidence — unable to verify against current versions due to web access restrictions)
- Apple developer documentation knowledge for IOKit, CoreBluetooth, BLE GATT (MEDIUM confidence)
- PROJECT.md requirements and constraints (HIGH confidence — directly read)
