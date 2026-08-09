import 'package:flutter/foundation.dart';
import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/domain/render/template.dart';

/// The one question the picker and the export screen both ask.
///
/// Written once, here, because the two screens disagreeing is exactly the bug
/// that lets somebody select a template they cannot export — or worse, export
/// one they never unlocked.
bool canUseTemplate(
  DocumentTemplate template, {
  required bool isPremium,
  required TemplateUnlocks unlocks,
}) => !template.isLocked || isPremium || unlocks.isUnlocked(template.id);

/// Which locked templates this phone may currently use, and until when (D19).
///
/// One ad unlocks **one** template for 24 hours. When it expires the template
/// locks again everywhere, including for a biodata already using it — so the
/// export screen has to check this too, not just the picker.
///
/// That is a deliberately strict rule and it was the owner's call over my
/// recommendation. The mitigation lives in the UI: an expired template never
/// dead-ends anyone, it offers the same one-tap choice as the picker does.
class TemplateUnlocks extends ChangeNotifier {
  TemplateUnlocks(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _documentId = 'templateUnlocks';

  /// How long one ad buys.
  static const duration = Duration(hours: 24);

  /// Expiry is stored as an absolute instant rather than a countdown, so
  /// setting the phone clock **forward** ends an unlock early and setting it
  /// **backward** makes one last longer in real time. The second is a real if
  /// trivial way to game this, and it is accepted: the alternative — refusing
  /// to trust a clock that moved — punishes anyone who crosses a timezone or
  /// whose phone corrects itself, and the prize for cheating is one skipped ad.

  final LocalStore _store;
  final DateTime Function() _now;

  /// Template id to the moment its unlock stops counting.
  final Map<String, DateTime> _until = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final values =
          await _store.read(Collections.preferences, _documentId) ?? const {};
      for (final entry in values.entries) {
        if (entry.value case final int ms) {
          _until[entry.key] = DateTime.fromMillisecondsSinceEpoch(ms);
        }
      }
    } on Object catch (error) {
      // Unreadable state locks everything rather than unlocking it. Erring the
      // other way would hand out paid designs on a storage hiccup.
      debugPrint('Template unlocks unreadable: $error');
      _until.clear();
    }
    notifyListeners();
  }

  /// Whether [templateId] can be used right now.
  ///
  /// Premium is *not* consulted here — that belongs to the caller, so this
  /// class stays about ads alone and there is still only one place that knows
  /// who has paid.
  bool isUnlocked(String templateId) {
    final until = _until[templateId];
    if (until == null) return false;

    return !until.difference(_now()).isNegative;
  }

  /// What is left, for showing "unlocked · 4h left". Null when locked.
  ///
  /// Clamped to [duration]. Without the clamp a user who has wound their phone
  /// clock backwards is told the unlock has 168 hours left, which is both wrong
  /// and a hint at how to game it.
  Duration? remainingFor(String templateId) {
    if (!isUnlocked(templateId)) return null;
    final remaining = _until[templateId]!.difference(_now());
    return remaining > duration ? duration : remaining;
  }

  /// Called when a rewarded ad has actually been watched to the end.
  ///
  /// Only ever from the reward callback — never from "the ad closed", which
  /// fires for someone who skipped out of it early.
  Future<void> grant(String templateId) async {
    _until[templateId] = _now().add(duration);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      await _store.put(Collections.preferences, _documentId, {
        for (final entry in _until.entries)
          entry.key: entry.value.millisecondsSinceEpoch,
      });
    } on Object catch (error) {
      // Losing this costs the user a repeat ad, which is bad but not broken.
      debugPrint('Template unlocks not saved: $error');
    }
  }
}
