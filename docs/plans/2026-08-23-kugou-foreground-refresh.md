# Kugou Foreground Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep Touch Bar karaoke animation and live line changes responsive when Kugou is the foreground application.

**Architecture:** `KTLAppDelegate` inspects the activated application's bundle identifier. It avoids re-presenting the system-modal Touch Bar when Kugou itself becomes active, while preserving delayed recovery for track changes, seeks, and transitions to other applications.

**Tech Stack:** Objective-C, Foundation, AppKit, NSTouchBar private presentation bridge, clang, Make.

---

### Task 1: Route foreground transitions

**Files:**
- Modify: `Sources/App/KTLAppDelegate.m`

1. Read `NSWorkspaceApplicationKey` from the activation notification.
2. Return without presenting the Touch Bar when the bundle identifier belongs to Kugou.
3. Keep recovery presentation for other foreground applications.

### Task 2: Preserve explicit recovery paths

**Files:**
- Modify: `Sources/App/KTLTouchBarController.h`
- Modify: `Sources/App/KTLTouchBarController.m`
- Modify: `Sources/App/KTLAppDelegate.m`

1. Keep `showAndRefresh` for track changes, seeks, user commands, and non-Kugou activation.
2. Use immediate and delayed refresh passes through 1.8 seconds only on those recovery paths.
3. Run `make test` and `make app`.

### Task 3: Launch A/B build

**Files:**
- Modify: `README.md`

1. Verify the App signature.
2. Replace the running test App.
3. Test foreground switching on the physical Touch Bar before rebuilding release assets.
