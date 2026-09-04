import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers.dart';
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

  /// Emits each share outcome, so the UI can confirm it — or, when the URL was
  /// already saved, say so instead (B6).
  final StreamController<ShareResult> saved =
      StreamController<ShareResult>.broadcast();

  Future<void> start() async {
    const ShareIntake intake = ShareIntake();
    final String? initial = await intake.initialText();
    if (initial != null) await _handle(initial);
    _subscription = intake.texts().listen(_handle);
  }

  Future<void> _handle(String text) async {
    final String? extracted = extractUrl(text);
    if (extracted == null) return;
    final String url = normalizeUrl(extracted);

    // B6 — a share of something already saved confirms the existing link
    // rather than quietly making a second copy.
    final Link? existing = await _ref.read(linkRepositoryProvider).byUrl(url);
    if (existing != null) {
      if (!saved.isClosed) {
        saved.add(ShareResult(id: existing.id, duplicate: true));
      }
      return;
    }

    final int id = await _ref.read(linkSaverProvider).save(url: url);
    if (!saved.isClosed) saved.add(ShareResult(id: id));
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(saved.close());
  }
}

/// What a share turned into.
class ShareResult {
  const ShareResult({required this.id, this.duplicate = false});

  final int id;
  final bool duplicate;
}

final Provider<ShareHandler> shareHandlerProvider = Provider<ShareHandler>((
  Ref ref,
) {
  final ShareHandler handler = ShareHandler(ref);
  ref.onDispose(handler.dispose);
  return handler;
});
