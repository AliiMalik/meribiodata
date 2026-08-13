import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/core/widgets/text_prompt_dialog.dart';
import 'package:meribiodata/features/sync/backup_service.dart';
import 'package:meribiodata/features/sync/sync_controller.dart';
import 'package:meribiodata/features/sync/sync_service.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// Google Drive backup.
///
/// Replaces the file-and-share-sheet screen entirely. The encryption is
/// unchanged — the same password-derived AES-GCM container — but the file now
/// lives in the user's own Drive instead of being handed to whatever app they
/// picked. What that buys is the thing the old design could not do: a new phone
/// gets everything back by signing in.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _busy = false;

  /// Runs [action], and — this is the part that was missing — says something
  /// when it throws.
  ///
  /// There was no catch here at all. A failed Google sign-in threw, the
  /// exception went nowhere a user could see, the screen rebuilt unchanged, and
  /// the Connect button simply reappeared. Reported as "connect, my account
  /// comes up, then Connect again", which is exactly what silence looks like
  /// from the outside. A failure the user cannot see is worse than an ugly
  /// message, and it also left us with nothing to diagnose from.
  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error, stack) {
      debugPrint('Drive action failed: $error');
      debugPrint('$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).syncErrorConnectFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(SyncController sync) => _guard(() async {
    final connected = await sync.connect();
    if (!connected || !mounted) return;

    // Signing in is only half of setup. Without a password there is nothing to
    // encrypt with, so ask immediately rather than leaving a connected account
    // that never uploads.
    if (sync.problem == SyncProblem.needsPassword) await _choosePassword(sync);
  });

  Future<void> _choosePassword(SyncController sync) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _NewPasswordDialog(),
    );
    if (password == null || !mounted) return;
    await sync.setPassword(password);
  }

  Future<void> _disconnect(SyncController sync) async {
    final l10n = AppL10n.of(context);
    final confirmed = await confirm(
      context,
      title: l10n.syncDisconnectConfirmTitle,
      body: l10n.syncDisconnectConfirmBody,
      confirmLabel: l10n.syncDisconnect,
      isDestructive: true,
    );
    if (!confirmed) return;
    await _guard(sync.disconnect);
  }

  Future<void> _restore(SyncController sync) => _guard(() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final (header, bytes) = await sync.service.fetch();
      if (!mounted) return;

      final password = await promptForText(
        context,
        title: l10n.backupPasswordEnter,
        obscure: true,
        helperText: l10n.syncRestoreFound(
          header.profileCount,
          _shortDate(header.createdAt),
        ),
      );
      if (password == null || !mounted) return;

      final strategy = await _askStrategy();
      if (strategy == null || !mounted) return;

      final count = await sync.service.restore(
        bytes,
        password: password,
        strategy: strategy,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.backupRestored(count))),
      );
    } on SyncException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_message(l10n, e.problem))),
      );
    }
  });

  /// Merge or Replace, never silently overwriting. Replace is destructive, so
  /// it takes a second confirmation.
  Future<RestoreStrategy?> _askStrategy() async {
    final l10n = AppL10n.of(context);

    final choice = await showDialog<RestoreStrategy>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncRestore),
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

  static String _message(AppL10n l10n, SyncProblem problem) =>
      switch (problem) {
        SyncProblem.needsSignIn => l10n.syncErrorNeedsSignIn,
        SyncProblem.needsPassword => l10n.syncErrorNeedsPassword,
        SyncProblem.driveUnavailable => l10n.syncErrorDriveUnavailable,
        SyncProblem.wrongPassword => l10n.syncErrorWrongPassword,
        SyncProblem.unreadableBackup => l10n.syncErrorUnreadable,
      };

  /// Local time. The header stores UTC, and a backup made after 5 pm in
  /// Pakistan otherwise reads as yesterday's.
  static String _shortDate(DateTime at) {
    final local = at.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;
    final sync = context.watch<SyncController>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(l10n.syncExplain, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.lg),

          _StatusCard(sync: sync, message: _message),
          const SizedBox(height: AppSpacing.xl),

          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (!sync.isConnected) ...[
            FilledButton.icon(
              onPressed: () => unawaited(_connect(sync)),
              icon: const Icon(Icons.cloud_outlined),
              label: Text(l10n.syncConnect),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Offered even when disconnected: this is exactly the new-phone
            // case, where there is nothing here yet and everything in Drive.
            OutlinedButton.icon(
              onPressed: () => unawaited(
                _connect(sync).then((_) {
                  if (sync.isConnected) unawaited(_restore(sync));
                }),
              ),
              icon: const Icon(Icons.restore_outlined),
              label: Text(l10n.syncRestore),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => unawaited(sync.syncNow()),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(l10n.syncNow),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => unawaited(_restore(sync)),
              icon: const Icon(Icons.restore_outlined),
              label: Text(l10n.syncRestore),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (sync.problem == SyncProblem.needsPassword)
              OutlinedButton.icon(
                onPressed: () => unawaited(_choosePassword(sync)),
                icon: const Icon(Icons.key_outlined),
                label: Text(l10n.syncPasswordTitle),
              ),
            TextButton.icon(
              onPressed: () => unawaited(_disconnect(sync)),
              icon: const Icon(Icons.logout),
              label: Text(l10n.syncDisconnect),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.backupNoRecovery,
            style: text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.sync, required this.message});

  final SyncController sync;
  final String Function(AppL10n, SyncProblem) message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;

    final (label, icon) = switch (sync.status) {
      SyncStatus.off => (l10n.syncNotConnected, Icons.cloud_off_outlined),
      SyncStatus.idle => (l10n.syncStatusIdle, Icons.cloud_done_outlined),
      SyncStatus.pending => (l10n.syncStatusPending, Icons.cloud_queue),
      SyncStatus.syncing => (l10n.syncStatusSyncing, Icons.cloud_sync_outlined),
      SyncStatus.failed => (l10n.syncStatusFailed, Icons.cloud_off_outlined),
    };

    final detail = switch (sync.status) {
      SyncStatus.failed when sync.problem != null => message(
        l10n,
        sync.problem!,
      ),
      _ when sync.lastSyncedAt != null => l10n.syncLastSynced(
        _relative(sync.lastSyncedAt!),
      ),
      _ when sync.isConnected => l10n.syncNever,
      _ => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.titleMedium),
                  if (sync.account case final String email) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      email,
                      style: text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (detail != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(detail, style: text.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inHours < 1) return '${delta.inMinutes} min ago';
    if (delta.inDays < 1) return '${delta.inHours} h ago';
    final local = at.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

/// Chooses and confirms the backup password.
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
      title: Text(l10n.syncPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.syncPasswordExplain,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
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
