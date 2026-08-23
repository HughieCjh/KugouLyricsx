# Touch Bar Karaoke Highlight Design

## Objective

Make the Touch Bar lyric resemble Kugou's macOS menu-bar lyric: the current text stays in place while a bright blue highlight advances from left to right, including smooth progress inside the character currently being sung. The existing previous, play/pause, and next controls remain unchanged.

## Data flow

Kugou remains the source of the currently displayed text. The app reads the matching local KRC file only for its per-word offsets and durations. This avoids replacing Kugou's selected lyric version while still gaining karaoke timing.

The local provider exposes two views of a KRC file:

- `lines`: filtered line-level lyrics used by the existing fallback timeline.
- `karaokeLines`: every timed row, including title and credit rows, with preserved per-word segments.

The karaoke matcher normalizes punctuation and whitespace, finds the KRC row containing the live Kugou text, and clips its segments to that visible substring. Exact matches win over substring matches.

## Synchronization

When the KRC duration matches the playing track, highlight progress uses the media playback position. This naturally follows pause and seek operations.

When the cached KRC is a different version but the visible words match, each new live Kugou line establishes a local monotonic anchor. Relative KRC word durations then animate from that observed change. If no word timing can be matched, the lyric remains readable with a complete blue highlight instead of showing misleading animation.

The normal one-second media snapshot remains responsible for track identity, playback position, and controls. A persistent media metadata stream supplies lyric changes with lower latency and falls back safely to polling if unavailable.

## Touch Bar rendering

A custom AppKit view draws the same centered text twice:

1. unplayed text in soft gray;
2. played text in Kugou-like bright blue, clipped at the current typographic offset.

Core Text measures the exact glyph position for the completed UTF-16 range and interpolates through the active character. A 30 FPS display timer provides smooth movement without changing the text layout on every frame.

## Compatibility and fallback

The implementation remains Objective-C and keeps the existing macOS 13 minimum. It requests neither Screen Recording nor Accessibility permission. If the MediaRemote stream, local KRC, or word tags are unavailable, current line-level behavior remains available.

