import 'package:flutter/material.dart';

/// Telegram dark palette. Change colors here and the whole app follows.
class Tg {
  Tg._();

  static const bg = Color(0xFF0E1621); // chat background
  static const header = Color(0xFF17212B); // app bar + composer
  static const inBubble = Color(0xFF182533); // received message
  static const outBubble = Color(0xFF2B5278); // sent message
  static const accent = Color(0xFF6AB2F2);
  static const subtle = Color(0xFF6D7F8F); // hints, incoming time
  static const outMeta = Color(0xFF7DA8D3); // outgoing time + ticks
  static const text = Color(0xFFFFFFFF);

  static ThemeData theme() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(primary: accent, surface: header),
      appBarTheme: const AppBarTheme(
        backgroundColor: header,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFAAB8C2)),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accent,
        selectionHandleColor: accent,
      ),
    );
  }
}
