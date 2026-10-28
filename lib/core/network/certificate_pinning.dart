import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:one_request/one_request.dart';
import 'package:spy_love/core/debug/app_log.dart';

/// Optional TLS certificate pinning for the shared Dio client.
///
/// Disabled by default. Enable at build time with:
///   `--dart-define=ENABLE_CERT_PINNING=true`
///   `--dart-define=CERT_PINS=comma-separated-SHA256-hex-fingerprints`
///
/// Do not commit real pins or hostnames. Pins are compared case-insensitively
/// against the SHA-256 digest of the leaf certificate DER bytes.
///
/// WebSocket clients (OneSocket) are not covered by this Dio adapter; pin
/// those separately if required.
abstract final class CertificatePinning {
  static const bool enabled = bool.fromEnvironment(
    'ENABLE_CERT_PINNING',
    defaultValue: false,
  );

  static const String pinsRaw = String.fromEnvironment(
    'CERT_PINS',
    defaultValue: '',
  );

  static Set<String> get _pins => {
    for (final part in pinsRaw.split(','))
      if (part.trim().isNotEmpty) part.trim().toLowerCase().replaceAll(':', ''),
  };

  /// Wires [OneRequest.client] when [enabled] and at least one pin is set.
  static void applyToSharedClient() {
    if (kIsWeb) return;
    if (!enabled) {
      AppLog.d('Certificate pinning disabled (ENABLE_CERT_PINNING=false)');
      return;
    }
    final pins = _pins;
    if (pins.isEmpty) {
      AppLog.d('Certificate pinning enabled but CERT_PINS is empty; skipping');
      return;
    }

    OneRequest.client.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient(),
      validateCertificate: (cert, host, port) {
        if (cert == null) return false;
        final digest = sha256.convert(cert.der).toString().toLowerCase();
        final ok = pins.contains(digest);
        if (!ok) {
          AppLog.d('Cert pin mismatch for host length=${host.length}');
        }
        return ok;
      },
    );
    AppLog.d('Certificate pinning active (${pins.length} pin(s))');
  }
}
