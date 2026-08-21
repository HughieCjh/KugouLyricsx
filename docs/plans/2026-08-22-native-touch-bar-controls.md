# Native Touch Bar Controls Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the three text-glyph media buttons with hollow white outline controls matching the approved preview and keep the play/pause image synchronized with playback state.

**Architecture:** Keep all UI changes inside `KTLTouchBarController`. A private renderer draws single-triangle previous/next, play, and pause paths into non-template 2x bitmaps; a button factory creates consistently sized accessible controls, and the existing state update method swaps the toggle image without changing media command flow.

**Tech Stack:** Objective-C, AppKit, NSTouchBar, Make, existing core test executable

---

### Task 1: Add hollow image-only media buttons

**Files:**
- Modify: `Sources/App/KTLTouchBarController.m`

**Step 1: Add a private button factory**

Create `mediaButtonWithIcon:accessibilityLabel:action:`. It must use `NSButton buttonWithImage:target:action:`, show only the image, scale proportionally, use a native textured rounded bezel, apply a 44pt width constraint, and set both tooltip and accessibility label.

**Step 2: Replace the text glyphs**

Render 22pt white non-template images using round-cap `NSBezierPath` strokes: `|<`, hollow play, pause, and `>|`. Previous and next must contain exactly one triangle each.

**Step 3: Compile**

Run: `make app`

Expected: Objective-C compilation succeeds with no warnings or errors.

### Task 2: Synchronize play and pause images

**Files:**
- Modify: `Sources/App/KTLTouchBarController.m`

**Step 1: Update playback rendering**

In `updateLyric:playing:`, set the toggle image to the custom pause icon while playing and the hollow play icon while paused. Update tooltip and accessibility label to match.

**Step 2: Run tests**

Run: `make test`

Expected: `PASS: all core tests`.

### Task 3: Version and release documentation

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `scripts/build-dmg.sh`
- Modify: `README.md`

**Step 1: Bump release metadata**

Set the user-facing version to 0.2.5 and bundle build number to 8.

**Step 2: Update README**

Document the hollow media icons and update all artifact names to 0.2.5.

### Task 4: Package and verify

**Files:**
- Generate: `dist/KugouTouchBarLyrics.app`
- Generate: `dist/KugouTouchBarLyrics-0.2.5-app.zip`
- Generate: `dist/KugouTouchBarLyrics-0.2.5.dmg`

**Step 1: Build the release**

Run: `make release`

Expected: tests pass and the three 0.2.5 artifacts are generated.

**Step 2: Verify artifacts**

Run `codesign --verify --deep --strict`, `unzip -t`, `hdiutil verify`, and confirm the bundle version with `plutil`.

**Step 3: Deploy for visual verification**

Synchronize the project to `/Users/hughie/Desktop/KugouTouchBarLyrics`, restart the desktop App, and verify the controls on the physical Touch Bar.

The directory is not currently a Git repository, so commit steps are intentionally omitted.
