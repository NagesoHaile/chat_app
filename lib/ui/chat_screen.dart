import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../data/message_repository.dart';
import 'app_theme.dart';
import 'composer.dart';
import 'goto_dialog.dart';
import 'message_tile.dart';

/// HOW THE LIST WORKS (read this first)
///
/// A CustomScrollView has a `center` sliver. Scroll offset 0 = the top of
/// the center sliver.
///   - Sliver BEFORE center ("older"): index 0 is the message just above the
///     anchor, and it grows upward.
///   - Sliver AT center ("newer"): index 0 is the anchor message itself.
///
/// Consequences:
///   * Opening at the first unread = anchor on it. No scrolling needed.
///   * Jump to any ID = anchor on that ID (new ScrollController). Instant.
///   * An image growing in the "older" sliver grows upward and does not move
///     what you read below it. An image growing in the "newer" sliver above
///     the viewport pushes content down, so we correct the offset.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _centerKey = ValueKey('chat-center');

  final _repo = MessageRepository();
  final _viewportKey = GlobalKey();
  final _tiles = <int, BuildContext>{}; // visible tiles, filled by MessageTile
  final _input = TextEditingController();

  late int _anchorId = _repo.firstUnreadId;
  late ScrollController _controller = ScrollController(
    initialScrollOffset: -96,
  ); // show a bit of read history
  int _generation = 0; // new generation = brand new scroll view

  bool _stick = false; // true while the user is at the bottom
  bool _programmatic = false; // true while WE move the scroll position
  bool _pinQueued = false;
  bool _hidden = false; // hide the list for 1 frame while jumping to bottom
  int _pendingNew = 0; // new messages that arrived while reading old ones
  int? _highlightId;
  Timer? _highlightTimer;

  /// Drives the round "scroll to bottom" button without rebuilding the list.
  final _showDown = ValueNotifier<bool>(true);

  Size? _lastSize;
  TextScaler? _lastScaler;

  // ---------------------------------------------------------------- lifecycle

  /// Fires when screen size (rotation) or text scale changes, BEFORE layout.
  /// The render tree still has the old layout, so we can measure which message
  /// the user is reading and re-anchor the list on it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final changed =
        _lastSize != null && (size != _lastSize || scaler != _lastScaler);
    _lastSize = size;
    _lastScaler = scaler;
    if (!changed || _stick) return; // at bottom: the pin logic handles it

    final reading = _captureReading();
    if (reading == null) return;
    if (_repo.total - reading.id < kMinForwardMessages) {
      _prepareBottom();
      _finishBottomAfterFrame();
    } else {
      _reanchor(reading.id, -reading.dy);
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _controller.dispose();
    _input.dispose();
    _showDown.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- helpers

  double get _viewportHeight =>
      _viewportKey.currentContext?.size?.height ?? 600;

  RenderBox? get _viewportBox {
    final box = _viewportKey.currentContext?.findRenderObject();
    return box is RenderBox && box.attached ? box : null;
  }

  /// Move the scroll position without confusing the "user is at bottom" logic.
  void _jump(double offset) {
    if (!_controller.hasClients) return;
    _programmatic = true;
    _controller.position.jumpTo(offset);
    _programmatic = false;
  }

  /// Swap the anchor message and start a fresh ScrollController.
  /// [offset] is the scroll offset relative to the anchor (negative = the
  /// anchor sits below the top of the screen). Call inside setState, or from
  /// didChangeDependencies (a build follows).
  void _reanchor(int id, double offset) {
    final old = _controller;
    _anchorId = id;
    _generation++;
    _controller = ScrollController(initialScrollOffset: offset);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _highlight(int id) {
    _highlightId = id;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ----------------------------------------- keep reading position (rotation)

  /// Finds the first message that is visible at the top of the viewport and
  /// how far its top edge is from the viewport top (dy, may be negative).
  ({int id, double dy})? _captureReading() {
    final viewport = _viewportBox;
    if (viewport == null) return null;

    int? bestId;
    var bestDy = 0.0;
    var bestBottom = double.infinity;
    _tiles.forEach((id, ctx) {
      if (!ctx.mounted) return;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final bottom = top + box.size.height;
      if (bottom > 1 && bottom < bestBottom) {
        bestBottom = bottom;
        bestId = id;
        bestDy = top;
      }
    });
    return bestId == null ? null : (id: bestId!, dy: bestDy);
  }

  // ------------------------------------------- images loading above the view

  /// Called by a tile just before its image changes height by [delta].
  void _onImageLoaded(int id, BuildContext tileContext, double delta) {
    final viewport = _viewportBox;
    final box = tileContext.findRenderObject();
    if (viewport == null || box is! RenderBox || !_controller.hasClients)
      return;

    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final pos = _controller.position;
    final isForward = id >= _anchorId; // lives in the sliver at the center

    if (isForward && top < 0) {
      // Grows downward while above the viewport: it would push content down.
      _jump(pos.pixels + delta);
    } else if (!isForward && top >= 0) {
      // Grows upward: everything older than it would move up on screen.
      _jump(pos.pixels - delta);
    }
  }

  // ------------------------------------------------------ stick to the bottom

  bool _onScroll(ScrollNotification n) {
    if (_programmatic || n.depth != 0) return false;
    // User is only stuck to bottom if extentAfter is virtually 0 AND not actively scrolling up
    _stick = n.metrics.extentAfter < 2.0;
    _showDown.value = !_stick;
    if (_stick && _pendingNew > 0) setState(() => _pendingNew = 0);
    return false;
  }

  /// Fires when content/viewport size changes (image loaded at the bottom,
  /// keyboard opened/closed, new messages). If we were at the bottom, stay.
  bool _onMetrics(ScrollMetricsNotification n) {
    // Only pin if genuine layout expansion pushed us away while user was at the very bottom
    if (_stick && n.metrics.extentAfter > 2.0) _pinToBottom();
    return false;
  }

  void _pinToBottom() {
    if (_pinQueued) return;
    _pinQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinQueued = false;
      if (!mounted || !_controller.hasClients) return;
      final p = _controller.position;
      if (_stick && p.extentAfter > 0.5) _jump(p.maxScrollExtent);
    });
  }

  // ---------------------------------------------------------------- actions

  /// Simulates 50 new incoming messages.
  void _addMessages() {
    final wasAtBottom = _stick;
    setState(() {
      _repo.addMessages(kNewBatchSize);
      if (!wasAtBottom) _pendingNew += kNewBatchSize; // don't move the view
    });
    if (wasAtBottom) _pinToBottom();
  }

  /// Sends what the user typed and ensures view pins to the message.
  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    if (_stick) {
      setState(() {
        _repo.send(text);
        _pendingNew = 0;
      });
      _pinToBottom();
    } else {
      _repo.send(text);
      _jumpToBottom();
    }
  }

  /// Anchor near the end, then (after one frame) scroll to the very bottom.
  void _prepareBottom() {
    _reanchor(math.max(1, _repo.total - kMinForwardMessages), 0);
    _stick = true;
    _pendingNew = 0;
    _hidden = true;
  }

  void _finishBottomAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) _jump(_controller.position.maxScrollExtent);
      _showDown.value = false;
      setState(() => _hidden = false);
    });
  }

  void _jumpToBottom({int? highlight}) {
    setState(() {
      _prepareBottom();
      if (highlight != null) _highlight(highlight);
    });
    _finishBottomAfterFrame();
  }

  Future<void> _askMessageId() async {
    final id = await showGoToDialog(context, _repo.total);
    if (id != null && mounted) _goToId(id);
  }

  void _goToId(int id) {
    if (id < 1 || id > _repo.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a number from 1 to ${_repo.total}')),
      );
      return;
    }

    final sw = Stopwatch()..start();
    if (_repo.total - id < kMinForwardMessages) {
      _jumpToBottom(highlight: id);
    } else {
      final offset = id <= 5 ? 0.0 : -_viewportHeight * 0.3;
      setState(() {
        _reanchor(id, offset);
        _stick = false;
        _highlight(id);
      });
      _showDown.value = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('Jump to #$id took ${sw.elapsedMilliseconds} ms');
    });
  }

  // ------------------------------------------------------------------- build

  Widget _tile(int id) {
    final m = _repo.get(id);
    final prev = id > 1 ? _repo.get(id - 1) : null;
    final next = id < _repo.total ? _repo.get(id + 1) : null;

    final newDay = prev == null || !_sameDay(prev.time, m.time);
    final divider = id == _repo.firstUnreadId;
    final isFirst = newDay || divider || prev.isMine != m.isMine;
    final isLast =
        next == null ||
        next.isMine != m.isMine ||
        !_sameDay(m.time, next.time) ||
        next.id == _repo.firstUnreadId;

    return MessageTile(
      key: ValueKey(id),
      message: m,
      showDate: newDay,
      showUnreadDivider: divider,
      isFirstInGroup: isFirst,
      isLastInGroup: isLast,
      highlighted: id == _highlightId,
      loadedImages: _repo.loadedImages,
      registry: _tiles,
      onImageLoaded: _onImageLoaded,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.header,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppTheme.header,
        systemNavigationBarColor: AppTheme.header,
      ),

      title: Row(
        children: [
          const _Avatar(initials: 'AB'),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Two F Capital',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.text,
                  ),
                ),
                Text(
                  'online',
                  style: TextStyle(fontSize: 13, color: AppTheme.accent),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Go to message ID',
          icon: const Icon(Icons.search),
          onPressed: _askMessageId,
        ),
        IconButton(
          tooltip: 'Receive $kNewBatchSize new messages',
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: _addMessages,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final olderCount = _anchorId - 1;
    final newerCount = _repo.total - _anchorId + 1;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Opacity(
                  opacity: _hidden ? 0 : 1,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: _onMetrics,
                      child: SizedBox.expand(
                        key: _viewportKey,
                        child: CustomScrollView(
                          key: ValueKey(_generation),
                          controller: _controller,
                          center: _centerKey,
                          cacheExtent: 300,
                          slivers: [
                            // Older messages: index 0 is right above the anchor.
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => _tile(_anchorId - 1 - i),
                                childCount: olderCount,
                                addAutomaticKeepAlives: false,
                                findChildIndexCallback: (key) {
                                  final id = (key as ValueKey<int>).value;
                                  final i = _anchorId - 1 - id;
                                  return i >= 0 && i < olderCount ? i : null;
                                },
                              ),
                            ),
                            // Anchor message and everything newer.
                            SliverList(
                              key: _centerKey,
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => _tile(_anchorId + i),
                                childCount: newerCount,
                                addAutomaticKeepAlives: false,
                                findChildIndexCallback: (key) {
                                  final id = (key as ValueKey<int>).value;
                                  final i = id - _anchorId;
                                  return i >= 0 && i < newerCount ? i : null;
                                },
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_pendingNew > 0)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _jumpToBottom,
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        label: Text('$_pendingNew new messages'),
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showDown,
                    builder: (context, show, _) => IgnorePointer(
                      ignoring: !show,
                      child: AnimatedOpacity(
                        opacity: show ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Material(
                          color: AppTheme.header,
                          elevation: 3,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _jumpToBottom,
                            child: const SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                size: 28,
                                color: AppTheme.subtle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7ED0A8), Color(0xFF3FA38A)],
        ),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }
}
