# CLAUDE.md – PanelForge Mobile (`panelforge-mobile`)

Flutter 3.44+ & Dart 3.12+ · Riverpod (`flutter_riverpod`) · GoRouter (`go_router`) · Dio (`dio`) · CachedNetworkImage · Offline Bookmarks & Audio/Sketch Annotations.

## Central Knowledge Base & Spec (Tất cả tài liệu đọc tại Hub)

> 🚨 **QUY TẮC CỐT LÕI:** Tất cả tài liệu đặc tả, nghiệp vụ, hiểu biết hệ thống, kiến trúc và kế hoạch triển khai **ĐƯỢC ĐỌC TẬP TRUNG TẠI `../panelforge-hub/docs/`**, KHÔNG đọc tại các repo riêng lẻ.

- **Master Spec V2.6:** `../panelforge-hub/docs/V2.6/PANELFORGE_MASTER_SPECIFICATION_V2_6.md` (quyết định Q1–Q14, BR-xx, 5 vai trò, 5 luồng CF1–CF5). Trích dẫn mã BR-xx / Module trong commit.
- **Kế hoạch triển khai (Plans):** `../panelforge-hub/docs/note/PANELFORGE_V2_6_IMPLEMENTATION_PLAN.md` và `../panelforge-hub/docs/note/plans/07_READER_PLAN.md`. Không tạo hay lưu file plan trong repo này.
- **Thuật ngữ & State Machines:** `../panelforge-hub/docs/standards/` (Ubiquitous Language, State Machine standards).
- **Team Workboard:** `../panelforge-hub/docs/tracking/TEAM_WORKBOARD.md`. Cập nhật trạng thái tác vụ cho cả nhóm xem.
## Quick Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Release cho Google Play (gói AAB):

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<máy chủ production>
```

- Cần `android/key.properties` + upload keystore (mẫu: `android/key.properties.example`, cả hai đã .gitignore). Thiếu key hoặc thiếu `API_BASE_URL` https → Gradle chặn `bundleRelease`.
- Bản release chỉ gọi HTTPS; HTTP (cleartext) chỉ bật ở manifest `src/debug` / `src/profile` cho máy chủ dev.
- Tăng `version: x.y.z+N` trong `pubspec.yaml` (N = versionCode) mỗi lần upload, và giữ `AppInfo.version` khớp.

Backend API Base URL:
- Bản build có `--dart-define=API_BASE_URL=...` → dùng địa chỉ đó (bắt buộc cho release).
- Không có (dev): Android Emulator `http://10.0.2.2:5044`; iOS / Desktop / Web `http://localhost:5044`.
- Base URL is chosen automatically by `services/api_config.dart` (no in-app server config screen).
- Đăng nhập Google: lỗi đổi token / backend thì báo lỗi, không tạo phiên chỉ có trên máy.
- Catalog đầy đủ được lưu sau mỗi lần tải thành công; mất mạng (lỗi kết nối / 5xx) thì Trang chủ dùng bản đã lưu kèm dải "Không có kết nối".
- Deep link: `panelforge://app/series/<id>` (Android intent-filter + iOS CFBundleURLTypes) → GoRouter mở `/series/<id>`.

## Project Structure & Navigation Map

```
lib/
├── main.dart                          # Application entry point
├── navigation/
│   ├── app_router.dart                # GoRouter route declarations & redirect logic
│   └── scaffold_with_nav_bar.dart     # Bottom nav 5 tab biểu tượng + nhãn (tab đang mở có nền viên thuốc cam): Trang chủ / Dành cho bạn / Tìm kiếm / Cửa hàng / Cá nhân
├── models/
│   ├── api_dtos.dart                  # Shared request/response DTOs & ApiResponse<T>
│   ├── auth_models.dart               # AuthState, UserToken, Session models
│   ├── comic_model.dart               # Series, Chapter, Page metadata
│   ├── comic_package_models.dart      # CBZ package models & reading positions
│   └── review_model.dart              # Review token, feedback, pinpoint annotations
├── providers/
│   ├── api_providers.dart             # Riverpod providers (ApiClient, Auth, Catalog, Review)
│   ├── notification_providers.dart    # notificationsProvider (GET /api/notifications khi đã đăng nhập), unreadNotificationCountProvider, đánh dấu đã đọc
│   ├── library_sync_provider.dart     # Đồng bộ Đọc sau / Theo dõi / Yêu thích / Lịch sử với /api/users/me/library: gộp khi đăng nhập & "Đồng bộ ngay", gửi từng thay đổi
│   └── catalog_providers.dart         # catalogSeriesProvider (toàn bộ catalog) + CatalogSections (Phổ biến, Mới, Thể loại, Đề xuất, badge MỚI/UP)
├── services/
│   ├── api_client.dart                # Dio HTTP client wrapper with JWT interceptor
│   ├── api_config.dart                # Base URL detection and runtime config
│   ├── auth_service.dart              # Login, register, token refresh
│   ├── catalog_service.dart           # Public catalog & chapter reader queries (BR-23)
│   ├── preview_service.dart           # Token inspection & feedback submission (BR-16, BR-17)
│   ├── cbz_package_service.dart       # Offline CBZ caching & package extraction
│   ├── library_sync_service.dart      # /api/users/me/library: merge, {read-later|following|favorites}/{id}, history
│   ├── notification_service.dart      # /api/notifications: danh sách, {id}/read, read-all
│   ├── monetization_service.dart      # Wallet balance & chapter paywall unlocking
│   ├── preferences_service.dart       # SharedPreferences: bookmarks (Đọc sau), theo dõi, lịch sử đọc, giao diện, giữ màn hình sáng
│   ├── crash_reporter.dart            # Ghi lỗi chưa bắt được vào nhật ký trên máy (Cài đặt → Nhật ký lỗi)
│   └── app_info.dart                  # Phiên bản & liên kết Liên hệ / Chính sách / Cửa hàng (điền khi có)
├── screens/
│   ├── auth/login_page.dart           # User login modal/page
│   ├── explore/
│   │   ├── explore_page.dart          # Trang chủ: banner nổi bật full-bleed, popup truyện mới, hàng bìa lớn, Thể loại tròn, khối Đề xuất, Truyện mới
│   │   ├── browse_page.dart           # /genres (push): lưới thể loại 2 cột → chạm mở lưới truyện của thể loại
│   │   ├── search_page.dart           # Tab Tìm kiếm: ô tìm + danh sách A–Z; lọc realtime theo tên / Studio / thể loại
│   │   ├── series_grid_page.dart      # Xem tất cả dạng lưới 2 cột
│   │   └── series_detail_page.dart    # AppBar (← tên, Chia sẻ, Yêu thích), DS chương ngay trên trang (ảnh, giá/đã mở, sắp xếp), nút "Bắt đầu đọc" dính đáy
│   ├── foryou/for_you_page.dart       # Tab Dành cho bạn: banner VIP, Phổ biến hôm nay, Đề xuất cho bạn, Đọc tất cả với VIP, Truyện mới
│   ├── shop/shop_page.dart            # Tab Cửa hàng: thẻ Tài sản (Ví/VIP thật), NẠP VÍ (VietQR) / GÓI VIP, Lịch sử giao dịch, Điều khoản
│   ├── profile/
│   │   ├── profile_page.dart          # Tab Cá nhân: thẻ Tạo tài khoản / hồ sơ + Ví, lối tắt Đọc sau / Theo dõi / Đã mở khóa, thẻ Lịch sử / Yêu thích
│   │   ├── settings_page.dart         # /settings (bánh răng): Tài khoản (hồ sơ, đổi MK, thiết bị tin cậy, giao dịch, mã Review, đăng xuất, xoá TK), Cài đặt ứng dụng (ngôn ngữ giao diện, giao diện, ...), Trợ giúp, Khác
│   │   ├── legal_page.dart            # /legal/:id — terms | privacy | copyright | faq (nội dung ở lib/content/legal_content.dart)
│   │   ├── downloads_page.dart        # /downloads (từ Cài đặt): chương đã tải offline theo bộ, dung lượng, xoá từng chương / xoá hết
│   │   └── activity_page.dart         # /activity (chuông có số chưa đọc ở tab Cá nhân): thông báo từ server, giao dịch Ví, đọc gần đây, lối vào Review (/review)
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
│   ├── wallet_history.dart            # Lịch sử giao dịch Ví: lọc theo tháng, tổng nạp/chi, biên lai từng giao dịch
│   ├── wallet_topup_dialog.dart       # Wallet top-up (VietQR order) & server transaction history
│   ├── unlock_chapter_bottom_sheet.dart # Mở khóa cả chương trả phí: Ví / VietQR / VIP (người chưa mua chỉ đọc trang xem trước); ChapterPurchaseOptionsSheet (Số dư hiện tại + Dùng Ví để đọc / Đọc thử / Hủy)
│   ├── locked_page_tile.dart          # Ô trang ngoài phần xem trước: làm mờ + nút "Mở khóa chương"
│   ├── vietqr_payment_panel.dart      # Shared VietQR order view + 3s polling until Producer approves
│   └── qr_scanner_dialog.dart         # Camera QR code reader (`mobile_scanner`)
├── core/theme/app_theme.dart         # Theme tập trung: AppColors (slate #13161F/#1E2330/#282E3E, cam #F97316, vàng #FBBF24), ForgeColors, NavigationBarTheme, ForgeText.tabular
└── theme/app_theme.dart              # Re-export đường dẫn cũ → core/theme
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

## Git workflow (bắt buộc cho mọi agent — Claude Code & Antigravity)

Bản cho Antigravity nằm ở `.agents/rules/git-workflow.md` (`trigger: always_on`); hai bản phải giống nhau.

- **Nhánh làm việc: `baominh`.** Mọi thay đổi đi vào `baominh`; không commit thẳng lên `main`. `main` chỉ nhận merge từ `baominh`.
- **Một agent:** làm trực tiếp trên `baominh` (`git checkout baominh && git pull --ff-only origin baominh`).
- **Nhiều agent (multi-agent / subagent / session song song):** mỗi agent làm trong **git worktree riêng**, nhánh con từ `baominh`:
  - `git worktree add ../.worktrees/panelforge-mobile-<task> -b baominh-<task> baominh`
  - Mỗi agent chỉ sửa file của task mình; hai agent không sửa cùng file; không sửa working tree chính khi agent khác đang chạy.
- **Xong mỗi task:**
  1. `flutter analyze` (0 issue) + `flutter test` (pass hết).
  2. Commit theo Conventional Commits (`feat(mobile): ...`).
  3. Worktree: `git checkout baominh && git merge --no-ff baominh-<task>` → giải quyết conflict → chạy lại analyze + test.
  4. `git push origin baominh`.
  5. `git checkout main && git pull --ff-only origin main && git merge --no-ff baominh` → analyze + test → `git push origin main` → `git checkout baominh`.
  6. Dọn worktree: `git worktree remove ../.worktrees/panelforge-mobile-<task>` và `git branch -d baominh-<task>`.
- **Cấm:** force-push, rebase lịch sử đã push trên `baominh`/`main`, `--no-verify`, push khi analyze/test còn lỗi.
