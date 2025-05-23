import 'dart:typed_data';

import 'package:hetu_script/value/variable/variable.dart';
import 'package:pub_semver/pub_semver.dart';

import '../version.dart';
import '../ast/ast.dart';
import '../value/namespace/namespace.dart';
import '../analyzer/analyzer.dart';
import '../interpreter/interpreter.dart';
import '../resource/resource.dart' show HTResourceType;
import '../resource/resource_context.dart';
import '../resource/overlay/overlay_context.dart';
// import '../type/type.dart';
import '../source/source.dart';
import '../bytecode/compiler.dart';
import '../logger/message_severity.dart';
import '../binding/function_binding.dart';
import '../precompiled_module.dart';
import '../locale/locale.dart';
import '../external/external_function.dart';
import '../external/external_class.dart';
import '../binding/class_binding.dart';
import '../lexer/lexer.dart';
import '../lexicon/lexicon.dart';
import '../parser/parser.dart';
import '../parser/parser_hetu.dart';
import '../resource/resource.dart';
import '../bundler/bundler.dart';
import '../logger/logger.dart';
import '../logger/console_logger.dart';
import 'console.dart';
import '../lexicon/lexicon_hetu.dart';
import '../value/struct/struct.dart';
import '../value/function/function.dart';

/// The config of hetu environment, this implements all config of components used by this environment.
class HetuConfig
    implements
        ParserConfig,
        BundlerConfig,
        AnalyzerConfig,
        CompilerConfig,
        InterpreterConfig {
  /// defaults to `true`
  @override
  bool normalizeImportPath;

  /// defaults to `false`
  @override
  bool explicitEndOfStatement;

  /// defaults to `false`
  @override
  bool computeConstantExpression;

  /// defaults to `false`
  @override
  bool doStaticAnalysis;

  /// defaults to `false`
  @override
  bool removeLineInfo;

  /// defaults to `false`
  @override
  bool removeAssertion;

  /// defaults to `false`
  @override
  bool removeDocumentation;

  /// defaults to `false`
  @override
  bool showDartStackTrace;

  /// defaults to `false`
  @override
  bool showHetuStackTrace;

  /// defaults to `false`
  @override
  int stackTraceDisplayCountLimit;

  /// defaults to `true`
  @override
  bool processError;

  /// defaults to `false`
  @override
  bool debugMode;

  /// defaults to `true`
  @override
  bool allowVariableShadowing;

  /// defaults to `false`
  @override
  bool allowImplicitVariableDeclaration;

  /// defaults to `false`
  @override
  bool allowImplicitNullToZeroConversion;

  /// defaults to `false`
  @override
  bool allowImplicitEmptyValueToFalseConversion;

  /// defaults to `false`
  @override
  bool allowInitializationExpresssionHaveValue;

  /// Wether check the nominal typename validity at runtime,
  /// will slightly affect the efficiency of the interpreter.
  ///
  /// defaults to `false`
  @override
  bool checkTypeAnnotationAtRuntime;

  @override
  bool resolveExternalFunctionsDynamically;

  /// defaults to `true`
  @override
  bool printPerformanceStatistics;

  HetuConfig({
    this.normalizeImportPath = true,
    this.explicitEndOfStatement = false,
    this.doStaticAnalysis = false,
    this.computeConstantExpression = false,
    this.removeLineInfo = false,
    this.removeAssertion = false,
    this.removeDocumentation = false,
    this.showDartStackTrace = false,
    this.showHetuStackTrace = false,
    this.stackTraceDisplayCountLimit = 5,
    this.processError = true,
    this.debugMode = false,
    this.allowVariableShadowing = false,
    this.allowImplicitVariableDeclaration = false,
    this.allowImplicitNullToZeroConversion = false,
    this.allowImplicitEmptyValueToFalseConversion = false,
    this.allowInitializationExpresssionHaveValue = false,
    this.checkTypeAnnotationAtRuntime = false,
    this.resolveExternalFunctionsDynamically = false,
    this.printPerformanceStatistics = false,
  });
}

/// A helper class wrapped sourceContext, lexicon, parser, bundler,
/// analyzer, compiler, interpreter, logger...
/// and make them work together.
class Hetu {
  HetuConfig config;

  Version? verison;

  late final Console console;

  final HTResourceContext<HTSource> sourceContext;

  late final HTParser parser;

  HTLexer get lexer => parser.lexer;

  HTLexicon get lexicon => parser.lexer.lexicon;

  // final Map<String, HTParser> _parsers = {};

  // late HTParser _currentParser;

  // HTParser get parser => _currentParser;

  // HTLexer get lexer => _currentParser.lexer;

  // HTLexicon get lexicon => lexer.lexicon;

  late final HTBundler bundler;

  late final HTAnalyzer analyzer;

  late final HTCompiler compiler;

  late final HTInterpreter interpreter;

  bool _isInitted = false;
  bool get isInitted => _isInitted;

  /// Create a Hetu environment.
  Hetu({
    HetuConfig? config,
    HTLogger? logger,
    HTResourceContext<HTSource>? sourceContext,
    HTLocale? locale,
    HTLexicon? lexicon,
    HTLexer? lexer,
    // String parserName = 'default',
    HTParser? parser,
  })  : config = config ?? HetuConfig(),
        sourceContext = sourceContext ?? HTOverlayContext() {
    lexicon ??= lexer?.lexicon ?? HTLexiconHetu();
    console = Console(
      lexicon: lexicon,
      logger: logger ?? HTConsoleLogger(),
    );
    if (locale != null) {
      HTLocale.current = locale;
    }
    if (parser != null) {
      this.parser = parser;
      if (lexer != null) {
        this.parser.lexer = lexer;
      } else {
        this.parser.lexer.lexicon = lexicon;
      }
    } else {
      if (lexer != null) {
        this.parser = HTParserHetu(
          config: this.config,
          lexer: lexer,
        );
      } else {
        this.parser = HTParserHetu(
          config: this.config,
          lexicon: lexicon,
        );
      }
    }
    // if (parser != null) {
    //   _currentParser = parser;
    // } else {
    //   _currentParser = HTParserHetu(
    //     config: this.config,
    //   );
    // }
    // if (lexer != null) {
    //   _currentParser.lexer = lexer;
    // }
    // _currentParser.lexer.lexicon = lexicon;
    // _parsers[parserName] = _currentParser;
    bundler = HTBundler(
      config: this.config,
      sourceContext: this.sourceContext,
      parser: this.parser,
    );
    analyzer = HTAnalyzer(
      config: this.config,
      sourceContext: this.sourceContext,
      lexicon: lexicon,
    );
    compiler = HTCompiler(
      config: this.config,
      lexicon: lexicon,
    );
    interpreter = HTInterpreter(
      config: this.config,
      sourceContext: this.sourceContext,
      lexicon: lexicon,
    );
  }

  /// Initialize the interpreter,
  /// prepare it with preincluded modules,
  /// bind it with HTExternalFunction, HTExternalFunctionTypedef, HTExternalClass, etc.
  ///
  /// A uninitted Hetu can still eval certain script,
  /// it cannot use any of the pre-included functions like `print` and the Dart apis on number & string, etc.
  void init({
    bool useDefaultModuleAndBinding = true,
    Map<String, Function> externalFunctions = const {},
    Map<String, HTExternalMethod> externalMethods = const {},
    Map<String, HTExternalFunctionTypedef> externalFunctionTypedef = const {},
    List<HTExternalClass> externalClasses = const [],
    List<HTExternalTypeReflection> externalTypeReflections = const [],
  }) {
    if (_isInitted) return;

    if (useDefaultModuleAndBinding) {
      final numBinding = HTNumberClassBinding();
      final iterableBinding = HTIterableClassBinding();
      interpreter.bindExternalClass(numBinding);
      interpreter
          .bindExternalClass(HTIntegerClassBinding(superClass: numBinding));
      interpreter
          .bindExternalClass(HTFloatClassBinding(superClass: numBinding));
      interpreter.bindExternalClass(HTBigIntClassBinding());
      interpreter.bindExternalClass(HTBooleanClassBinding());
      interpreter.bindExternalClass(HTStringClassBinding());
      interpreter.bindExternalClass(HTIteratorClassBinding());
      interpreter.bindExternalClass(iterableBinding);
      interpreter
          .bindExternalClass(HTListClassBinding(superClass: iterableBinding));
      interpreter
          .bindExternalClass(HTSetClassBinding(superClass: iterableBinding));
      interpreter.bindExternalClass(HTMapClassBinding());
      interpreter.bindExternalClass(HTRandomClassBinding());
      interpreter.bindExternalClass(HTFutureClassBinding());
      interpreter.bindExternalClass(HTCryptoClassBinding());
      interpreter.bindExternalClass(HTConsoleClassBinding(console: console));
      interpreter.bindExternalClass(HTJSONClassBinding(lexicon: lexicon));

      // bind dynamic external functions or static method
      interpreter.bindExternalFunction('print',
          ({positionalArgs, namedArgs}) => console.log(positionalArgs));
      interpreter.bindExternalFunction(
          'eval', ({positionalArgs, namedArgs}) => eval(positionalArgs.first));
      interpreter.bindExternalFunction('require',
          ({positionalArgs, namedArgs}) => require(positionalArgs.first));
      interpreter.bindExternalFunction(
          'help', ({positionalArgs, namedArgs}) => help(positionalArgs.first));
      interpreter.bindExternalFunction('Object.fromJSON', (
          {positionalArgs, namedArgs}) {
        final jsonData = positionalArgs.first as Map<dynamic, dynamic>;
        return interpreter.createStructfromJSON(jsonData);
      });
      interpreter.bindExternalFunction('Object.assign', (
          {positionalArgs, namedArgs}) {
        final target = positionalArgs[0] as HTStruct;
        final source = positionalArgs[1] as HTStruct;
        target.assign(source);
      });
      interpreter.bindExternalFunction('Object.merge', (
          {positionalArgs, namedArgs}) {
        final target = positionalArgs[0] as HTStruct;
        final source = positionalArgs[1] as HTStruct;
        target.merge(source);
      });

      // bind dynamic external method
      interpreter.bindExternalMethod('ClassRoot::toString', (
          {object, positionalArgs, namedArgs}) {
        return lexicon.stringify(object);
      });
      interpreter.bindExternalMethod('Object::iterator', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        return struct.keys.iterator;
      });
      interpreter.bindExternalMethod('Object::keys', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        return struct.keys;
      });
      interpreter.bindExternalMethod('Object::values', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        return struct.values;
      });
      interpreter.bindExternalMethod('Object::contains', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        return struct.contains(positionalArgs.first);
      });
      interpreter.bindExternalMethod('Object::containsKey', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        return struct.containsKey(positionalArgs.first);
      });
      interpreter.bindExternalMethod('Object::isEmpty', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        return struct.isEmpty;
      });
      interpreter.bindExternalMethod('Object::isNotEmpty', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        return struct.isNotEmpty;
      });
      interpreter.bindExternalMethod('Object::length', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        return struct.length;
      });
      interpreter.bindExternalMethod('Object::remove', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        struct.remove(positionalArgs.first);
      });
      interpreter.bindExternalMethod('Object::clone', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        return struct.clone();
      });
      interpreter.bindExternalMethod('Object::assign', (
          {object, positionalArgs, namedArgs}) {
        final struct = object as HTStruct;
        final other = positionalArgs.first as HTStruct;
        struct.assign(other);
      });

      // must convert the return type to let dart know its return value type.
      interpreter.bindExternalFunctionType(
        'VoidCallback',
        (HTFunction function) {
          return () {
            return function.call();
          };
        },
      );

      interpreter.bindExternalFunctionType(
        'ValueCallback',
        (HTFunction function) {
          return (value) {
            return function.call(positionalArgs: [value]);
          };
        },
      );

      // bind non-dynamic external functions
      for (var key in preincludeFunctions.keys) {
        interpreter.bindExternalFunction(key, preincludeFunctions[key]!);
      }

      // load precompiled core module.
      final coreModule = Uint8List.fromList(hetuCoreModule);
      interpreter.loadBytecode(
        bytes: coreModule,
        module: 'hetu',
        globallyImport: true,
      );

      interpreter.define(
        'kHetuVersion',
        HTVariable(
          id: 'kHetuVersion',
          interpreter: interpreter,
          closure: interpreter.globalNamespace,
          value: kHetuVersion.toString(),
        ),
      );
      interpreter.define(
        lexicon.kThis,
        HTVariable(
          id: lexicon.kThis,
          interpreter: interpreter,
          closure: interpreter.globalNamespace,
          value: interpreter.globalNamespace,
        ),
      );
      interpreter.define(
        lexicon.idGlobal,
        HTVariable(
          id: lexicon.idGlobal,
          interpreter: interpreter,
          closure: interpreter.globalNamespace,
          value: interpreter.globalNamespace,
        ),
      );

      // interpreter.assign('console', console);

      HTInterpreter.classRoot = interpreter.globalNamespace
          .memberGet(lexicon.idGlobalObject, isRecursive: true);
      HTInterpreter.structRoot = interpreter.globalNamespace
          .memberGet(lexicon.idGlobalPrototype, isRecursive: true);
    }

    for (final key in externalFunctions.keys) {
      interpreter.bindExternalFunction(key, externalFunctions[key]!);
    }
    for (final key in externalMethods.keys) {
      interpreter.bindExternalMethod(key, externalMethods[key]!);
    }
    for (final key in externalFunctionTypedef.keys) {
      interpreter.bindExternalFunctionType(key, externalFunctionTypedef[key]!);
    }
    for (final value in externalClasses) {
      interpreter.bindExternalClass(value);
    }
    for (final value in externalTypeReflections) {
      interpreter.bindExternalReflection(value);
    }

    interpreter.currentNamespace = interpreter.globalNamespace;

    _isInitted = true;
  }

  // /// Add a new parser.
  // void addParser(String name, HTParser parser) {
  //   assert(!_parsers.containsKey(name));
  //   _currentParser = _parsers[name] = parser;
  // }

  // /// Change the current parser.
  // void setParser(String name) {
  //   assert(_parsers.containsKey(name));
  //   _currentParser = _parsers[name]!;
  // }

  String stringify(dynamic) => lexicon.stringify(dynamic);

  /// Evaluate a string content.
  /// If [invoke] is provided, will immediately
  /// call the function after evaluation completed.
  dynamic eval(
    String content, {
    String? filename,
    String? module,
    bool globallyImport = false,
    HTResourceType type = HTResourceType.hetuLiteralCode,
    String? invoke,
    List<dynamic> positionalArgs = const [],
    Map<String, dynamic> namedArgs = const {},
    // List<HTType> typeArgs = const [],
  }) {
    if (content.trim().isEmpty) return null;
    final source = HTSource(content, filename: filename, type: type);
    final result = evalSource(
      source,
      module: module,
      globallyImport: globallyImport,
      invoke: invoke,
      positionalArgs: positionalArgs,
      namedArgs: namedArgs,
      // typeArgs: typeArgs,
    );
    return result;
  }

  /// Evaluate a file.
  /// [key] is a possibly relative path.
  /// file content will be searched by [sourceContext].
  /// If [invoke] is provided, will immediately
  /// call the function after evaluation completed.
  dynamic evalFile(
    String key, {
    String? module,
    bool globallyImport = false,
    String? invoke,
    List<dynamic> positionalArgs = const [],
    Map<String, dynamic> namedArgs = const {},
    // List<HTType> typeArgs = const [],
  }) {
    final source = sourceContext.getResource(key);
    final result = evalSource(
      source,
      module: module,
      globallyImport: globallyImport,
      invoke: invoke,
      positionalArgs: positionalArgs,
      namedArgs: namedArgs,
      // typeArgs: typeArgs,
    );
    return result;
  }

  /// Evaluate a [HTSource].
  /// If [invoke] is provided, will immediately
  /// call the function after evaluation completed.
  dynamic evalSource(
    HTSource source, {
    String? module,
    bool globallyImport = false,
    String? invoke,
    List<dynamic> positionalArgs = const [],
    Map<String, dynamic> namedArgs = const {},
    // List<HTType> typeArgs = const [],
  }) {
    if (source.content.trim().isEmpty) {
      return null;
    }
    final bytes = _compileSource(source);
    final savedContext = interpreter.getContext();
    final result = interpreter.loadBytecode(
      bytes: bytes,
      module: module ?? source.fullName,
      globallyImport: globallyImport,
      invoke: invoke,
      positionalArgs: positionalArgs,
      namedArgs: namedArgs,
      // typeArgs: typeArgs,
    );
    interpreter.setContext(savedContext);
    return result;
  }

  /// Process the import declaration within several sources,
  /// generate a single [ASTCompilation] for [HTCompiler] to compile.
  ASTCompilation bundle(HTSource source,
      {Version? version, bool errorHandled = false}) {
    final compilation = bundler.bundle(
      source: source,
      // parser: _currentParser,
      version: version,
    );
    if (compilation.errors.isNotEmpty) {
      for (final error in compilation.errors) {
        if (errorHandled) {
          throw error;
        } else {
          interpreter.processError(error);
        }
      }
    }
    return compilation;
  }

  /// Compile a string into bytecode.
  /// This won't execute the code, so runtime errors will not be reported.
  Uint8List compile(
    String content, {
    String? filename,
    CompilerConfig? config,
    bool isModuleEntryScript = false,
    Version? version,
  }) {
    final source = HTSource(content,
        filename: filename,
        type: isModuleEntryScript
            ? HTResourceType.hetuScript
            : HTResourceType.hetuModule);
    return _compileSource(
      source,
      version: version,
    );
  }

  /// Compile a source within current [sourceContext].
  /// This won't execute the code, so runtime errors will not be reported.
  Uint8List compileFile(
    String key, {
    CompilerConfig? config,
    Version? version,
  }) {
    final source = sourceContext.getResource(key);
    return _compileSource(
      source,
      version: version,
    );
  }

  /// Compile a [HTSource] into bytecode for later use.
  Uint8List _compileSource(
    HTSource source, {
    Version? version,
    bool errorHandled = false,
  }) {
    try {
      final compilation = bundle(
        source,
        version: version,
        errorHandled: true,
      );
      Uint8List bytes;
      if (config.doStaticAnalysis) {
        final result = analyzer.analyzeCompilation(compilation);
        if (result.errors.isNotEmpty) {
          for (final error in result.errors) {
            if (error.severity >= MessageSeverity.error) {
              if (errorHandled) {
                throw error;
              } else {
                interpreter.processError(error);
              }
            } else {
              print('hetu - ${error.severity}: $error');
            }
          }
        }
      }
      bytes = compiler.compile(compilation);
      return bytes;
    } catch (error, stackTrace) {
      if (errorHandled) {
        rethrow;
      } else {
        interpreter.processError(error, stackTrace);
        return Uint8List.fromList([]);
      }
    }
  }

  /// Load a bytecode module and immediately run a function in it.
  dynamic loadBytecode({
    required Uint8List bytes,
    required String module,
    bool globallyImport = false,
    String? invoke,
    List<dynamic> positionalArgs = const [],
    Map<String, dynamic> namedArgs = const {},
    // List<HTType> typeArgs = const [],
  }) {
    final result = interpreter.loadBytecode(
      bytes: bytes,
      module: module,
      globallyImport: globallyImport,
      invoke: invoke,
      positionalArgs: positionalArgs,
      namedArgs: namedArgs,
      // typeArgs: typeArgs,
    );
    if (config.doStaticAnalysis &&
        interpreter.currentBytecodeModule.namespaces.isNotEmpty) {
      analyzer.globalNamespace.import(
          interpreter.currentBytecodeModule.namespaces.values.last,
          idOnly: true);
    }
    return result;
  }

  /// Dynamically load a source into current bytecode.
  HTNamespace require(String path) {
    final key = config.normalizeImportPath
        ? sourceContext.getAbsolutePath(key: path)
        : path;

    // Search in current module first
    if (interpreter.currentBytecodeModule.namespaces.containsKey(key)) {
      return interpreter.currentBytecodeModule.namespaces[key]!;
    }

    // If the source is not in current module, then try to search it in any loaded modules.
    else {
      for (final module in interpreter.cachedModules.values) {
        for (final nsp in module.namespaces.values) {
          if (nsp.fullName == key) {
            return nsp;
          }
        }
      }
    }

    // If the source has not been evaled at all, then we have to load the source dynamically.
    final source = sourceContext.getResource(key);
    final bytes = _compileSource(source);
    final HTContext savedContext = interpreter.getContext();

    interpreter.loadBytecode(bytes: bytes, module: key);

    final nsp = interpreter.currentBytecodeModule.namespaces.values.last;
    interpreter.setContext(savedContext);
    return nsp;
  }

  /// Get the documentational comment of an identifier within the soruce code.
  String? help(dynamic id, {String? module}) =>
      interpreter.help(id, module: module);

  /// Add a declaration to certain namespace.
  void define(
    String id,
    dynamic value, {
    bool isMutable = false,
    bool override = false,
    bool throws = true,
    String? module,
  }) =>
      interpreter.define(
        id,
        value,
        isMutable: isMutable,
        override: override,
        throws: throws,
        module: module,
      );

  /// Get a variable defined in a certain namespace in the interpreter.
  dynamic fetch(
    String id, {
    String? namespace,
    String? module,
    bool ignoreUndefined = false,
  }) =>
      interpreter.fetch(
        id,
        namespace: namespace,
        module: module,
        ignoreUndefined: ignoreUndefined,
      );

  /// Assign value to a top level variable defined in a certain namespace in the interpreter.
  void assign(
    String id,
    dynamic value, {
    String? namespace,
    String? module,
    bool defineIfAbsent = false,
  }) =>
      interpreter.assign(
        id,
        value,
        namespace: namespace,
        module: module,
        defineIfAbsent: defineIfAbsent,
      );

  /// Invoke a top level function defined in a certain namespace in the interpreter.
  dynamic invoke(
    String func, {
    bool ignoreUndefined = false,
    String? namespace,
    String? module,
    List<dynamic> positionalArgs = const [],
    Map<String, dynamic> namedArgs = const {},
    // List<HTType> typeArgs = const [],
  }) =>
      interpreter.invoke(
        func,
        ignoreUndefined: ignoreUndefined,
        namespace: namespace,
        module: module,
        positionalArgs: positionalArgs,
        namedArgs: namedArgs,
        // typeArgs: typeArgs,
      );
}
