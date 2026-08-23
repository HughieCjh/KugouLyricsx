# Adaptive Karaoke Timing Design

## Goal

Reduce phrase-to-phrase karaoke speed errors when Kugou's live song version does not match the duration of the cached KRC, without requesting new macOS permissions.

## Learning model

Every real Kugou lyric event establishes a playback-position anchor. When the next distinct lyric event arrives, the model measures the previous phrase's actual playback duration. It compares that duration with the span from the first KRC word offset to the final KRC word end and stores a scale for the phrase presentation key.

The first valid observation becomes the scale. Later observations use an exponential moving average so one delayed event cannot abruptly change the animation. Ratios outside a conservative range are rejected as seeks or incompatible transitions. Seeking cancels only the pending measurement; track changes clear all learned values.

## Playback mapping

For duration-mismatched KRC data, elapsed real seconds are divided by the learned scale before entering the KRC word timeline. A scale above one slows the blue fill; a scale below one speeds it up. Lyric offset is added in real seconds before scaling, so “提前 0.50 秒” remains a true half-second adjustment.

When an early transition promotes the preview phrase, overflow time is converted back to real seconds with the previous phrase's scale and then into the next phrase's KRC time with its own scale. The predicted phrase and later live Kugou event retain the same progress anchor.

## Safety and fallback

The model learns only from real live lyric changes, never predicted transitions. It ignores missing segments, sub-0.25-second samples, long gaps, and extreme ratios. Compatible KRC versions continue using their absolute media timeline. A phrase with no learned sample keeps the original KRC timing, so behavior never becomes worse solely because the model lacks data.

