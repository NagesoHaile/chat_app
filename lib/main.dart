import 'package:flutter/material.dart';

import 'ui/app_theme.dart';
import 'ui/chat_screen.dart';

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      home: const ChatScreen(),
    );
  }
}
