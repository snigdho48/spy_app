/// App-level result type. Left is success, Right is an error message.
///
/// one_request 3.1 uses dart_either with the opposite convention (Right = data).
/// [ApiService] maps that at the network boundary so repositories stay Left-success.
sealed class Either<L, R> {
  const Either();

  bool get isLeft;
  bool get isRight => !isLeft;

  L get left;
  R get right;

  T fold<T>(T Function(L left) ifLeft, T Function(R right) ifRight);
}

final class Left<L, R> extends Either<L, R> {
  const Left(this.value);

  final L value;

  @override
  bool get isLeft => true;

  @override
  L get left => value;

  @override
  R get right => throw StateError('Tried to read right from Left');

  @override
  T fold<T>(T Function(L left) ifLeft, T Function(R right) ifRight) =>
      ifLeft(value);
}

final class Right<L, R> extends Either<L, R> {
  const Right(this.value);

  final R value;

  @override
  bool get isLeft => false;

  @override
  L get left => throw StateError('Tried to read left from Right');

  @override
  R get right => value;

  @override
  T fold<T>(T Function(L left) ifLeft, T Function(R right) ifRight) =>
      ifRight(value);
}
