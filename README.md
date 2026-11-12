# PanelForge Mobile (`panelforge-mobile`)

PanelForge Mobile là ứng dụng di động Flutter dành cho độc giả đọc truyện tranh (Reader) và các chuyên gia đánh giá bản thảo tiền phát hành (Collaborative Pre-release Review). Ứng dụng tích hợp trực tiếp với hệ thống backend **PanelForge.API** (.NET 8 + PostgreSQL) theo chuẩn BR-23, BR-24, BR-09 và BR-17.

---

## Tính Năng Chính (Key Features)

- **Khám Phá & Đọc Truyện (Catalog & Reader)**:
  - Tải danh sách truyện đã xuất bản từ `GET /api/catalog/series` (BR-23).
  - Tải ảnh trang truyện thực tế bằng `CachedNetworkImage` qua `GET /api/catalog/chapters/{id}/pages/{id}/image`.
  - Hỗ trợ 3 chế độ đọc linh hoạt: Manga RTL (phải sang trái), Western Comic LTR (trái sang phải), Webtoon (cuộn dọc).
  - Đổi màu giấy đọc: Chế độ Đêm (Night), Giấy Cổ (Vintage Paper), Sáng (Light).
  - Lưu và quản lý danh sách truyện yêu thích (Bookmarks) offline.
- **Review Canvas & Không Gian Góp Ý (Reviewer Workspace)**:
  - Mở bản thảo bảo mật bằng mã Token hoặc quét mã QR qua `POST /api/preview/open` (BR-16).
  - Lớp phủ bản quyền Watermark động theo email người nhận (`WatermarkOverlay`, BR-17).
  - Đóng góp ý kiến trực tiếp vào từng khung tranh (Annotation Pinpoint).
  - Tự động đồng bộ phản hồi lên server qua `POST /api/preview/feedback`.
  - Ghi âm chỉ dẫn giọng nói bằng micro thật (`record` + `audioplayers`).
  - Vẽ phác thảo khoanh vùng lỗi trực tiếp trên khung tranh (`SketchDrawingDialog`).
- **Quét Mã QR Camera Thật (`mobile_scanner`)**:
  - Quét mã QR bản thảo trực tiếp bằng Camera sau của điện thoại.
  - Hỗ trợ bật/tắt đèn Flash (Torch) và chuyển đổi Camera trước/sau.
  - Tích hợp sẵn các mã token test nhanh khi chạy trên máy ảo hoặc môi trường không có camera.

---

## Công Nghệ Sử Dụng (Tech Stack)

- **Framework**: Flutter 3.44.1 / Dart 3.12.1
- **Networking**: `dio` (^5.11.1) kết nối tới .NET 8 Web API
- **State Management**: `flutter_riverpod` (^3.4.3)
- **Routing**: `go_router` (^17.5.0)
- **Lưu trữ Cục Bộ (Local Storage)**: `shared_preferences` (^2.5.6)
- **Camera & Quét QR**: `mobile_scanner` (^7.4.2)
- **Thu & Phát Âm Thanh**: `record` (^7.1.2) & `audioplayers` (^6.8.1)
- **Xử Lý Ảnh & Bộ Nhớ Đệm**: `cached_network_image` (^3.4.1)

---

## Cấu Hình Môi Trường (API Configuration)

Ứng dụng tự động nhận diện Base URL API:
* **Android Emulator**: `http://10.0.2.2:5044`
* **iOS Simulator / Web / Desktop**: `http://localhost:5044`
* **Thiết bị thật (Physical Device)**: Bạn có thể nhấn vào biểu tượng Cài đặt (`tune_rounded`) ở góc phải màn hình Khám Phá để nhập địa chỉ IP mạng LAN (ví dụ: `http://192.168.1.50:5044`) và kiểm tra kết nối ngay lập tức.

---

## Hướng Dẫn Chạy Ứng Dụng

1. **Cài đặt dependencies:**
   ```bash
   flutter pub get
   ```

2. **Chạy kiểm tra tĩnh:**
   ```bash
   flutter analyze
   ```

3. **Chạy ứng dụng:**
   ```bash
   flutter run
   ```

## Đặc tả & theo dõi công việc

- Đặc tả nghiệp vụ dùng chung: [`panelforge-fe/docs/PANELFORGE_MASTER_SPECIFICATION_V2_6.md`](../panelforge-fe/docs/PANELFORGE_MASTER_SPECIFICATION_V2_6.md) (repo `panelforge-fe`). Phần của Mobile chủ yếu ở Module 5: Ví VNĐ, mở khoá theo ấn bản ngôn ngữ, chọn ngôn ngữ đọc, thống kê đọc (BR-32, BR-33, BR-34).
- Ai đang làm gì: [`panelforge-fe/docs/TEAM_WORKBOARD.md`](../panelforge-fe/docs/TEAM_WORKBOARD.md). Bắt buộc cập nhật khi bắt đầu và khi xong việc, kể cả việc làm trong repo này.
