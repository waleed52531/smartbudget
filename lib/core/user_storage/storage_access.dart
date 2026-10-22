import 'dart:async';
import 'dart:math';

/// Safe to report: never includes SQL, account identifiers, paths or key bytes.
enum StorageFailureKind {
  locked,
  keyUnavailable,
  damaged,
  ownership,
  unsupported,
  busy,
  migrationPending,
}

class StorageFailure implements Exception {
  const StorageFailure(this.kind);
  final StorageFailureKind kind;
  @override
  String toString() => 'StorageFailure(${kind.name})';
}

/// An in-process capability issued only after Stage 3 lease verification.
/// Identity fields bind storage; they are not a substitute for [StorageAuthority].
class StorageGrant {
  StorageGrant({
    required this.projectId,
    required this.uid,
    required this.expiresAtMs,
    required this.trustedMs,
    required bool Function() stillCurrent,
  }) : _stillCurrent = stillCurrent;
  final String projectId, uid;
  final int expiresAtMs, trustedMs;
  final bool Function() _stillCurrent;
  // Sample wall before starting the stopwatch: constructor delays can only
  // shorten a lease, never manufacture an apparent rollback or extend expiry.
  final int _wallStart = DateTime.now().millisecondsSinceEpoch;
  final Stopwatch _elapsed = Stopwatch()..start();

  bool get valid {
    // A cold callback or scheduling pause must not sit between the wall/elapsed
    // readings used to detect rollback. Bound the wall sample on both sides;
    // the later monotonic reading remains the conservative expiry bound.
    if (!_stillCurrent()) return false;
    final beforeWall = _elapsed.elapsedMilliseconds;
    final wallDelta = DateTime.now().millisecondsSinceEpoch - _wallStart;
    final afterWall = _elapsed.elapsedMilliseconds;
    return wallDelta >= beforeWall - 2000 &&
        trustedMs + max(wallDelta, afterWall) < expiresAtMs;
  }

  void check() {
    if (!valid) throw const StorageFailure(StorageFailureKind.locked);
  }

  int get trustedNowMs {
    check();
    return trustedMs +
        max(
          DateTime.now().millisecondsSinceEpoch - _wallStart,
          _elapsed.elapsedMilliseconds,
        );
  }
}

abstract interface class StorageAuthority {
  StorageGrant? get storageGrant;
  Stream<void> get storageChanges;

  /// Rechecks the native clock and the real signed lease before storage work.
  Future<void> verifyStorage(StorageGrant grant);
}

abstract interface class StorageLifecycle {
  /// Invalidates access synchronously, then drains pending writes and closes.
  Future<void> lock();
  Future<void> dispose();
}
