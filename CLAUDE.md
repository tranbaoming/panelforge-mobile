# CLAUDE.md – PanelForge Mobile (`panelforge-mobile`)

Flutter 3.44+ & Dart 3.12+ · Riverpod (`flutter_riverpod`) · GoRouter (`go_router`) · Dio (`dio`) · CachedNetworkImage · Offline Bookmarks & Audio/Sketch Annotations.

## Spec & team workboard (shared by backend, frontend and mobile)

- Business spec for all three repos: `../panelforge-fe/docs/PANELFORGE_MASTER_SPECIFICATION_V2_6.md` (in the `panelforge-fe` repo; decision log Q1–Q14 at the top). Cite BR-xx / Module / Q-n in commits.
- **Team workboard `../panelforge-fe/docs/TEAM_WORKBOARD.md` is mandatory**, also for work done in this repo: before coding, pull `panelforge-fe` `trungkien`, add one row to §2 "Đang làm", commit `docs(tracker): start <task>` in `panelforge-fe` and push; when merged, move the row to §3 "Đã xong" with any API/DB/enum change other repos must know, commit `docs(tracker): finish <task>`.
- Do not add implementation-plan files to this repo.
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
- Server Config Dialog: Accessible via Settings icon (`tune_rounded`) in Explore Page.

## Project Structure & Navigation Map

```
lib/
├── main.dart                          # Application entry point
├── navigation/
│   ├── app_router.dart                # GoRouter route declarations & redirect logic
│   └── scaffold_with_nav_bar.dart     # Bottom navigation shell
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
│   └── preferences_service.dart       # SharedPreferences reader preferences & bookmarks
├── screens/
│   ├── auth/login_page.dart           # User login modal/page
│   ├── explore/
│   │   ├── explore_page.dart          # Catalog browse & series search
│   │   └── series_detail_page.dart    # Series overview & chapter list
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
│   ├── sketch_drawing_dialog.dart     # Canvas drawing for pinpoint feedback
│   ├── watermark_overlay.dart         # Security watermark overlay (BR-17)
│   ├── wallet_chip.dart               # Header wallet balance indicator
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
4. **Offline & Concurrency:**
   - Bookmarks and reading progress persist via `PreferencesService`.
   - Network image loading uses `CachedNetworkImage` with fallback error placeholders.
5. **Pre-commit Verification:**
   - Always run `flutter analyze` and pass with 0 errors before committing changes.
