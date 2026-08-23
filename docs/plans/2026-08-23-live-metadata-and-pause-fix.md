# Live Metadata and Pause Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent author/credit rows from flashing between lyrics and freeze karaoke progress reliably while Kugou is paused.

**Architecture:** Preserve KRC metadata classification through karaoke presentations and exclude metadata only from display and prediction. Add a pure playback-state resolver that rejects stale resume events at an unchanged position, then route both stream and polling states through it.

**Tech Stack:** Objective-C, Foundation, AppKit, MediaRemote bridge, clang, Make.

---

### Task 1: Prevent metadata prediction

**Files:**
- Modify: `Sources/Core/KTLKaraokeTimeline.m`
- Test: `Tests/CoreTests.m`

1. Add failing tests that presentation matching retains the metadata flag and next-presentation lookup skips credit rows.
2. Run `make test` and confirm failure.
3. Propagate `metadata` into presentation dictionaries and iterate past metadata rows when predicting.
4. Run `make test` and confirm success.

### Task 2: Resolve stale pause events

**Files:**
- Create: `Sources/Core/KTLPlaybackStateResolver.h`
- Create: `Sources/Core/KTLPlaybackStateResolver.m`
- Modify: `Makefile`
- Test: `Tests/CoreTests.m`

1. Add failing tests for pause latching, same-position stale resume rejection, position-based resume, explicit resume, and reset.
2. Run `make test` and confirm failure.
3. Implement the minimal state resolver and add it to `CORE`.
4. Run `make test` and confirm success.

### Task 3: Make real live lyrics authoritative

**Files:**
- Modify: `Sources/App/KTLAppDelegate.m`

1. Route every incoming snapshot through the playback resolver.
2. Suppress matched metadata and the resolved artist name from Touch Bar text.
3. Use live phrase anchors for both compatible and incompatible KRC files; use absolute KRC anchoring only for initial load and seek reconciliation.
4. Keep learned adaptive scale, lyric offset, prediction overflow, and dual-line preview operating on the live presentation.
5. Run `make test` and `make app`.

### Task 4: Document and launch

**Files:**
- Modify: `README.md`

1. Document metadata suppression and pause-state protection.
2. Verify the app signature.
3. Replace the running test build and confirm its executable path.
4. Ask for physical Touch Bar verification before release packaging.
