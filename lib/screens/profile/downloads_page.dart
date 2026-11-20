import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/read_guard.dart';
import '../../providers/api_providers.dart';
import '../../services/cbz_package_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';

/// Dung lượng từng chương đã tải (chapterId → bytes), đọc từ thư mục offline trên máy.
final downloadSizesProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final ids = ref.watch(downloadedChaptersProvider);
  final service = ref.watch(cbzPackageServiceProvider);
  return {for (final id in ids) id: await service.getDownloadedPackageSize(id)};
});

/// `/downloads` — chương đã tải để đọc offline: nhóm theo bộ truyện, dung lượng, xoá từng chương / xoá hết.
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(downloadedChaptersProvider);
    final sizes = ref.watch(downloadSizesProvider).asData?.value ?? const <String, int>{};
    final meta = PreferencesService.getOfflineChapterMeta();
    final total = sizes.values.fold<int>(0, (a, b) => a + b);

    // Nhóm theo bộ truyện; chương tải từ bản cũ chưa có thông tin → nhóm "Chương khác".
    final groups = <String, List<String>>{};
    for (final id in ids) {
      final key = meta[id]?.seriesTitle ?? '';
      groups.putIfAbsent(key, () => []).add(id);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    for (final list in groups.values) {
      list.sort((a, b) => (meta[a]?.chapterNumber ?? 0).compareTo(meta[b]?.chapterNumber ?? 0));
    }

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: AppBar(
        backgroundColor: ForgeColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Truyện đã tải',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: ForgeColors.text),
        ),
        actions: [
          if (ids.isNotEmpty)
            TextButton(
              onPressed: () => _confirmDeleteAll(context, ref, ids.length),
              child: Text(
                'Xoá hết',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ForgeColors.danger),
              ),
            ),
        ],
      ),
      body: ids.isEmpty
          ? const Center(
              child: ForgeEmptyState(
                icon: Icons.download_for_offline_outlined,
                message: 'Chưa tải chương nào.\nMở một bộ truyện và chọn tải chương để đọc khi không có mạng.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: ForgeColors.card, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.sd_storage_rounded, color: ForgeColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${ids.length} chương',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ForgeColors.text),
                        ),
                      ),
                      Text(
                        CbzPackageService.formatBytes(total),
                        key: const ValueKey('downloads-total'),
                        style: ForgeText.tabular(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                for (final key in keys) ...[
                  ForgeSectionHeader(title: key.isEmpty ? 'Chương khác' : key),
                  Container(
                    decoration: BoxDecoration(color: ForgeColors.card, borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          for (final (i, id) in groups[key]!.indexed) ...[
                            if (i > 0) Divider(height: 1, color: ForgeColors.divider),
                            _DownloadTile(chapterId: id, info: meta[id], bytes: sizes[id]),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá tất cả chương đã tải?'),
        content: Text('$count chương sẽ bị xoá khỏi máy. Bạn vẫn đọc online được và có thể tải lại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá hết')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cbzPackageServiceProvider).clearAllOfflinePackages();
    ref.read(downloadedChaptersProvider.notifier).refresh();
  }
}

class _DownloadTile extends ConsumerWidget {
  final String chapterId;
  final OfflineChapterInfo? info;
  final int? bytes;
  const _DownloadTile({required this.chapterId, required this.info, required this.bytes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = info == null
        ? 'Chương đã tải'
        : 'Chương ${info!.chapterNumberLabel}${info!.chapterTitle.isEmpty ? '' : ' • ${chapterSubtitle(info!.chapterTitle)}'}';
    return ListTile(
      key: ValueKey('download-$chapterId'),
      onTap: info == null ? null : () => openReaderGuarded(context, ref, info!.seriesId, chapterId),
      leading: const Icon(Icons.offline_pin_rounded, color: ForgeColors.green),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ForgeColors.text),
      ),
      subtitle: Text(
        [
          if (bytes != null) CbzPackageService.formatBytes(bytes!),
          if (info != null) 'Tải ${timeAgo(info!.downloadedAt)}',
        ].join(' • '),
        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted),
      ),
      trailing: IconButton(
        tooltip: 'Xoá chương đã tải',
        icon: const Icon(Icons.delete_outline_rounded, color: ForgeColors.muted),
        onPressed: () async {
          await ref.read(cbzPackageServiceProvider).deleteOfflinePackage(chapterId);
          ref.read(downloadedChaptersProvider.notifier).remove(chapterId);
        },
      ),
    );
  }
}
