library hetimatorrent.message.piece;

import 'dart:core';
import 'dart:async';
import 'package:hetimacore/hetimacore.dart';
import 'torrentmessage.dart';
import 'dart:typed_data';

class TMessagePiece extends TorrentMessage {
  int _mIndex = 0;
  int _mBegin = 0;
  int _mLength = 0;
  Uint8List _mContent = null;

  int get index => _mIndex;
  int get begin => _mBegin;
  int get length => _mLength;
  List<int> get content => _mContent.sublist(0, _mLength);
  List<int> get rawcontent => _mContent;

  TMessagePiece._empty() : super(TorrentMessage.SIGN_PIECE) {}

  TMessagePiece(int index, int begin, List<int> content, [int length = null]) : super(TorrentMessage.SIGN_PIECE) {
    this._mIndex = index;
    this._mBegin = begin;
    this._mContent = new Uint8List.fromList(content);
    if(length != null) {
      this._mLength = length;
    } else {
      this._mLength = content.length;      
    }
  }

  static Future<TMessagePiece> decode(EasyParser parser,{List<int> buffer: null, List<int> pieceBuffer:null}) async {
    List<int> outLength = [0];
    TMessagePiece message = new TMessagePiece._empty();
    parser.push();
    try {
      int messageLength = await parser.readInt(ByteOrder.BYTEORDER_BIG_ENDIAN, buffer:buffer, outLength:outLength);
      if (messageLength < 9) {
        throw {};
      }
      int vv = await parser.readByte(buffer:buffer, outLength:outLength);
      if (vv != TorrentMessage.SIGN_PIECE) {
        throw {};
      }
      message._mIndex = await parser.readInt(ByteOrder.BYTEORDER_BIG_ENDIAN, buffer:buffer, outLength:outLength);
      message._mBegin = await parser.readInt(ByteOrder.BYTEORDER_BIG_ENDIAN, buffer:buffer, outLength:outLength);
      List<int> c = await parser.nextBuffer(messageLength - 9, buffer:buffer, outLength:outLength);
      if(outLength[0] != messageLength - 9) {
        throw {};
      }
      message._mLength = outLength[0];
      if(pieceBuffer == null) {
        message._mContent = new Uint8List.fromList(c.sublist(0, messageLength - 9));
      } else {
        message._mContent = pieceBuffer;
        for(int i=0;i<message._mLength;i++) {
          pieceBuffer[i] = c[i];
        }
      }
      parser.pop();
      return message;
    } catch (e) {
      parser.back();
      parser.pop();
      throw e;
    }
  }

  Future<List<int>> encode() async {
    ArrayBuilder builder = new ArrayBuilder();
    builder.appendIntList(ByteOrder.parseIntByte(1 + 4 * 2 + _mContent.length, ByteOrder.BYTEORDER_BIG_ENDIAN));
    builder.appendByte(id);
    builder.appendIntList(ByteOrder.parseIntByte(_mIndex, ByteOrder.BYTEORDER_BIG_ENDIAN));
    builder.appendIntList(ByteOrder.parseIntByte(_mBegin, ByteOrder.BYTEORDER_BIG_ENDIAN));
    builder.appendIntList(_mContent);
    return builder.toList();
  }

  String toString() {
    return "${TorrentMessage.toText(id)}: ${_mIndex} ${_mBegin} contLen=${_mContent.length}";
  }
}
