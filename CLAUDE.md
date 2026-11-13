# CLAUDE.md – PanelForge Mobile (`panelforge-mobile`)

Flutter 3.44+ & Dart 3.12+ · Riverpod (`flutter_riverpod`) · GoRouter (`go_router`) · Dio (`dio`) · CachedNetworkImage · Offline Bookmarks & Audio/Sketch Annotations.

## Quick Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Backend API Base URL:
- Android Emulator: `http://10.0.2.2:5044`
- iOS / Desktop / Web: `http://localhost:5044`
- Base URL is chosen automatically by `services/api_config.dart` (no in-app server config screen).

## Project Structure & Navigation Map

```
lib/
├── main.dart                          # Application entry point
├── navigation/
│   ├── app_router.dart                # GoRouter route declarations & redirect logic
│   └── scaffold_with_nav_bar.dart     # Bottom nav 5 tab chỉ biểu tượng (tên ở tooltip): Trang chủ / Khám phá / Tìm kiếm / Cá nhân / Thông báo
├── models/
│   ├── api_dtos.dart                  # Shared request/response DTOs & ApiResponse<T>
│   ├── auth_models.dart               # AuthState, UserToken, Session models
│   ├── comic_model.dart               # Series, Chapter, Page metadata
│   ├── comic_package_models.dart      # CBZ package models & reading positions
│   └── review_model.dart              # Review token, feedback, pinpoint annotations
├── providers/
│   └── api_providers.dart             # Riverpod providers (ApiClient, Auth, Catalog, Review)
├── services/
│   ├── api_client.dart                # Dio HTTP client wrapper with JWT interceptor
│   ├── api_config.dart                # Base URL detection and runtime config
│   ├── auth_service.dart              # Login, register, token refresh
│   ├── catalog_service.dart           # Public catalog & chapter reader queries (BR-23)
│   ├── preview_service.dart           # Token inspection & feedback submission (BR-16, BR-17)
│   ├── cbz_package_service.dart       # Offline CBZ caching & package extraction
│   ├── monetization_service.dart      # Wallet balance & chapter paywall unlocking
│   ├── preferences_service.dart       # SharedPreferences: bookmarks (Đọc sau), theo dõi, lịch sử đọc, giao diện, giữ màn hình sáng
│   └── app_info.dart                  # Phiên bản & liên kết Liên hệ / Chính sách / Cửa hàng (điền khi có)
├── screens/
│   ├── auth/login_page.dart           # User login modal/page
│   ├── explore/
│   │   ├── explore_page.dart          # Trang chủ: Tiếp tục đọc, danh mục nhanh, hàng truyện ngang
│   │   ├── browse_page.dart           # Tab Khám phá: lưới thể loại 2 cột → chạm mở lưới truyện của thể loại
│   │   ├── search_page.dart           # Tab Tìm kiếm: không AppBar, lọc realtime theo tên truyện / Studio
│   │   ├── series_grid_page.dart      # Xem tất cả dạng lưới 2 cột
│   │   └── series_detail_page.dart    # Header ảnh mờ, thể loại, Giới thiệu, sheet DS Chương (mở khóa / CBZ)
│   ├── profile/
│   │   ├── profile_page.dart          # Tab Cá nhân: hồ sơ, Ví & VIP, danh sách, cài đặt, liên hệ, đăng xuất
│   │   └── activity_page.dart         # Tab Thông báo: giao dịch Ví, đọc gần đây, lối vào Review (/review)
│   ├── reader/
│   │   └── comic_reader_page.dart     # Multi-mode manga/comic/webtoon reader
│   └── review/
│       ├── review_hub_page.dart       # Review token entry & active preview sessions
│       ├── review_canvas_page.dart    # Annotation canvas, audio note & sketch tools
│       ├── review_invite_page.dart    # Invitation acceptor
│       └── review_expired_page.dart   # Expired token fallback
├── widgets/
│   ├── adaptive_webtoon_view.dart     # Continuous vertical scroll mode
│   ├── guided_panel_viewer.dart       # Panel-by-panel guided reading
│   ├── vertical_page_slider.dart      # Thanh trượt trang dọc mép phải reader: ẩn, chỉ hiện khi bấm đè mép phải (lướt vẫn bình thường)
│   ├── sketch_drawing_dialog.dart     # Canvas drawing for pinpoint feedback
│   ├── watermark_overlay.dart         # Security watermark overlay (BR-17)
│   ├── vip_purchase_sheet.dart        # Mua VIP: trừ Ví hoặc VietQR (đơn VipSubscription)
│   ├── forge_ui.dart                  # Thẻ truyện, logo, header section, lưới 2 cột (bảng màu ForgeColors)
│   ├── wallet_chip.dart               # Header wallet balance indicator
│   ├── wallet_topup_dialog.dart       # Wallet top-up (VietQR order) & server transaction history
│   ├── unlock_chapter_bottom_sheet.dart # Mở khóa cả chương trả phí: Ví / VietQR / VIP (người chưa mua chỉ đọc trang xem trước)
│   ├── locked_page_tile.dart          # Ô trang ngoài phần xem trước: làm mờ + nút "Mở khóa chương"
│   ├── vietqr_payment_panel.dart      # Shared VietQR order view + 3s polling until Producer approves
│   └── qr_scanner_dialog.dart         # Camera QR code reader (`mobile_scanner`)
└── theme/
    └── app_theme.dart                 # Dark/Vintage/Light reader themes
```

## Architectural & Coding Rules

1. **State Management:**
   - Use `flutter_riverpod` providers (StateNotifierProvider, FutureProvider, or Provider).
   - Never inject business logic into View build methods; delegate to Services/Providers.
2. **Networking & Serialization:**
   - All HTTP requests go through `ApiClient` (`dio`) with standard error catching.
   - Parse JSON using typed factory constructors (`fromJson`) in `models/*.dart`.
3. **Zero-Trust Security & Watermarking:**
   - Pre-release preview canvas MUST display `WatermarkOverlay` containing reviewer identity.
   - Expired or revoked review tokens must immediately redirect to `review_expired_page.dart`.
4. **Lazy Authentication:**
   - Mở app vào thẳng Trang chủ; Khám phá, Tìm kiếm, Chi tiết truyện, DS Chương mở tự do khi chưa đăng nhập.
   - Mọi lối mở chương (đọc / tải CBZ) đi qua `ensureLoggedInForReading` / `openReaderGuarded` (`navigation/read_guard.dart`):
     chưa đăng nhập → sheet `ReadLoginPromptSheet` (ảnh bìa, "Tiếp Theo" / "Để sau") → Tiếp Theo push `/login`
     (Email → Mật khẩu nếu đã có tài khoản / Đăng ký nếu chưa), đăng nhập xong tự mở tiếp đúng chương.
   - Router chặn `/reader/...` khi chưa đăng nhập → `/login?redirect=<chương>` (chỉ nhận đường dẫn nội bộ, `safeLoginRedirect`).
5. **Offline & Concurrency:**
   - Bookmarks and reading progress persist via `PreferencesService`.
   - Network image loading uses `CachedNetworkImage` with fallback error placeholders.
6. **Pre-commit Verification:**
   - Always run `flutter analyze` and pass with 0 errors before committing changes.
