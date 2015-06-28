library test.messageinterested;

import 'package:unittest/unittest.dart' as unit;
import 'package:hetimatorrent/hetimatorrent.dart';
import 'package:hetimacore/hetimacore.dart';
import 'dart:convert' as convert;

void main() {

  ArrayBuilder builder = new ArrayBuilder();
  builder.appendIntList(ByteOrder.parseIntByte(1, ByteOrder.BYTEORDER_BIG_ENDIAN));
  builder.appendByte(2);

  unit.group('A group of tests', () {
    unit.test("decode/encode", () {
      EasyParser parser = new EasyParser(builder);
      return MessageInterested.decode(parser).then((MessageInterested message) {
        return message.encode();
      }).then((List<int> data) {
        unit.expect(builder.toList(), data);
      });
    });


    unit.test("encode", () {
      MessageInterested message = new MessageInterested();
      message.encode().then((List<int> data) {
        unit.expect(builder.toList(), data);
      });
    });

    unit.test("error", () {
      ArrayBuilder b = new ArrayBuilder.fromList(builder.toList().sublist(0,builder.size()-1));
      b.fin();
      EasyParser parser = new EasyParser(b);

      MessageInterested.decode(parser).then((_) {
        unit.expect(true,false);
      }).catchError((e){
        unit.expect(true,true);
      });
    });
  });
}