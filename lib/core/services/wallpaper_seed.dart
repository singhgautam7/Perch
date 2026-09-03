import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Material You accent Android derives from the wallpaper.
///
/// Null below Android 12, where there is no system palette — the Appearance
/// screen's Dynamic colour toggle then simply has nothing to apply and the
/// chosen family stays in effect.
final FutureProvider<Color?> wallpaperSeedProvider = FutureProvider<Color?>((
  Ref ref,
) async {
  const MethodChannel channel = MethodChannel('com.grs.perch/share');
  try {
    final int? argb = await channel.invokeMethod<int>('getWallpaperAccent');
    return argb == null ? null : Color(argb);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
});
