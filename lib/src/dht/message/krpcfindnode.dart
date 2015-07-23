library hetimatorrent.dht.krpcfindnode;

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

class KrpcFindNodeQuery extends KrpcQuery {
  //find_node Query = {"t":"aa", "y":"q", "q":"find_node", "a": {"id":"abcdefghij0123456789", "target":"mnopqrstuvwxyz123456"}}
  //bencoded = d1:ad2:id20:abcdefghij01234567896:target20:mnopqrstuvwxyz123456e1:q9:find_node1:t2:aa1:y1:qe
  KrpcFindNodeQuery.fromString(String transactionIdAsString, String queryingNodesIdAsString, String targetNodeIdAsString) {
    List<int> transactionId = UTF8.encode(transactionIdAsString);
    List<int> queryingNodesId = UTF8.encode(queryingNodesIdAsString);
    List<int> targetNodeId = UTF8.encode(targetNodeIdAsString);
    _init(transactionId, queryingNodesId, targetNodeId);
  }

  KrpcFindNodeQuery(List<int> transactionId, List<int> queryingNodesId, List<int> targetNodeId) {}
  _init(List<int> transactionId, List<int> queryingNodesId, List<int> targetNodeId) {
    if (transactionId is Uint8List) {
      transactionId = new Uint8List.fromList(transactionId);
    }
    if (queryingNodesId is Uint8List) {
      queryingNodesId = new Uint8List.fromList(queryingNodesId);
    }
    if (targetNodeId is Uint8List) {
      targetNodeId = new Uint8List.fromList(targetNodeId);
    }
    rawMessageMap.addAll({"a": {"id": queryingNodesId, "target": targetNodeId}, "q": "find_node", "t": transactionId, "y": "q"});
  }

  KrpcFindNodeQuery.fromMap(Map<String, Object> messageAsMap) {
    if (!KrpcQuery.queryCheck(messageAsMap, "find_node")) {
      throw {};
    }
    Map<String, Object> a = messageAsMap["a"];
    rawMessageMap.addAll({"a": {"id": a["id"], "target": a["target"]}, "q": "find_node", "t": messageAsMap["t"], "y": "q"});
  }

  static Future<KrpcFindNodeQuery> decode(EasyParser parser) {
    return KrpcMessage.decodeTest(parser, (Object v) {
      return new KrpcFindNodeQuery.fromMap(v);
    });
  }
}

class KrpcFindNodeResponse extends KrpcResponse {

  // Response with peers = {"t":"aa", "y":"r", "r": {"id":"abcdefghij0123456789", "token":"aoeusnth", "values": ["axje.u", "idhtnm"]}}
  // bencoded = d1:rd2:id20:abcdefghij01234567895:token8:aoeusnth6:valuesl6:axje.u6:idhtnmee1:t2:aa1:y1:re
  KrpcFindNodeResponse.fromString(String transactionIdAsString, String queryingNodesIdAsString, List<int> compactNodeInfo) {
    List<int> transactionId = UTF8.encode(transactionIdAsString);
    List<int> queryingNodesId = UTF8.encode(queryingNodesIdAsString);
    _init(transactionId, queryingNodesId, compactNodeInfo);
  }
  
  KrpcFindNodeResponse(List<int> transactionId, List<int> queryingNodesId, List<int> compactNodeInfo) {
    if (!(transactionId is Uint8List)) {
      transactionId = new Uint8List.fromList(transactionId);
    }
    if (!(queryingNodesId is Uint8List)) {
      queryingNodesId = new Uint8List.fromList(queryingNodesId);
    }
    if (!(compactNodeInfo is Uint8List)) {
      compactNodeInfo = new Uint8List.fromList(compactNodeInfo);
    }
    _init(transactionId, queryingNodesId, compactNodeInfo);
  }

  _init(List<int> transactionId, List<int> queryingNodesId, List<int> compactNodeInfo) {
    rawMessageMap.addAll({"r": {"id": queryingNodesId, "nodes": compactNodeInfo}, "t": transactionId, "y": "r"});
  }

  KrpcFindNodeResponse.fromMap(Map<String, Object> messageAsMap) {
    if (!KrpcResponse.queryCheck(messageAsMap)) {
      throw {};
    }
    Map<String, Object> r = messageAsMap["r"];
    rawMessageMap.addAll({"r": {"id": r["id"], "nodes": r["nodes"]}, "t": messageAsMap["t"], "y": "r"});
  }

  static Future<KrpcFindNodeResponse> decode(EasyParser parser) {
    return KrpcMessage.decodeTest(parser, (Object v) {
      return new KrpcFindNodeResponse.fromMap(v);
    });
  }
}
