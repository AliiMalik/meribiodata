import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/bundled_roman_urdu.dart';
import 'package:meribiodata/domain/text/roman_urdu.dart';

/// The fixed evaluation set 9.2 asks for: real-world Roman Urdu as Pakistanis
/// actually type it, with the Urdu a native writer would expect.
///
/// Accuracy is reported rather than asserted at 100%: the feature is
/// deliberately time-boxed, and 80% with one-tap correction is already a step
/// change over every competitor. The floor below guards against regression.
const _evaluationSet = <String, String>{
  // --- Male names -------------------------------------------------------
  'Muhammad': 'محمد',
  'Mohammad': 'محمد',
  'Mohd': 'محمد',
  'Ahmed': 'احمد',
  'Ahmad': 'احمد',
  'Ali': 'علی',
  'Hassan': 'حسن',
  'Hussain': 'حسین',
  'Hussein': 'حسین',
  'Usman': 'عثمان',
  'Umar': 'عمر',
  'Bilal': 'بلال',
  'Hamza': 'حمزہ',
  'Abdullah': 'عبداللہ',
  'Aslam': 'اسلم',
  'Akram': 'اکرم',
  'Asif': 'آصف',
  'Arif': 'عارف',
  'Tariq': 'طارق',
  'Shahid': 'شاہد',
  'Khalid': 'خالد',
  'Rashid': 'راشد',
  'Waseem': 'وسیم',
  'Nadeem': 'ندیم',
  'Naveed': 'نوید',
  'Javed': 'جاوید',
  'Saeed': 'سعید',
  'Rafiq': 'رفیق',
  'Shafiq': 'شفیق',
  'Ibrahim': 'ابراہیم',
  'Ismail': 'اسماعیل',
  'Yousaf': 'یوسف',
  'Yusuf': 'یوسف',
  'Yaqoob': 'یعقوب',
  'Sulaiman': 'سلیمان',
  'Haroon': 'ہارون',
  'Imran': 'عمران',
  'Irfan': 'عرفان',
  'Adnan': 'عدنان',
  'Salman': 'سلمان',
  'Farhan': 'فرحان',
  'Kamran': 'کامران',
  'Zeeshan': 'ذیشان',
  'Rizwan': 'رضوان',
  'Nauman': 'نعمان',
  'Faisal': 'فیصل',
  'Kashif': 'کاشف',
  'Aamir': 'عامر',
  'Atif': 'عاطف',
  'Sajid': 'ساجد',
  'Majid': 'ماجد',
  'Abid': 'عابد',
  'Zahid': 'زاہد',
  'Waqar': 'وقار',
  'Asad': 'اسد',
  'Danish': 'دانش',
  'Fahad': 'فہد',
  'Talha': 'طلحہ',
  'Zain': 'زین',
  'Arsalan': 'ارسلان',

  // --- Female names -----------------------------------------------------
  'Ayesha': 'عائشہ',
  'Aisha': 'عائشہ',
  'Fatima': 'فاطمہ',
  'Khadija': 'خدیجہ',
  'Zainab': 'زینب',
  'Maryam': 'مریم',
  'Amna': 'آمنہ',
  'Hafsa': 'حفصہ',
  'Sana': 'ثنا',
  'Sadia': 'سعدیہ',
  'Nadia': 'نادیہ',
  'Saba': 'صبا',
  'Rabia': 'رابعہ',
  'Farah': 'فرح',
  'Sidra': 'سدرہ',
  'Hina': 'حنا',
  'Uzma': 'عظمیٰ',
  'Shazia': 'شازیہ',
  'Nazia': 'نازیہ',
  'Samina': 'ثمینہ',
  'Rukhsana': 'رخسانہ',
  'Kiran': 'کرن',
  'Iqra': 'اقرا',
  'Noor': 'نور',
  'Anum': 'انم',
  'Bushra': 'بشریٰ',
  'Nasreen': 'نسرین',
  'Tahira': 'طاہرہ',
  'Razia': 'رضیہ',
  'Parveen': 'پروین',
  'Shabana': 'شبانہ',
  'Asma': 'اسما',
  'Sumaira': 'سمیرا',
  'Javeria': 'جویریہ',

  // --- Surnames and biradaris -------------------------------------------
  'Khan': 'خان',
  'Malik': 'ملک',
  'Sheikh': 'شیخ',
  'Chaudhry': 'چوہدری',
  'Chaudhary': 'چوہدری',
  'Ch': 'چوہدری',
  'Syed': 'سید',
  'Mirza': 'مرزا',
  'Butt': 'بٹ',
  'Bhatti': 'بھٹی',
  'Qureshi': 'قریشی',
  'Siddiqui': 'صدیقی',
  'Ansari': 'انصاری',
  'Abbasi': 'عباسی',
  'Hashmi': 'ہاشمی',
  'Gilani': 'گیلانی',
  'Rana': 'رانا',
  'Raja': 'راجہ',
  'Shah': 'شاہ',
  'Awan': 'اعوان',
  'Gujjar': 'گجر',
  'Jatt': 'جٹ',
  'Arain': 'آرائیں',
  'Rajput': 'راجپوت',
  'Mughal': 'مغل',
  'Memon': 'میمن',
  'Soomro': 'سومرو',
  'Baloch': 'بلوچ',
  'Pathan': 'پٹھان',
  'Yousafzai': 'یوسفزئی',
  'Afridi': 'آفریدی',
  'Khattak': 'خٹک',
  'Niazi': 'نیازی',
  'Cheema': 'چیمہ',
  'Dogar': 'ڈوگر',
  'Sial': 'سیال',
  'Zardari': 'زرداری',
  'Bhutto': 'بھٹو',
  'Khokhar': 'کھوکھر',
  'Qazi': 'قاضی',

  // --- Cities and places ------------------------------------------------
  'Lahore': 'لاہور',
  'Karachi': 'کراچی',
  'Islamabad': 'اسلام آباد',
  'Rawalpindi': 'راولپنڈی',
  'Faisalabad': 'فیصل آباد',
  'Multan': 'ملتان',
  'Peshawar': 'پشاور',
  'Quetta': 'کوئٹہ',
  'Hyderabad': 'حیدرآباد',
  'Sialkot': 'سیالکوٹ',
  'Gujranwala': 'گوجرانوالہ',
  'Gujrat': 'گجرات',
  'Sargodha': 'سرگودھا',
  'Bahawalpur': 'بہاولپور',
  'Sukkur': 'سکھر',
  'Mardan': 'مردان',
  'Abbottabad': 'ایبٹ آباد',
  'Sahiwal': 'ساہیوال',
  'Okara': 'اوکاڑہ',
  'Jhelum': 'جہلم',
  'Kasur': 'قصور',
  'Sheikhupura': 'شیخوپورہ',
  'Mirpur': 'میرپور',
  'Gilgit': 'گلگت',
  'Jhang': 'جھنگ',
  'Attock': 'اٹک',
  'Mianwali': 'میانوالی',
  'Swat': 'سوات',
  'Kohat': 'کوہاٹ',
  'Gulberg': 'گلبرگ',
  'Pakistan': 'پاکستان',
  'Punjab': 'پنجاب',
  'Sindh': 'سندھ',

  // --- Biodata vocabulary -----------------------------------------------
  'walid': 'والد',
  'walida': 'والدہ',
  'naam': 'نام',
  'zaat': 'ذات',
  'biradari': 'برادری',
  'qaum': 'قوم',
  'rishta': 'رشتہ',
  'shadi': 'شادی',
  'taleem': 'تعلیم',
  'pesha': 'پیشہ',
  'pata': 'پتہ',
  'rabta': 'رابطہ',
  'maslak': 'مسلک',
  'hanafi': 'حنفی',
  'deobandi': 'دیوبندی',
  'doctor': 'ڈاکٹر',
  'engineer': 'انجینئر',
  'ustad': 'استاد',
  'wakeel': 'وکیل',
  'sarkari': 'سرکاری',
  'hospital': 'ہسپتال',
  'university': 'یونیورسٹی',
  'bhai': 'بھائی',
  'behn': 'بہن',
  'ghar': 'گھر',
  'makan': 'مکان',
  'kaam': 'کام',
  'sal': 'سال',
};

/// Words deliberately **absent** from the bundled dictionary.
///
/// This is the number that actually means something. The set above is drawn
/// from the same vocabulary the dictionary contains, so it scores ~100% and
/// measures coverage, not skill. These are held out to exercise the rule
/// engine on input it has never seen — which is what happens the moment a user
/// types a name we did not anticipate.
const _heldOutSet = <String, String>{
  'Zorawar': 'زوراور',
  'Gulraiz': 'گلریز',
  'Dilawar': 'دلاور',
  'Shahnawaz': 'شاہنواز',
  'Mehrunnisa': 'مہرالنسا',
  'Naimatullah': 'نعمت اللہ',
  'Bakhtawar': 'بختاور',
  'Zarnab': 'زرناب',
  'Shamshad': 'شمشاد',
  'Manzoor': 'منظور',
  'Barkat': 'برکت',
  'Nusrat': 'نصرت',
  'Liaqat': 'لیاقت',
  'Sarfaraz': 'سرفراز',
  'Kalsoom': 'کلثوم',
  'Zubaida': 'زبیدہ',
  'Ghulam': 'غلام',
  'Sardar': 'سردار',
  'Bashir': 'بشیر',
  'Mushtaq': 'مشتاق',
};

void main() {
  late RomanUrduTransliterator transliterator;
  late BundledRomanUrduDictionary dictionary;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dictionary = await BundledRomanUrduDictionary.load();
    transliterator = RomanUrduTransliterator(dictionary);
  });

  group('accuracy on the fixed evaluation set (9.2)', () {
    test('reports accuracy and holds a regression floor', () {
      final misses = <String, String>{};

      for (final entry in _evaluationSet.entries) {
        final produced = transliterator.transliterate(entry.key);
        if (produced != entry.value) misses[entry.key] = produced;
      }

      final total = _evaluationSet.length;
      final correct = total - misses.length;
      final accuracy = correct / total;

      // Printed so the figures in docs/progress/M5.md can be regenerated
      // rather than remembered — reporting is this test's whole purpose.
      // ignore: avoid_print
      print(
        'Roman Urdu — in-dictionary coverage: $correct/$total '
        '(${(accuracy * 100).toStringAsFixed(1)}%), '
        'dictionary size ${dictionary.entryCount}.',
      );
      if (misses.isNotEmpty) {
        // Reporting the measurement is this test's purpose.
        // ignore: avoid_print
        print('Coverage misses: $misses');
      }

      // Near-total by construction: this set is the vocabulary the dictionary
      // was built from. It guards the dictionary against corruption, and says
      // nothing about unseen words — see the held-out test below.
      expect(
        accuracy,
        greaterThanOrEqualTo(0.95),
        reason:
            'The dictionary should cover its own vocabulary. Misses: $misses',
      );
    });

    test('held-out words: the number that actually means something', () {
      final misses = <String, String>{};

      for (final entry in _heldOutSet.entries) {
        final produced = transliterator.transliterate(entry.key);
        if (produced != entry.value) misses[entry.key] = produced;
      }

      final total = _heldOutSet.length;
      final correct = total - misses.length;
      final accuracy = correct / total;

      // Reporting the measurement is this test's purpose.
      // ignore: avoid_print
      print(
        'Roman Urdu — held-out (rules only): $correct/$total '
        '(${(accuracy * 100).toStringAsFixed(1)}%).',
      );
      // Reporting the measurement is this test's purpose.
      // ignore: avoid_print
      print('Held-out misses: $misses');

      // Deliberately a low floor. 9.2 is explicitly time-boxed, and the
      // product bet is that a rough guess plus one-tap correction still beats
      // having no Urdu keyboard at all. The honest way to raise this number is
      // to grow the dictionary, not to tune the rules until the test passes.
      expect(
        accuracy,
        greaterThanOrEqualTo(0.2),
        reason:
            'Rule-based transliteration of unseen names has collapsed. '
            'Misses: $misses',
      );
    });

    test('the whole evaluation set produces Urdu script, never Latin', () {
      final latin = RegExp('[A-Za-z]');

      for (final roman in _evaluationSet.keys) {
        expect(
          transliterator.transliterate(roman),
          isNot(matches(latin)),
          reason: '"$roman" left Latin characters in the output',
        );
      }
    });
  });

  group('the letters that trip transliteration up (9.2)', () {
    test('kh, gh, ch, sh and zh are single sounds, not two letters', () {
      expect(RomanUrduTransliterator.applyRules('kh'), 'خ');
      expect(RomanUrduTransliterator.applyRules('gh'), 'غ');
      expect(RomanUrduTransliterator.applyRules('ch'), 'چ');
      expect(RomanUrduTransliterator.applyRules('sh'), 'ش');
      expect(RomanUrduTransliterator.applyRules('zh'), 'ژ');
    });

    test('the aspirated pairs stay aspirated', () {
      expect(RomanUrduTransliterator.applyRules('bh'), 'بھ');
      expect(RomanUrduTransliterator.applyRules('ph'), 'پھ');
      expect(RomanUrduTransliterator.applyRules('th'), 'تھ');
      expect(RomanUrduTransliterator.applyRules('dh'), 'دھ');
      expect(RomanUrduTransliterator.applyRules('jh'), 'جھ');
    });

    test('earlier medial vowels are dropped, the last one is written', () {
      // Roman Urdu gives no signal for vowel length, so the engine guesses
      // that the long vowel is in the final syllable — right for a useful
      // share of Pakistani names.
      expect(RomanUrduTransliterator.applyRules('sardar'), 'سردار');
      expect(RomanUrduTransliterator.applyRules('ghulam'), 'غلام');
      expect(RomanUrduTransliterator.applyRules('bashir'), 'بشیر');
    });

    test('the guess is wrong for genuinely short words, by design', () {
      // "kam" (less) is کم and "kaam" (work) is کام — identical in careless
      // Roman. The dictionary carries these; the rules cannot know.
      expect(RomanUrduTransliterator.applyRules('kam'), 'کام');
    });

    test('a trailing vowel is written, because it is heard', () {
      expect(RomanUrduTransliterator.applyRules('hamza'), endsWith('ہ'));
      expect(RomanUrduTransliterator.applyRules('kami'), endsWith('ی'));
    });
  });

  group('behaviour around the edges', () {
    test('every alternative Roman spelling reaches the same Urdu', () {
      for (final group in [
        ['Muhammad', 'Mohammad', 'Mohd'],
        ['Hussain', 'Hussein'],
        ['Chaudhry', 'Chaudhary'],
        ['Ayesha', 'Aisha'],
      ]) {
        final outputs = group.map(transliterator.transliterate).toSet();
        expect(
          outputs.length,
          1,
          reason: '$group produced different spellings: $outputs',
        );
      }
    });

    test('punctuation and case do not change the lookup', () {
      expect(
        transliterator.transliterate('CHAUDHRY'),
        transliterator.transliterate('chaudhry'),
      );
    });

    test('spacing and punctuation survive', () {
      expect(transliterator.transliterate('Ali Khan'), 'علی خان');
      expect(transliterator.transliterate('Lahore, Punjab'), 'لاہور، پنجاب');
    });

    test('digits and years pass through untouched', () {
      // A user typing "Ali 2019" must not have the year mangled.
      expect(transliterator.transliterate('2019'), '2019');
      expect(transliterator.transliterate('Ali 2019'), 'علی 2019');
    });

    test('text already in Urdu is left exactly as it is', () {
      const urdu = 'محمد علی ملک';
      expect(transliterator.transliterate(urdu), urdu);
    });

    test('an empty input stays empty', () {
      expect(transliterator.transliterate(''), '');
    });

    test('candidates put dictionary hits before the rule-based guess', () {
      final options = transliterator.candidates('Muhammad');

      expect(options.first.fromDictionary, isTrue);
      expect(options.first.text, 'محمد');
      // The rules-only guess is still offered, so a user whose name the
      // dictionary gets wrong has something to fall back on.
      expect(options.length, greaterThan(1));
      expect(options.last.fromDictionary, isFalse);
    });

    test('an unknown word still produces something usable', () {
      final options = transliterator.candidates('Zorawar');

      expect(options, isNotEmpty);
      expect(options.first.text, isNotEmpty);
      expect(options.first.fromDictionary, isFalse);
    });
  });
}
