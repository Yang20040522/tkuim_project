import 'dart:async';

import 'package:flutter/foundation.dart';

import '../account/app_session.dart';
import 'ml_research_api.dart';
import 'research_owner_scope.dart';

/// Server-authoritative research intent shared by phone and TV.
/// A stale or unverified state never authorizes a new sample.
class ResearchCollectionGate extends ChangeNotifier {
  ResearchCollectionGate({MlResearchRemote? remote, DateTime Function()? now})
      : _remote = remote ?? MlResearchApi(),
        _now = now ?? DateTime.now {
    AppSession.changes.addListener(_accountChanged);
  }

  static final ResearchCollectionGate instance = ResearchCollectionGate();
  static const freshness = Duration(seconds: 25);
  final MlResearchRemote _remote;
  final DateTime Function() _now;
  ResearchOwnerScope? _owner;
  MlResearchConsent? _consent;
  DateTime? _verifiedAt;
  Future<MlResearchConsent?>? _refreshing;
  Timer? _activeTimer;
  int _activeSessions = 0;
  bool _changing = false;
  String? error;

  MlResearchConsent? get consent => _consent;
  bool get busy => _changing;
  bool get fresh => _verifiedAt != null &&
      _now().difference(_verifiedAt!) >= Duration.zero &&
      _now().difference(_verifiedAt!) < freshness;
  bool get enabled => fresh && _consent?.active == true && _consent?.available == true;
  bool get handEnabled => enabled && _consent?.handAvailable == true;
  bool bodyEnabled(String actionId) => enabled &&
      (_consent?.bodyAvailableActions.contains(actionId) ?? false);

  void _accountChanged() {
    _owner = null;
    _consent = null;
    _verifiedAt = null;
    _refreshing = null;
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeSessions = 0;
    error = null;
    notifyListeners();
    if (ResearchOwnerScope.captureIfPresent() != null) unawaited(refresh(force: true));
  }

  Future<MlResearchConsent?> refresh({bool force = false}) {
    if (!force && fresh) return Future.value(_consent);
    if (_refreshing != null) return _refreshing!;
    final owner = ResearchOwnerScope.captureIfPresent();
    if (owner == null) {
      _consent = null;
      _verifiedAt = null;
      notifyListeners();
      return Future.value(null);
    }
    _owner = owner;
    final work = _remote.getConsent().then<MlResearchConsent?>((value) {
      owner.check(requireToken: true);
      if (identical(_owner, owner)) {
        _consent = value;
        _verifiedAt = _now();
        error = null;
        notifyListeners();
      }
      return value;
    }).catchError((Object failure) {
      if (identical(_owner, owner)) {
        _verifiedAt = null;
        _consent = null;
        error = MlResearchException.safeMessage(failure);
        notifyListeners();
      }
      return null;
    });
    _refreshing = work;
    return work.whenComplete(() { if (identical(_refreshing, work)) _refreshing = null; });
  }

  Future<bool> setEnabled(bool value) async {
    if (_changing) return enabled;
    _changing = true;
    if (!value) {
      // Local capture stops before the withdrawal request finishes.
      _verifiedAt = null;
      _consent = null;
      notifyListeners();
    }
    try {
      final owner = ResearchOwnerScope.capture();
      if (value) {
        final latest = await refresh(force: true);
        owner.check(requireToken: true);
        if (latest == null || !latest.available || latest.currentVersion.isEmpty) {
          error = latest == null ? '研究同意狀態無法確認。'
              : MlResearchException.safeMessage(
                  MlResearchException.unavailable(latest.unavailableReason));
          return false;
        }
        final saved = await _remote.setConsent(true, latest.currentVersion);
        owner.check(requireToken: true);
        _consent = saved;
        _verifiedAt = _now();
        return enabled;
      }
      final latest = await _remote.getConsent();
      owner.check(requireToken: true);
      await _remote.setConsent(false, latest.currentVersion);
      owner.check(requireToken: true);
      _consent = null;
      _verifiedAt = null;
      return false;
    } catch (failure) {
      error = MlResearchException.safeMessage(failure);
      _consent = null;
      _verifiedAt = null;
      return false;
    } finally {
      _changing = false;
      notifyListeners();
    }
  }

  Future<bool> canCollect({String? actionId, bool hand = false}) async {
    if (!fresh && await refresh(force: true) == null) return false;
    if (hand) return handEnabled;
    return actionId == null ? enabled : bodyEnabled(actionId);
  }

  void beginSession() {
    _activeSessions++;
    unawaited(refresh(force: true));
    _activeTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      if (_activeSessions > 0 && _consent?.active == true) unawaited(refresh(force: true));
    });
  }

  void endSession() {
    if (_activeSessions > 0) _activeSessions--;
    if (_activeSessions == 0) {
      _activeTimer?.cancel();
      _activeTimer = null;
    }
  }

  @override
  void dispose() {
    _activeTimer?.cancel();
    AppSession.changes.removeListener(_accountChanged);
    super.dispose();
  }
}
