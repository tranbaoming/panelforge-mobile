import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic_model.dart';
import '../services/library_sync_service.dart';
import '../services/preferences_service.dart';
import 'api_providers.dart';
import 'catalog_providers.dart';
import 'notification_providers.dart';

final librarySyncServiceProvider = Provider<LibrarySyncService>(
  (ref) => LibrarySyncService(ref.watch(apiClientProvider)),
);

/// Trạng thái đồng bộ thư viện cá nhân (Đọc sau / Theo dõi / Yêu thích / Lịch sử) với server.
class LibrarySyncState {
  final bool syncing;
  final DateTime? lastSyncedAt;
  final String? error;

  /// Tăng mỗi lần thư viện trên máy được ghi đè từ server — màn hình watch để vẽ lại.
  final int version;

  const LibrarySyncState({this.syncing = false, this.lastSyncedAt, this.error, this.version = 0});

  LibrarySyncState copyWith({
    bool? syncing,
    DateTime? lastSyncedAt,
    String? error,
    bool clearError = false,
    int? version,
  }) => LibrarySyncState(
    syncing: syncing ?? this.syncing,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: clearError ? null : (error ?? this.error),
    version: version ?? this.version,
  );
}

/// Đăng nhập (hoặc mở app khi đã đăng nhập) → gộp thư viện trên máy với server rồi ghi đè bản trên máy.
/// Sau đó mỗi thay đổi trên máy được gửi ngay lên server; tiến độ đọc gửi gộp sau [progressDebounce].
/// Gửi lỗi (mất mạng) thì lần gộp kế tiếp sẽ bù — riêng thao tác bỏ khỏi danh sách khi offline có thể bị khôi phục.
final librarySyncProvider = NotifierProvider<LibrarySyncNotifier, LibrarySyncState>(LibrarySyncNotifier.new);

class LibrarySyncNotifier extends Notifier<LibrarySyncState> {
  static const progressDebounce = Duration(seconds: 3);

  final Map<String, Timer> _progressTimers = {};
  Future<void>? _running;

  LibrarySyncService get _service => ref.read(librarySyncServiceProvider);

  bool get _signedIn => ref.read(authStateProvider).isAuthenticated;

  @override
  LibrarySyncState build() {
    PreferencesService.onLibraryChanged = _onLocalChange;
    ref.onDispose(() {
      if (PreferencesService.onLibraryChanged == _onLocalChange) PreferencesService.onLibraryChanged = null;
      for (final t in _progressTimers.values) {
        t.cancel();
      }
      _progressTimers.clear();
    });
    ref.listen<bool>(authStateProvider.select((a) => a.isAuthenticated), (was, now) {
      if (now && was != true) unawaited(syncNow());
    });
    if (_signedIn) Future.microtask(syncNow);
    return const LibrarySyncState();
  }

  /// Gộp hai chiều với server. Gọi đồng thời nhiều lần chỉ chạy một lượt.
  Future<void> syncNow() => _running ??= _sync().whenComplete(() => _running = null);

  Future<void> _sync() async {
    if (!_signedIn) return;
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final local = LocalLibrarySnapshot.fromPreferences();
      final server = await _service.merge(local);
      final titles = <String, String>{
        for (final s in ref.read(catalogSeriesProvider).asData?.value ?? const <SeriesItem>[]) s.id: s.title,
        for (final h in local.history) h.seriesId: h.seriesTitle,
      };
      await PreferencesService.replaceLibraryFromServer(
        readLater: server.readLater,
        following: server.following,
        favorites: server.favorites,
        history: [for (final p in server.history) p.toEntry(titles[p.seriesId] ?? '')],
      );
      ref.read(followUpdatesProvider.notifier).recompute();
      state = state.copyWith(syncing: false, lastSyncedAt: DateTime.now(), version: state.version + 1);
    } catch (e) {
      debugPrint('[LibrarySync] Không đồng bộ được thư viện: $e');
      state = state.copyWith(syncing: false, error: e.toString());
    }
  }

  void _onLocalChange(LibraryChange change) {
    if (!_signedIn) return;
    if (change.progress != null) {
      final entry = change.progress!;
      _progressTimers.remove(entry.seriesId)?.cancel();
      _progressTimers[entry.seriesId] = Timer(progressDebounce, () {
        _progressTimers.remove(entry.seriesId);
        _send(() => _service.saveProgress(entry));
      });
      return;
    }
    if (change.clearHistory) {
      for (final t in _progressTimers.values) {
        t.cancel();
      }
      _progressTimers.clear();
      _send(_service.clearHistory);
      return;
    }
    _send(() => _service.setItem(change.list!, change.seriesId!, added: change.added, lastSeenAt: change.lastSeenAt));
  }

  void _send(Future<void> Function() call) {
    unawaited(
      call().catchError((Object e) {
        debugPrint('[LibrarySync] Gửi thay đổi thất bại, sẽ gộp lại ở lần đồng bộ sau: $e');
      }),
    );
  }
}
