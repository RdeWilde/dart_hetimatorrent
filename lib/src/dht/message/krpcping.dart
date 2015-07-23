library hetimatorrent.dht.krpcping;

import 'dart:core';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../kid.dart';
import '../../util/bencode.dart';
import '../../util/hetibencode.dart';
import 'package:hetimacore/hetimacore.dart';
import 'krpcmessage.dart';
import 'dart:typed_data';

class KrpcPingQuery extends KrpcQuery {
  Map<String, Object> _messageAsMap = null;
  Map<String, Object> get messageAsMap => new Map.from(_messageAsMap);
  List<int> get messageAsBencode => Bencode.encode(_messageAsMap);

/**
 * 
 * transactionId is "t", queryingNodesId is "id"
 * 
 * ping Query = {"t":"aa", "y":"q", "q":"ping", "a":{"id":"abcdefghij0123456789"}}
 * bencoded = d1:ad2:id20:abcdefghij0123456789e1:q4:ping1:t2:aa1:y1:qe
 */
  KrpcPingQuery.fromString(String transactionIdAsString, String queryingNodesIdAsString) {
    List<int> transactionId = UTF8.encode(transactionIdAsString);
    List<int> queryingNodesId = UTF8.encode(queryingNodesIdAsString);
    _messageAsMap = {"a": {"id": queryingNodesId}, "q": "ping", "t": transactionId, "y": "q"};
  }

  KrpcPingQuery(List<int> transactionId, List<int> queryingNodesId) {
    if(transactionId is Uint8List) {
      transactionId = new Uint8List.fromList(transactionId);
    }
    if(queryingNodesId is Uint8List) {
      queryingNodesId = new Uint8List.fromList(queryingNodesId);
    }
    _messageAsMap = {"a": {"id": queryingNodesId}, "q": "ping", "t": transactionId, "y": "q"};
  }

  KrpcPingQuery.fromMap(Map<String, Object> messageAsMap) {
    if (!KrpcQuery.queryCheck(messageAsMap, "ping")) {
      throw {};
    }
    Map<String, Object> a = messageAsMap["a"];
    _messageAsMap = {"a": {"id": a["id"]}, "q": messageAsMap["q"], "t": messageAsMap["t"], "y": messageAsMap["y"]};
  }

  static Future<KrpcPingQuery> decode(EasyParser parser) {
    return KrpcMessage.decodeTest(parser, (Object v) {
      return new KrpcPingQuery.fromMap(v);
    });
  }
}

// Response = {"t":"aa", "y":"r", "r": {"id":"mnopqrstuvwxyz123456"}}
// bencoded = d1:rd2:id20:mnopqrstuvwxyz123456e1:t2:aa1:y1:re
class KrpcPingResponse extends KrpcResponse {
  Map<String, Object> _messageAsMap = null;
  Map<String, Object> get messageAsMap => new Map.from(_messageAsMap);
  List<int> get messageAsBencode => Bencode.encode(_messageAsMap);

  KrpcPingResponse(String transactionId, String queryingNodesId) {
    _messageAsMap = {"r": {"id": queryingNodesId}, "t": transactionId, "y": "r"};
  }

  KrpcPingResponse.fromMap(Map<String, Object> messageAsMap) {
    if (!KrpcResponse.queryCheck(messageAsMap)) {
      throw {};
    }
    Map<String, Object> r = messageAsMap["r"];
    _messageAsMap = {"r": {"id": r["id"]}, "t": messageAsMap["t"], "y": messageAsMap["y"]};
  }

  static Future<KrpcPingResponse> decode(EasyParser parser) {
    return KrpcMessage.decodeTest(parser, (Object v) {
      return new KrpcPingResponse.fromMap(v);
    });
  }
}
