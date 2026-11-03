import 'package:flutter/material.dart';

import 'ui/chat_screen.dart';
import 'ui/tg_theme.dart';

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat',
      debugShowCheckedModeBanner: false,
      theme: Tg.theme(),
      home: const ChatScreen(),
    );
  }
}
