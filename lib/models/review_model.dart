import 'package:flutter/material.dart';
import 'api_dtos.dart';
import 'comic_package_models.dart';

enum AnnotationCategory {
  lightingColor('Ánh sáng / Màu', Icons.palette_outlined, Color(0xFFF59E0B)),
  lineArt('Lỗi nét', Icons.edit_outlined, Color(0xFFEF4444)),
  dialogue('Thoại / Dịch', Icons.chat_bubble_outline, Color(0xFF3B82F6)),
  layout('Bố cục', Icons.grid_view_outlined, Color(0xFF10B981));

  final String label;
  final IconData icon;
  final Color color;
  const AnnotationCategory(this.label, this.icon, this.color);
}

class AnnotationItem {
  final String id;
  final String panelId;
  final String? textRegionId;
  final AnnotationCategory category;
  final String note;
  final DateTime createdAt;
  final String author;
  final bool hasAudio;
  final int? audioDurationSec;
  final bool hasSketch;
  final Offset normalizedPoint; // (0..1, 0..1) relative to panel

  const AnnotationItem({
    required this.id,
    required this.panelId,
    this.textRegionId,
    required this.category,
    required this.note,
    required this.createdAt,
    required this.author,
    this.hasAudio = false,
    this.audioDurationSec,
    this.hasSketch = false,
    this.normalizedPoint = const Offset(0.5, 0.45),
  });
}

class ReviewPanel {
  final String id;
  final String? pageId;
  final int panelNumber;
  final String title;
  final String dialogue;
  final String inkingNotes;
  final double aspectRatio;
  final String? imageUrl;
  final List<AnnotationItem> annotations;
  final NormalizedBounds? bounds;
  final List<TextRegion> textRegions;

  const ReviewPanel({
    required this.id,
    this.pageId,
    required this.panelNumber,
    required this.title,
    required this.dialogue,
    required this.inkingNotes,
    this.aspectRatio = 1.28,
    this.imageUrl,
    this.annotations = const [],
    this.bounds,
    this.textRegions = const [],
  });

  ReviewPanel copyWith({
    List<AnnotationItem>? annotations,
    String? imageUrl,
    NormalizedBounds? bounds,
    List<TextRegion>? textRegions,
  }) {
    return ReviewPanel(
      id: id,
      pageId: pageId,
      panelNumber: panelNumber,
      title: title,
      dialogue: dialogue,
      inkingNotes: inkingNotes,
      aspectRatio: aspectRatio,
      imageUrl: imageUrl ?? this.imageUrl,
      annotations: annotations ?? this.annotations,
      bounds: bounds ?? this.bounds,
      textRegions: textRegions ?? this.textRegions,
    );
  }
}

class ReviewManuscript {
  final String token;
  final String seriesTitle;
  final String chapterTitle;
  final String producerName;
  final String producerStudio;
  final String producerEmail;
  final String recipientEmail;
  final String recipientId;
  final DateTime expiresAt;
  final bool isExpired;
  final int totalPanels;
  final List<ReviewPanel> panels;
  final String encryptionCipher;
  final List<TextRegion> textRegions;
  final List<PanelInfo> manifestPanels;

  const ReviewManuscript({
    required this.token,
    required this.seriesTitle,
    required this.chapterTitle,
    required this.producerName,
    required this.producerStudio,
    required this.producerEmail,
    required this.recipientEmail,
    required this.recipientId,
    required this.expiresAt,
    this.isExpired = false,
    required this.totalPanels,
    required this.panels,
    this.encryptionCipher = 'AES-256-GCM / Hardware Enclave Bound',
    this.textRegions = const [],
    this.manifestPanels = const [],
  });

  factory ReviewManuscript.fromPreviewDto(PreviewChapterDto dto, String token) {
    final panelsList = <ReviewPanel>[];
    for (final page in dto.pages) {
      final pageIndex = page.pageNumber - 1;
      final pageTextRegions = page.textRegions.isNotEmpty
          ? page.textRegions
          : dto.textRegions.where((t) => t.pageIndex == pageIndex).toList();

      if (page.panels.isEmpty) {
        // Nếu trang chưa chia panel, tạo 1 panel toàn trang
        panelsList.add(ReviewPanel(
          id: page.pageId,
          pageId: page.pageId,
          panelNumber: page.pageNumber,
          title: 'Trang #${page.pageNumber}',
          dialogue: 'Bản thảo trang #${page.pageNumber} phiên bản ${page.versionNumber}',
          inkingNotes: 'Toàn trang',
          aspectRatio: 1.33,
          imageUrl: page.fullImageUrl,
          annotations: const [],
          bounds: const NormalizedBounds(x: 0, y: 0, w: 1, h: 1),
          textRegions: pageTextRegions,
        ));
      } else {
        for (final p in page.panels) {
          final panelBounds = p.bounds ?? NormalizedBounds.tryParse(p.boundingBox);
          // Tìm các text-regions thuộc khung này nếu có tọa độ
          final associatedTextRegions = pageTextRegions.where((tr) {
            if (panelBounds == null) return true;
            // Nếu tâm text region nằm trong panel bounds
            final cx = tr.bounds.x + tr.bounds.w / 2;
            final cy = tr.bounds.y + tr.bounds.h / 2;
            return panelBounds.containsPoint(cx, cy);
          }).toList();

          panelsList.add(ReviewPanel(
            id: p.panelId,
            pageId: page.pageId,
            panelNumber: p.panelNumber,
            title: 'Khung #${p.panelNumber} (Trang ${page.pageNumber})',
            dialogue: 'Khung tranh #${p.panelNumber}',
            inkingNotes: 'Vị trí: ${p.boundingBox}',
            aspectRatio: 1.33,
            imageUrl: page.fullImageUrl,
            annotations: const [],
            bounds: panelBounds,
            textRegions: associatedTextRegions.isNotEmpty ? associatedTextRegions : pageTextRegions,
          ));
        }
      }
    }

    return ReviewManuscript(
      token: token,
      seriesTitle: dto.seriesTitle,
      chapterTitle: dto.chapterTitle ?? 'Chương ${dto.chapterNumber}',
      producerName: 'PanelForge Studio',
      producerStudio: 'Hệ thống Studio PanelForge',
      producerEmail: 'producer@panelforge.studio',
      recipientEmail: dto.recipientEmail,
      recipientId: 'EXCL-${dto.chapterId.length > 8 ? dto.chapterId.substring(0, 8).toUpperCase() : dto.chapterId}',
      expiresAt: dto.expiresAt,
      isExpired: dto.isExpired,
      totalPanels: panelsList.length,
      panels: panelsList,
      encryptionCipher: 'AES-256-GCM / Watermark: ${dto.watermarkText}',
      textRegions: dto.textRegions,
      manifestPanels: dto.panels,
    );
  }

  Duration get remainingTime {
    final now = DateTime.now();
    if (isExpired || now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  ReviewManuscript copyWith({
    bool? isExpired,
    List<ReviewPanel>? panels,
    List<TextRegion>? textRegions,
    List<PanelInfo>? manifestPanels,
  }) {
    return ReviewManuscript(
      token: token,
      seriesTitle: seriesTitle,
      chapterTitle: chapterTitle,
      producerName: producerName,
      producerStudio: producerStudio,
      producerEmail: producerEmail,
      recipientEmail: recipientEmail,
      recipientId: recipientId,
      expiresAt: expiresAt,
      isExpired: isExpired ?? this.isExpired,
      totalPanels: totalPanels,
      panels: panels ?? this.panels,
      encryptionCipher: encryptionCipher,
      textRegions: textRegions ?? this.textRegions,
      manifestPanels: manifestPanels ?? this.manifestPanels,
    );
  }
}
