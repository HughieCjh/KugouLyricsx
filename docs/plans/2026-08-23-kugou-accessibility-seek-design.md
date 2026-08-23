# Kugou Accessibility Seek Synchronization Design

## Confirmed cause

When Kugou is frontmost, dragging its progress bar does not publish a seek through macOS Now Playing. During a controlled 30-second observation, both MediaRemote sources advanced linearly while the user dragged. Kugou's own accessibility tree did update its elapsed-time label. The label has the stable identifier `listen_playView_playedTime_Label` and exposes text such as `0:46` and `1:34`.

## Design

KugouLyricsx reads only that elapsed-time label while Kugou is frontmost. A dedicated provider finds the running Kugou process, walks its accessibility tree, selects the exact identifier, and parses `m:ss` or `h:mm:ss`. The provider does not read keystrokes, control the interface, or inspect other applications.

The one-second poll compares the whole-second accessibility value with KugouLyricsx's current estimated playback time. A difference of at least two seconds is treated as a confirmed seek and replaces the stale MediaRemote position. Smaller differences are ignored so normal rounding does not make karaoke progress jump once per second. If the label is absent, malformed, or inaccessible, the existing MediaRemote path continues unchanged.

Accessibility authorization is requested through the standard macOS prompt. The status menu reports whether foreground seek synchronization is authorized and lets the user request authorization again. The App remains usable without permission, but dragging while Kugou is frontmost cannot be synchronized reliably.

## Verification

Unit tests cover `m:ss`, `h:mm:ss`, whitespace, invalid seconds, invalid text, normal rounding, and a real seek. Physical verification keeps Kugou frontmost, drags across at least one minute, and confirms the Touch Bar switches lines within about one second without clicking the desktop.
