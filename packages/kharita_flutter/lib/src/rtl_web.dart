import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool _requested = false;

/// MapLibre GL JS needs a plugin to shape Arabic and Hebrew labels.
void ensureRtlPlugin(String url) {
  if (_requested) return;
  final lib = globalContext['maplibregl'] as JSObject?;
  if (lib == null) return;
  final status = lib.callMethod<JSString>('getRTLTextPluginStatus'.toJS).toDart;
  if (status != 'unavailable') return;
  _requested = true;
  lib.callMethod<JSAny?>('setRTLTextPlugin'.toJS, url.toJS, true.toJS);
}
