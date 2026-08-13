import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/field_descriptor.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/field_values.dart';
import 'package:meribiodata/features/editor/widgets/roman_urdu_field.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';

/// Renders the input for one field, chosen by its [FieldType].
///
/// The whole form is built from these, so a user-created field of a given type
/// looks and behaves exactly like a built-in one of the same type — which is
/// the point of a schema-driven engine (§6).
class FieldInput extends StatelessWidget {
  const FieldInput({
    required this.field,
    required this.value,
    required this.onChanged,
    this.documentLanguage,
    super.key,
  });

  final FieldDescriptor field;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  /// Drives the Roman-typing offer (9.2). Null in contexts that have no
  /// document, such as a repeatable group's inner fields.
  final LanguageDescriptor? documentLanguage;

  @override
  Widget build(BuildContext context) => switch (field.type) {
    FieldType.text => _maybeRoman(
      context,
      maxLines: 1,
      fallback: () => _TextInput(
        field: field,
        value: value as String?,
        onChanged: onChanged,
      ),
    ),
    FieldType.multiline => _maybeRoman(
      context,
      maxLines: 4,
      fallback: () => _TextInput(
        field: field,
        value: value as String?,
        onChanged: onChanged,
        maxLines: 4,
      ),
    ),
    FieldType.number => _TextInput(
      field: field,
      value: value?.toString(),
      onChanged: (text) => onChanged(num.tryParse(text)),
      keyboardType: TextInputType.number,
    ),
    FieldType.date => _DateInput(value: value as String?, onChanged: onChanged),
    FieldType.dropdown => _DropdownInput(
      field: field,
      value: value as String?,
      onChanged: onChanged,
    ),
    FieldType.boolean => _BooleanInput(
      value: value as bool? ?? false,
      onChanged: onChanged,
    ),
    FieldType.height => _HeightInput(value: value, onChanged: onChanged),
    FieldType.weight => _WeightInput(value: value, onChanged: onChanged),
    FieldType.currency => _CurrencyInput(value: value, onChanged: onChanged),
    FieldType.repeatableGroup => _GroupInput(
      field: field,
      value: value,
      onChanged: onChanged,
    ),
  };

  /// Offers Roman typing only where it helps: a text field in a document
  /// written in a Perso-Arabic script.
  Widget _maybeRoman(
    BuildContext context, {
    required int maxLines,
    required Widget Function() fallback,
  }) {
    final language = documentLanguage;
    if (language == null || !RomanUrduField.isOfferedFor(language)) {
      return fallback();
    }

    final preferences = context.watch<AppPreferences>();
    return RomanUrduField(
      language: language,
      value: value as String?,
      onChanged: onChanged,
      enabled: preferences.romanInputDefault,
      onEnabledChanged: (enabled) =>
          preferences.setRomanInputDefault(enabled: enabled),
      maxLines: maxLines,
      maxLength: field.validation?.maxLength,
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.field,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.keyboardType,
  });

  final FieldDescriptor field;
  final String? value;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxLength = widget.field.validation?.maxLength;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      textCapitalization: TextCapitalization.words,
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
    );
  }
}

class _DateInput extends StatelessWidget {
  const _DateInput({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final parsed = value == null ? null : DateTime.tryParse(value!);

    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed ?? DateTime(now.year - 25),
          firstDate: DateTime(1900),
          lastDate: now,
        );
        if (picked != null) onChanged(picked.toIso8601String());
      },
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(
        parsed == null
            ? l10n.fieldChooseDate
            : '${parsed.day}/${parsed.month}/${parsed.year}'
                  '  ·  ${l10n.fieldAgeYears(ageOn(parsed, DateTime.now()))}',
      ),
    );
  }
}

class _DropdownInput extends StatelessWidget {
  const _DropdownInput({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final FieldDescriptor field;
  final String? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final options = field.options ?? const <String>[];
    // Free text is always allowed on top of the list (§6.2) — being told your
    // maslak "isn't an option" is a bad first impression.
    final isCustom =
        value != null && value!.isNotEmpty && !options.contains(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: isCustom ? _otherSentinel : value,
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
            DropdownMenuItem(
              value: _otherSentinel,
              child: Text(l10n.fieldOther),
            ),
          ],
          onChanged: (selected) => onChanged(
            selected == _otherSentinel ? (isCustom ? value : '') : selected,
          ),
        ),
        if (isCustom || value == '') ...[
          const SizedBox(height: AppSpacing.sm),
          _TextInput(
            field: field,
            value: isCustom ? value : '',
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }

  static const _otherSentinel = '__other__';
}

class _BooleanInput extends StatelessWidget {
  const _BooleanInput({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) =>
      Switch(value: value, onChanged: onChanged);
}

class _HeightInput extends StatelessWidget {
  const _HeightInput({required this.value, required this.onChanged});

  final Object? value;
  final ValueChanged<Object?> onChanged;

  HeightValue? get _height => value is Map<String, dynamic>
      ? HeightValue.fromJson(value! as Map<String, dynamic>)
      : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final height = _height;

    return Row(
      children: [
        Expanded(
          child: _NumberBox(
            label: l10n.unitFeet,
            value: height?.feet,
            onChanged: (feet) => onChanged(
              HeightValue.fromFeetInches(
                feet?.toInt() ?? 0,
                height?.inches ?? 0,
              ).toJson(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _NumberBox(
            label: l10n.unitInches,
            value: height?.inches,
            onChanged: (inches) => onChanged(
              HeightValue.fromFeetInches(
                height?.feet ?? 0,
                inches?.toInt() ?? 0,
              ).toJson(),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeightInput extends StatelessWidget {
  const _WeightInput({required this.value, required this.onChanged});

  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final weight = value is Map<String, dynamic>
        ? WeightValue.fromJson(value! as Map<String, dynamic>)
        : null;

    return _NumberBox(
      label: l10n.unitKilograms,
      value: weight?.kilograms.round(),
      onChanged: (kg) => onChanged(
        kg == null ? null : WeightValue(kilograms: kg.toDouble()).toJson(),
      ),
    );
  }
}

class _CurrencyInput extends StatelessWidget {
  const _CurrencyInput({required this.value, required this.onChanged});

  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final money = value is Map<String, dynamic>
        ? CurrencyValue.fromJson(value! as Map<String, dynamic>)
        : null;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _NumberBox(
            label: money?.currencyCode ?? 'PKR',
            value: money?.amount.round(),
            onChanged: (amount) => onChanged(
              amount == null
                  ? null
                  : CurrencyValue(
                      amount: amount,
                      period: money?.period ?? IncomePeriod.perMonth,
                    ).toJson(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          // Even split, and compact labels. "Monthly" and "Yearly" were being
          // squeezed into a third of the row at full label size, which wrapped
          // and read as oversized next to the amount box.
          flex: 2,
          child: SegmentedButton<IncomePeriod>(
            style: SegmentedButton.styleFrom(
              textStyle: Theme.of(context).textTheme.labelMedium,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
              ),
              visualDensity: VisualDensity.compact,
            ),
            segments: [
              ButtonSegment(
                value: IncomePeriod.perMonth,
                label: Text(l10n.periodMonth),
              ),
              ButtonSegment(
                value: IncomePeriod.perYear,
                label: Text(l10n.periodYear),
              ),
            ],
            selected: {money?.period ?? IncomePeriod.perMonth},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(
              CurrencyValue(
                amount: money?.amount ?? 0,
                period: selection.first,
              ).toJson(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Siblings (§6.2).
///
/// Leads with the shorthand — "2 brothers, 1 married" — because that is what
/// most families write. Per-person detail is opt-in underneath, never a
/// prerequisite.
class _GroupInput extends StatelessWidget {
  const _GroupInput({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final FieldDescriptor field;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  RepeatableGroupValue get _group => value is Map<String, dynamic>
      ? RepeatableGroupValue.fromJson(value! as Map<String, dynamic>)
      : const RepeatableGroupValue();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final group = _group;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _NumberBox(
                label: l10n.groupTotal,
                value: group.total,
                onChanged: (total) =>
                    onChanged(group.copyWith(total: total?.toInt()).toJson()),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _NumberBox(
                label: l10n.groupMarried,
                value: group.marriedCount,
                onChanged: (married) => onChanged(
                  group.copyWith(marriedCount: married?.toInt()).toJson(),
                ),
              ),
            ),
          ],
        ),
        for (var i = 0; i < group.entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _GroupEntry(
              field: field,
              entry: group.entries[i],
              index: i,
              onChanged: (entry) {
                final entries = [...group.entries];
                entries[i] = entry;
                onChanged(group.copyWith(entries: entries).toJson());
              },
              onRemove: () {
                final entries = [...group.entries]..removeAt(i);
                onChanged(group.copyWith(entries: entries).toJson());
              },
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: group.entries.length >= SchemaLimits.maxGroupEntries
                ? null
                : () => onChanged(
                    group
                        .copyWith(
                          entries: [
                            ...group.entries,
                            const <String, dynamic>{},
                          ],
                        )
                        .toJson(),
                  ),
            icon: const Icon(Icons.add),
            label: Text(l10n.groupAddPerson),
          ),
        ),
      ],
    );
  }
}

class _GroupEntry extends StatelessWidget {
  const _GroupEntry({
    required this.field,
    required this.entry,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final FieldDescriptor field;
  final Map<String, dynamic> entry;
  final int index;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final inner in field.groupFields)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FieldInput(
                key: ValueKey('${inner.id}-$index'),
                field: inner,
                value: entry[inner.id],
                onChanged: (v) => onChanged({...entry, inner.id: v}),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NumberBox extends StatefulWidget {
  const _NumberBox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final num? value;
  final ValueChanged<num?> onChanged;

  @override
  State<_NumberBox> createState() => _NumberBoxState();
}

class _NumberBoxState extends State<_NumberBox> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(labelText: widget.label, isDense: true),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (text) => widget.onChanged(num.tryParse(text)),
  );
}
