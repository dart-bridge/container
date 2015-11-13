part of container;

class _Container implements Container {
  /// Contains instances bound as singletons as types
  final Map<Type, dynamic> _singletons = {};

  /// Contains types registered as replacements for other types
  final Map<Type, Type> _bindings = {};

  /// Contains a list of decoration functions bound to types
  final Map<Type, List<Function>> _decorators = {};

  void bind(Type abstraction, Type implementation) {
    // This implementation will now replace the abstraction
    // when the abstraction is requested
    _bindings[abstraction] = implementation;
  }

  void singleton(Object singleton, {Type as}) {
    // Decide what type to bind the singleton to
    Type type = as ?? singleton.runtimeType;

    // This instance will now be used for that type
    _singletons[type] = singleton;
  }

  void decorate(Type target,
      {Type decorator,
      Iterable<Type> decorators,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting}) {
    // Create an iterable from the optional arguments
    // [decorator] and [decorators].
    final allDecorators = _merge(decorators, decorator);

    if (allDecorators.isEmpty)
      throw new ArgumentError('At least one decorator must be provided.');

    for (final decorator in allDecorators)
      _registerDecorator(target, decorator, namedParameters, injecting);
  }

  make(Type type,
      {Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting}) {
    final instance = _getInstance(type, namedParameters, injecting);

    final decorators = _decorators[type] ?? [];
    return _applyDecorators(instance, decorators);
  }

  resolve(Function function,
      {Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting}) {
    ClosureMirror closure = reflect(function);

    final positional = _getPositionalParameters(closure.function, injecting);
    final named = _getNamedArguments(namedParameters);

    return closure
        .apply(positional.toList(), named)
        .reflectee;
  }

  resolveMethod(Object object, String methodName,
      {Map<String, dynamic> namedParameters, Map<Type, dynamic> injecting}) {
    final symbol = new Symbol(methodName);
    final instance = reflect(object);
    final method = instance.type.instanceMembers[symbol];

    final positional = _getPositionalParameters(method, injecting);
    final named = _getNamedArguments(namedParameters);

    return instance
        .invoke(symbol, positional.toList(), named)
        .reflectee;
  }

  bool hasMethod(Object object, String method) {
    return reflect(object).type.instanceMembers.containsKey(new Symbol(method));
  }

  Function curry(Function function,
      {Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting}) {
    // Return a function that can take 0–10 arguments
    return ([_1, _2, _3, _4, _5, _6, _7, _8, _9, _10]) {
      // Turn the arguments that were actually supplied to a
      // map with their respective types as key
      final arguments = _mapTypes(
          [_1, _2, _3, _4, _5, _6, _7, _8, _9, _10]
              .where((a) => a != null)
      );

      // Create a new map that will contain the injections when the
      // curried function is called.
      Map<Type, dynamic> injections = new Map.from(injecting ?? {});

      // Add the arguments that was passed into the curried function
      // to the map of injections.
      injections.addAll(arguments);

      // Resolve the original function with the injections
      return resolve(function,
          injecting: injections,
          namedParameters: namedParameters);
    };
  }

  /// Turns an iterable into a map with the items' respective types
  /// as keys.
  Map<Type, dynamic> _mapTypes(Iterable instances) {
    final types = instances.map((i) => i.runtimeType);
    return new Map.fromIterables(types, instances);
  }

  /// Merges a maybe-iterable and a maybe-item to an iterable that's maybe empty
  Iterable _merge([Iterable iterable, item]) {
    return [iterable, item]
        .expand((e) => e is Iterable ? e : [e])
        .where((e) => e != null);
  }

  Object _getInstance(Type type,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting) {
    // If the type is registered as a singleton, that should be used
    if (_isSingleton(type)) return _singletons[type];

    // If this type has been bound to another implementation,
    // target that instead
    final implementationType = _isBound(type)
        ? _bindings[type]
        : type;

    // Create a new instance of the implementation type
    return _make(implementationType, namedParameters, injecting);
  }

  bool _isSingleton(Type type) => _singletons.containsKey(type);

  bool _isBound(Type type) => _bindings.containsKey(type);

  bool _hasConstructor(ClassMirror classMirror) =>
      classMirror.declarations.containsKey(classMirror.simpleName);

  MethodMirror _getConstructor(ClassMirror classMirror) =>
      classMirror.declarations[classMirror.simpleName];

  bool _existsAndContains(Map map, item) =>
      map != null && map.containsKey(item);

  bool _isAssignableTo(Type from, Type to) =>
      reflectType(from).isAssignableTo(reflectType(to));

  _make(Type type,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting) {
    return _catchWhileInstantiating(type, () {
      final ClassMirror classMirror = reflectType(type);

      // If the class doesn't have a default constructor the call should be
      // a call with no arguments passed to method with empty symbol
      if (!_hasConstructor(classMirror)) {
        return _instantiate(
            classMirror,
            const Symbol(''),
            [],
            namedParameters,
            injecting);
      }

      final constructor = _getConstructor(classMirror);
      return _instantiate(
          classMirror,
          constructor.constructorName,
          _getPositionalParameters(constructor, injecting),
          namedParameters,
          injecting);
    });
  }

  /// Creates a new instance of a class, and directly afterwards
  /// runs the $inject method if it exists on the class
  _instantiate(ClassMirror classMirror,
      Symbol constructorSymbol,
      Iterable positionalArguments,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting) {
    final namedArguments = _getNamedArguments(namedParameters);

    // Perform the instantiation
    final instance = (classMirror.newInstance(
        constructorSymbol,
        positionalArguments.toList(),
        namedArguments)
    ).reflectee;

    // Resolve $inject if exists
    _resolve$injectMethod(instance, namedParameters, injecting);

    return instance;
  }

  void _resolve$injectMethod(Object instance,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting) {
    if (hasMethod(instance, r'$inject'))
      resolveMethod(instance, r'$inject',
          namedParameters: namedParameters,
          injecting: injecting);
  }

  /// Catches all [AbstractClassInstantiationError] and [NoSuchMethodError]
  /// and wraps them in a chain of container exceptions which propagate
  /// out to the initial call
  _catchWhileInstantiating(Type type, callback()) {
    try {
      return callback();
    } on ContainerException catch (e) {
      // Propagates a nested [make] call failure, adding this type
      // To the chain ("couldn't create X because: couldn't create Y...")
      throw new ContainerException(type, e);
    } on AbstractClassInstantiationError catch (e) {
      throw new ContainerException._finalize(type, e);
    } on NoSuchMethodError catch (e) {
      throw new ContainerException._finalize(type, e);
    }
  }

  /// Turns a nullable map of named arguments and creates a new map
  /// with keys of type [Symbol]
  Map<Symbol, dynamic> _getNamedArguments([Map<String, dynamic> map]) {
    if (map == null) return {};

    final keys = map.keys.map((k) => new Symbol(k));

    return new Map.fromIterables(keys, map.values);
  }

  /// Resolves the arguments in a method signature into instances
  /// from the type declarations.
  Iterable _getPositionalParameters(MethodMirror method,
      Map<Type, dynamic> injecting) sync* {
    if (method == null) return;

    final positional = method.parameters.where((p) => !p.isNamed);

    for (final parameter in positional) {
      final type = _returnType(parameter);

      // If a replacement to this type was provided in the [injecting]
      // parameter then that object should be returned directly
      if (_existsAndContains(injecting, type)) yield injecting[type];

      // Otherwise a new instance of the type should be created
      else yield make(type, injecting: injecting);
    }
  }

  /// Gets the return type of a parameter
  _returnType(ParameterMirror parameter) {
    if (!parameter.type.hasReflectedType)
      throw new ArgumentError('Each parameter must be typed in '
          'order to resolve the method!');

    return parameter.type.reflectedType;
  }

  void _registerDecorator(Type target, Type decorator,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting) {
    // The decorator pattern requires the decorator pattern to
    // implement the interface it is decorating on
    if (!_isAssignableTo(decorator, target))
      throw new ArgumentError('The decorator must implement [$target].');

    // Ensure that there is a list of decorators for this type
    _decorators[target] ??= [];

    // Add the new decoration function to the list
    _decorators[target].add(
        _makeDecorationFunction(target, decorator, namedParameters, injecting)
    );
  }

  Function _makeDecorationFunction(Type target, Type decorator,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting) {
    // This function will be called when a new instance of the
    // target type has been created. The instance is passed in as
    // the [instance] argument.
    //
    // The function will then create a new instance of the decorator,
    // passing in the instance into the argument list, and then return
    // the decorated instance.
    return (Object instance) {
      // Create a map of temporary singletons
      final injections = new Map.from(injecting ?? {});

      // Add the base instance to the injections, by the type that is
      // being decorated
      injections[target] = instance;

      // Instantiate and return the decorator, passing in the base object
      // in the argument list.
      return make(decorator,
          injecting: injections,
          namedParameters: namedParameters);
    };
  }

  /// Takes an instance and passes it through a list of decoration
  /// functions that replaces it with a new decorator
  _applyDecorators(Object instance, List<Function> decorators) {
    return decorators.fold(instance, (i, f) => f(i));
  }

  /// Use [curry] instead
  @Deprecated('soon')
  presolve(_, {namedParameters, injecting}) {
    return curry(_, namedParameters: namedParameters, injecting: injecting);
  }
}
