import 'dart:js_interop';
import 'dart:ui';

@JS('window.open')
external JSAny? _openWindow(JSString url, JSString target, JSString features);

Future<void> openWebUrl(String url) async {
  final uri = Uri.parse(url);
  if (uri.scheme != 'https' || uri.host.isEmpty) {
    throw ArgumentError.value(url, 'url', 'An HTTPS URL is required.');
  }
  _openWindow(uri.toString().toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
}

Future<void> openExternalUrl(String url, {Rect? sharePositionOrigin}) async {
  _openWindow(url.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
}
