library test.messagechoke;

import 'package:unittest/unittest.dart' as unit;
import 'package:hetimatorrent/hetimatorrent.dart';
import 'package:hetimacore/hetimacore.dart';
import 'dart:convert' as convert;

void main() {
  ArrayBuilder builder = new ArrayBuilder();
  builder.appendIntList(ByteOrder.parseIntByte(1, ByteOrder.BYTEORDER_BIG_ENDIAN));
  builder.appendByte(0);

  unit.group('A group of tests', () {
    unit.test("decode/encode", () {
      EasyParser parser = new EasyParser(builder);
      return TMessageChoke.decode(parser).then((TMessageChoke message) {
        return message.encode();
      }).then((List<int> data) {
        unit.expect(builder.toList(), data);
      });
    });

    unit.test("encode", () {
      TMessageChoke message = new TMessageChoke();
      message.encode().then((List<int> data) {
        unit.expect(builder.toList(), data);
      });
    });

    unit.test("error", () async {
      ArrayBuilder b = new ArrayBuilder.fromList(builder.toList().sublist(0, builder.size() - 1));
      b.fin();
      EasyParser parser = new EasyParser(b);

      bool isOk = false;
      try {
        await TMessageChoke.decode(parser);
      } catch (e) {
        isOk = true;
      }
      unit.expect(isOk, true);
    });
  });
}
