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

class KNode {
  HetiSocketBuilder _socketBuilder = null;
  HetiUdpSocket _udpSocket = null;
  KRootingTable _rootingtable = null;
  Map<String, EasyParser> buffers = {};
  KId _nodeId = null;
  KId get nodeId => _nodeId;
  List<SendInfo> queryInfo = [];

  KNode(HetiSocketBuilder socketBuilder, {int kBucketSize: 8, List<int> nodeIdAsList: null}) {
    if (nodeIdAsList == null) {
      _nodeId = KId.createIDAtRandom();
    } else {
      _nodeId = new KId(nodeIdAsList);
    }
    this._socketBuilder = socketBuilder;
    this._rootingtable = new KRootingTable(kBucketSize);
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
          
        });
      });
    });
  }

  static int id = 0;
  Future sendPing(String ip, int port) {
    Completer c;
    new Future(() {
      KrpcPingQuery query = new KrpcPingQuery(UTF8.encode("p_${id}"), _nodeId.id);
      queryInfo.add(new SendInfo ("p_${id}", c));
      return _udpSocket.send(query.messageAsBencode, ip, port);
    }).catchError(c.completeError);
    return c.future;
  }

  Future sendFindNode() {}

  Future sendGetPeers() {}

  Future stop() {
    return new Future(() {
      if (_udpSocket == null) {
        return null;
      }
      return _udpSocket.close();
    });
  }
}

class SendInfo {
  String _id = "";
  String get id => _id;

  int _time = 0;
  int get time => _time;

  Completer _c = null;
  SendInfo(String id, Completer c) {
    this._id = id;
    this._c = c;
    this._time = new DateTime.now().millisecondsSinceEpoch;
  }
}
