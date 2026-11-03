import 'dart:math';

import '../models/message.dart';
import 'corpus.dart';

enum _Lang { english, amharic, mixed }

/// Builds message #[id] from a seeded Random, so the same ID always gives
/// the same message. Nothing is stored: 100k messages cost ~0 memory.
class MessageGenerator {
  static final DateTime _epoch = DateTime(2026, 1, 1, 8);

  static Message generate(int id) {
    final r = Random(id * 1000003 ^ 0x5bd1e995);

    // 1 to 500 words, skewed toward short messages, ~1% exactly 500.
    final words = r.nextInt(100) == 0
        ? 500
        : 1 + (499 * pow(r.nextDouble(), 3)).floor();

    final roll = r.nextDouble();
    final lang = roll < 0.45
        ? _Lang.english
        : roll < 0.90
            ? _Lang.amharic
            : _Lang.mixed;

    final hasImage = r.nextDouble() < 0.20; // ~20%
    final image = hasImage
        ? ImageSpec(
            finalHeight: 120.0 + r.nextInt(300),
            loadDelay: Duration(milliseconds: 500 + r.nextInt(2501)),
            seed: id,
          )
        : null;

    return Message(
      id: id,
      text: _buildText(r, words, lang),
      isMine: r.nextDouble() < 0.4,
      time: _epoch.add(Duration(seconds: id * 37)),
      image: image,
    );
  }

  static String _buildText(Random r, int words, _Lang lang) {
    final b = StringBuffer();
    var amharic = lang == _Lang.amharic;
    var sentenceLen = 5 + r.nextInt(9);
    var inSentence = 0;

    for (var i = 0; i < words; i++) {
      final list = amharic ? kAmharicWords : kEnglishWords;
      var w = list[r.nextInt(list.length)];
      if (!amharic && inSentence == 0) {
        w = w[0].toUpperCase() + w.substring(1);
      }
      b.write(w);
      inSentence++;

      final last = i == words - 1;
      if (last || inSentence >= sentenceLen) {
        b.write(amharic ? '።' : '.');
        inSentence = 0;
        sentenceLen = 5 + r.nextInt(9);
        if (lang == _Lang.mixed) amharic = r.nextBool();
        if (!last) b.write(r.nextInt(12) == 0 ? '\n\n' : ' ');
      } else {
        b.write(' ');
      }
    }
    return b.toString();
  }
}
