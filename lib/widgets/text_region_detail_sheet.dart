import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_package_models.dart';
import '../theme/app_theme.dart';

class TextRegionDetailSheet extends StatefulWidget {
  final TextRegion region;
  final String activeLanguage;
  final LoadedComicPackage? package;

  const TextRegionDetailSheet({
    super.key,
    required this.region,
    required this.activeLanguage,
    this.package,
  });

  static Future<void> show(
    BuildContext context, {
    required TextRegion region,
    required String activeLanguage,
    LoadedComicPackage? package,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TextRegionDetailSheet(
        region: region,
        activeLanguage: activeLanguage,
        package: package,
      ),
    );
  }

  @override
  State<TextRegionDetailSheet> createState() => _TextRegionDetailSheetState();
}

class _TextRegionDetailSheetState extends State<TextRegionDetailSheet> {
  AudioPlayer? _audioPlayer;
  bool _isPlayingTts = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _playTts(String? ttsText) async {
    if (ttsText == null || ttsText.trim().isEmpty) return;

    setState(() => _isPlayingTts = true);

    try {
      // Nếu ttsText là URL âm thanh (.mp3, .wav), phát qua AudioPlayer
      if (ttsText.startsWith('http://') || ttsText.startsWith('https://')) {
        await _audioPlayer?.play(UrlSource(ttsText));
      } else {
        // Mô phỏng hiệu ứng phát âm thanh TTS
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    } catch (e) {
      debugPrint('[TTS Error] $e');
    } finally {
      if (mounted) {
        setState(() => _isPlayingTts = false);
      }
    }
  }

  String _getRegionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'thought':
        return 'SUY NGHĨ (THOUGHT)';
      case 'narration':
        return 'THUYẾT MINH (NARRATION)';
      case 'sfx':
        return 'HIỆU ỨNG ÂM THANH (SFX)';
      case 'speech':
      default:
        return 'BÓNG THOẠI (SPEECH)';
    }
  }

  IconData _getRegionTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'thought':
        return Icons.cloud_outlined;
      case 'narration':
        return Icons.auto_stories_outlined;
      case 'sfx':
        return Icons.graphic_eq_rounded;
      case 'speech':
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTranslation = widget.package?.getTranslation(widget.activeLanguage, widget.region.id);
    final displayText = activeTranslation?.text ?? 'Chưa có bản dịch cho vùng thoại này.';
    final note = activeTranslation?.furiganaOrNote;
    final ttsText = activeTranslation?.ttsText ?? displayText;

    // Lấy các bản dịch ở các ngôn ngữ khác để đối chiếu song ngữ
    final otherTranslations = <String, TranslationEntry>{};
    if (widget.package != null) {
      for (final lang in widget.package!.availableLanguages) {
        if (lang.toLowerCase() != widget.activeLanguage.toLowerCase()) {
          final trans = widget.package!.getTranslation(lang, widget.region.id);
          if (trans != null && trans.text.isNotEmpty) {
            otherTranslations[lang.toUpperCase()] = trans;
          }
        }
      }
    }

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.primary, width: 2),
          left: BorderSide(color: AppColors.darkBorder),
          right: BorderSide(color: AppColors.darkBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Type badge & Copy/Close actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getRegionTypeIcon(widget.region.type),
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getRegionTypeLabel(widget.region.type),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.darkTextSecondary),
                    tooltip: 'Sao chép văn bản',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: displayText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép văn bản vùng thoại vào bộ nhớ tạm'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Translated Content Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BẢN DỊCH HIỆN TẠI (${widget.activeLanguage.toUpperCase()})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    // TTS Audio Playback Button
                    InkWell(
                      onTap: _isPlayingTts ? null : () => _playTts(ttsText),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isPlayingTts
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isPlayingTts ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isPlayingTts ? 'Đang phát...' : 'Nghe phát âm (TTS)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  displayText,
                  style: GoogleFonts.newsreader(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Chú giải từ vựng & Furigana (nếu có trong gói truyện)
          if (note != null && note.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.school_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHÚ GIẢI TỪ VỰNG & FURIGANA',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Đối chiếu song ngữ (Parallel Language Comparisons)
          if (otherTranslations.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'ĐỐI CHIẾU NGÔN NGỮ KHÁC',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...otherTranslations.entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.darkCard.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.key,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value.text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

