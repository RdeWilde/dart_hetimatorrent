library test.messagebitfield;

import 'package:unittest/unittest.dart' as unit;
import 'package:hetimatorrent/hetimatorrent.dart';
import 'package:hetimacore/hetimacore.dart';
import 'dart:convert' as convert;

void main() {

  ArrayBuilder builder = new ArrayBuilder();
  List<int> bitfield = [0xf0,0xff,0x0f];
  builder.appendIntList(ByteOrder.parseIntByte(bitfield.length+1,ByteOrder.BYTEORDER_BIG_ENDIAN));
  builder.appendByte(5);
  builder.appendIntList(bitfield);

  unit.group('A group of tests', () {
    unit.test("decode/encode", () {
      EasyParser parser = new EasyParser(builder);
      return MessageBitfield.decode(parser).then((MessageBitfield message) {
        unit.expect(message.bitfield, bitfield);//message.
        return message.encode();
      }).then((List<int> data) {
        unit.expect(builder.toList(), data);
      });
    });

    unit.test("encode", () {
      EasyParser parser = new EasyParser(builder);
      MessageBitfield message = new MessageBitfield([0xf0,0xff,0x0f]);
      message.encode().then((List<int> data) {
        unit.expect(builder.toList(), data);
      });
    });
    unit.test("error", () {
      ArrayBuilder b = new ArrayBuilder.fromList(builder.toList().sublist(0,builder.size()-1));
      b.fin();
      EasyParser parser = new EasyParser(b);

      MessageHandshake.decode(parser).then((_) {
        unit.expect(true,false);
      }).catchError((e){
        unit.expect(true,true);
      });
    });
  });
}
