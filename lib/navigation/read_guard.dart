import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/comic_model.dart';
import '../providers/api_providers.dart';
import '../widgets/read_login_prompt_sheet.dart';

/// Lazy Authentication: mở app, lướt Trang chủ / Khám phá / Tìm kiếm / Chi tiết truyện / DS Chương tự do;
/// chỉ khi mở một chương để đọc mới cần tài khoản thật.

/// Được đọc chương khi đã đăng nhập bằng tài khoản thật (không phải Khách / chưa đăng nhập).
bool canReadChapters(AuthState auth) => auth.isAuthenticated;

String readerPath(String seriesId, String chapterId) =>
    '/reader/$seriesId?chapterId=${Uri.encodeQueryComponent(chapterId)}';

/// `/login?redirect=<đích>` — dùng khi điều hướng thẳng tới `/reader/...` mà chưa đăng nhập.
String loginPathFor(String target) => '/login?redirect=${Uri.encodeComponent(target)}';

/// Chỉ chấp nhận đường dẫn nội bộ của app (chặn open redirect và vòng lặp về /login).
String? safeLoginRedirect(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (!raw.startsWith('/') || raw.startsWith('//') || raw.contains('://')) return null;
  if (raw == '/login' || raw.startsWith('/login?') || raw.startsWith('/login/')) return null;
  return raw;
}

/// Bảo đảm người dùng đã đăng nhập trước khi đọc.
///
/// Chưa đăng nhập → sheet mời đăng nhập (ảnh bìa [series], "Tiếp Theo" / "Để sau").
/// Tiếp Theo → màn Đăng nhập Email-first (nhập Email → Mật khẩu nếu đã có tài khoản / Đăng ký nếu chưa).
///
/// Trả `true` khi đã (hoặc vừa) đăng nhập thành công — caller tiếp tục mở đúng chương vừa bấm.
/// Trả `false` khi người dùng chọn Để sau hoặc đóng màn Đăng nhập.
Future<bool> ensureLoggedInForReading(BuildContext context, WidgetRef ref, {SeriesItem? series}) async {
  if (canReadChapters(ref.read(authStateProvider))) return true;
  final goLogin = await ReadLoginPromptSheet.show(context, series: series);
  if (!goLogin || !context.mounted) return false;
  await context.push<bool>('/login');
  return canReadChapters(ref.read(authStateProvider));
}

/// Mở chương [chapterId] của bộ [seriesId]; yêu cầu đăng nhập trước nếu cần.
Future<void> openReaderGuarded(
  BuildContext context,
  WidgetRef ref,
  String seriesId,
  String chapterId, {
  SeriesItem? series,
}) async {
  if (!await ensureLoggedInForReading(context, ref, series: series)) return;
  if (!context.mounted) return;
  context.push(readerPath(seriesId, chapterId));
}
