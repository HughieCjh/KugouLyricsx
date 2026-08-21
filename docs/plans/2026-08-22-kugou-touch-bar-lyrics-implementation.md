# Kugou Touch Bar Lyrics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu-bar app that shows the current Kugou lyric and transport controls persistently on the Touch Bar.

**Architecture:** A Swift Package builds an AppKit executable. A macOS 15.4-compatible MediaRemote helper streams system Now Playing JSON; pure Swift modules normalize tracks, parse/cache LRC, select the active line, and drive a persistent system-modal Touch Bar.

**Tech Stack:** Swift 6, AppKit, Foundation/URLSession, XCTest, MediaRemote adapter helper, Swift Package Manager.

---

### Task 1: Package skeleton and lyric timeline

**Files:**
- Create: `Package.swift`
- Create: `Sources/KugouTouchBarLyrics/Lyrics/LRCParser.swift`
- Create: `Sources/KugouTouchBarLyrics/Lyrics/LyricTimeline.swift`
- Test: `Tests/KugouTouchBarLyricsTests/LRCParserTests.swift`

**Steps:** Write failing parser/timeline tests; run `swift test`; implement multi-tag LRC parsing, metadata skipping and binary-search line selection; rerun tests; commit.

### Task 2: Track model, normalization and cache

**Files:**
- Create: `Sources/KugouTouchBarLyrics/Playback/Track.swift`
- Create: `Sources/KugouTouchBarLyrics/Lyrics/LyricsCache.swift`
- Test: `Tests/KugouTouchBarLyricsTests/TrackTests.swift`

**Steps:** Test stable cache keys and removal of live/remaster/quality suffixes; implement Codable models and Application Support cache; run tests; commit.

### Task 3: MediaRemote integration

**Files:**
- Vendor: `Vendor/MediaRemoteAdapter/`
- Create: `Sources/KugouTouchBarLyrics/Playback/MediaRemoteClient.swift`
- Create: `Sources/KugouTouchBarLyrics/Playback/NowPlayingState.swift`
- Create: `Sources/KugouTouchBarProbe/main.swift`

**Steps:** Build the adapter; decode streamed JSON; filter bundle identifiers/display names containing Kugou/酷狗; interpolate elapsed time from timestamp and playback rate; run the probe while Kugou plays; verify title, artist, duration and elapsed time; commit.

### Task 4: Lyrics providers and fallback

**Files:**
- Create: `Sources/KugouTouchBarLyrics/Lyrics/LyricsProvider.swift`
- Create: `Sources/KugouTouchBarLyrics/Lyrics/KugouLyricsProvider.swift`
- Create: `Sources/KugouTouchBarLyrics/Lyrics/NeteaseLyricsProvider.swift`
- Create: `Sources/KugouTouchBarLyrics/Lyrics/LRCLIBLyricsProvider.swift`
- Create: `Sources/KugouTouchBarLyrics/Lyrics/LyricsService.swift`
- Test: `Tests/KugouTouchBarLyricsTests/LyricsServiceTests.swift`

**Steps:** Add URLProtocol-backed response tests; implement time-bounded providers and ordered fallback; validate returned duration/title before accepting a match; cache successful LRC; run tests; commit.

### Task 5: Menu bar and persistent Touch Bar

**Files:**
- Create: `Sources/KugouTouchBarLyrics/App/AppDelegate.swift`
- Create: `Sources/KugouTouchBarLyrics/App/ApplicationController.swift`
- Create: `Sources/KugouTouchBarLyrics/TouchBar/TouchBarController.swift`
- Create: `Sources/KugouTouchBarLyrics/TouchBar/PrivateTouchBarAPI.swift`
- Create: `Sources/KugouTouchBarLyrics/main.swift`

**Steps:** Build the status menu; implement `NSTouchBar` buttons and lyric label; present it with the system-modal private API; wire transport commands; ensure hide/show and offset controls work; build and launch; commit.

### Task 6: Bundle, documentation and real-device verification

**Files:**
- Create: `scripts/build-app.sh`
- Create: `Resources/Info.plist`
- Create: `README.md`

**Steps:** Build a universal-ready `.app` bundle for the local arm64 machine; copy adapter artifacts/resources; ad-hoc sign; run unit tests; run the probe; launch with Kugou; verify Touch Bar persistence, pause/seek/track changes and sleep/wake; document installation and limitations; commit.
