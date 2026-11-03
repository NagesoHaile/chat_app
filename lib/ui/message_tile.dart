import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/message.dart';
import 'app_theme.dart';
import 'bubble.dart';
import 'fake_image.dart';

const Color _kHighlight = Color(0x59FFC107);
const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

/// Called right BEFORE an image changes the tile's height, so the screen can
/// compensate the scroll offset. [delta] = finalHeight - placeholderHeight.
typedef ImageLoadedCallback = void Function(
    int id, BuildContext context, double delta);

class MessageTile extends StatefulWidget {
  const MessageTile({
    super.key,
    required this.message,
    required this.showDate,
    required this.showUnreadDivider,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.highlighted,
    required this.loadedImages,
    required this.registry,
    required this.onImageLoaded,
  });

  final Message message;
  final bool showDate; // first message of a new day
  final bool showUnreadDivider;
  final bool isFirstInGroup; // previous message is from someone else
  final bool isLastInGroup; // next message is from someone else (gets a tail)
  final bool highlighted;
  final Set<int> loadedImages;

  /// Lets the screen find visible tiles (used to keep position on rotation).
  final Map<int, BuildContext> registry;
  final ImageLoadedCallback onImageLoaded;

  @override
  State<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<MessageTile> {
  Timer? _timer;
  late bool _loaded;

  @override
  void initState() {
    super.initState();
    final m = widget.message;
    widget.registry[m.id] = context;
    _loaded = m.image == null || widget.loadedImages.contains(m.id);
    if (!_loaded) {
      // Height is unknown until this timer fires (0.5 to 3 s).
      _timer = Timer(m.image!.loadDelay, _finishLoading);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.registry[widget.message.id] == context) {
      widget.registry.remove(widget.message.id);
    }
    super.dispose();
  }

  void _finishLoading() {
    if (!mounted) return;
    final m = widget.message;
    final delta = m.image!.finalHeight - kImagePlaceholderHeight;
    widget.onImageLoaded(m.id, context, delta); // compensate scroll first
    widget.loadedImages.add(m.id);
    setState(() => _loaded = true);
  }

  String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.80;
    final radius = bubbleRadius(
      isMine: m.isMine,
      isFirst: widget.isFirstInGroup,
      isLast: widget.isLastInGroup,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                m.isMine ? 'You' : 'User #${(m.id % 24) + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '#${m.id}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: m.isMine ? AppTheme.outMeta.withValues(alpha: 0.7) : AppTheme.subtle,
                ),
              ),
            ],
          ),
        ),
        if (m.image != null)
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: radius.topLeft,
              topRight: radius.topRight,
            ),
            child: _buildImage(m.image!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: _textWithTime(m),
        ),
      ],
    );

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: CustomPaint(
        painter: BubblePainter(
          color: m.isMine ? AppTheme.outBubble : AppTheme.inBubble,
          radius: radius,
          isMine: m.isMine,
          hasTail: widget.isLastInGroup,
        ),
        // Image bubbles are always full width, like Telegram.
        child: m.image != null ? SizedBox(width: maxWidth, child: content) : content,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDate) _DateChip(label: _dateLabel(m.time)),
        if (widget.showUnreadDivider) const _UnreadDivider(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          color: widget.highlighted ? _kHighlight : Colors.transparent,
          padding: EdgeInsets.fromLTRB(
              12, widget.isFirstInGroup ? 6 : 1.5, 12, 1.5),
          alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: bubble,
        ),
      ],
    );
  }

  String _dateLabel(DateTime t) => '${_months[t.month - 1]} ${t.day}';

  /// Text with the time + ticks floating at the bottom-right, like Telegram.
  /// A transparent spacer at the end of the text reserves room for the time.
  Widget _textWithTime(Message m) {
    final reserve = m.isMine ? 64.0 : 46.0;
    return Stack(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: m.text),
              WidgetSpan(
                alignment: PlaceholderAlignment.bottom,
                child: SizedBox(width: reserve, height: 14),
              ),
            ],
          ),
          style: const TextStyle(color: AppTheme.text, fontSize: 16, height: 1.25),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _clock(m.time),
                style: TextStyle(
                  fontSize: 12,
                  color: m.isMine ? AppTheme.outMeta : AppTheme.subtle,
                ),
              ),
              if (m.isMine) ...[
                const SizedBox(width: 3),
                Icon(m.read ? Icons.done_all : Icons.done,
                    size: 16, color: AppTheme.outMeta),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage(ImageSpec spec) {
    return _loaded
        ? SizedBox(
            height: spec.finalHeight,
            width: double.infinity,
            child: CustomPaint(painter: FakeImagePainter(spec.seed)),
          )
        : Container(
            height: kImagePlaceholderHeight,
            width: double.infinity,
            color: const Color(0x33000000),
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined, size: 40, color: AppTheme.subtle),
          );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xB317212B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            label,
            style: const TextStyle(
                color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xCC17212B),
      alignment: Alignment.center,
      child: const Text(
        'Unread messages',
        style: TextStyle(
            color: Color(0xFF8FA3B3), fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
