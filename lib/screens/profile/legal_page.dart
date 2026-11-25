import 'package:flutter/material.dart';
import '../../navigation/back_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../content/legal_content.dart';
import '../../services/google_play_billing_service.dart';
import '../../theme/app_theme.dart';

/// Trang văn bản: Điều khoản sử dụng, Chính sách bảo mật, Bản quyền, Câu hỏi thường gặp (`/legal/:id`).
class LegalPage extends StatelessWidget {
  final String docId;
  const LegalPage({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    final doc = legalDocumentsFor(googlePlayBilling: GooglePlayBillingService.isSupportedPlatform)[docId];
    final isFaq = docId == 'faq';
    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: AppBar(
        backgroundColor: ForgeColors.bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: Icon(Icons.arrow_back_rounded, color: ForgeColors.text),
          onPressed: () => context.popOrGo('/settings'),
        ),
        title: Text(
          doc?.title ?? 'Không tìm thấy',
          style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: ForgeColors.text),
        ),
      ),
      body: doc == null
          ? Center(
              child: Text('Không tìm thấy văn bản.', style: GoogleFonts.plusJakartaSans(color: ForgeColors.muted)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Cập nhật: ${doc.updated}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.muted),
                ),
                if (doc.intro != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    doc.intro!,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14.5, color: ForgeColors.textSoft, height: 1.55),
                  ),
                ],
                const SizedBox(height: 8),
                for (final s in doc.sections) isFaq ? _FaqTile(section: s) : _Section(section: s),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final LegalSection section;
  const _Section({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: ForgeColors.text),
          ),
          const SizedBox(height: 6),
          for (final p in section.body)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                p,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.textSoft, height: 1.55),
              ),
            ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final LegalSection section;
  const _FaqTile({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: ForgeColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ForgeColors.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: ForgeColors.muted,
            collapsedIconColor: ForgeColors.muted,
            title: Text(
              section.heading,
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: ForgeColors.text),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            expandedAlignment: Alignment.centerLeft,
            children: [
              for (final p in section.body)
                Text(p, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.textSoft, height: 1.55)),
            ],
          ),
        ),
      ),
    );
  }
}
