# Kugou Foreground Refresh Design

## Problem

When Kugou becomes the foreground application, its media state and live lyric stream continue to advance, but KugouLyricsx's visible karaoke fill and line changes can freeze. No false pause event is emitted. A test build that prevented App Nap did not change the physical Touch Bar behavior, ruling out background scheduling as the primary cause.

## Design

The freeze is correlated with `NSWorkspaceDidActivateApplicationNotification`: the app was calling the private system-modal presentation API again exactly while macOS activated Kugou's own foreground Touch Bar. The visible result is a retained snapshot that no longer receives subsequent view updates.

When the activated application is Kugou, KugouLyricsx now leaves the already-presented system-modal Touch Bar untouched. When another application becomes active, or when a track/seek transition genuinely requires recovery, the app may still present and redraw the Touch Bar with delayed retries. No permanent activity assertion or periodic re-presentation timer is added.

## Verification

Existing core tests guard pause and lyric timing behavior. The final manual test switches repeatedly between Codex/Finder and Kugou while watching both within-word blue progress and live line transitions. Release assets are rebuilt only after this A/B test succeeds.
