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

  /// Two entries plus the blunt warning. 9.5 requires being explicit that
  /// there is no recovery path — a vague error later reads as data loss
  /// caused by the app.
  Future<String?> _askForNewPassword() async {
    final l10n = AppL10n.of(context);

    while (true) {
      final first = await promptForText(
        context,
        title: l10n.backupPasswordLabel,
        helperText: l10n.backupNoRecovery,
      );
      if (first == null || !mounted) return null;

      if (first.length < 8) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupPasswordTooShort)));
        continue;
      }

      final second = await promptForText(
        context,
        title: l10n.backupPasswordConfirm,
      );
      if (second == null || !mounted) return null;

      if (first != second) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupPasswordMismatch)));
        continue;
      }
      return first;
    }
  }

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

  static String _shortDate(DateTime at) => '${at.day}/${at.month}/${at.year}';

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
