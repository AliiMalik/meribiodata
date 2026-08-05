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
  bool obscure = false,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextPromptDialog(
    title: title,
    initialValue: initialValue,
    helperText: helperText,
    maxLength: maxLength,
    obscure: obscure,
  ),
);

/// A [StatefulWidget] purely so the controller's lifetime is the *dialog's*,
/// not the future's.
///
/// The obvious version creates the controller beside `showDialog` and disposes
/// it in `whenComplete`. That is subtly wrong: the future completes the moment
/// `Navigator.pop` is called, while the route is still on screen playing its
/// exit animation, so the controller is disposed out from under a live
/// [TextField]. It survives being ignored right up until something pushes a
/// second dialog in the same frame — which the backup screen does — and then it
/// fails as an inherited-widget assertion a long way from the cause.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initialValue,
    required this.helperText,
    required this.maxLength,
    required this.obscure,
  });

  final String title;
  final String initialValue;
  final String? helperText;
  final int? maxLength;
  final bool obscure;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: widget.obscure,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(helperText: widget.helperText),
        inputFormatters: [
          if (widget.maxLength case final int limit)
            LengthLimitingTextInputFormatter(limit),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionSave)),
      ],
    );
  }
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
