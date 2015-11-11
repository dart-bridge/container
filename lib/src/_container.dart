part of container;

class _Container implements Container {
  final Map<Type, dynamic> _singletons = {};
  final Map<Type, Type> _bindings = {};
  final Map<Type, List<Function>> _decorators = {};

  void bind(Type abstraction, Type implementation) {
    _bindings[abstraction] = implementation;
  }

  void singleton(Object singleton, {Type as}) {
    Type type = (as == null) ? singleton.runtimeType : as;

    _singletons[type] = singleton;
  }

  make(Type type,
      {Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting}) {
    final decorators = _decorators[type] ?? [];

    if (_singletons.containsKey(type))
      return _decorate(_singletons[type], decorators);

    if (_bindings.containsKey(type)) type = _bindings[type];

    return _decorate(_make(type, namedParameters, injecting), decorators);
  }

  resolve(Function function,
      {Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting}) {
    ClosureMirror closure = reflect(function);

    List positional = _getPositionalParameters(closure.function, injecting);

    return closure
        .apply(
        positional, _convertStringKeysToSymbols(namedParameters))
        .reflectee;
  }

  _make(Type type,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting) {
    try {
      var namedArguments = _convertStringKeysToSymbols(namedParameters);

      ClassMirror classMirror = reflectType(type);

      Symbol constructorSymbol;

      List positionalArguments;

      if (classMirror.declarations.containsKey(classMirror.simpleName)) {
        MethodMirror constructor =
        classMirror.declarations[classMirror.simpleName];

        positionalArguments = _getPositionalParameters(constructor, injecting);

        constructorSymbol = constructor.constructorName;
      } else {
        positionalArguments = [];

        constructorSymbol = const Symbol('');
      }

      final instance = (classMirror.newInstance(
          constructorSymbol,
          positionalArguments,
          namedArguments)
      ).reflectee;

      if (hasMethod(instance, r'$inject'))
        resolveMethod(instance, r'$inject',
            namedParameters: namedParameters,
            injecting: injecting);

      return instance;
    } on ContainerException catch (e) {
      throw new ContainerException(type, e);
    } on AbstractClassInstantiationError catch (e) {
      throw new ContainerException._finalize(type, e);
    } on NoSuchMethodError catch (e) {
      throw new ContainerException._finalize(type, e);
    }
  }

  Map<Symbol, dynamic> _convertStringKeysToSymbols(Map<String, dynamic> map) {
    if (map == null) return {};

    return new Map<Symbol, dynamic>.fromIterables(
        map.keys.map((String key) => new Symbol(key)), map.values);
  }

  List _getPositionalParameters(MethodMirror method,
      Map<Type, dynamic> injecting) {
    List positionalParameters = [];

    if (method == null) return positionalParameters;

    method.parameters.forEach((ParameterMirror parameter) {
      if (!parameter.isNamed) {
        if (!parameter.type
            .hasReflectedType) throw new ArgumentError(
            'Each parameter must be typed in order to resolve the method!');

        var type = parameter.type.reflectedType;

        if (injecting != null && injecting.containsKey(type)) {
          return positionalParameters.add(injecting[type]);
        }

        positionalParameters.add(make(type, injecting: injecting));
      }
    });

    return positionalParameters;
  }

  resolveMethod(Object object, String methodName,
      {Map<String, dynamic> namedParameters, Map<Type, dynamic> injecting}) {
    var symbol = new Symbol(methodName);

    var instance = reflect(object);

    var objectClass = instance.type;

    var method = objectClass.instanceMembers[symbol];

    var args = _getPositionalParameters(method, injecting);

    return instance
        .invoke(
        symbol, args, _convertStringKeysToSymbols(namedParameters))
        .reflectee;
  }

  bool hasMethod(Object object, String method) {
    return reflect(object).type.instanceMembers.containsKey(new Symbol(method));
  }

  Function presolve(Function function,
      {Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting}) {
    return ([arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10]) {
      var arguments = [
        arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10]
          .where((a) => a != null);

      var argumentsWithTypes = ((injecting != null ? injecting : {}) as Map)
        ..addAll(new Map.fromIterables(
            arguments.map((a) => a.runtimeType),
            arguments));

      return resolve(function, injecting: argumentsWithTypes,
          namedParameters: namedParameters);
    };
  }

  void decorate(Type target,
      {Type decorator,
      Map<String, dynamic> namedParameters,
      Map<Type, dynamic> injecting}) {
    if (decorator == null)
      throw new ArgumentError('A decorator must be provided.');
    if (!reflectType(decorator).isAssignableTo(reflectType(target)))
      throw new ArgumentError('The decorator must implement [$target].');
    _decorators[target] ??= [];
    _decorators[target].add((Object instance) {
      return make(decorator, injecting: new Map.from(injecting ?? {})
        ..addAll({
          target: instance
        }), namedParameters: namedParameters);
    });
  }

  _decorate(Object instance, List<Function> decorators) {
    var _instance = instance;
    for (final decoratorFunction in decorators)
      _instance = decoratorFunction(_instance);
    return _instance;
  }
}
