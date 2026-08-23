# Kugou Accessibility Seek Synchronization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Synchronize Touch Bar lyrics after the user drags Kugou's progress bar while Kugou remains frontmost.

**Architecture:** Add a read-only Accessibility provider for Kugou's stable elapsed-time label. Feed its whole-second value into the existing polling path only when it differs enough to prove a seek, preserving MediaRemote precision during ordinary playback.

**Tech Stack:** Objective-C, AppKit, macOS Accessibility API, Foundation, clang, Make.

---

### Task 1: Specify parsing and seek detection

**Files:**
- Create: `Sources/Media/KTLKugouAccessibilityPositionProvider.h`
- Create: `Sources/Media/KTLKugouAccessibilityPositionProvider.m`
- Modify: `Tests/CoreTests.m`
- Modify: `Makefile`

1. Add failing tests for `0:46`, `1:34`, `1:02:03`, surrounding whitespace, invalid seconds, and invalid text.
2. Add failing tests showing that sub-two-second rounding is ignored and a minute-scale change is accepted.
3. Run `make test` and confirm the new expectations fail.

### Task 2: Implement the read-only provider

**Files:**
- Create: `Sources/Media/KTLKugouAccessibilityPositionProvider.h`
- Create: `Sources/Media/KTLKugouAccessibilityPositionProvider.m`

1. Parse whole-second time labels without accepting malformed components.
2. Find the Kugou process by bundle identifier.
3. Recursively locate only `listen_playView_playedTime_Label` and read its description or value.
4. Expose macOS authorization state and the standard authorization prompt.
5. Run `make test` and confirm parsing and seek-policy tests pass.

### Task 3: Integrate foreground seek synchronization

**Files:**
- Modify: `Sources/App/KTLAppDelegate.m`
- Modify: `Makefile`

1. Read the accessibility position on the existing background polling queue only while Kugou is frontmost.
2. On the main thread, replace the MediaRemote position only for a confirmed difference of at least two seconds.
3. Let the existing seek reset path clear adaptive timing and redraw the current lyric in place.
4. Add a status-menu authorization item and request authorization once at launch.
5. Run `make test` and `make app`.

### Task 4: Document and physically verify

**Files:**
- Modify: `README.md`

1. Replace claims that Accessibility is never needed with a precise explanation: it is needed only for foreground progress-bar synchronization.
2. Document System Settings → Privacy & Security → Accessibility and the fallback without permission.
3. Verify the App signature.
4. Launch the staging App, grant permission, keep Kugou frontmost, and seek across one minute.
5. Package release assets only after physical verification succeeds.
