import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/url.dart';
import 'link_saver.dart';

/// Reads shared text from the Android share sheet.
///
/// Two paths, both handled in `MainActivity`: a cold start parks the text until
/// this asks for it, a warm share arrives on the event channel.
class ShareIntake {
  const ShareIntake();

  static const MethodChannel _methods = MethodChannel('com.grs.perch/share');
  static const EventChannel _events = EventChannel(
    'com.grs.perch/share_events',
  );

  /// The share that started the app, if it was started by one. Consumed on
  /// read, so a later restart does not save it twice.
  Future<String?> initialText() async {
    try {
      return await _methods.invokeMethod<String>('getInitialText');
    } on PlatformException {
      return null;
    }
  }

  /// Shares arriving while Perch is already running.
  Stream<String> texts() =>
      _events.receiveBroadcastStream().map((Object? e) => e as String);
}

/// Saves a shared link straight into Unsorted and fetches its metadata in the
/// background — the share sheet's job is to be instant.
class ShareHandler {
  ShareHandler(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _subscription;

  /// Emits the id of each link saved from a share, so the UI can confirm it.
  final StreamController<int> saved = StreamController<int>.broadcast();

  Future<void> start() async {
    const ShareIntake intake = ShareIntake();
    final String? initial = await intake.initialText();
    if (initial != null) await _handle(initial);
    _subscription = intake.texts().listen(_handle);
  }

  Future<void> _handle(String text) async {
    final String? url = extractUrl(text);
    if (url == null) return;
    final int id = await _ref.read(linkSaverProvider).save(url: url);
    if (!saved.isClosed) saved.add(id);
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(saved.close());
  }
}

final Provider<ShareHandler> shareHandlerProvider = Provider<ShareHandler>((
  Ref ref,
) {
  final ShareHandler handler = ShareHandler(ref);
  ref.onDispose(handler.dispose);
  return handler;
});
