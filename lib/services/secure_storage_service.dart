import 'dart:convert';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

/// Giao diện lưu trữ khóa-giá trị bảo mật (Keystore / Keychain), cho phép mock trong unit test.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Triển khai mặc định dùng `flutter_secure_storage` (Android Keystore / iOS Keychain).
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  final FlutterSecureStorage _storage;

  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// Bộ nhớ tạm trong RAM dùng cho unit test hoặc fallback khi môi trường không có plugin native.
class InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  Map<String, String> get snapshot => Map.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();
}

/// Dịch vụ lưu dữ liệu xác thực nhạy cảm (`authUser`, `rememberDeviceToken`) bằng secure storage,
/// kèm bộ đệm RAM đồng bộ để các getter đồng bộ của `PreferencesService` vẫn hoạt động không đổi API.
class SecureStorageService {
  static const String keyAuthUser = 'pf_secure_auth_user';
  static const String keyRememberDeviceToken = 'pf_secure_remember_device_token';

  static SecureKeyValueStore _store = FlutterSecureKeyValueStore();
  static bool _isCustomTestStore = false;
  static bool _usingFallbackMemory = false;

  static String? _cachedAuthUserJson;
  static String? _cachedRememberDeviceToken;

  static SecureKeyValueStore get store => _store;

  /// Gán store giả lập trong unit test (không bị tự động reset giữa các lần gọi `init`).
  @visibleForTesting
  static void setStoreForTesting(SecureKeyValueStore? customStore) {
    if (customStore != null) {
      _store = customStore;
      _isCustomTestStore = true;
      _usingFallbackMemory = false;
    } else {
      _store = FlutterSecureKeyValueStore();
      _isCustomTestStore = false;
      _usingFallbackMemory = false;
    }
    _cachedAuthUserJson = null;
    _cachedRememberDeviceToken = null;
  }

  /// Tải sẵn `authUser` và `rememberDeviceToken` từ secure storage vào bộ đệm đồng bộ.
  static Future<void> init() async {
    if (_usingFallbackMemory && !_isCustomTestStore) {
      await _store.deleteAll();
    }
    _cachedAuthUserJson = await _safeRead(keyAuthUser);
    _cachedRememberDeviceToken = await _safeRead(keyRememberDeviceToken);
  }

  static String? getAuthUserJsonSync() => _cachedAuthUserJson;

  static Future<void> setAuthUserJson(String? json) async {
    if (json == null || json.isEmpty) {
      _cachedAuthUserJson = null;
      await _safeDelete(keyAuthUser);
    } else {
      _cachedAuthUserJson = json;
      await _safeWrite(keyAuthUser, json);
    }
  }

  static String? getRememberDeviceTokenSync() => _cachedRememberDeviceToken;

  static Future<void> setRememberDeviceToken(String? token) async {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _cachedRememberDeviceToken = null;
      await _safeDelete(keyRememberDeviceToken);
    } else {
      _cachedRememberDeviceToken = trimmed;
      await _safeWrite(keyRememberDeviceToken, trimmed);
    }
  }

  static Future<void> clearAuthCredentials() async {
    _cachedAuthUserJson = null;
    await _safeDelete(keyAuthUser);
  }

  static Future<void> clearAllCredentials() async {
    _cachedAuthUserJson = null;
    _cachedRememberDeviceToken = null;
    await _safeDelete(keyAuthUser);
    await _safeDelete(keyRememberDeviceToken);
  }

  static Future<String?> _safeRead(String key) async {
    try {
      return await _store.read(key);
    } on MissingPluginException {
      _switchToFallbackMemory();
      return _store.read(key);
    } catch (e) {
      debugPrint('[SecureStorage] read($key) thất bại: $e');
      return null;
    }
  }

  static Future<void> _safeWrite(String key, String value) async {
    try {
      await _store.write(key, value);
    } on MissingPluginException {
      _switchToFallbackMemory();
      await _store.write(key, value);
    } catch (e) {
      debugPrint('[SecureStorage] write($key) thất bại: $e');
    }
  }

  static Future<void> _safeDelete(String key) async {
    try {
      await _store.delete(key);
    } on MissingPluginException {
      _switchToFallbackMemory();
      await _store.delete(key);
    } catch (e) {
      debugPrint('[SecureStorage] delete($key) thất bại: $e');
    }
  }

  static void _switchToFallbackMemory() {
    if (!_isCustomTestStore && !_usingFallbackMemory) {
      _store = InMemorySecureStore();
      _usingFallbackMemory = true;
    }
  }
}

/// `Storage` cho `PersistCookieJar` lưu toàn bộ cookie phiên (`pf_access`, `pf_refresh`, `pf_2fa`)
/// trong `SecureKeyValueStore` thay vì file văn bản rõ `.cookies`.
class SecureCookieStorage implements Storage {
  static const String _prefix = 'pf_cookie_v1_';
  static const String _keyIndexName = '${_prefix}__keys';

  final SecureKeyValueStore _store;
  String _namespace = '';

  SecureCookieStorage({SecureKeyValueStore? store}) : _store = store ?? SecureStorageService.store;

  String _storageKey(String key) => '$_prefix${_namespace}_$key';

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {
    _namespace = 'ie${ignoreExpires ? 1 : 0}_ps${persistSession ? 1 : 0}';
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _store.read(_storageKey(key));
    } catch (e) {
      debugPrint('[SecureCookieStorage] read($key) lỗi: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final fullKey = _storageKey(key);
    try {
      await _store.write(fullKey, value);
      final keys = await _loadKeyIndex();
      if (keys.add(fullKey)) {
        await _store.write(_keyIndexName, jsonEncode(keys.toList()));
      }
    } catch (e) {
      debugPrint('[SecureCookieStorage] write($key) lỗi: $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    final fullKey = _storageKey(key);
    try {
      await _store.delete(fullKey);
      final keys = await _loadKeyIndex();
      if (keys.remove(fullKey)) {
        await _store.write(_keyIndexName, jsonEncode(keys.toList()));
      }
    } catch (e) {
      debugPrint('[SecureCookieStorage] delete($key) lỗi: $e');
    }
  }

  @override
  Future<void> deleteAll(List<String> keys) async {
    try {
      final tracked = await _loadKeyIndex();
      final allToDelete = <String>{
        ...tracked,
        for (final k in keys) _storageKey(k),
      };
      for (final fullKey in allToDelete) {
        await _store.delete(fullKey);
      }
      await _store.delete(_keyIndexName);
    } catch (e) {
      debugPrint('[SecureCookieStorage] deleteAll lỗi: $e');
    }
  }

  /// Di chuyển an toàn cookie phiên từ thư mục `.cookies` dạng rõ cũ sang secure storage,
  /// sau đó xóa sạch thư mục `.cookies` cũ để không còn cookie dạng rõ trên đĩa.
  Future<int> migrateLegacyCookieDir(Directory legacyDir) async {
    if (!await legacyDir.exists()) return 0;
    var migrated = 0;
    try {
      // FileStorage của PersistCookieJar(persistSession: true, ignoreExpires: false) lưu trong thư mục con ie0_ps1.
      final subDir = Directory(p.join(legacyDir.path, 'ie0_ps1'));
      final sourceDir = await subDir.exists() ? subDir : legacyDir;

      if (_namespace.isEmpty) {
        await init(true, false);
      }

      await for (final entity in sourceDir.list(recursive: false, followLinks: false)) {
        if (entity is! File) continue;
        final key = p.basename(entity.path);
        try {
          final content = await entity.readAsString();
          if (content.isNotEmpty) {
            final existing = await read(key);
            if (existing == null || existing.isEmpty) {
              await write(key, content);
              migrated++;
            }
          }
        } catch (e) {
          debugPrint('[SecureCookieStorage] Bỏ qua file cookie cũ lỗi ($key): $e');
        }
      }
    } catch (e) {
      debugPrint('[SecureCookieStorage] Lỗi di chuyển thư mục .cookies cũ: $e');
    } finally {
      try {
        if (await legacyDir.exists()) {
          await legacyDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('[SecureCookieStorage] Không thể xóa thư mục .cookies cũ: $e');
      }
    }
    return migrated;
  }

  Future<Set<String>> _loadKeyIndex() async {
    try {
      final raw = await _store.read(_keyIndexName);
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }
}
