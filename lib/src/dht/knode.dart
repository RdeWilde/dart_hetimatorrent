library hetimatorrent.dht.knode;

import 'dart:core';
import 'dart:async';
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimanet/hetimanet.dart';
import 'krootingtable.dart';

import 'message/krpcping.dart';
import 'message/krpcfindnode.dart';
import 'message/krpcgetpeers.dart';
import 'kid.dart';
import 'dart:convert';
import '../util/shufflelinkedlist.dart';

import 'message/krpcmessage.dart';
import 'message/krpcping.dart';
import 'message/krpcfindnode.dart';
import 'message/krpcgetpeers.dart';
import 'message/krpcannounce.dart';
import 'kpeerinfo.dart';
import 'ai/knodeai.dart';

class KNode extends Object with KrpcResponseInfo {
  HetiSocketBuilder _socketBuilder = null;
  HetiUdpSocket _udpSocket = null;
  KRootingTable _rootingtable = null;
  Map<String, EasyParser> buffers = {};
  KId _nodeId = null;
  KId get nodeId => _nodeId;
  List<SendInfo> queryInfo = [];
  KNodeAI _ai = null;

  KRootingTable get rootingtable => _rootingtable;
  KNodeAI get ai => _ai;

  KNode(HetiSocketBuilder socketBuilder, {int kBucketSize: 8, List<int> nodeIdAsList: null, KNodeAI ai: null}) {
    if (nodeIdAsList == null) {
      _nodeId = KId.createIDAtRandom();
    } else {
      _nodeId = new KId(nodeIdAsList);
    }
    this._socketBuilder = socketBuilder;
    this._rootingtable = new KRootingTable(kBucketSize, _nodeId);
    if (ai == null) {
      this._ai = new KNodeAI();
    } else {
      this._ai = ai;
    }
  }

  addKPeerInfo(KPeerInfo info) {
    _rootingtable.update(info);
  }

  Future start({String ip: "0.0.0.0", int port: 28080}) {
    return new Future(() {
      if (_udpSocket != null) {
        throw {};
      }
      _udpSocket = this._socketBuilder.createUdpClient();
      return _udpSocket.bind(ip, port).then((int v) {
        _udpSocket.onReceive().listen((HetiReceiveUdpInfo info) {
          if (!buffers.containsKey("${info.remoteAddress}:${info.remotePort}")) {
            buffers["${info.remoteAddress}:${info.remotePort}"] = new EasyParser(new ArrayBuilder());
          }
          EasyParser parser = buffers["${info.remoteAddress}:${info.remotePort}"];

          //
          //
          (parser.buffer as ArrayBuilder).appendIntList(info.data);
          KrpcMessage.decode(parser, this).then((KrpcMessage message) {
            if (message is KrpcResponse) {
              SendInfo rm = removeQueryNameFromTransactionId(UTF8.decode(message.rawMessageMap["t"]));
              _onReceiveResponse(info, message);
              rm._c.complete(message);
            } else if (message is KrpcQuery) {
              _onReceiveQuery(info, message);
            } else if (message is KrpcError) {
              _onReceiveError(info, message);
            } else {
              _onReceiveUnknown(info, message);
            }
          }).catchError((e) {
            parser.last();
          });
          //
        });
        //////
        //////
        _ai.start(this);
      });
    });
  }

  updatePeer() {
    this._ai.maintenance(this);
  }
  _onReceiveQuery(HetiReceiveUdpInfo info, KrpcQuery message) {
    this._ai.onReceiveQuery(this, info, message);
  }
  _onReceiveResponse(HetiReceiveUdpInfo info, KrpcResponse message) {
    this._ai.onReceiveResponse(this, info, message);
  }
  _onReceiveError(HetiReceiveUdpInfo info, KrpcError message) {
    this._ai.onReceiveError(this, info, message);
  }
  _onReceiveUnknown(HetiReceiveUdpInfo info, KrpcMessage message) {
    this._ai.onReceiveUnknown(this, info, message);
  }

  String getQueryNameFromTransactionId(String transactionId) {
    for (SendInfo si in queryInfo) {
      if (si._id == transactionId) {
        return si._act;
      }
    }
    return "";
  }
  SendInfo removeQueryNameFromTransactionId(String transactionId) {
    SendInfo re = null;
    for (SendInfo si in queryInfo) {
      if (si._id == transactionId) {
        re = si;
        break;
      }
    }
    queryInfo.remove(re);
    return re;
  }
  static int id = 0;
  Future _sendQuery(String ip, int port, KrpcQuery message) {
    Completer c = new Completer();
    new Future(() {
      queryInfo.add(new SendInfo(message.transactionIdAsString, message.q, c));
      return _udpSocket.send(message.messageAsBencode, ip, port);
    }).catchError(c.completeError);
    return c.future;
  }

  Future sendPingQuery(String ip, int port) {
    KrpcPingQuery query = new KrpcPingQuery(UTF8.encode("p_${id++}"), _nodeId.id);
    return _sendQuery(ip, port, query);
  }

  Future sendFindNodeQuery(String ip, int port, List<int> targetNodeId) {
    KrpcFindNodeQuery query = new KrpcFindNodeQuery(UTF8.encode("p_${id++}"), _nodeId.id, targetNodeId);
    return _sendQuery(ip, port, query);
  }

  Future sendGetPeersQuery(String ip, int port, List<int> infoHash) {
    KrpcGetPeersQuery query = new KrpcGetPeersQuery(UTF8.encode("p_${id++}"), _nodeId.id, infoHash);
    return _sendQuery(ip, port, query);
  }

  Future sendAnnouncePeerQuery(String ip, int port, int implied_port, List<int> infoHash, List<int> opaqueToken) {
    KrpcAnnouncePeerQuery query = new KrpcAnnouncePeerQuery(UTF8.encode("p_${id++}"), _nodeId.id, implied_port, infoHash, port, opaqueToken);
    return _sendQuery(ip, port, query);
  }

  Future sendPingResponse(String ip, int port, List<int> transactionId) {
    KrpcPingResponse response = new KrpcPingResponse(transactionId, _nodeId.id);
    return _udpSocket.send(response.messageAsBencode, ip, port);
  }

  Future sendFindNodeResponse(String ip, int port, List<int> transactionId, List<int> compactNodeInfo) {
    KrpcFindNodeResponse query = new KrpcFindNodeResponse(transactionId, this._nodeId.id, compactNodeInfo);
    return _udpSocket.send(query.messageAsBencode, ip, port);
  }

  Future sendGetPeersResponseWithClosestNodes(String ip, int port, List<int> transactionId, List<int> opaqueWriteToken, List<int> compactNodeInfo) {
    KrpcGetPeersResponse query = new KrpcGetPeersResponse.withClosestNodes(transactionId, this._nodeId.id, opaqueWriteToken, compactNodeInfo);
    return _udpSocket.send(query.messageAsBencode, ip, port);
  }

  Future sendGetPeersResponseWithPeers(String ip, int port, List<int> transactionId, List<int> opaqueWriteToken, List<List<int>> peerInfoStrings) {
    KrpcGetPeersResponse query = new KrpcGetPeersResponse.withPeers(transactionId, this._nodeId.id, opaqueWriteToken, peerInfoStrings);
    return _udpSocket.send(query.messageAsBencode, ip, port);
  }

  Future sendAnnouncePeerResponse(String ip, int port, List<int> transactionId) {
    KrpcAnnouncePeerResponse query = new KrpcAnnouncePeerResponse(transactionId, this._nodeId.id);
    return _udpSocket.send(query.messageAsBencode, ip, port);
  }

  Future sendErrorResponse(String ip, int port, int errorCode, List<int> transactionId, [String errorDescription = null]) {
    KrpcError query = new KrpcError(transactionId, errorCode);
    return _udpSocket.send(query.messageAsBencode, ip, port);
  }

  Future stop() {
    return new Future(() {
      if (_udpSocket == null) {
        return null;
      } else {
        return _udpSocket.close();
      }
    }).whenComplete(() {
      _ai.stop(this);
    });
  }
}


class SendInfo {
  String _id = "";
  String get id => _id;
  String _act = "";
  String get act => _act;

  int _time = 0;
  int get time => _time;

  Completer _c = null;
  SendInfo(String id, String act, Completer c) {
    this._id = id;
    this._c = c;
    this._act = act;
    this._time = new DateTime.now().millisecondsSinceEpoch;
  }
}
