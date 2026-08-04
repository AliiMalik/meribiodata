import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';

/// Asks for a single line of text. Returns null if the user cancels.
///
/// Used for renaming labels and naming new fields and sections — all places
/// where a full screen would be heavy and an inline editor would fight with
/// the form's own text fields.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? helperText,
  int? maxLength,
}) {
  final controller = TextEditingController(text: initialValue);

  return showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = AppL10n.of(context);
      void submit() {
        final text = controller.text.trim();
        if (text.isEmpty) return;
        Navigator.of(context).pop(text);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(helperText: helperText),
          inputFormatters: [
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(onPressed: submit, child: Text(l10n.actionSave)),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}

/// A yes/no confirmation. Returns true only on an explicit confirm.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppL10n.of(context);
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
