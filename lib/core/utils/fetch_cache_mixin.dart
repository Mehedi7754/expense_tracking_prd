/// Mixin providing TTL-based cache validation and in-flight request
/// deduplication for Riverpod Notifiers.
///
/// Usage:
/// ```dart
/// class MyNotifier extends Notifier<List<MyModel>> with FetchCacheMixin {
///   Future<void> fetchData({bool force = false}) async {
///     if (!shouldFetch(force: force, hasData: state.isNotEmpty)) return;
///     markFetchStarted();
///     try {
///       // ... fetch logic ...
///       markFetchCompleted();
///     } catch (e) {
///       markFetchFailed();
///       rethrow;
///     }
///   }
/// }
/// ```
mixin FetchCacheMixin {
  /// Duration after which cached data is considered stale.
  static const Duration defaultTtl = Duration(minutes: 2);

  DateTime? _lastFetchTime;
  bool _isFetching = false;

  /// Whether a fetch is currently in-flight.
  bool get isFetching => _isFetching;

  /// Whether the cache is still valid (fetched within [ttl]).
  bool isCacheValid({Duration ttl = defaultTtl}) {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < ttl;
  }

  /// Returns `true` if a new fetch should proceed.
  ///
  /// Prevents duplicate in-flight requests and skips fetches when
  /// the cache is still valid and data exists.
  bool shouldFetch({
    bool force = false,
    bool hasData = false,
    Duration ttl = defaultTtl,
  }) {
    // Prevent concurrent duplicate calls
    if (_isFetching) return false;

    // Force always fetches
    if (force) return true;

    // Return cached state if fetched recently
    if (isCacheValid(ttl: ttl) && hasData) return false;

    return true;
  }

  /// Call at the start of a fetch operation.
  void markFetchStarted() {
    _isFetching = true;
  }

  /// Call after a successful fetch operation.
  void markFetchCompleted() {
    _lastFetchTime = DateTime.now();
    _isFetching = false;
  }

  /// Call when a fetch operation fails.
  void markFetchFailed() {
    _isFetching = false;
  }

  /// Invalidates the cache so the next [shouldFetch] call returns `true`.
  /// Use after mutations (create/update/delete) to force the next navigation
  /// fetch to hit the server.
  void invalidateCache() {
    _lastFetchTime = null;
  }
}
