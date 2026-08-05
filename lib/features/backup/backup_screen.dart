import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:meribiodata/core/platform/platform_bridge.dart';
import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/widgets/text_prompt_dialog.dart';
import 'package:meribiodata/features/backup/backup_format.dart';
import 'package:meribiodata/features/backup/backup_service.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// Backup & Restore (9.5).
///
/// The practical benefit of cloud sync with no backend, no cloud dependency
/// and no account: one password-protected file the user keeps wherever they
/// like. Without this, a lost phone means every biodata is gone — the one way
/// an offline-first app can be *worse* than a cloud one.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  BackupService _service(BuildContext context) =>
      BackupService(context.read<LocalStore>());

  Future<void> _create() async {
    final l10n = AppL10n.of(context);
    final password = await _askForNewPassword();
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _service(context).create(password: password);
      final file = await _write(bytes);

      messenger.showSnackBar(SnackBar(content: Text(l10n.backupCreated)));
      // The app never uploads it. Handing it to the share sheet lets the user
      // put it wherever they trust — their own Drive, a chat to themselves.
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: l10n.backupTitle),
      );
    } on Object catch (error, stack) {
      debugPrint('Backup failed: $error\n$stack');
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGenericTitle)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _write(Uint8List bytes) async {
    final dir = await getApplicationSupportDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/MeriBiodata-$stamp.mbd');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// One dialog with both entries, not two in sequence.
  ///
  /// Two reasons. The user should see the no-recovery warning *while* choosing
  /// the password rather than before it, and a mismatch should be answerable
  /// without retyping both. The sequential version also pushed its second
  /// dialog in the same frame the first was closing, which is a genuinely
  /// awkward moment in a Navigator (see `text_prompt_dialog.dart`).
  Future<String?> _askForNewPassword() => showDialog<String>(
    context: context,
    builder: (context) => const _NewPasswordDialog(),
  );

  Future<void> _restore() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final bytes = await const PlatformBridge().openDocument();
    // Null means the user backed out of the picker, which is not an error.
    if (bytes == null || !mounted) return;

    final service = _service(context);

    // Inspect before asking for anything: a wrong file or a future version
    // should be rejected without making the user type a password first.
    final BackupHeader header;
    try {
      header = service.inspect(bytes);
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_message(l10n, e.error))));
      return;
    }

    if (!mounted) return;
    final password = await promptForText(
      context,
      title: l10n.backupPasswordEnter,
      obscure: true,
      helperText: l10n.backupContains(
        header.profileCount,
        _shortDate(header.createdAt),
      ),
    );
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final contents = await service.open(bytes, password: password);
      if (!mounted) return;

      final strategy = await _askStrategy();
      if (strategy == null || !mounted) return;

      await service.restore(contents, strategy: strategy);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.backupRestored(contents.profiles.length))),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_message(l10n, e.error))));
    } on Object catch (error, stack) {
      debugPrint('Restore failed: $error\n$stack');
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGenericTitle)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Merge or Replace, never silently overwriting. Replace is destructive, so
  /// it takes a second confirmation (9.5).
  Future<RestoreStrategy?> _askStrategy() async {
    final l10n = AppL10n.of(context);

    final choice = await showDialog<RestoreStrategy>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupRestore),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(RestoreStrategy.replace),
            child: Text(l10n.backupReplace),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(RestoreStrategy.merge),
            child: Text(l10n.backupMerge),
          ),
        ],
      ),
    );

    if (choice != RestoreStrategy.replace) return choice;
    if (!mounted) return null;

    final confirmed = await confirm(
      context,
      title: l10n.backupReplaceConfirmTitle,
      body: l10n.backupReplaceConfirmBody,
      confirmLabel: l10n.backupReplace,
      isDestructive: true,
    );
    return confirmed ? RestoreStrategy.replace : null;
  }

  static String _message(AppL10n l10n, BackupError error) => switch (error) {
    BackupError.notABackup => l10n.backupErrorNotABackup,
    BackupError.futureVersion => l10n.backupErrorFutureVersion,
    BackupError.wrongPasswordOrTampered => l10n.backupErrorWrongPassword,
    BackupError.corrupt => l10n.backupErrorCorrupt,
  };

  /// Converted to local time first. The header stores UTC, and a backup made
  /// after 5 pm in Pakistan otherwise reads as having been made yesterday —
  /// which, on the one screen whose job is to tell the user *which* file this
  /// is, is exactly the wrong thing to get wrong.
  static String _shortDate(DateTime at) {
    final local = at.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            l10n.backupExplain,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.backupNoRecovery,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else ...[
            FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.backupCreate),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _restore,
              icon: const Icon(Icons.restore_outlined),
              label: Text(l10n.backupRestore),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            // Reassurance that matters for this audience: the file is theirs
            // and the app never sends it anywhere.
            l10n.onboardingPrivacyBody,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Chooses and confirms a backup password.
///
/// The minimum length and the match are checked here rather than by the caller
/// because they are the same question the user is looking at: 9.5 requires
/// being blunt that a forgotten password is unrecoverable, and a rule the user
/// only meets by trial and error undercuts that.
class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

  static const minimumLength = 8;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppL10n.of(context);
    final password = _password.text;

    if (password.length < _NewPasswordDialog.minimumLength) {
      setState(() => _error = l10n.backupPasswordTooShort);
      return;
    }
    if (password != _confirmation.text) {
      setState(() => _error = l10n.backupPasswordMismatch);
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AlertDialog(
      title: Text(l10n.backupPasswordLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.backupNoRecovery,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.backupPasswordLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _confirmation,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.backupPasswordConfirm,
              errorText: _error,
            ),
          ),
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
