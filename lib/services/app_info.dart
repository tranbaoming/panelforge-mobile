/// Thông tin hiển thị ở màn Cá nhân (Phiên bản, Liên hệ, Chính sách, Đánh giá, Chia sẻ).
///
/// Các liên kết để trống cho tới khi có địa chỉ chính thức: màn Cá nhân sẽ báo "chưa cấu hình"
/// thay vì mở một địa chỉ đoán bừa.
class AppInfo {
  AppInfo._();

  /// Khớp `version:` trong pubspec.yaml.
  static const String version = '1.4.0';

  /// Email hỗ trợ của Admin, ví dụ `support@your-domain`.
  static const String supportEmail = '';

  /// Trang Chính sách bảo mật (https://...).
  static const String privacyPolicyUrl = '';

  /// Trang ứng dụng trên Google Play / App Store để đánh giá.
  static const String storeUrl = '';

  /// Liên kết tải ứng dụng dùng khi chia sẻ.
  static const String shareUrl = '';
}
