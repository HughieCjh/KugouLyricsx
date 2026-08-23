# Alternating Dual Lyrics Design

## Goal

Add an optional Touch Bar layout that always shows two lyric phrases side by side. One side is active and receives the existing karaoke highlight; the other side is a muted preview. When the active phrase finishes, the preview side becomes active and the finished side is replaced by the following preview.

## Interaction

The menu bar gains a persisted checkbox named `左右双句歌词`. It is off by default so the current single-line layout remains unchanged. Enabling or disabling it updates the Touch Bar immediately without restarting playback.

The two lyric lanes have equal width with a 20-point empty gap and no divider. The active lane uses the gray base plus blue karaoke fill. The preview lane stays dim gray. Existing previous, play/pause, and next buttons keep their current size and position.

The lyric offset controls both phrase selection and word highlighting. With a positive “提前” value, the preview phrase becomes active when the shared offset clock reaches the current phrase end; its blue highlight starts immediately from its first word, and the old active lane is replaced by the following preview. The later Kugou live event confirms the same presentation key and therefore does not flip the lanes twice.

## State and synchronization

Each karaoke presentation retains its source KRC row and visible source range. A pure timeline helper returns the next phrase: first the remaining phrase inside the same KRC row, otherwise the following KRC row. The app derives a stable presentation key and flips the active left/right lane only when that key changes. If a predicted phrase later becomes the actual Kugou live phrase, the key remains the same, preventing a second unwanted flip.

For a duration-compatible KRC, playback time and lyric offset may advance across rows. For a mismatched KRC, the active lyric keeps the existing conservative rule and does not cross-row predict; the other lane may preview the immediate KRC successor, while every real Kugou lyric event corrects the active lane. Seeking and track changes clear the alternating state and establish a fresh left-side current phrase.

## Fallbacks

If there is no trustworthy next phrase, the preview lane stays empty. No music-note placeholder is inserted. Remote line-only lyrics continue to show the current phrase; the next lane remains empty unless ordered source data is available.
