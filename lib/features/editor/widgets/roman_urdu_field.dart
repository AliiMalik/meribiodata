import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/domain/text/roman_urdu.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';

/// A text field that can turn Roman typing into Urdu script (9.2).
///
/// Opt-in per field with a visible toggle, because a user who has a real Urdu
/// keyboard must never be forced through this. The toggle is only offered when
/// the *document* language is written in Perso-Arabic — it would be noise on
/// an English biodata.
///
/// The output is always editable. Transliteration is an input aid, never a
/// lock: once the user edits the Urdu directly, that word is left alone.
class RomanUrduField extends StatefulWidget {
  const RomanUrduField({
    required this.language,
    required this.value,
    required this.onChanged,
    required this.enabled,
    required this.onEnabledChanged,
    this.maxLines = 1,
    this.maxLength,
    super.key,
  });

  final LanguageDescriptor language;
  final String? value;
  final ValueChanged<String> onChanged;

  /// Whether Roman input is currently on for this field.
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;

  final int maxLines;
  final int? maxLength;

  /// Roman input only makes sense for a document in a Perso-Arabic script.
  static bool isOfferedFor(LanguageDescriptor language) =>
      language.script != TextScript.latin;

  @override
  State<RomanUrduField> createState() => _RomanUrduFieldState();
}

class _RomanUrduFieldState extends State<RomanUrduField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );

  List<Transliteration> _candidates = const [];

  /// Where the word being typed starts, so a chosen candidate replaces only
  /// that word rather than the whole field.
  int _tokenStart = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    widget.onChanged(text);
    if (!widget.enabled) {
      if (_candidates.isNotEmpty) setState(() => _candidates = const []);
      return;
    }

    final caret = _controller.selection.baseOffset;
    final cursor = caret < 0 ? text.length : caret;

    // The word immediately behind the caret.
    var start = cursor;
    while (start > 0 && _isRoman(text[start - 1])) {
      start--;
    }
    final token = text.substring(start, cursor);

    if (token.isEmpty) {
      if (_candidates.isNotEmpty) setState(() => _candidates = const []);
      return;
    }

    final transliterator = context.read<RomanUrduTransliterator>();
    setState(() {
      _tokenStart = start;
      _candidates = transliterator.candidates(token);
    });
  }

  /// Replaces the word behind the caret, leaving the rest of the field —
  /// including anything the user typed in Urdu by hand — untouched.
  void _apply(Transliteration choice) {
    final text = _controller.text;
    final caret = _controller.selection.baseOffset;
    final cursor = caret < 0 ? text.length : caret;

    final updated =
        text.substring(0, _tokenStart) + choice.text + text.substring(cursor);
    final newCaret = _tokenStart + choice.text.length;

    _controller
      ..text = updated
      ..selection = TextSelection.collapsed(offset: newCaret);

    widget.onChanged(updated);
    setState(() => _candidates = const []);
  }

  static bool _isRoman(String ch) => RegExp('[A-Za-z]').hasMatch(ch);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                maxLines: widget.maxLines,
                textCapitalization: TextCapitalization.words,
                style: widget.enabled
                    ? null
                    : TextStyle(
                        fontFamily: widget.language.documentFontFamily,
                        fontFamilyFallback:
                            widget.language.documentFontFallback,
                        height: widget.language.uiLineHeight,
                      ),
                inputFormatters: [
                  if (widget.maxLength != null)
                    LengthLimitingTextInputFormatter(widget.maxLength),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // A visible per-field switch, remembered as a preference (9.2).
            IconButton(
              tooltip: widget.enabled ? l10n.romanInputOn : l10n.romanInputOff,
              isSelected: widget.enabled,
              icon: const Icon(Icons.keyboard_outlined),
              selectedIcon: const Icon(
                Icons.translate,
                color: AppColors.primaryDark,
              ),
              onPressed: () {
                widget.onEnabledChanged(!widget.enabled);
                setState(() => _candidates = const []);
              },
            ),
          ],
        ),
        if (widget.enabled && _candidates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _candidates.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final option = _candidates[index];
                  return ActionChip(
                    onPressed: () => _apply(option),
                    avatar: option.fromDictionary
                        ? const Icon(Icons.check, size: 16)
                        : null,
                    label: Text(
                      option.text,
                      style: TextStyle(
                        fontFamily: widget.language.documentFontFamily,
                        fontFamilyFallback:
                            widget.language.documentFontFallback,
                        height: widget.language.uiLineHeight,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        if (widget.enabled)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              l10n.romanInputHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
