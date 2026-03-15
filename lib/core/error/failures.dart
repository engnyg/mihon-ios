sealed class Failure {
  const Failure([this.message]);
  final String? message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message]);
}

class SourceFailure extends Failure {
  const SourceFailure([super.message]);
}

class ParseFailure extends Failure {
  const ParseFailure([super.message]);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message]);
}
