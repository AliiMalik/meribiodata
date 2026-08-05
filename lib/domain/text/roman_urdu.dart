/// Roman Urdu → Urdu script transliteration (9.2).
///
/// The biggest real-world blocker to Urdu biodatas is that most users have no
/// Urdu keyboard and cannot type Nastaliq. This closes that gap **entirely on
/// device** — there is no transliteration API and never will be, because
/// sending user names off the phone would break NFR-1 outright.
///
/// Two layers, in order:
///
/// 1. a bundled dictionary of biodata vocabulary — names, biradaris, cities,
///    occupations, relationship terms;
/// 2. a rule-based grapheme mapping for anything else.
///
/// The dictionary always wins. Names are precisely where rule-based
/// transliteration fails and precisely where a wrong answer is least
/// acceptable, so "Muhammad" is a lookup, not a derivation.
library;

/// A candidate spelling, best first.
class Transliteration {
  const Transliteration({
    required this.text,
    required this.fromDictionary,
  });

  final String text;

  /// True when this came from the bundled dictionary rather than the rules.
  /// The UI can present those with more confidence.
  final bool fromDictionary;
}

/// Supplies the bundled word lists. Injected so the engine stays pure Dart and
/// testable without loading an asset.
///
/// An interface rather than a bare function type: implementations also carry
/// an entry count for the accuracy report, and this is the seam a
/// user-extensible dictionary would slot into later.
// ignore: one_member_abstracts
abstract interface class RomanUrduDictionary {
  /// All Urdu spellings known for a normalised Roman token, best first.
  List<String> lookup(String token);
}

class RomanUrduTransliterator {
  const RomanUrduTransliterator(this._dictionary);

  final RomanUrduDictionary _dictionary;

  /// Transliterates a whole line, token by token.
  ///
  /// Punctuation, digits and anything already in Urdu script pass through
  /// untouched — a user who types "Ali 2019" should not have the year mangled.
  String transliterate(String input) {
    if (input.isEmpty) return input;

    final buffer = StringBuffer();
    for (final token in _tokenise(input)) {
      buffer.write(
        _isWord(token) ? candidates(token).first.text : _urduPunctuation(token),
      );
    }
    return buffer.toString();
  }

  /// Urdu uses its own comma, semicolon and question mark. Leaving the ASCII
  /// ones in place is a small tell that the text was typed on a Latin
  /// keyboard, and this feature exists precisely so it does not read that way.
  static String _urduPunctuation(String token) =>
      token.replaceAll(',', '،').replaceAll(';', '؛').replaceAll('?', '؟');

  /// Candidate spellings for a single word, best first.
  ///
  /// The suggestion strip shows these so the user can correct a guess with one
  /// tap rather than retyping.
  List<Transliteration> candidates(String word) {
    if (word.isEmpty) return const [];
    if (_containsUrdu(word)) {
      return [Transliteration(text: word, fromDictionary: false)];
    }

    final normalised = _normalise(word);
    final seen = <String>{};
    final results = <Transliteration>[];

    for (final entry in _dictionary.lookup(normalised)) {
      if (seen.add(entry)) {
        results.add(Transliteration(text: entry, fromDictionary: true));
      }
    }

    final ruled = applyRules(normalised);
    if (seen.add(ruled)) {
      results.add(Transliteration(text: ruled, fromDictionary: false));
    }

    return results;
  }

  /// Digraphs are matched before single letters, longest first, because `sh`
  /// must never be read as `s` + `h`.
  static const _digraphs = <String, String>{
    'sch': 'سک',
    'kkh': 'کھ',
    'chh': 'چھ',
    'ssh': 'ش',
    'aan': 'ان',
    'kh': 'خ',
    'gh': 'غ',
    'ch': 'چ',
    'sh': 'ش',
    'zh': 'ژ',
    'th': 'تھ',
    'ph': 'پھ',
    'bh': 'بھ',
    'dh': 'دھ',
    'jh': 'جھ',
    'rh': 'ڑھ',
    'ng': 'نگ',
    'ck': 'ک',
    'qu': 'ک',
    'ee': 'ی',
    'ea': 'ی',
    'ii': 'ی',
    'oo': 'و',
    'ou': 'و',
    'au': 'او',
    'aa': 'ا',
    // 'ai' is far more often ی than ای in the middle of a Pakistani name —
    // Gulraiz گلریز, Zubaida زبیدہ — so the commoner reading wins.
    'ai': 'ی',
    'ay': 'ے',
    'ey': 'ے',
    'ia': 'یہ',
  };

  static const _letters = <String, String>{
    'b': 'ب',
    'p': 'پ',
    't': 'ت',
    's': 'س',
    'j': 'ج',
    'h': 'ہ',
    'd': 'د',
    'r': 'ر',
    'z': 'ز',
    'f': 'ف',
    'q': 'ق',
    'k': 'ک',
    'g': 'گ',
    'l': 'ل',
    'm': 'م',
    'n': 'ن',
    'v': 'و',
    'w': 'و',
    'y': 'ی',
    'x': 'کس',
    'c': 'ک',
  };

  /// The rule-based fallback.
  ///
  /// The hard part is that Roman Urdu does not distinguish long vowels from
  /// short ones, and Urdu writes only the long ones. "Muhammad" is م-ح-م-د
  /// with nothing between, but "Ghulam" is غلام with the second vowel written.
  /// Same letter `a`, different treatment, no signal in the input.
  ///
  /// The heuristic: **write the last medial vowel, drop the earlier ones.** In
  /// Pakistani names the stressed long vowel usually falls in the final
  /// syllable — Ghul-*aa*m, Bash-*ee*r, Musht-*aa*q, Sard-*aa*r — so this gets
  /// a useful share of unseen names right. It is a heuristic and it will be
  /// wrong sometimes; that is what the dictionary and the correction strip are
  /// for. Measured on a held-out set in `roman_urdu_test.dart`.
  static String applyRules(String word) {
    final lastMedialVowel = _lastMedialVowelIndex(word);

    final buffer = StringBuffer();
    var i = 0;
    var isFirst = true;

    while (i < word.length) {
      final remaining = word.length - i;

      // Longest digraph first.
      var matched = false;
      for (var size = 3; size >= 2 && !matched; size--) {
        if (remaining < size) continue;
        final chunk = word.substring(i, i + size);
        final mapped = _digraphs[chunk];
        if (mapped != null) {
          buffer.write(mapped);
          i += size;
          isFirst = false;
          matched = true;
        }
      }
      if (matched) continue;

      final ch = word[i];
      final isLast = i == word.length - 1;

      if (_isVowel(ch)) {
        buffer.write(
          _vowel(
            ch,
            isFirst: isFirst,
            isLast: isLast,
            isStressed: i == lastMedialVowel,
          ),
        );
      } else {
        buffer.write(_letters[ch] ?? ch);
      }

      isFirst = false;
      i++;
    }

    return buffer.toString();
  }

  /// Index of the last vowel that is neither first nor final, or -1.
  static int _lastMedialVowelIndex(String word) {
    for (var i = word.length - 2; i > 0; i--) {
      if (_isVowel(word[i])) return i;
    }
    return -1;
  }

  static bool _isVowel(String ch) => 'aeiou'.contains(ch);

  static String _vowel(
    String ch, {
    required bool isFirst,
    required bool isLast,
    required bool isStressed,
  }) {
    if (isFirst) {
      return switch (ch) {
        'a' => 'ا',
        'e' => 'ای',
        'i' => 'ا',
        'o' => 'او',
        _ => 'ا',
      };
    }
    if (isLast) {
      // A trailing vowel is audible, so it is written: "Hamza" ends in ہ,
      // "Ali" in ی, "Abu" in و.
      return switch (ch) {
        'a' => 'ہ',
        'e' => 'ے',
        'i' => 'ی',
        'o' => 'و',
        _ => 'و',
      };
    }
    if (isStressed) {
      // The long vowel of the final syllable, which Urdu does write.
      return switch (ch) {
        'a' => 'ا',
        'i' => 'ی',
        'e' => 'ی',
        'u' => 'و',
        'o' => 'و',
        _ => '',
      };
    }
    // Earlier medial vowels are short, and Urdu does not write those.
    return '';
  }

  static final _wordPattern = RegExp('[A-Za-z]+');
  static final _urduPattern = RegExp('[؀-ۿ]');

  static bool _isWord(String token) => _wordPattern.hasMatch(token);

  static bool _containsUrdu(String token) => _urduPattern.hasMatch(token);

  /// Lowercases and drops the punctuation people scatter through names —
  /// "Ch." and "Ch" must reach the dictionary as the same key.
  static String _normalise(String word) =>
      word.toLowerCase().replaceAll(RegExp('[^a-z]'), '');

  /// Splits into words and the separators between them, keeping both so the
  /// original spacing and punctuation survive.
  static List<String> _tokenise(String input) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool? wasWord;

    for (final ch in input.split('')) {
      final isWord = _wordPattern.hasMatch(ch);
      if (wasWord != null && isWord != wasWord) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      buffer.write(ch);
      wasWord = isWord;
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }
}
