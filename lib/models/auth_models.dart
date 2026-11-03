import 'package:flutter/foundation.dart';

/// Thông tin người dùng cơ bản từ Backend PanelForge
@immutable
class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final bool isActive;
  final bool isEmailConfirmed;
  final bool twoFactorEnabled;
  final String role;
  final bool canCreateStudio;

  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    required this.isActive,
    this.isEmailConfirmed = false,
    this.twoFactorEnabled = false,
    this.role = 'User',
    this.canCreateStudio = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      isActive: json['isActive'] == true,
      isEmailConfirmed: json['isEmailConfirmed'] == true,
      twoFactorEnabled: json['twoFactorEnabled'] == true,
      role: json['role']?.toString() ?? 'User',
      canCreateStudio: json['canCreateStudio'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'isActive': isActive,
      'isEmailConfirmed': isEmailConfirmed,
      'twoFactorEnabled': twoFactorEnabled,
      'role': role,
      'canCreateStudio': canCreateStudio,
    };
  }
}

/// Mô hình phản hồi từ các endpoint xác thực của Backend (.NET AuthResponse)
@immutable
class AuthResponseModel {
  final String? token;
  final DateTime? expiresAt;
  final AuthUser? user;
  final bool requiresTwoFactor;
  final String? twoFactorEmail;
  final String? message;
  final String? rememberDeviceToken;
  final String? refreshToken;

  const AuthResponseModel({
    this.token,
    this.expiresAt,
    this.user,
    this.requiresTwoFactor = false,
    this.twoFactorEmail,
    this.message,
    this.rememberDeviceToken,
    this.refreshToken,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    DateTime? exp;
    if (json['expiresAt'] != null) {
      exp = DateTime.tryParse(json['expiresAt'].toString());
    }
    return AuthResponseModel(
      token: json['token']?.toString(),
      expiresAt: exp,
      user: json['user'] is Map<String, dynamic>
          ? AuthUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      requiresTwoFactor: json['requiresTwoFactor'] == true,
      twoFactorEmail: json['twoFactorEmail']?.toString(),
      message: json['message']?.toString(),
      rememberDeviceToken: json['rememberDeviceToken']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
    );
  }
}

/// Tóm tắt Workspace mà User tham gia
@immutable
class WorkspaceSummary {
  final String workspaceId;
  final String name;
  final String role;

  const WorkspaceSummary({
    required this.workspaceId,
    required this.name,
    required this.role,
  });

  factory WorkspaceSummary.fromJson(Map<String, dynamic> json) {
    return WorkspaceSummary(
      workspaceId: json['workspaceId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'workspaceId': workspaceId,
        'name': name,
        'role': role,
      };
}

/// Ngữ cảnh điều hướng Landing Context từ Backend (GET /api/auth/me/landing-context)
@immutable
class LandingContext {
  final String userId;
  final String systemRole;
  final bool canCreateStudio;
  final List<WorkspaceSummary> workspaces;
  final String suggestedLanding; // 'AdminDashboard' | 'YourWorkspaces' | 'StudioCreation' | 'PublicCatalog'

  const LandingContext({
    required this.userId,
    required this.systemRole,
    required this.canCreateStudio,
    required this.workspaces,
    required this.suggestedLanding,
  });

  factory LandingContext.fromJson(Map<String, dynamic> json) {
    final list = json['workspaces'];
    final workspaces = <WorkspaceSummary>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          workspaces.add(WorkspaceSummary.fromJson(item));
        }
      }
    }
    return LandingContext(
      userId: json['userId']?.toString() ?? '',
      systemRole: json['systemRole']?.toString() ?? '',
      canCreateStudio: json['canCreateStudio'] == true,
      workspaces: workspaces,
      suggestedLanding: json['suggestedLanding']?.toString() ?? 'PublicCatalog',
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'systemRole': systemRole,
        'canCreateStudio': canCreateStudio,
        'workspaces': workspaces.map((w) => w.toJson()).toList(),
        'suggestedLanding': suggestedLanding,
      };

  /// Kiểm tra xem tài khoản có vai trò quản trị hoặc sản xuất trên Web không
  bool get isRestrictedWebRole =>
      suggestedLanding == 'AdminDashboard' ||
      suggestedLanding == 'YourWorkspaces' ||
      suggestedLanding == 'StudioCreation';
}

/// Phân loại vai trò người dùng trong phạm vi Ứng dụng Mobile
enum MobileAuthRole {
  /// Chưa xác thực (chưa chọn vào Guest, chưa đăng nhập Reader) -> hiển thị màn hình Login
  unauthenticated,

  /// Khách chưa đăng nhập (đã bấm chọn 'Tiếp tục với tư cách Khách')
  guest,

  /// Độc giả thông thường đã đăng nhập
  reader,

  /// Tài khoản có quyền Producer / Admin trên web, nhưng trên mobile bị giới hạn ở chế độ Độc giả
  restrictedReader,
}

/// Trạng thái xác thực toàn cục cho Ứng dụng Mobile
@immutable
class AuthState {
  final MobileAuthRole role;
  final AuthUser? user;
  final LandingContext? landingContext;
  final String? restrictionNotice;
  final bool isLoading;

  const AuthState({
    required this.role,
    this.user,
    this.landingContext,
    this.restrictionNotice,
    this.isLoading = false,
  });

  bool get isAuthenticated =>
      (role == MobileAuthRole.reader || role == MobileAuthRole.restrictedReader) && user != null;
  bool get isGuest => role == MobileAuthRole.guest;
  bool get isUnauthenticated => role == MobileAuthRole.unauthenticated;
  bool get isRestricted => role == MobileAuthRole.restrictedReader;

  factory AuthState.unauthenticated() => const AuthState(role: MobileAuthRole.unauthenticated);
  factory AuthState.guest() => const AuthState(role: MobileAuthRole.guest);

  AuthState copyWith({
    MobileAuthRole? role,
    AuthUser? user,
    LandingContext? landingContext,
    String? restrictionNotice,
    bool? isLoading,
    bool clearNotice = false,
  }) {
    return AuthState(
      role: role ?? this.role,
      user: user ?? this.user,
      landingContext: landingContext ?? this.landingContext,
      restrictionNotice: clearNotice ? null : (restrictionNotice ?? this.restrictionNotice),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

