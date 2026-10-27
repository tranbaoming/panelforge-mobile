enum ComicFormat {
  comic('Comic'),
  manga('Manga'),
  webtoon('Webtoon');

  final String label;
  const ComicFormat(this.label);
}

enum ReadingMode {
  ltr('LTR (Trái sang phải)'),
  rtl('RTL (Manga - Phải sang trái)'),
  webtoon('Webtoon (Cuộn dọc)');

  final String title;
  const ReadingMode(this.title);
}

enum ReaderThemeMode {
  night('Đêm', 0xFF07080D, 0xFF10121A, 0xFFF9FAFB),
  vintage('Giấy Cổ', 0xFFF4EEDD, 0xFFEBE3CE, 0xFF2A2318),
  light('Sáng', 0xFFFCF9F2, 0xFFFFFFFF, 0xFF1E2024);

  final String label;
  final int bgColor;
  final int surfaceColor;
  final int textColor;

  const ReaderThemeMode(this.label, this.bgColor, this.surfaceColor, this.textColor);
}

class ComicPanelData {
  final String id;
  final int panelNumber;
  final String description;
  final String dialogue;
  final String colorHex;
  final String soundEffect;
  final double aspectRatio;

  const ComicPanelData({
    required this.id,
    required this.panelNumber,
    required this.description,
    required this.dialogue,
    required this.colorHex,
    required this.soundEffect,
    this.aspectRatio = 1.33,
  });
}

class ComicPageData {
  final int pageNumber;
  final String title;
  final List<ComicPanelData> panels;

  const ComicPageData({
    required this.pageNumber,
    required this.title,
    required this.panels,
  });
}

class ChapterItem {
  final String id;
  final int number;
  final String title;
  final String releaseDate;
  final int pageCount;
  final bool isFree;
  final List<ComicPageData> pages;

  const ChapterItem({
    required this.id,
    required this.number,
    required this.title,
    required this.releaseDate,
    required this.pageCount,
    this.isFree = true,
    required this.pages,
  });
}

class SeriesItem {
  final String id;
  final String title;
  final String author;
  final String artist;
  final ComicFormat format;
  final String coverGradientStart;
  final String coverGradientEnd;
  final String synopsisQuote;
  final String fullSynopsis;
  final double rating;
  final int views;
  final int readProgressChapter;
  final int totalChapters;
  final List<String> genres;
  final List<ChapterItem> chapters;
  final bool isBookmarked;
  final String editorialNote;

  const SeriesItem({
    required this.id,
    required this.title,
    required this.author,
    required this.artist,
    required this.format,
    required this.coverGradientStart,
    required this.coverGradientEnd,
    required this.synopsisQuote,
    required this.fullSynopsis,
    required this.rating,
    required this.views,
    required this.readProgressChapter,
    required this.totalChapters,
    required this.genres,
    required this.chapters,
    this.isBookmarked = false,
    required this.editorialNote,
  });

  SeriesItem copyWith({
    bool? isBookmarked,
    int? readProgressChapter,
  }) {
    return SeriesItem(
      id: id,
      title: title,
      author: author,
      artist: artist,
      format: format,
      coverGradientStart: coverGradientStart,
      coverGradientEnd: coverGradientEnd,
      synopsisQuote: synopsisQuote,
      fullSynopsis: fullSynopsis,
      rating: rating,
      views: views,
      readProgressChapter: readProgressChapter ?? this.readProgressChapter,
      totalChapters: totalChapters,
      genres: genres,
      chapters: chapters,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      editorialNote: editorialNote,
    );
  }
}

// Mock Data Generator for High Quality Comic Pages
class MockDataRepository {
  static List<ComicPanelData> _generatePanelsForPage(int page, String chapterPrefix) {
    return [
      ComicPanelData(
        id: '$chapterPrefix-p$page-1',
        panelNumber: 1,
        description: 'Đại sảnh tháp cơ khí rực rỡ trong ánh hoàng hôn màu đồng.',
        dialogue: '“Cánh cổng thời không chỉ mở ra một lần duy nhất trong chu kỳ 100 năm...”',
        colorHex: '0xFF1E2638',
        soundEffect: 'THUD!!',
        aspectRatio: 1.6,
      ),
      ComicPanelData(
        id: '$chapterPrefix-p$page-2',
        panelNumber: 2,
        description: 'Kairi chỉnh lại chiếc găng tay áp điện, ánh mắt kiên định.',
        dialogue: '“Dù là một phần vạn giây, ta cũng sẽ đưa bản thiết kế trở lại.”',
        colorHex: '0xFF2A1C2E',
        soundEffect: 'ZZZ-T...',
        aspectRatio: 1.25,
      ),
      ComicPanelData(
        id: '$chapterPrefix-p$page-3',
        panelNumber: 3,
        description: 'Vòng xoay rotor phản vật chất bắt đầu tăng tốc cực đại.',
        dialogue: '“Hệ thống làm mát sụt áp 30%! Cảnh báo xung động!”',
        colorHex: '0xFF172922',
        soundEffect: 'VROOOOOOM!',
        aspectRatio: 1.4,
      ),
    ];
  }

  static List<ComicPageData> _generatePages(int count, String chapterPrefix) {
    return List.generate(count, (index) {
      final pNum = index + 1;
      return ComicPageData(
        pageNumber: pNum,
        title: 'Trang $pNum',
        panels: _generatePanelsForPage(pNum, chapterPrefix),
      );
    });
  }

  static List<SeriesItem> getMockSeries() {
    return [
      SeriesItem(
        id: 'chronicles-aether',
        title: 'Biên Niên Sử Khí Giới',
        author: 'Lâm Triết',
        artist: 'Studio Obsidian Art',
        format: ComicFormat.manga,
        coverGradientStart: '0xFF1B2A4A',
        coverGradientEnd: '0xFF0E1424',
        synopsisQuote: '“Khi bánh răng cuối cùng dừng lại, chỉ có lời thề của người thợ rèn là còn tồn tại.”',
        fullSynopsis:
            'Lấy bối cảnh lục địa Aethelgard thời kỳ hơi nước kết hợp ma thuật cổ đại, một kỹ sư trẻ vô tình giải mã được cuộn bản đồ mật của đế chế sụp đổ, khởi đầu cuộc chạy đua giành quyền kiểm soát lõi năng lượng vĩnh hằng.',
        rating: 4.9,
        views: 342000,
        readProgressChapter: 4,
        totalChapters: 24,
        genres: ['Steampunk', 'Huyền Bí', 'Hành Động', 'Khoa Học'],
        isBookmarked: true,
        editorialNote:
            'Tác phẩm xuất sắc nhất giải Graphic Novel Mùa Thu. Nét vẽ chi tiết cơ khí đạt độ chuẩn xác công nghiệp cùng bố cục khung tranh phá cách ngoạn mục.',
        chapters: [
          ChapterItem(
            id: 'ae-ch1',
            number: 1,
            title: 'Chương 1: Lời Thề Bánh Răng Đồng',
            releaseDate: '12/10/2026',
            pageCount: 16,
            pages: _generatePages(16, 'ae-ch1'),
          ),
          ChapterItem(
            id: 'ae-ch2',
            number: 2,
            title: 'Chương 2: Ngọn Lửa Trong Ống Khói',
            releaseDate: '19/10/2026',
            pageCount: 18,
            pages: _generatePages(18, 'ae-ch2'),
          ),
          ChapterItem(
            id: 'ae-ch3',
            number: 3,
            title: 'Chương 3: Tiếng Hú Còi Áp Suất',
            releaseDate: '26/10/2026',
            pageCount: 20,
            pages: _generatePages(20, 'ae-ch3'),
          ),
          ChapterItem(
            id: 'ae-ch4',
            number: 4,
            title: 'Chương 4: Tâm Bão Điện Từ',
            releaseDate: '02/11/2026',
            pageCount: 22,
            pages: _generatePages(22, 'ae-ch4'),
          ),
          ChapterItem(
            id: 'ae-ch5',
            number: 5,
            title: 'Chương 5: Vực Thẳm Obsidian',
            releaseDate: '09/11/2026',
            pageCount: 20,
            isFree: false,
            pages: _generatePages(20, 'ae-ch5'),
          ),
        ],
      ),
      SeriesItem(
        id: 'neon-lotus',
        title: 'Hoa Sen Neon',
        author: 'Đặng Tuệ Minh',
        artist: 'MonoVerse Lab',
        format: ComicFormat.webtoon,
        coverGradientStart: '0xFF4A154B',
        coverGradientEnd: '0xFF1A0826',
        synopsisQuote: '“Trong màn sương axit của Sài Gòn 2088, ký ức là thứ hàng lậu đắt đỏ nhất.”',
        fullSynopsis:
            'Thợ săn dữ liệu ngầm An Vi nhận một hợp đồng trích xuất tệp ý thức từ một siêu người máy đào tẩu, mở ra âm mưu kiểm soát hệ thần kinh của tập đoàn NeuroLink.',
        rating: 4.8,
        views: 512000,
        readProgressChapter: 1,
        totalChapters: 40,
        genres: ['Cyberpunk', 'Trinh Thám', 'Webtoon', 'Sci-Fi'],
        isBookmarked: false,
        editorialNote:
            'Phong cách Webtoon phối màu neon tím rực rỡ, góc nhìn điện ảnh với độ dài khung cuộn mượt mà.',
        chapters: [
          ChapterItem(
            id: 'nl-ch1',
            number: 1,
            title: 'Chương 1: Mưa Độc Tầng 88',
            releaseDate: '05/10/2026',
            pageCount: 14,
            pages: _generatePages(14, 'nl-ch1'),
          ),
          ChapterItem(
            id: 'nl-ch2',
            number: 2,
            title: 'Chương 2: Tín Hiệu Ghost',
            releaseDate: '12/10/2026',
            pageCount: 16,
            pages: _generatePages(16, 'nl-ch2'),
          ),
        ],
      ),
      SeriesItem(
        id: 'valkyrie-horizon',
        title: 'Chân Trời Valkyrie',
        author: 'Erik Jansen',
        artist: 'Klaus Richter',
        format: ComicFormat.comic,
        coverGradientStart: '0xFF243B2C',
        coverGradientEnd: '0xFF0E1A12',
        synopsisQuote: '“Bầu trời thuộc về những kẻ dám cắt đứt dây dù an toàn.”',
        fullSynopsis:
            'Phi đội phản lực thử nghiệm số 9 trong cuộc chiến phòng thủ quỹ đạo địa tĩnh trước đợt xâm lăng của những thực thể tinh thể ngoài không gian.',
        rating: 4.7,
        views: 189000,
        readProgressChapter: 2,
        totalChapters: 12,
        genres: ['Western Comic', 'Không Gian', 'Chiến Đấu'],
        isBookmarked: false,
        editorialNote:
            'Đậm phong cách truyện tranh phương Tây với nét mực sắc nhọn (inking) và phân tầng màu kỹ thuật số chuẩn quốc tế.',
        chapters: [
          ChapterItem(
            id: 'vh-ch1',
            number: 1,
            title: 'Tập 1: Cất Cánh Khẩn Cấp',
            releaseDate: '01/09/2026',
            pageCount: 24,
            pages: _generatePages(24, 'vh-ch1'),
          ),
          ChapterItem(
            id: 'vh-ch2',
            number: 2,
            title: 'Tập 2: Quỹ Đạo Đỏ',
            releaseDate: '15/09/2026',
            pageCount: 24,
            pages: _generatePages(24, 'vh-ch2'),
          ),
        ],
      ),
      SeriesItem(
        id: 'spirit-blade',
        title: 'Linh Kiếm Phách',
        author: 'Nguyễn Hải Phong',
        artist: 'Phong Vân Studio',
        format: ComicFormat.manga,
        coverGradientStart: '0xFF3E2723',
        coverGradientEnd: '0xFF1A100E',
        synopsisQuote: '“Kiếm không có mắt, nhưng lưỡi kiếm khắc cốt ghi tâm.”',
        fullSynopsis:
            'Một thanh niên mồ côi giữ trong mình kiếm phổ thất truyền, dấn thân vào chốn giang hồ đầy hiểm nguy để tìm lời giải cho sự biến mất của cả môn phái.',
        rating: 4.85,
        views: 290000,
        readProgressChapter: 0,
        totalChapters: 18,
        genres: ['Võ Hiệp', 'Kỳ Ảo', 'Cổ Trang'],
        isBookmarked: true,
        editorialNote:
            'Nét vẽ cọ mực thủy mặc kết hợp kịch tính truyện tranh hành động phương Đông.',
        chapters: [
          ChapterItem(
            id: 'sb-ch1',
            number: 1,
            title: 'Hồi 1: Rút Kiếm Rời Núi',
            releaseDate: '08/10/2026',
            pageCount: 20,
            pages: _generatePages(20, 'sb-ch1'),
          ),
        ],
      ),
    ];
  }
}
