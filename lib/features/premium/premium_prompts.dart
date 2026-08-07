import 'package:flutter/foundation.dart';
import 'package:meribiodata/core/storage/local_store.dart';

/// How often Premium is allowed to ask.
///
/// Split from `Entitlements` because it answers a different question. That one
/// knows whether the user has paid; this one knows how recently they were
/// bothered about it, which is the part that decides whether the app feels
/// helpful or grabby.
///
/// The owner's original request was to replay the onboarding carousel on every
/// launch with the prices on the end. That was argued down: the slides teach a
/// first-time user, and making a returning parent tap through them to reach
/// their daughter's biodata is friction aimed at the most engaged people in the
/// app. What replaced it — a permanent card on Home, plus the full screen at
/// most weekly — gets more total exposure, because people stop seeing things
/// that annoy them.
class PremiumPrompts extends ChangeNotifier {
  PremiumPrompts(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _documentId = 'premiumPrompts';
  static const _keyCardDismissed = 'cardDismissed';
  static const _keyLastPromptMs = 'lastPromptMs';

  /// The full-screen prompt appears at most this often.
  static const promptInterval = Duration(days: 7);

  final LocalStore _store;
  final DateTime Function() _now;

  bool _cardDismissed = false;
  DateTime? _lastPrompt;
  bool _loaded = false;

  /// Never more than one full-screen prompt per app run, whatever the dates
  /// say. Not persisted — it is about this session only.
  bool _promptedThisSession = false;

  /// Whether the Home upsell card has been sent away. Dismissal is permanent:
  /// somebody who said "not now" once should not be asked by the same card
  /// again, and the header icon is always there if they change their mind.
  bool get showCard => _loaded && !_cardDismissed;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final values =
          await _store.read(Collections.preferences, _documentId) ?? const {};
      _cardDismissed = values[_keyCardDismissed] as bool? ?? false;
      if (values[_keyLastPromptMs] case final int ms) {
        _lastPrompt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } on Object catch (error) {
      // Unreadable state must never block the app. Starting fresh at worst
      // shows one extra card.
      debugPrint('Premium prompt state unreadable: $error');
    }

    // First run: start the clock rather than prompting. The last onboarding
    // panel has just made this exact pitch, and following it immediately with
    // the full screen is how an app teaches people to dismiss things unread.
    // The first automatic prompt therefore lands a week in.
    if (_lastPrompt == null) {
      _lastPrompt = _now();
      await _save();
    }

    notifyListeners();
  }

  Future<void> dismissCard() async {
    _cardDismissed = true;
    notifyListeners();
    await _save();
  }

  /// Whether the full Premium screen may open by itself right now.
  ///
  /// Callers must already know the user is not Premium — this class does not
  /// hold that, deliberately, so there is only one place that decides who has
  /// paid.
  bool get canPromptAtLaunch {
    if (!_loaded || _promptedThisSession) return false;

    // Never null after load() — it seeds the clock on first run.
    final last = _lastPrompt;
    if (last == null) return false;

    final since = _now().difference(last);
    // A clock moved backwards reads as "too soon" rather than "go ahead",
    // matching the ad pacing rule. Cost of being wrong is one skipped upsell.
    if (since.isNegative) return false;

    return since >= promptInterval;
  }

  Future<void> recordPrompt() async {
    _promptedThisSession = true;
    _lastPrompt = _now();
    await _save();
  }

  Future<void> _save() async {
    try {
      await _store.put(Collections.preferences, _documentId, {
        _keyCardDismissed: _cardDismissed,
        if (_lastPrompt case final DateTime at)
          _keyLastPromptMs: at.millisecondsSinceEpoch,
      });
    } on Object catch (error) {
      debugPrint('Premium prompt state not saved: $error');
    }
  }
}
