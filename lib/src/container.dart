part of container;

abstract class Container {
  factory Container() => new _Container();

  /// Creates a new instance of a class, while injecting its
  /// dependencies recursively. Assign to a typed variable:
  ///
  ///     Config config = container.make(Config);
  ///
  /// Optionally provide named parameters to be inserted
  /// in the constructor invocation.
  ///
  ///     class MyClass {
  ///       MyClass(Config config, {String myString}) {
  ///         ...
  ///       }
  ///     }
  ///
  ///     container.make(MyClass, namedParameters: {'myString': 'value'});
  ///
  /// Optionally provide temporary singletons, to be injected if
  /// the constructor depends on a type.
  ///
  ///     class MyClass {
  ///       MyClass(MyInterface interface) {
  ///         ...
  ///       }
  ///     }
  ///
  ///     container.make(MyClass, injecting: {MyInterface: new MyImpl()});
  make(Type type,
      {Map<String, dynamic> namedParameters, Map<Type, dynamic> injecting});

  /// Resolves a method or a top-level function be injecting its
  /// arguments and their dependencies recursively
  ///
  ///     String getConfigItem(Config config) {
  ///       return config['file.key'];
  ///     }
  ///
  ///     container.resolve(getConfigItem); // 'value'
  ///
  /// Optionally provide named parameters to be inserted in the invocation.
  /// Optionally provide temporary singletons, to potentially be injected
  /// into the invocation.
  resolve(Function function,
      {Map<String, dynamic> namedParameters, Map<Type, dynamic> injecting});

  /// Resolves a named method on an instance. Use only when the type is
  /// not known or when expects a subtype or an implementation.
  ///
  /// Otherwise, use [resolve].
  ///
  /// Optionally provide named parameters to be inserted in the invocation.
  /// Optionally provide temporary singletons, to potentially be injected
  /// into the invocation.
  resolveMethod(Object object, String methodName,
      {Map<String, dynamic> namedParameters, Map<Type, dynamic> injecting});

  /// Checks if an object has a method.
  bool hasMethod(Object object, String method);

  /// Binds an instance as a singleton in the container, so that every
  /// time a class of that type is requested, that instance will
  /// be injected instead.
  ///
  /// Optionally set the type to bind as. This is especially useful if you want
  /// to have a singleton instance of an abstract class.
  ///
  /// Optionally provide named parameters to be inserted in the invocation.
  /// Optionally provide temporary singletons, to potentially be injected
  /// into the invocation.
  void singleton(Object singleton, {Type as});

  /// Binds an abstract class to an implementation, so that the
  /// non-abstract class will be injected when the
  /// abstraction is requested.
  void bind(Type abstraction, Type implementation);

  /// Creates a function that can take any arguments. The arguments will
  /// then, by their type, be injected into the inner function when called,
  /// evaluating the inner function and returning the response.
  ///
  ///     functionWillBeInjected(SomeClass input) {}
  ///     Function curried = container.curry(functionWillBeInjected);
  ///     curried(...);
  Function curry(Function function,
      {Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting});

  @Deprecated('very soon. Use [curry] instead.')
  Function presolve(Function function,
      {Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting})
    => curry(function, namedParameters: namedParameters, injecting: injecting);

  /// Registers a decorator on a target type, so that every time that type
  /// is injected, it will be decorated with the decorator.
  ///
  /// That means a class can be decorated with multiple decorators.
  ///
  ///     class Parent {}
  ///
  ///     class Decorator implements Parent {
  ///       final Parent parent;
  ///
  ///       Decorator(this.parent);
  ///     }
  ///
  ///     container.decorate(Parent, decorator: Decorator);
  ///     container.make(Parent); // Instance of 'Decorator'
  void decorate(Type target,
      {Type decorator,
      Iterable<Type> decorators,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting});
}
