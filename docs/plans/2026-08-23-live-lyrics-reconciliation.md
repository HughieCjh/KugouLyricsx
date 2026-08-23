# Live Lyrics Reconciliation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make KugouLyricsx follow Kugou's visible live lyrics while safely handling mismatched KRC versions, metadata rows, and instrumental gaps.

**Architecture:** Add a small stateful detector for lyric text published through MediaRemote, enrich parsed KRC lines with end times, and validate local timing before displaying it. The app chooses live Kugou text first, compatible local KRC second, and remote synchronized lyrics last.

**Tech Stack:** Objective-C, Foundation, AppKit, existing command-line core test harness.

---

### Task 1: Preserve KRC duration and filter metadata

**Files:**
- Modify: `Sources/Lyrics/KTLKRCDecoder.m`
- Modify: `Tests/CoreTests.m`

**Steps:**
1. Add failing fixtures containing timed title/credit rows and a real lyric row.
2. Assert metadata rows are removed and real rows contain `duration` and `endTime`.
3. Run `make test` and confirm failure.
4. Implement minimal KRC filtering and duration parsing.
5. Run `make test` and confirm pass.

### Task 2: Respect instrumental gaps and reject incompatible timing

**Files:**
- Create: `Sources/Core/KTLLyricsTimingPolicy.h`
- Create: `Sources/Core/KTLLyricsTimingPolicy.m`
- Modify: `Sources/Core/KTLLyricTimeline.m`
- Modify: `Sources/Lyrics/KTLKugouLocalLyricsProvider.h`
- Modify: `Sources/Lyrics/KTLKugouLocalLyricsProvider.m`
- Modify: `Makefile`
- Modify: `Tests/CoreTests.m`

**Steps:**
1. Add tests for a blank gap after `endTime` and for 168.1/282.8-second incompatibility.
2. Run `make test` and confirm failure.
3. Implement the timing policy and timeline end-time check.
4. Expose `lastLyricEnd` and `timingCompatible` on local results.
5. Run `make test` and confirm pass.

### Task 3: Detect Kugou live lyrics safely

**Files:**
- Create: `Sources/Core/KTLLiveLyricDetector.h`
- Create: `Sources/Core/KTLLiveLyricDetector.m`
- Modify: `Sources/App/KTLAppDelegate.m`
- Modify: `Makefile`
- Modify: `Tests/CoreTests.m`

**Steps:**
1. Add tests for substring matching, changing media text, blank intervals, and a stable artist name.
2. Run `make test` and confirm failure.
3. Implement the detector and reset it on track changes.
4. Make display priority live text, compatible KRC, remote timeline, then track title.
5. Run `make test` and confirm pass.

### Task 4: Release and verify

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `scripts/build-dmg.sh`
- Modify: `README.md`

**Steps:**
1. Set version 0.3.1 and build 10; document live lyrics and KRC safeguards.
2. Run `make clean && make test && make release`.
3. Verify code signing, Info.plist, DMG checksum and mounted contents.
4. Sync the tested project to `/Users/hughie/Desktop/KugouTouchBarLyrics` and restart `KugouLyricsx.app`.
