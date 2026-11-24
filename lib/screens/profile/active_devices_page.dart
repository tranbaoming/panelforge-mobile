import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/api_providers.dart';
import '../../theme/app_theme.dart';

/// Màn hình quản lý các thiết bị đang đăng nhập (`/settings/devices`).
/// Hiển thị giới hạn thiết bị đồng thời (mặc định 3 máy) và cho phép đăng xuất từ xa.
class ActiveDevicesPage extends ConsumerStatefulWidget {
  const ActiveDevicesPage({super.key});

  @override
  ConsumerState<ActiveDevicesPage> createState() => _ActiveDevicesPageState();
}

class _ActiveDevicesPageState extends ConsumerState<ActiveDevicesPage> {
  ActiveSessionsResponse? _data;
  bool _loading = true;
  String? _error;
  String? _revokingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(authServiceProvider).getActiveSessions();
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _revoke(ActiveSessionModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ForgeColors.surface,
        title: Text(
          'Đăng xuất thiết bị này?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ForgeColors.text),
        ),
        content: Text(
          'Thiết bị "${session.deviceName}" sẽ bị đăng xuất khỏi tài khoản PanelForge của bạn.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: ForgeColors.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ForgeColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _revokingId = session.sessionId);
    try {
      final msg = await ref.read(authServiceProvider).revokeSession(session.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể đăng xuất thiết bị: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _revokingId = null);
    }
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return 'Không rõ';
    final local = dt.toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(local.day)}/${p(local.month)}/${local.year} ${p(local.hour)}:${p(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: AppBar(
        backgroundColor: ForgeColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Thiết bị đang đăng nhập',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: ForgeColors.text),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: Icon(Icons.refresh_rounded, color: ForgeColors.text),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 42, color: ForgeColors.muted),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(color: ForgeColors.muted),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: ForgeColors.accent),
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ForgeColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ForgeColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.devices_rounded, color: ForgeColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tài khoản cho phép tối đa ${_data?.maxConcurrentSessions ?? 3} thiết bị đăng nhập đồng thời. '
                                'Khi đăng nhập thêm, thiết bị cũ nhất sẽ tự động đăng xuất.',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.textSoft),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_data == null || _data!.sessions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Chưa ghi nhận thiết bị nào đang hoạt động.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(color: ForgeColors.muted),
                          ),
                        )
                      else
                        for (final session in _data!.sessions)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: ForgeColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: session.isCurrent ? ForgeColors.accent : ForgeColors.divider,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                session.isCurrent ? Icons.smartphone_rounded : Icons.devices_other_rounded,
                                color: session.isCurrent ? ForgeColors.accent : ForgeColors.muted,
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      session.deviceName,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: ForgeColors.text,
                                      ),
                                    ),
                                  ),
                                  if (session.isCurrent) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ForgeColors.accentSoft,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        'Thiết bị này',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: ForgeColors.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                'Hoạt động: ${_formatTime(session.lastActiveAt)}'
                                '${session.ipAddress != null && session.ipAddress!.isNotEmpty ? '\nIP: ${session.ipAddress}' : ''}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted),
                              ),
                              isThreeLine: session.ipAddress != null && session.ipAddress!.isNotEmpty,
                              trailing: session.isCurrent
                                  ? null
                                  : _revokingId == session.sessionId
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : TextButton(
                                          onPressed: () => _revoke(session),
                                          child: Text(
                                            'Đăng xuất',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppColors.rose,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
