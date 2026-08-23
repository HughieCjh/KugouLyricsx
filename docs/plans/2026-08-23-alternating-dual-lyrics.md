# Alternating Dual Lyrics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a persisted optional Touch Bar mode with alternating current and next lyric lanes.

**Architecture:** Extend the pure karaoke timeline with ordered next-presentation lookup, maintain a stable active-lane key in the app delegate, and render two equal-width lyric regions in the custom AppKit view. Live Kugou events remain authoritative and the existing single-line mode remains the default.

**Tech Stack:** Objective-C, Foundation, AppKit, NSUserDefaults, command-line core tests, Make.

---

### Task 1: Ordered next-presentation model

**Files:**
- Modify: `Sources/Lyrics/KTLKRCDecoder.m`
- Modify: `Sources/Core/KTLKaraokeTimeline.h`
- Modify: `Sources/Core/KTLKaraokeTimeline.m`
- Test: `Tests/CoreTests.m`

1. Add failing tests for a same-row remaining phrase and the following KRC row.
2. Preserve each parsed row's source index.
3. Implement a pure next-presentation helper.
4. Run `make test` and expect all assertions to pass.

### Task 2: Dual-lane Touch Bar renderer

**Files:**
- Modify: `Sources/App/KTLKaraokeLyricView.h`
- Modify: `Sources/App/KTLKaraokeLyricView.m`
- Modify: `Sources/App/KTLTouchBarController.h`
- Modify: `Sources/App/KTLTouchBarController.m`

1. Extend the renderer API with next text, dual-mode state, and active side.
2. Draw two equal-width lanes separated by 20 points.
3. Apply karaoke fill only to the active lane and dim the preview lane.
4. Preserve the existing single-line drawing path.
5. Build with warnings treated as errors.

### Task 3: Persisted setting and alternating state

**Files:**
- Modify: `Sources/App/KTLAppDelegate.m`
- Test: `Tests/CoreTests.m`

1. Add the `左右双句歌词` checkbox and store it in `NSUserDefaults`.
2. Reset the alternating state on track changes, seeks, and setting changes.
3. Derive current and next presentations on every display update.
4. Flip lanes once when the current presentation key changes.
5. Keep mismatched-KRC current-line prediction conservative.

### Task 4: Documentation and verification

**Files:**
- Modify: `README.md`

1. Document the checkbox, alternating behavior, and fallback.
2. Run `make test` and a clean app build.
3. Launch the test app and verify single mode, dual mode, seek, pause, and track changes on the physical Touch Bar.
