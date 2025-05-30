import '../../error/error.dart';
import '../../interpreter/interpreter.dart';
import '../../type/type.dart';
import '../../type/nominal.dart';
import '../class/class.dart';
import '../object.dart';
import 'instance.dart';

/// The implementation of a certain type cast of a object
class HTCast with HTObject, InterpreterRef {
  @override
  final HTNominalType valueType;

  final HTClass klass;

  late final HTInstance object;

  @override
  String toString() => object.toString();

  HTCast(HTObject castee, this.klass, HTInterpreter interpreter,
      {List<HTType> typeArgs = const []})
      : valueType = HTNominalType(klass: klass, typeArgs: typeArgs) {
    this.interpreter = interpreter;
    // final extended = <HTType>[];

    // HTClass? curSuper = klass;
    // var superClassType = HTType(klass.id, typeArgs: typeArgs);
    // while (curSuper != null) {
    // extended.add(superClassType);
    // curSuper = curSuper.superClass;
    // if (curSuper?.extendedType != null) {
    //   extended.add(curSuper!.extendedType!);
    // }
    // }
    if (castee.valueType?.isNotA(valueType) ?? true) {
      throw HTError.typeCast(interpreter.lexicon.stringify(castee.valueType),
          interpreter.lexicon.stringify(valueType));
    }

    if (castee is HTInstance) {
      object = castee;
    } else if (castee is HTCast) {
      object = castee.object;
    } else {
      throw HTError.castee(interpreter.stack.localSymbol!);
    }
  }

  @override
  dynamic memberGet(String id,
          {String? from,
          bool isRecursive = false,
          bool ignoreUndefined = false}) =>
      object.memberGet(id,
          cast: klass.id, from: from, ignoreUndefined: ignoreUndefined);

  @override
  void memberSet(String id, dynamic value,
          {String? from, bool defineIfAbsent = false}) =>
      object.memberSet(id, value, cast: klass.id, from: from);
}
