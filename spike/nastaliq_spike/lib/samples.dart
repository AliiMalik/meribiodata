// Throwaway spike data. Real biodata-shaped content (labels + values), not
// lorem ipsum, because label/value alignment in RTL is where pipelines break.

enum ScriptFamily { nastaliq, naskh, latin }

class SampleRow {
  const SampleRow(this.label, this.value);
  final String label;
  final String value;
}

class SampleDoc {
  const SampleDoc({
    required this.code,
    required this.name,
    required this.script,
    required this.rtl,
    required this.heading,
    required this.rows,
    required this.paragraph,
    required this.alphabet,
  });

  final String code;
  final String name;
  final ScriptFamily script;
  final bool rtl;
  final String heading;
  final List<SampleRow> rows;

  /// Mixed-direction torture test: Latin acronym, Western digits, phone number.
  final String paragraph;

  /// Every letter of the language's alphabet, to expose .notdef (tofu).
  final String alphabet;
}

const samples = <SampleDoc>[
  SampleDoc(
    code: 'ur',
    name: 'Urdu',
    script: ScriptFamily.nastaliq,
    rtl: true,
    heading: 'شادی کا بایوڈیٹا',
    rows: [
      SampleRow('نام', 'محمد علی ملک'),
      SampleRow('والد کا نام', 'محمد اسلم ملک'),
      SampleRow('ذات / برادری', 'آرائیں'),
      SampleRow('تاریخ پیدائش', '15 مارچ 1995'),
      SampleRow('تعلیم', 'ایم بی بی ایس، کنگ ایڈورڈ میڈیکل یونیورسٹی لاہور'),
      SampleRow('پیشہ', 'ڈاکٹر، سرکاری ہسپتال'),
      SampleRow('قد', '5 فٹ 9 انچ'),
      SampleRow('مسلک', 'حنفی'),
      SampleRow('پتہ', 'مکان نمبر 12، گلبرگ، لاہور'),
      SampleRow('رابطہ', '+92 300 1234567'),
    ],
    paragraph:
        'میں نے 2019 میں MBBS مکمل کیا اور اس وقت لاہور کے سرکاری ہسپتال میں '
        'خدمات انجام دے رہا ہوں۔ رابطے کے لیے +92 300 1234567 پر کال کریں۔',
    alphabet:
        'ا آ ب پ ت ٹ ث ج چ ح خ د ڈ ذ ر ڑ ز ژ س ش ص ض ط ظ ع غ ف ق ک گ ل م ن ں و ہ ھ ء ی ے',
  ),
  SampleDoc(
    code: 'sd',
    name: 'Sindhi',
    script: ScriptFamily.naskh,
    rtl: true,
    heading: 'شادي جو بايوڊيٽا',
    rows: [
      SampleRow('نالو', 'محمد علي سومرو'),
      SampleRow('پيءُ جو نالو', 'عبدالرحمان سومرو'),
      SampleRow('ذات', 'سومرو'),
      SampleRow('تعليم', 'ايم اي سنڌي، سنڌ يونيورسٽي ڄامشورو'),
      SampleRow('پيشو', 'استاد'),
      SampleRow('قد', '5 فٽ 9 انچ'),
      SampleRow('شهر', 'ڪراچي'),
      SampleRow('رابطو', '+92 300 1234567'),
    ],
    paragraph:
        'مان 2019 ۾ سنڌ يونيورسٽي مان MA ڪيو ۽ هن وقت ڪراچي ۾ استاد آهيان. '
        'رابطي لاءِ +92 300 1234567 تي ڪال ڪريو.',
    alphabet:
        'ا ب ٻ ڀ ت ٿ ٽ ٺ ث پ ج ڄ ڃ چ ڇ ح خ د ڌ ڏ ڊ ڍ ذ ر ڙ ز س ش ص ض ط ظ ع غ ف ڦ ق ڪ ک گ ڳ ڱ ڳ ل م ن ڻ ه ھ و ي',
  ),
  SampleDoc(
    code: 'ps',
    name: 'Pashto',
    script: ScriptFamily.naskh,
    rtl: true,
    heading: 'د واده بایوډاټا',
    rows: [
      SampleRow('نوم', 'محمد علي خان'),
      SampleRow('د پلار نوم', 'عبدالله خان'),
      SampleRow('قام', 'یوسفزی'),
      SampleRow('زده کړه', 'بي اې، د پېښور پوهنتون'),
      SampleRow('دنده', 'ښوونکی'),
      SampleRow('جګوالی', '5 فټه 9 اینچه'),
      SampleRow('ښار', 'پېښور'),
      SampleRow('اړیکه', '+92 300 1234567'),
    ],
    paragraph:
        'ما په 2019 کال کې BA بشپړ کړ او اوس په پېښور کې ښوونکی یم. '
        'د اړیکې لپاره +92 300 1234567 ته زنګ ووهئ.',
    alphabet:
        'ا ب پ ت ټ ث ج ځ چ څ ح خ د ډ ذ ر ړ ز ژ ږ س ش ښ ص ض ط ظ ع غ ف ق ک ګ ل م ن ڼ و ه ی ې ۍ ئ',
  ),
  SampleDoc(
    code: 'en',
    name: 'English (control)',
    script: ScriptFamily.latin,
    rtl: false,
    heading: 'Marriage Biodata',
    rows: [
      SampleRow('Name', 'Muhammad Ali Malik'),
      SampleRow("Father's Name", 'Muhammad Aslam Malik'),
      SampleRow('Caste / Biradari', 'Arain'),
      SampleRow('Date of Birth', '15 March 1995'),
      SampleRow('Education', 'MBBS, King Edward Medical University, Lahore'),
      SampleRow('Occupation', 'Doctor, Government Hospital'),
      SampleRow('Height', "5 ft 9 in"),
      SampleRow('Maslak', 'Hanafi'),
      SampleRow('Address', 'House 12, Gulberg, Lahore'),
      SampleRow('Contact', '+92 300 1234567'),
    ],
    paragraph:
        'Completed MBBS in 2019 and currently serving at a government hospital '
        'in Lahore. For contact, please call +92 300 1234567.',
    alphabet: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789',
  ),
];
