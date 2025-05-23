import 'package:test/test.dart';
import 'package:hetu_script/hetu_script.dart';

void main() {
  final hetu = Hetu(
    config: HetuConfig(
      printPerformanceStatistics: false,
    ),
  );
  hetu.init();

  group('type -', () {
    test('type is operator', () {
      final result = hetu.eval(r'''
        '' is! string
      ''');
      expect(
        result,
        false,
      );
    });

    test('extends', () {
      final result = hetu.eval(r'''
        class Super2 {
          var name = 'Super'
        }
        class Extend2 extends Super2 {
          var name = 'Extend'
        }
        var a = Extend2()
        a is Super2
      ''');
      expect(
        result,
        true,
      );
    });
    // test('arguments', () {
    //   final result = hetu.eval(r'''
    //     function functionAssign1 {
    //       function convert(n) -> number {
    //         return number.parse(n)
    //       }
    //       const a: function (number) -> number = convert
    //       return a.valueType.toString()
    //     }
    //   ''', invoke: 'functionAssign1');
    //   expect(
    //     result,
    //     'function(any) -> number',
    //   );
    // });
    // test('return type', () {
    //   final result = hetu.eval(r'''
    //     function functionAssign2 {
    //       var a: function (number) -> number = function (n: any) -> number { return n }
    //       return a.valueType.toString()
    //     }
    //   ''', invoke: 'functionAssign2');
    //   expect(
    //     result,
    //     'function(any) -> number',
    //   );
    // });
    test('function type', () {
      final result = hetu.eval(r'''
        var numparse: (string) -> number = function (value: string) -> number { return number.parse(value) }
        var getType = function { typeof numparse }
        var functype2 = getType()
        var strlength: functype2 = function (value: string) -> number { return value.length }
        strlength('hello world')
      ''');
      expect(
        result,
        11,
      );
    });
    test('type alias class', () {
      final result = hetu.eval(r'''
        class A {
          var name: string
          constructor (name: string) {
            this.name = name
          }
        }
        type Alias = A
        var aa = Alias('jimmy')
        aa.name
      ''');
      expect(
        result,
        'jimmy',
      );
    });
    test('type alias function', () {
      final result = hetu.eval(r'''
        type MyFuncType = (number, number) -> number
        var func: MyFuncType = function add(a: number, b: number) -> number => a + b
        func(6, 7)
      ''');
      expect(
        result,
        13,
      );
    });
    test('structural type', () {
      final result = hetu.eval(r'''
        type ObjType = {
          name: string,
          greeting: () -> any,
        }
        var aObj: {} = {
          name: 'jimmy',
          greeting: () {
            print('hi! I\'m ${this.name}')
          }
        }
        aObj is ObjType
      ''');
      expect(
        result,
        true,
      );
    });
    test('type in expression', () {
      final result = hetu.eval(r'''
        function checkType(t: type) {
          switch (t) {
            typeval {} : 'a structural type'
            // the function won't match here
            // you have to use the exact type value here for match
            typeval ()->any : 'a function type'
          }
        }
        checkType(typeof () {})
      ''');
      expect(
        result,
        'a function type',
      );
    });
  });
}
