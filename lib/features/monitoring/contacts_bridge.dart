import 'package:flutter/services.dart';

/// Reads the device address book (name, phones, emails) via the native
/// monitoring plugin for the `contact.snapshot` collector.
///
/// Photo blobs are never read — the backend strips them anyway. Consent for the
/// `contacts` scope is enforced server-side on ingest; this bridge only returns
/// data when the OS READ_CONTACTS permission has been granted.
///
/// Each entry: `{contact_id, name, phones: List<String>, emails: List<String>}`.
class ContactsBridge {
  ContactsBridge._();

  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');

  static Future<List<Map<String, dynamic>>> getContacts({
    int limit = 2000,
  }) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getContacts',
        {'limit': limit},
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}
