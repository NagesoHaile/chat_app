import 'package:flutter/material.dart';

import 'tg_theme.dart';

/// Bottom input bar: emoji button, multi-line field, attach button, and a
/// mic that turns into a send button as soon as there is text.
class Composer extends StatelessWidget {
  const Composer({super.key, required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tg.header,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () {},
              iconSize: 26,
              color: Tg.subtle,
              icon: const Icon(Icons.emoji_emotions_outlined),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Tg.text, fontSize: 17),
                cursorColor: Tg.accent,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: Tg.subtle, fontSize: 17),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {},
                      iconSize: 26,
                      color: Tg.subtle,
                      icon: const Icon(Icons.attach_file),
                    ),
                    hasText
                        ? IconButton(
                            onPressed: onSend,
                            iconSize: 26,
                            color: Tg.accent,
                            icon: const Icon(Icons.send_rounded),
                          )
                        : IconButton(
                            onPressed: () {},
                            iconSize: 26,
                            color: Tg.subtle,
                            icon: const Icon(Icons.mic_none),
                          ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
