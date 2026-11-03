/// Describes an image attached to a message.
/// [finalHeight] is only "revealed" to the UI after [loadDelay].
class ImageSpec {
  const ImageSpec({
    required this.finalHeight,
    required this.loadDelay,
    required this.seed,
  });

  final double finalHeight;
  final Duration loadDelay;
  final int seed; // drives the procedurally drawn picture
}

class Message {
  const Message({
    required this.id,
    required this.text,
    required this.isMine,
    required this.time,
    this.image,
    this.read = true,
  });

  final int id;
  final String text;
  final bool isMine;
  final DateTime time;
  final ImageSpec? image;

  /// For my own messages: false = one tick (sent), true = two ticks (read).
  final bool read;
}
