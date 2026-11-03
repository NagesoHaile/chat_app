import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for a message ID. Returns null if cancelled.
Future<int?> showGoToDialog(BuildContext context, int maxId) {
  return showDialog<int>(
    context: context,
    builder: (_) => _GoToDialog(maxId: maxId),
  );
}

class _GoToDialog extends StatefulWidget {
  const _GoToDialog({required this.maxId});
  final int maxId;

  @override
  State<_GoToDialog> createState() => _GoToDialogState();
}

class _GoToDialogState extends State<_GoToDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, int.tryParse(_controller.text.trim()));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to message'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(hintText: 'Message ID (1 to ${widget.maxId})'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Go')),
      ],
    );
  }
}
