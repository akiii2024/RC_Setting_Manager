import 'dart:js_interop';
import 'dart:ui';

@JS('window.open')
external JSAny? _openWindow(JSString url, JSString target, JSString features);

Future<void> openExternalUrl(String url, {Rect? sharePositionOrigin}) async {
  _openWindow(url.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
}
