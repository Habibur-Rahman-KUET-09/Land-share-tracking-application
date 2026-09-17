/// Hands a generated file (Excel report) to the platform's own "share"
/// affordance: the share sheet on Android/iOS, a browser download on the
/// web. The two have nothing in common at the API level, so the real
/// implementation is picked at compile time — `dart:io` simply does not
/// exist in a browser, and importing it unconditionally breaks the whole
/// web build.
///
/// PDF export doesn't need this: `Printing.sharePdf` already does the
/// equivalent on every platform.
export 'byte_share_io.dart' if (dart.library.js_interop) 'byte_share_web.dart';
