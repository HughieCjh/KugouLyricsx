# Kugou Foreground Lyric Continuity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep lyrics, line transitions, and blue karaoke progress moving while Kugou remains frontmost.

**Architecture:** Sanitize untrusted foreground MediaRemote events before they replace the reliable playback clock. Render foreground lyrics from the absolute local KRC timeline, then return to live-line calibration outside Kugou. Cache media icons so lyric frames redraw only the lyric view.

**Tech Stack:** Objective-C, Foundation, AppKit, MediaRemote bridge, clang, Make.

---

### Task 1: Protect the playback clock

**Files:**
- Modify: `Sources/Media/KTLNowPlaying.h`
- Modify: `Sources/Media/KTLNowPlaying.m`
- Test: `Tests/CoreTests.m`

1. Add failing cases for missing duration/time, a stale near-zero foreground time, a real pause, and a real track change.
2. Add a reconciliation method that preserves the current reliable clock only for suspicious same-track foreground observer events.
3. Run `make test`.

### Task 2: Add continuous foreground KRC rendering

**Files:**
- Modify: `Sources/App/KTLAppDelegate.m`
- Test: `Tests/CoreTests.m`

1. Track whether Kugou is frontmost.
2. Add tests showing that the existing absolute timeline advances across multiple rows and returns no row in instrumental gaps.
3. Route foreground rendering through the duration-compatible local karaoke timeline.
4. Preserve opening credits, suppress mid-song metadata, and restore live reconciliation when focus leaves Kugou.
5. Run `make test`.

### Task 3: Remove per-frame button layout churn

**Files:**
- Modify: `Sources/App/KTLTouchBarController.m`

1. Cache the four rendered button images.
2. Change the toggle button image, tooltip, and accessibility label only when playback state changes.
3. Run `make test` and `make app`.

### Task 4: Physical A/B verification

1. Sign and launch the staging App.
2. Keep Kugou frontmost across at least three lyric transitions.
3. Verify blue progress, pause/resume, and a seek.
4. Verify a KRC gap preloads the next lyric without a black interval.
5. Switch to a track with a malformed tail duration and confirm foreground mode remains enabled.
6. Package release assets only after the physical test succeeds.
