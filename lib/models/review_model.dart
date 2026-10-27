import 'package:flutter/material.dart';

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
  final int panelNumber;
  final String title;
  final String dialogue;
  final String inkingNotes;
  final double aspectRatio;
  final List<AnnotationItem> annotations;

  const ReviewPanel({
    required this.id,
    required this.panelNumber,
    required this.title,
    required this.dialogue,
    required this.inkingNotes,
    this.aspectRatio = 1.28,
    this.annotations = const [],
  });

  ReviewPanel copyWith({
    List<AnnotationItem>? annotations,
  }) {
    return ReviewPanel(
      id: id,
      panelNumber: panelNumber,
      title: title,
      dialogue: dialogue,
      inkingNotes: inkingNotes,
      aspectRatio: aspectRatio,
      annotations: annotations ?? this.annotations,
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
  });

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
    );
  }
}

class MockReviewRepository {
  static List<ReviewPanel> _generateReviewPanels() {
    return [
      ReviewPanel(
        id: 'rev-p1',
        panelNumber: 1,
        title: 'Toàn cảnh Lò Luyện Khí Giới',
        dialogue: '“Nhiệt lượng buồng áp đang vượt ngưỡng an toàn! Cần giảm tải buồng đốt số 2!”',
        inkingNotes: 'Cần kiểm tra lại độ dày của đường viền van áp suất. Layer khói đang che mất mặt đồng hồ đo.',
        aspectRatio: 1.45,
        annotations: [
          AnnotationItem(
            id: 'ann-1',
            panelId: 'rev-p1',
            category: AnnotationCategory.lightingColor,
            note: 'Tông cam ở cửa lò hơi gắt quá, giảm saturation 15% để nổi bật bóng đổ nhân vật.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
            author: 'Chief Colorist',
            hasAudio: true,
            audioDurationSec: 14,
            normalizedPoint: const Offset(0.38, 0.4),
          ),
          AnnotationItem(
            id: 'ann-2',
            panelId: 'rev-p1',
            category: AnnotationCategory.lineArt,
            note: 'Đường line của ống dẫn hơi nước phía góc trái bị vỡ răng cưa, cần làm mượt.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
            author: 'Inking Lead',
            hasSketch: true,
            normalizedPoint: const Offset(0.18, 0.25),
          ),
        ],
      ),
      ReviewPanel(
        id: 'rev-p2',
        panelNumber: 2,
        title: 'Cận cảnh Kairi gạt cần xả áp',
        dialogue: '“Nếu van xả bị kẹt, cả phân xưởng này sẽ bốc hơi trong 30 giây!”',
        inkingNotes: 'Góc nghiêng ba phần tư, cơ bắp cánh tay căng cứng, mồ hôi và muội than trên gò má.',
        aspectRatio: 1.25,
        annotations: [
          AnnotationItem(
            id: 'ann-3',
            panelId: 'rev-p2',
            category: AnnotationCategory.dialogue,
            note: 'Bong bóng thoại đè lên chỏm tóc của Kairi, dời lệch sang phải 20px.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
            author: 'Editorial Editor',
            normalizedPoint: const Offset(0.68, 0.32),
          ),
        ],
      ),
      ReviewPanel(
        id: 'rev-p3',
        panelNumber: 3,
        title: 'Tia lửa điện lóe sáng từ cổ góp rotor',
        dialogue: '“CRACKKKLE! Ánh chớp hồ quang xanh lục lan tỏa khắp sàn nhà.”',
        inkingNotes: 'Hiệu ứng ánh sáng động ngược sáng (rim light), độ tương phản cao sắc bén.',
        aspectRatio: 1.35,
        annotations: [],
      ),
      ReviewPanel(
        id: 'rev-p4',
        panelNumber: 4,
        title: 'Bóng người bí ẩn xuất hiện sau làn hơi',
        dialogue: '“‘Ngươi vẫn cứng đầu như ngày xưa, Kairi...’”',
        inkingNotes: 'Silhouette đen tuyền, chỉ lộ đôi mắt cơ khí đỏ rực qua lớp kính bảo hộ.',
        aspectRatio: 1.5,
        annotations: [
          AnnotationItem(
            id: 'ann-4',
            panelId: 'rev-p4',
            category: AnnotationCategory.layout,
            note: 'Khoảng thở giữa hai khung tranh 3 và 4 nên nới rộng thêm 8pt để tạo nhịp thở hồi hộp.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            author: 'Art Director',
            normalizedPoint: const Offset(0.52, 0.55),
          ),
        ],
      ),
    ];
  }

  static ReviewManuscript getActiveReview() {
    return ReviewManuscript(
      token: 'REV-8891-OBSIDIAN-AETHEL',
      seriesTitle: 'Biên Niên Sử Khí Giới',
      chapterTitle: 'Bản Thảo Tiền Ký Chương 5 (Pre-Release Inking)',
      producerName: 'Trần Hoài Nam',
      producerStudio: 'Obsidian Art Works & Publishing',
      producerEmail: 'nam.tran@obsidianart.vn',
      recipientEmail: 'reviewer.senior@comicguild.org',
      recipientId: 'EXCL-RV-8891-DEPT-ART',
      expiresAt: DateTime.now().add(const Duration(hours: 4, minutes: 28, seconds: 40)),
      isExpired: false,
      totalPanels: 4,
      panels: _generateReviewPanels(),
    );
  }

  static ReviewManuscript getExpiredReview() {
    return ReviewManuscript(
      token: 'REV-EXPIRED-TEST-TOKEN',
      seriesTitle: 'Hoa Sen Neon (Cyberpunk Saigon)',
      chapterTitle: 'Bản Thảo Storyboard Tập 3',
      producerName: 'Đặng Tuệ Minh',
      producerStudio: 'MonoVerse Lab Vietnam',
      producerEmail: 'minh.dang@monoverse.io',
      recipientEmail: 'reviewer.senior@comicguild.org',
      recipientId: 'EXCL-RV-7712-ARCHIVED',
      expiresAt: DateTime.now().subtract(const Duration(hours: 12, minutes: 15)),
      isExpired: true,
      totalPanels: 3,
      panels: [],
    );
  }

  static List<ReviewManuscript> getRecentManuscripts() {
    return [
      getActiveReview(),
      ReviewManuscript(
        token: 'REV-4420-VALKYRIE-02',
        seriesTitle: 'Chân Trời Valkyrie',
        chapterTitle: 'Chương 2: Quỹ Đạo Đỏ (Color Proof #1)',
        producerName: 'Erik Jansen',
        producerStudio: 'Titan Comicworks Int.',
        producerEmail: 'erik.jansen@titancomic.eu',
        recipientEmail: 'reviewer.senior@comicguild.org',
        recipientId: 'EXCL-RV-4420-TITAN',
        expiresAt: DateTime.now().add(const Duration(hours: 18, minutes: 5)),
        isExpired: false,
        totalPanels: 6,
        panels: _generateReviewPanels(),
      ),
      getExpiredReview(),
    ];
  }
}
