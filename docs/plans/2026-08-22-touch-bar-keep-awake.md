# Touch Bar Keep Awake Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a persisted menu setting that keeps the Touch Bar and display awake only while Kugou is actively playing.

**Architecture:** A pure policy object decides whether a display-sleep assertion is required. `KTLAppDelegate` owns the IOKit assertion and synchronizes it with the saved preference and now-playing state.

**Tech Stack:** Objective-C, AppKit, Foundation, IOKit Power Management, clang, Make.

---

### Task 1: Add the keep-awake policy

**Files:**
- Create: `Sources/Core/KTLKeepAwakePolicy.h`
- Create: `Sources/Core/KTLKeepAwakePolicy.m`
- Modify: `Tests/CoreTests.m`
- Modify: `Makefile`

**Step 1:** Add failing tests asserting that the policy returns true only when the preference is enabled, Kugou is active, and playback is running.

**Step 2:** Run `make test` and verify the policy symbol is missing or the new assertions fail.

**Step 3:** Implement the minimal pure Boolean policy and add it to `CORE`.

**Step 4:** Run `make test` and expect `PASS: all core tests`.

### Task 2: Add the persisted menu setting and assertion lifecycle

**Files:**
- Modify: `Sources/App/KTLAppDelegate.m`
- Modify: `Makefile`

**Step 1:** Add a checkable menu item titled `播放时保持 Touch Bar/屏幕常亮` and store its value in `NSUserDefaults` under `KTLKeepDisplayAwakeWhilePlaying`.

**Step 2:** Add an `IOPMAssertionID` owner and a synchronization method that creates `kIOPMAssertionTypePreventUserIdleDisplaySleep` only when policy returns true.

**Step 3:** Call synchronization after every playback/idle transition, when the menu setting changes, and before termination. Link the app target with `IOKit`.

**Step 4:** Build with `make app`; expect no warnings and a valid app bundle.

### Task 3: Update release documentation and version

**Files:**
- Modify: `README.md`
- Modify: `Resources/Info.plist`
- Modify: `scripts/build-dmg.sh`

**Step 1:** Document the setting, main-screen side effect, battery impact, and default-off behavior.

**Step 2:** Bump the feature release to `0.2.0` and generate matching artifacts.

### Task 4: Verify and deploy

**Files:**
- Test: `Tests/CoreTests.m`
- Output: `dist/KugouTouchBarLyrics.app`
- Output: `dist/KugouTouchBarLyrics-0.2.0.dmg`
- Output: `dist/KugouTouchBarLyrics-0.2.0-app.zip`

**Step 1:** Run `make release` and expect all tests to pass.

**Step 2:** Temporarily enable the preference, launch during Kugou playback, and verify `pmset -g assertions` lists the app's display-sleep assertion.

**Step 3:** Quit the app and verify the assertion is released, then restore the default-off preference.

**Step 4:** Verify code signing, ZIP integrity and DMG checksum; sync the complete project to the user's chosen project directory.
