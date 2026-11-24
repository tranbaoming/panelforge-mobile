import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafeBackNavigation on BuildContext {
  /// Nút "←" trong app: quay lại trang trước nếu có; nếu trang được mở thẳng
  /// (deep link `panelforge://app/series/<id>`, chuyển hướng sau đăng nhập, tải lại web)
  /// thì không còn gì để pop → đi tới [fallback] thay vì đứng yên.
  void popOrGo(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
