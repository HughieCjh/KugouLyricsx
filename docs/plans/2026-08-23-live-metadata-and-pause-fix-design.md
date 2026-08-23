# Live Metadata and Pause Fix Design

## Problem

Kugou publishes both live lyric text and artist/credit text through the macOS media `artist` field. Local KRC karaoke rows also retain credits so that incoming media text can be matched. The current preview path can therefore treat a credit row as the next lyric, and the compatible-timing path can temporarily replace Kugou's real current lyric with a timed local metadata row.

Kugou can also emit `playing=false` followed immediately by a stale `playing=true` event at the same playback position. Treating the second event literally restarts the app's display clock while audio remains paused.

## Design

KRC presentations retain their `metadata` classification. Before the first real lyric, Kugou's live artist and production introduction is displayed in full. After lyric playback begins, later metadata is suppressed. Prediction always skips metadata rows, so credits can neither become the next preview nor be promoted between two sung phrases. Local KRC timing supplies word segments only; it no longer chooses a different current row while live lyrics are active.

A small playback-state resolver latches an explicit paused state. A later `playing=true` report at the same position is ignored. Playback resumes when position has genuinely advanced or when the user explicitly requests resume from the Touch Bar. Track changes and seeks reset the resolver.

## Verification

Core tests cover metadata propagation, metadata skipping, pause latching, stale true rejection, real position-based resume, and explicit user resume. The full app is then rebuilt and tested with Kugou on a physical Touch Bar.
