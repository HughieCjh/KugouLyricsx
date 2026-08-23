# Adaptive Karaoke Timing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Learn per-phrase timing scales from Kugou's real lyric transitions and apply them to KRC word highlighting.

**Architecture:** A pure core model owns pending live-event measurements and smoothed scales keyed by karaoke presentation. The app delegate feeds only real Kugou transitions into it and maps real elapsed seconds into scaled KRC time for mismatched lyrics. Seek and track lifecycle events reset measurement state safely.

**Tech Stack:** Objective-C, Foundation, command-line core tests, AppKit integration, Make.

---

### Task 1: Adaptive timing core model

**Files:**
- Create: `Sources/Core/KTLAdaptiveTimingModel.h`
- Create: `Sources/Core/KTLAdaptiveTimingModel.m`
- Modify: `Makefile`
- Test: `Tests/CoreTests.m`

1. Add failing tests for default scale, first observation, repeated smoothing, outlier rejection, pending cancellation, and track reset.
2. Implement KRC phrase-span extraction from segment offsets and durations.
3. Implement event observation and bounded exponential averaging.
4. Run `make test` and expect all assertions to pass.

### Task 2: Live-event integration

**Files:**
- Modify: `Sources/App/KTLAppDelegate.m`
- Test: `Tests/CoreTests.m`

1. Create/reset the model on app launch and track changes.
2. Cancel pending measurement on detected seeks.
3. Feed each distinct real live presentation and playback position into the model.
4. Preserve predicted-to-live progress using the learned scale.

### Task 3: Scaled karaoke clock

**Files:**
- Modify: `Sources/App/KTLAppDelegate.m`
- Test: `Tests/CoreTests.m`

1. Apply real lyric offset before converting elapsed time by the phrase scale.
2. Convert early-transition overflow between the previous and next phrase scales.
3. Keep compatible KRC absolute timing unchanged.
4. Verify repeated phrases converge while first occurrences retain KRC timing.

### Task 4: Documentation and verification

**Files:**
- Modify: `README.md`

1. Document adaptive learning, first-occurrence limitations, seek rejection, and no new permissions.
2. Run the full core suite and clean app build.
3. Launch with the current mismatched song and verify repeated sections improve without blue progress resets.
