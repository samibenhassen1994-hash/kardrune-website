import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> shareClan(String url) async {
  try {
    await web.window.navigator
        .share(web.ShareData(title: 'Rune Clans', url: url))
        .toDart;
    return true;
  } catch (_) {
    return false;
  }
}

/// Remove the consumed ?clan= without reloading the Web/PWA route.
/// Retain other URL parameters, fragments, and browser history state.
void clearClanInviteUrl() {
  try {
    final current = Uri.parse(web.window.location.href);
    if (!current.queryParameters.containsKey('clan')) return;
    final remaining = Map<String, String>.of(current.queryParameters)
      ..remove('clan');
    final cleaned = remaining.isEmpty
        ? current.replace(query: '')
        : current.replace(queryParameters: remaining);
    web.window.history.replaceState(
      web.window.history.state,
      '',
      cleaned.toString(),
    );
  } catch (_) {
    // Never block the app or an invitation because history access fails.
  }
}
