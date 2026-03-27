---
phase: 2
slug: menu-bar-app-iokit-integration
status: active
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-27
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `swift build` (compile verification — no unit test targets in this phase) |
| **Config file** | BTBatteryMonitor/Package.swift |
| **Quick run command** | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && swift build 2>&1 | tail -5` |
| **Full suite command** | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && bash build.sh 2>&1 | tail -10` |
| **Estimated runtime** | ~30 seconds (swift build cold), ~60 seconds (bash build.sh release) |

---

## Sampling Rate

- **After every task commit:** Run quick run command (`swift build | tail -5`)
- **After every plan wave:** Run full suite command (`bash build.sh | tail -10`)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds (compile time)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-T1 | 01 | 1 | DISC-01, DISC-02 | compile | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && swift build 2>&1 \| head -20` | ❌ pre-execution | ⬜ pending |
| 02-01-T2 | 01 | 1 | DISC-03, BATT-01 | compile | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && swift build 2>&1 \| tail -5` | ❌ pre-execution | ⬜ pending |
| 02-02-T1 | 02 | 2 | UI-01, LIFE-02 | compile | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && swift build 2>&1 \| tail -10` | ❌ pre-execution | ⬜ pending |
| 02-02-T2 | 02 | 2 | UI-03, UI-04 | compile | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && swift build 2>&1 \| tail -5` | ❌ pre-execution | ⬜ pending |
| 02-03-T1 | 03 | 3 | LIFE-02 | build+sign | `cd /Users/kimwoojung/report-app/.claude/worktrees/unruffled-euclid/BTBatteryMonitor && bash build.sh 2>&1 \| tail -10` | ❌ pre-execution | ⬜ pending |
| 02-03-T2 | 03 | 3 | LIFE-02, UI-01, UI-03 | manual | CHECKPOINT — human verification required | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

No Wave 0 required. This phase uses `swift build` as its compile-time verification harness. No test framework installation is needed — the Swift toolchain is already present on the development machine.

*Existing infrastructure covers all automated phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Menu bar icon appears after app launch | UI-01, LIFE-02 | Requires visual inspection of macOS menu bar | Run `open BTBatteryMonitor.app`, look for icon in top-right menu bar area |
| Clicking menu bar icon opens popover | UI-03 | Requires mouse interaction with live app | Click menu bar icon, verify NSPopover appears below |
| Popover closes on outside click | UI-03 | Requires mouse interaction | Click outside popover, verify it dismisses |
| No Dock icon visible | LIFE-02 | Requires visual inspection of Dock | Launch app, confirm it does not appear in macOS Dock |
| Bluetooth TCC permission prompt | DISC-01 | System dialog triggered by first IOBluetooth access | First launch: macOS dialog asking for Bluetooth access |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or manual checkpoint noted above
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (all auto tasks use swift build)
- [x] Wave 0 covers all MISSING references (none — no MISSING entries)
- [x] No watch-mode flags
- [x] Feedback latency < 60s (swift build ~30s cold, warm incremental ~5s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
