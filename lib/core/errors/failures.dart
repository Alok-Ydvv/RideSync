/// Minimal failure model for Phase 1 repositories. Keeps UI code honest
/// without pulling in a full Either/dartz stack yet.
sealed class Failure implements Exception {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No connection. Data queued offline.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

class LocationFailure extends Failure {
  const LocationFailure([super.message = 'Location unavailable.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local cache error.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error. Retry queued.']);
}
