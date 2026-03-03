import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CookieEntry {
  final String name;
  final String value;
  final String domain;
  final String path;
  final DateTime? expires;
  final bool secure;
  final bool httpOnly;

  const CookieEntry({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.expires,
    this.secure = false,
    this.httpOnly = false,
  });

  factory CookieEntry.fromJson(Map<String, dynamic> json) {
    return CookieEntry(
      name: json['name'] as String,
      value: json['value'] as String,
      domain: json['domain'] as String,
      path: json['path'] as String? ?? '/',
      expires: json['expires'] != null
          ? DateTime.tryParse(json['expires'] as String)
          : null,
      secure: json['secure'] as bool? ?? false,
      httpOnly: json['http_only'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'domain': domain,
        'path': path,
        'expires': expires?.toIso8601String(),
        'secure': secure,
        'http_only': httpOnly,
      };

  String toCookieString() => '$name=$value';
}

class SiteSession {
  final String siteId;
  final List<CookieEntry> cookies;
  final DateTime lastUsed;
  final bool isValid;

  const SiteSession({
    required this.siteId,
    required this.cookies,
    required this.lastUsed,
    this.isValid = true,
  });

  factory SiteSession.fromJson(Map<String, dynamic> json) {
    return SiteSession(
      siteId: json['site_id'] as String,
      cookies: (json['cookies'] as List<dynamic>)
          .map((c) => CookieEntry.fromJson(c as Map<String, dynamic>))
          .toList(),
      lastUsed: DateTime.parse(json['last_used'] as String),
      isValid: json['is_valid'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'site_id': siteId,
        'cookies': cookies.map((c) => c.toJson()).toList(),
        'last_used': lastUsed.toIso8601String(),
        'is_valid': isValid,
      };

  bool get isExpired {
    for (final cookie in cookies) {
      if (cookie.expires != null && cookie.expires!.isBefore(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  String get cookieHeader =>
      cookies.map((c) => c.toCookieString()).join('; ');
}

/// Cookie 安全存储服务（使用 Keychain/Keystore）
class CookieService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String _key(String siteId) => 'session_$siteId';

  Future<void> saveSession(String siteId, List<CookieEntry> cookies) async {
    final session = SiteSession(
      siteId: siteId,
      cookies: cookies,
      lastUsed: DateTime.now(),
    );
    await _storage.write(
      key: _key(siteId),
      value: jsonEncode(session.toJson()),
    );
  }

  Future<SiteSession?> getSession(String siteId) async {
    final raw = await _storage.read(key: _key(siteId));
    if (raw == null) return null;
    try {
      return SiteSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isSessionValid(String siteId) async {
    final session = await getSession(siteId);
    if (session == null) return false;
    return session.isValid && !session.isExpired;
  }

  Future<void> invalidateSession(String siteId) async {
    await _storage.delete(key: _key(siteId));
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<List<String>> listSiteIds() async {
    final all = await _storage.readAll();
    return all.keys
        .where((k) => k.startsWith('session_'))
        .map((k) => k.substring('session_'.length))
        .toList();
  }

  Future<void> cleanupExpired() async {
    final siteIds = await listSiteIds();
    for (final siteId in siteIds) {
      final session = await getSession(siteId);
      if (session != null && session.isExpired) {
        await invalidateSession(siteId);
      }
    }
  }
}
