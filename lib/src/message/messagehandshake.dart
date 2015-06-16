library hetimatorrent.message.handshake;

import 'dart:core';
import 'dart:async';
import 'dart:convert';
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimanet/hetimanet.dart';


class MessageHandshake {
  static final List<int> RESERVED = new List.from([0, 0, 0, 0, 0, 0, 0, 0], growable: false);
  static final List<int> ProtocolId = new List.from(UTF8.encode("BitTorrent protocol"), growable: false); //19byte

  List<int> _mProtocolId = []; //19byte
  List<int> _mInfoHash = []; //20byte
  List<int> _mPeerID = []; //20byte
  List<int> _mReserved = []; //8byte

  List<int> get protocolId => new List.from(_mProtocolId, growable: false);
  List<int> get reserved => new List.from(_mReserved, growable: false);

  List<int> get infoHash => new List.from(_mInfoHash, growable: false);
  List<int> get peerId => new List.from(_mPeerID, growable: false);

  static Future<MessageHandshake> decode(EasyParser parser) {
    Completer c = new Completer();
    MessageHandshake mesHandshake = new MessageHandshake();
    parser.push();
    parser.readByte().then((int size) {
      if (!(0 <= size && size <= 256)) {
        throw {};
      }
      return parser.nextBuffer(size);
    }).then((List<int> id) {
      mesHandshake._mProtocolId.clear();
      mesHandshake._mProtocolId.addAll(id);
      return parser.nextBuffer(8);
    }).then((List<int> reserved) {
      mesHandshake._mReserved.clear();
      mesHandshake._mReserved.addAll(reserved);
      return parser.nextBuffer(20);
    }).then((List<int> infoHash) {
      mesHandshake._mInfoHash.clear();
      mesHandshake._mInfoHash.addAll(infoHash);
      return parser.nextBuffer(20);
    }).then((List<int> peerId) {
      mesHandshake._mPeerID.clear();
      mesHandshake._mPeerID.addAll(peerId);
      parser.pop();
      c.complete(mesHandshake);
    }).catchError((e) {
      parser.back();
      parser.pop();
      c.completeError(e);
    });
    return c.future;
  }
  
  Future<List<int>> encode() {
    return new Future((){
      ArrayBuilder builder = new ArrayBuilder();
      builder.appendByte(_mProtocolId.length);
      builder.appendIntList(_mProtocolId, 0, _mProtocolId.length);
      builder.appendIntList(_mReserved, 0, _mReserved.length);
      builder.appendIntList(_mInfoHash, 0, _mInfoHash.length);
      builder.appendIntList(_mPeerID, 0, _mPeerID.length);
      return builder.toList();
    });
  }

  
}
