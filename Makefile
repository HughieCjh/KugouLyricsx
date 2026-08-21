SDK := $(shell xcrun --sdk macosx --show-sdk-path)
CC := clang
CFLAGS := -fobjc-arc -fmodules -fmodules-cache-path=$(CURDIR)/build/module-cache -Wall -Wextra -Werror -mmacosx-version-min=13.0 -isysroot $(SDK)
CORE := Sources/Core/KTLLRCParser.m Sources/Core/KTLLyricTimeline.m Sources/Core/KTLTrack.m Sources/Core/KTLLyricsCache.m Sources/Core/KTLKeepAwakePolicy.m
MEDIA := Sources/Media/KTLNowPlaying.m Sources/Media/KTLMediaRemoteClient.m
LYRICS := Sources/Lyrics/KTLKRCDecoder.m Sources/Lyrics/KTLKugouLocalLyricsProvider.m Sources/Lyrics/KTLRemoteLyricsService.m

.PHONY: all app dmg release test probe clean

all: app

build/KugouTouchBarLyrics: $(CORE) $(MEDIA) $(LYRICS) Sources/App/KTLTouchBarController.m Sources/App/KTLAppDelegate.m Sources/App/main.m
	@mkdir -p build
	$(CC) $(CFLAGS) -framework Foundation -framework AppKit -framework IOKit -lz $^ -o $@

app: build/KugouTouchBarLyrics
	sh scripts/build-app.sh

dmg: app
	sh scripts/build-dmg.sh

release: test dmg

build/core-tests: $(CORE) $(LYRICS) Sources/Media/KTLNowPlaying.m Tests/CoreTests.m
	@mkdir -p build
	$(CC) $(CFLAGS) -framework Foundation -lz $^ -o $@

test: build/core-tests
	./build/core-tests

build/KugouTouchBarProbe: $(CORE) $(MEDIA) $(LYRICS) Sources/Probe/main.m
	@mkdir -p build
	$(CC) $(CFLAGS) -framework Foundation -lz $^ -o $@

probe: build/KugouTouchBarProbe
	./build/KugouTouchBarProbe "$(CURDIR)/Resources"

clean:
	@mkdir -p build
	find build -mindepth 1 -maxdepth 1 -exec rm -rf {} +
