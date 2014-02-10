import 'package:unittest/unittest.dart';
import 'package:preprocessor/preprocessor.dart';

void _test(name, defines, data, expected, [type = 'js']){
  test(name,(){
    Preprocessor p = new Preprocessor(type);
    p.process(defines, data)
      .then(expectAsync((String result){
          expect(result.trim(),expected);
        }), onError: (err) => expect(true, isFalse, reason:err)
       );

  });
}

void main(){
  Preprocessor p = new Preprocessor('js');
  p.process({ 'DEV': true },"test(/*#val value*/0);")
    .then((_){
      _test('if DEV, multiline comment, DEV is true',
          { 'DEV': true },
          "/*#if DEV*/alert('test');\n/*#endif*/",
          "alert('test');");

      _test('if DEV, single comment line, DEV is false',
          { 'DEV': false },
          "//#if DEV\nalert('test');\n/*#endif*/",
          "");

      _test('if then, true',
          { 'DEV': true },
          "var test = 1/*#if DEV then 00*/",
          "var test = 100");

      _test('if then, false',
          { 'DEV': false },
          "var test = 1/*#if DEV then 00*/;",
          "var test = 1;");

      _test('val',
          { 'value': 1 },
          "test(/*#val value*/0);",
          "test(1);");

    });
}