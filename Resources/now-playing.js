ObjC.import('Foundation');

function unwrap(value) {
    if (!value || String(value) === '[id nil]') return null;
    return ObjC.unwrap(value);
}

function run() {
    const framework = $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/');
    framework.load;
    const request = $.NSClassFromString('MRNowPlayingRequest');
    const item = request.localNowPlayingItem;
    if (String(item) === '[id nil]') return '{}';

    const info = item.nowPlayingInfo;
    const client = request.localNowPlayingPlayerPath.client;
    const get = key => unwrap(info.valueForKey(key));
    const metadata = item.metadata;
    let elapsed = null;
    if (metadata && String(metadata) !== '[id nil]') {
        elapsed = unwrap(metadata.calculatedPlaybackPosition);
    }

    return JSON.stringify({
        title: get('kMRMediaRemoteNowPlayingInfoTitle'),
        artist: get('kMRMediaRemoteNowPlayingInfoArtist'),
        album: get('kMRMediaRemoteNowPlayingInfoAlbum'),
        duration: get('kMRMediaRemoteNowPlayingInfoDuration'),
        elapsed: elapsed,
        playbackRate: get('kMRMediaRemoteNowPlayingInfoPlaybackRate'),
        playing: unwrap(request.localIsPlaying),
        bundleIdentifier: unwrap(client.bundleIdentifier),
        appName: unwrap(client.displayName),
        contentItemIdentifier: get('kMRMediaRemoteNowPlayingInfoContentItemIdentifier')
    });
}
