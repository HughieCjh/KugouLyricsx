ObjC.import('Foundation');

function run(argv) {
    if (!argv || argv.length !== 1) throw new Error('A single media command is required');
    const command = Number(argv[0]);
    if (![0, 1, 2, 3, 4, 5].includes(command)) throw new Error('Unsupported media command');

    $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/').load;
    const controllerClass = $.NSClassFromString('MRNowPlayingController');
    const controller = controllerClass.localRouteController;
    controller.sendCommandOptionsCompletion(command, $.NSDictionary.alloc.init, null);
    return 'ok';
}
