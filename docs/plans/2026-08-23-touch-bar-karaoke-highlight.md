# Touch Bar Karaoke Highlight Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add smooth word-by-word blue lyric highlighting to the Touch Bar while keeping Kugou's live lyric text and the existing media controls.

**Architecture:** Preserve KRC word segments in the local lyric result, match each live Kugou text fragment to those segments, calculate a pure highlight position from either the media clock or a live-line anchor, and render it in a custom Core Text Touch Bar view. A long-lived media metadata observer reduces live-line detection latency while the existing snapshot path remains the fallback.

**Tech Stack:** Objective-C, Foundation, AppKit, Core Text, NSTask/MediaRemoteAdapter, XCTest-style command-line assertions, Make.

---

### Task 1: Preserve karaoke timing in KRC parsing

**Files:**
- Modify: `Sources/Lyrics/KTLKRCDecoder.h`
- Modify: `Sources/Lyrics/KTLKRCDecoder.m`
- Modify: `Sources/Lyrics/KTLKugouLocalLyricsProvider.h`
- Modify: `Sources/Lyrics/KTLKugouLocalLyricsProvider.m`
- Test: `Tests/CoreTests.m`

1. Add failing assertions for word text, UTF-16 ranges, offsets, durations, and unfiltered credit rows.
2. Add `parseKaraokeString:` while preserving the filtered contract of `parseString:`.
3. Store `karaokeLines` on the local result and verify all parser tests pass.

### Task 2: Match live text and calculate highlight state

**Files:**
- Create: `Sources/Core/KTLKaraokeTimeline.h`
- Create: `Sources/Core/KTLKaraokeTimeline.m`
- Modify: `Makefile`
- Test: `Tests/CoreTests.m`

1. Add failing assertions for exact matching, substring clipping, punctuation normalization, and partial-character progress.
2. Implement a pure matcher returning visible text segments.
3. Implement highlight state as completed UTF-16 length plus active-character fraction.
4. Verify pause, pre-roll, completion, and unmatched fallbacks.

### Task 3: Build the Touch Bar karaoke view

**Files:**
- Create: `Sources/App/KTLKaraokeLyricView.h`
- Create: `Sources/App/KTLKaraokeLyricView.m`
- Modify: `Sources/App/KTLTouchBarController.h`
- Modify: `Sources/App/KTLTouchBarController.m`
- Modify: `Makefile`

1. Replace the lyric label with a custom view while retaining its width and truncation behavior.
2. Draw gray base text and clipped blue foreground text with the same Core Text line.
3. Expose a controller update method accepting highlight length and fraction.
4. Build with warnings treated as errors.

### Task 4: Add low-latency live-line events and application coordination

**Files:**
- Create: `Sources/Media/KTLMediaRemoteObserver.h`
- Create: `Sources/Media/KTLMediaRemoteObserver.m`
- Modify: `Sources/App/KTLAppDelegate.m`
- Modify: `Makefile`
- Test: `Tests/CoreTests.m`

1. Inspect the bundled `media-control stream` output and encode only the verified event format.
2. Implement a restartable observer with line-buffered JSON decoding and a polling fallback.
3. On live lyric changes, select a karaoke line and store a monotonic anchor.
4. Use absolute playback time for compatible KRC and relative time for mismatched KRC.
5. Increase only the lightweight display renderer to 30 FPS; keep heavyweight snapshots at one second.

### Task 5: Release documentation and verification

**Files:**
- Modify: `README.md`
- Modify: `Resources/Info.plist`
- Modify: `Makefile`
- Modify: `scripts/build-dmg.sh`

1. Document karaoke behavior, fallback cases, permissions, system requirements, and limitations.
2. Set version `0.4.0` and build `11`.
3. Run the full core test suite and a clean app build.
4. Launch the app with Kugou, verify controls and live highlight on the physical Touch Bar, then inspect signing.
5. Build and validate the App ZIP and DMG, and copy final artifacts to `outputs` and the Desktop project.
