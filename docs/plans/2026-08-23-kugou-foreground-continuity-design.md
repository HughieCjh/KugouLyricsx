# Kugou Foreground Lyric Continuity Design

## Confirmed cause

When Kugou is frontmost, it can stop publishing menu-bar lyric text through macOS Now Playing and fall back to the real artist name. It also emits incomplete transition snapshots: duration and elapsed time may disappear, elapsed time may jump back near zero, and `playing` may briefly flip false and true. KugouLyricsx itself remains active, advances its clock, and redraws its view.

The previous live-lyric path predicts only one presentation beyond the last live update. Without another live line from Kugou, the presentation eventually stops advancing.

## Design

While Kugou is frontmost and a duration-compatible local KRC is available, render from the KRC's absolute playback timeline. This mode selects every successive row by playback time, preserves per-character timing, leaves instrumental gaps empty, shows opening credit rows normally, and suppresses later credit rows after real lyrics have begun. When another app becomes frontmost, mark the live anchor for reconciliation and allow Kugou's resumed live text to correct timing again.

For the alternating two-line display, a gap no longer clears both lanes. The upcoming non-metadata lyric is preloaded in gray and begins filling blue only when its real KRC start time arrives. Some Kugou files also contain a malformed final row whose declared duration is effectively the whole track; when that duration exceeds the row's word-segment span by more than 15 seconds, the parser uses the real segment end. This prevents a valid KRC from being rejected and prevents the final lyric from remaining on screen through the outro.

Before applying a foreground observer snapshot, reconcile incomplete or implausibly stale fields with the current reliable state. A plausible pause at the current elapsed time remains valid; a snapshot with missing time or a large clock discontinuity is treated as a focus transition and cannot reset or pause the lyric clock. Polling remains authoritative for seeks and real playback changes.

Media button images are cached and the play/pause button is updated only when its state changes, preventing full Touch Bar layout invalidation on every lyric frame.

Kugou does not publish a reliable seek event while its own window is frontmost. The calculated macOS position is therefore authoritative when the one-second poll detects a seek. The polling snapshots are matched by title and compatible duration, not by artist: Kugou reuses the artist field for live lyric text, so that value can change between two reads of the same song. That correction redraws the existing lyric view in place; it must not call the private system-modal presentation API while Kugou is frontmost, because re-presenting at that moment can retain the old physical Touch Bar surface. Track changes and media-button commands follow the same in-place foreground rule.

## Verification

Core tests cover incomplete focus snapshots, stale near-zero elapsed time, real pause acceptance, multi-line absolute KRC advancement, gaps, and metadata handling. The physical test keeps Kugou frontmost through several lyric rows, pauses, resumes, and seeks without clicking the desktop.
