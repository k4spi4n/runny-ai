import 'package:flutter/material.dart';

/// Cuộn để phần đầu của phản hồi mới nằm ở đầu vùng chat.
///
/// Dùng [Scrollable.ensureVisible] thay vì cuộn đến `maxScrollExtent` để các
/// phản hồi dài luôn bắt đầu ở đoạn người dùng cần đọc trước tiên.
void scrollChatResponseToStart(
  GlobalKey responseKey, {
  Duration duration = const Duration(milliseconds: 240),
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final responseContext = responseKey.currentContext;
    if (responseContext == null) return;

    Scrollable.ensureVisible(
      responseContext,
      alignment: 0,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  });
}
