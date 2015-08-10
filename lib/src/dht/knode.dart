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
import 'message/krpcannounce.dart';
import 'kpeerinfo.dart';
import 'message/kgetpeervalue.dart';
import 'ai/knodeai.dart';
import 'ai/knodeaibasic.dart';

class KNode extends Object with KrpcResponseInfo {
  HetiSocketBuilder _socketBuilder = null;
  HetiUdpSocket _udpSocket = null;
  HetiUdpSocket get rawUdoSocket => _udpSocket;
  KRootingTable _rootingtable = null;
  Map<String, EasyParser> buffers = {};
  KId _nodeId = null;
  KId get nodeId => _nodeId;
  List<KSendInfo> queryInfo = [];
  KNodeAI _ai = null;
  bool _isStart = false;
  bool get isStart => _isStart;

  KRootingTable get rootingtable => _rootingtable;
  KNodeAI get ai => _ai;
  ShuffleLinkedList<KGetPeerValue> _announced = new ShuffleLinkedList(300);
  ShuffleLinkedList<KGetPeerValue> _searcResult = new ShuffleLinkedList(300);
  List<KGetPeerValue> get announcedPeer => _announced.sequential;
  ShuffleLinkedList<KGetPeerValue> get rawSearchResult => _searcResult;
  ShuffleLinkedList<KGetPeerValue> get rawAnnounced => _announced;
  static int id = 0;

  StreamController<KGetPeerValue> _controller = new StreamController.broadcast();
  Stream<KGetPeerValue> get onGetPeerValue => _controller.stream;
  int _nodeDebugId = 0;
  int get nodeDebugId => _nodeDebugId;

  int _intervalSecondForMaintenance = 5;
  int get intervalSecondForMaintenance => _intervalSecondForMaintenance;

  int _intervalSecondForAnnounce = 60;
  int get intervalSecondForAnnounce => _intervalSecondForAnnounce;

  bool _verbose = false;
  bool get verbose => _verbose;

  KNode(HetiSocketBuilder socketBuilder,
      {int kBucketSize: 8, List<int> nodeIdAsList: null, KNodeAI ai: null, 
        intervalSecondForMaintenance: 10, intervalSecondForAnnounce: 3 * 60, bool verbose: false}) {
    this._verbose = verbose;
    this._intervalSecondForMaintenance = intervalSecondForMaintenance;
    this._intervalSecondForAnnounce = intervalSecondForAnnounce;
    this._nodeId = (nodeIdAsList == null ? KId.createIDAtRandom() : new KId(nodeIdAsList));
    this._socketBuilder = socketBuilder;
    this._rootingtable = new KRootingTable(kBucketSize, _nodeId);
    this._ai = (ai == null ? new KNodeAIBasic(verbose: verbose) : ai);
    this._nodeDebugId = id++;
  }

  Future start({String ip: "0.0.0.0", int port: 28080}) {
    return new Future(() {
      if (_isStart) {
        throw {};
      }
      _udpSocket = this._socketBuilder.createUdpClient();
      return _udpSocket.bind(ip, port, multicast: true).then((int v) {
        _udpSocket.onReceive().listen((HetiReceiveUdpInfo info) {
          if (!buffers.containsKey("${info.remoteAddress}:${info.remotePort}")) {
            buffers["${info.remoteAddress}:${info.remotePort}"] = new EasyParser(new ArrayBuilder());
            _ai.startParseLoop(this, buffers["${info.remoteAddress}:${info.remotePort}"], info, "${info.remoteAddress}:${info.remotePort}");
          }
          EasyParser parser = buffers["${info.remoteAddress}:${info.remotePort}"];
          (parser.buffer as ArrayBuilder).appendIntList(info.data);
        });

        //////
        _isStart = true;
        _ai.start(this);
        ai.startTick(this);
      });
    }).catchError((e) {
      _isStart = false;
      throw e;
    });
  }

  Future stop() {
    return new Future(() {
      return (_udpSocket == null ? null : _udpSocket.close());
    }).whenComplete(() {
      _isStart = false;
      _ai.stop(this);
    });
  }

  Future startSearchValue(KId infoHash, int port, {getPeerOnly: false}) {
    return new Future(() {
      return this._ai.startSearchValue(this, infoHash, port, getPeerOnly: getPeerOnly);
    });
  }

  Future stopSearchPeer(KId infoHash) {
    return new Future(() {
      return this._ai.stopSearchValue(this, infoHash);
    });
  }

  bool containSeardchResult(KGetPeerValue info) {
    return _searcResult.sequential.contains(info);
  }

  addSeardchResult(KGetPeerValue info) {
    bool c = containSeardchResult(info);
    _searcResult.addLast(info);
    if (c == false) {
      _controller.add(info);
    }
  }

  addKPeerInfo(KPeerInfo info) => _rootingtable.update(info);

  updateP2PNetwork() => this._ai.updateP2PNetwork(this);

  researchSearchPeer([KId infoHash = null]) => this._ai.researchSearchPeer(this, infoHash);

  addBootNode(String ip, int port) => this._ai.onAddNodeFromIPAndPort(this, ip, port);

  List<int> getOpaqueWriteToken(KId infoHash, KId nodeID) => KId.createToken(infoHash, nodeID, this.nodeId);

  String getQueryNameFromTransactionId(String transactionId) {
    for (KSendInfo si in queryInfo) {
      if (si._id == transactionId) {
        return si._act;
      }
    }
    return "";
  }

  KSendInfo removeQueryNameFromTransactionId(String transactionId) {
    KSendInfo re = null;
    for (KSendInfo si in queryInfo) {
      if (si._id == transactionId) {
        re = si;
        break;
      }
    }
    queryInfo.remove(re);
    return re;
  }

  List<KSendInfo> clearTimeout(int timeout) {
    int currentTime = new DateTime.now().millisecondsSinceEpoch;
    List<KSendInfo> ret = [];
    for (KSendInfo si in queryInfo) {
      if (currentTime - si._time > timeout) {
        ret.add(si);
      }
    }
    for (KSendInfo i in ret) {
      queryInfo.remove(i);
    }
    return ret;
  }

  Future sendPingQuery(String ip, int port) => _sendMessage(ip, port, new KrpcPingQuery(UTF8.encode("p_${id++}"), _nodeId.value));

  Future sendFindNodeQuery(String ip, int port, List<int> targetNodeId) => _sendMessage(ip, port, new KrpcFindNodeQuery(UTF8.encode("p_${id++}"), _nodeId.value, targetNodeId));

  Future sendGetPeersQuery(String ip, int port, List<int> infoHash) => _sendMessage(ip, port, new KrpcGetPeersQuery(UTF8.encode("p_${id++}"), _nodeId.value, infoHash));

  Future sendAnnouncePeerQuery(String ip, int port, int implied_port, List<int> infoHash, int announcedPort, List<int> opaqueToken) =>
      _sendMessage(ip, port, new KrpcAnnouncePeerQuery(UTF8.encode("p_${id++}"), _nodeId.value, implied_port, infoHash, announcedPort, opaqueToken));

  Future sendPingResponse(String ip, int port, List<int> transactionId) => _sendMessage(ip, port, new KrpcPingResponse(transactionId, _nodeId.value));

  Future sendFindNodeResponse(String ip, int port, List<int> transactionId, List<int> compactNodeInfo) =>
      _sendMessage(ip, port, new KrpcFindNodeResponse(transactionId, this._nodeId.value, compactNodeInfo));

  Future sendGetPeersResponseWithClosestNodes(String ip, int port, List<int> transactionId, List<int> opaqueWriteToken, List<int> compactNodeInfo) =>
      _sendMessage(ip, port, new KrpcGetPeersResponse.withClosestNodes(transactionId, this._nodeId.value, opaqueWriteToken, compactNodeInfo));

  Future sendGetPeersResponseWithPeers(String ip, int port, List<int> transactionId, List<int> opaqueWriteToken, List<List<int>> peerInfoStrings) =>
      _sendMessage(ip, port, new KrpcGetPeersResponse.withPeers(transactionId, this._nodeId.value, opaqueWriteToken, peerInfoStrings));

  Future sendAnnouncePeerResponse(String ip, int port, List<int> transactionId) => _sendMessage(ip, port, new KrpcAnnouncePeerResponse(transactionId, this._nodeId.value));

  Future sendErrorResponse(String ip, int port, int errorCode, List<int> transactionId, [String errorDescription = null]) => _sendMessage(ip, port, new KrpcError(transactionId, errorCode));

  Future _sendMessage(String ip, int port, KrpcMessage message) {
    Completer c = new Completer();
    new Future(() {
      if (message is KrpcQuery) {
        queryInfo.add(new KSendInfo(message.transactionIdAsString, message.q, c));
      }
      if (_verbose == true) {
        String sign = "null";

        if (message is KrpcError) {
          sign = "error";
        } else if (message is KrpcQuery) {
          sign = "query";
        } else if (message is KrpcResponse) {
          sign = "response";
        }
        print("--->send ${sign}[${_nodeDebugId}] ${ip}:${port} ${message}");
      }
      return _udpSocket.send(message.messageAsBencode, ip, port);
    }).catchError(c.completeError);
    return c.future;
  }
}

class KSendInfo {
  String _id = "";
  String get id => _id;
  String _act = "";
  String get act => _act;

  int _time = 0;
  int get time => _time;

  Completer _c = null;
  Completer get c => _c;
  KSendInfo(String id, String act, Completer c) {
    this._id = id;
    this._c = c;
    this._act = act;
    this._time = new DateTime.now().millisecondsSinceEpoch;
  }
}
