part of container;

/// An [Exception] thrown when an instantiation failed. It is thrown,
/// caught and rethrown to that we can see the stack of failing
/// instantiations.
///
/// If one class depends on another, that depends on a third one, and that
/// third one fails to instantiate, we can trace what class was being
/// requested, and why the instantiation failed.
class ContainerException implements Exception {
  final Type type;
  final String _innerMessage;

  ContainerException(this.type, ContainerException exception)
    : _innerMessage = exception._toString();

  ContainerException._finalize(this.type, error)
    : _innerMessage = error.toString();

  String _toString() => 'Cannot resolve $type because:\n$_innerMessage';

  String toString() => 'ContainerException: ${_toString()}';
}