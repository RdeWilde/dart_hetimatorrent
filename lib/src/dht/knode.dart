library hetimatorrent.dht.knode;

import 'dart:core';
import 'dart:async';
import 'package:hetimanet/hetimanet.dart';
import 'krootingtable.dart';

import 'kid.dart';
import 'dart:convert';
import '../util/shufflelinkedlist.dart';
import 'message/krpcmessage.dart';
import 'message/krpcmessage_announce.dart';
import 'message/krpcmessage_ping.dart';
import 'message/krpcmessage_findnode.dart';
import 'message/krpcmessage_getpeers.dart';
import 'message/krpcmessage_error.dart';
import 'kpeerinfo.dart';
import 'kgetpeervalue.dart';
import 'work/knodework.dart';
import 'work/knodework_basic.dart';

class KNode extends Object {
  HetimaSocketBuilder _socketBuilder = null;
  HetimaUdpSocket _udpSocket = null;
  HetimaUdpSocket get rawUdoSocket => _udpSocket;

  KRootingTable _rootingtable = null;
  KRootingTable get rootingtable => _rootingtable;

  KId _nodeId = null;
  KId get nodeId => _nodeId;

  bool _isStart = false;
  bool get isStart => _isStart;

  ShuffleLinkedList<KGetPeerValue> _announced = new ShuffleLinkedList(300);
  List<KGetPeerValue> get announcedPeer => _announced.sequential;
  ShuffleLinkedList<KGetPeerValue> get rawAnnounced => _announced;

  ShuffleLinkedList<KGetPeerValue> _searcResult = new ShuffleLinkedList(300);
  ShuffleLinkedList<KGetPeerValue> get rawSearchResult => _searcResult;

  static int id = 0;

  List<KSendInfo> queryInfo = [];
  KNodeWork _ai = null;
  KNodeWork get ai => _ai;

  StreamController<KGetPeerValue> _controller = new StreamController.broadcast();
  Stream<KGetPeerValue> get onGetPeerValue => _controller.stream;

  int _nodeDebugId = 0;
  int get nodeDebugId => _nodeDebugId;

  int _intervalSecondForMaintenance = 5;
  int get intervalSecondForMaintenance => _intervalSecondForMaintenance;

  int _intervalSecondForAnnounce = 60;
  int get intervalSecondForAnnounce => _intervalSecondForAnnounce;

  int _intervalSecondForFindNode = 10*60;
  int get intervalSecondForFindNode => _intervalSecondForFindNode;
  bool _verbose = false;
  bool get verbose => _verbose;

  KNode(HetimaSocketBuilder socketBuilder,
      {int kBucketSize: 8, List<int> nodeIdAsList: null, KNodeWork ai: null,
      intervalSecondForMaintenance: 10, intervalSecondForAnnounce: 5 * 60, 
      intervalSecondForFindNode: 10 * 60,bool verbose: false}) {
    this._verbose = verbose;
    this._intervalSecondForMaintenance = intervalSecondForMaintenance;
    this._intervalSecondForAnnounce = intervalSecondForAnnounce;
    this._intervalSecondForFindNode = intervalSecondForFindNode;
    this._nodeId = (nodeIdAsList == null ? KId.createIDAtRandom() : new KId(nodeIdAsList));
    this._socketBuilder = socketBuilder;
    this._rootingtable = new KRootingTable(kBucketSize, _nodeId);
    this._ai = (ai == null ? new KNodeAIBasic(verbose: verbose) : ai);
    this._nodeDebugId = id++;
  }

  int port = 0;
  Future start({String ip: "0.0.0.0", int port: 28080}) async {
    (_isStart != false ? throw "already started" : 0);
    _udpSocket = this._socketBuilder.createUdpClient();
    this.port = port;
    return _udpSocket.bind(ip, port, multicast: true).then((HetimaBindResult v) {
      _udpSocket.onReceive.listen((HetimaReceiveUdpInfo info) {
        KrpcMessage.decode(info.data).then((KrpcMessage message) {
          onReceiveMessage(info, message);
        }).catchError((e){
          ;
        });
      });
      _isStart = true;
      _ai.start(this);
      _ai.startTick(this);
    });
  }

  onReceiveMessage(HetimaReceiveUdpInfo info, KrpcMessage message) {
    if (verbose == true) {
      log("--->receive[${nodeDebugId}] ${info.remoteAddress}:${info.remotePort} ${message}");
    }
    if (message.isResonse) {
      KSendInfo rm = removeQueryNameFromTransactionId(UTF8.decode(message.rawMessageMap["t"]));
      this._ai.onReceiveResponse(this, info, message);
      if (rm != null && rm.c != null) {
        rm.c.complete(message);
      } else {
        log("----> receive null : [${nodeDebugId}] ${info.remoteAddress} ${info.remotePort}");
      }
    } else if (message.isQuery) {
      this._ai.onReceiveQuery(this, info, message);
    } else if (message.isError) {
      this._ai.onReceiveError(this, info, message);
    } else {
      this._ai.onReceiveUnknown(this, info, message);
    }
    for (KSendInfo i in clearTimeout(20000)) {
      if (i.c != null && i.c.isCompleted == false) {
        i.c.completeError({message: "timeout"});
      }
    }
  }

  Future stop() async {
    if (_isStart == false || _udpSocket == null) {
      return null;
    }
    return _udpSocket.close().whenComplete(() {
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

  Future sendPingQuery(String ip, int port, {waitByResponse:false}) => sendMessage(ip, port, KrpcPing.createQuery(_nodeId.value), waitByResponse:waitByResponse);

  Future sendFindNodeQuery(String ip, int port, List<int> targetNodeId, {waitByResponse:false}) => sendMessage(ip, port, KrpcFindNode.createQuery(_nodeId.value, targetNodeId), waitByResponse:waitByResponse);

  Future sendGetPeersQuery(String ip, int port, List<int> infoHash, {waitByResponse:false}) => sendMessage(ip, port, KrpcGetPeers.createQuery(_nodeId.value, infoHash), waitByResponse:waitByResponse);

  Future sendAnnouncePeerQuery(String ip, int port, int implied_port, List<int> infoHash, int announcedPort, List<int> opaqueToken, {waitByResponse:false}) =>
      sendMessage(ip, port, KrpcAnnounce.createQuery(_nodeId.value, implied_port, infoHash, announcedPort, opaqueToken), waitByResponse:waitByResponse);

  Future sendPingResponse(String ip, int port, List<int> transactionId) => sendMessage(ip, port, KrpcPing.createResponse(_nodeId.value, transactionId));

  Future sendFindNodeResponse(String ip, int port, List<int> transactionId, List<int> compactNodeInfo) =>
      sendMessage(ip, port, KrpcFindNode.createResponse(compactNodeInfo, this._nodeId.value, transactionId));

  Future sendGetPeersResponseWithClosestNodes(String ip, int port, List<int> transactionId, List<int> opaqueWriteToken, List<int> compactNodeInfo) =>
      sendMessage(ip, port, KrpcGetPeers.createResponseWithClosestNodes(transactionId, this._nodeId.value, opaqueWriteToken, compactNodeInfo));

  Future sendGetPeersResponseWithPeers(String ip, int port, List<int> transactionId, List<int> opaqueWriteToken, List<List<int>> peerInfoStrings) =>
      sendMessage(ip, port, KrpcGetPeers.createResponseWithPeers(transactionId, this._nodeId.value, opaqueWriteToken, peerInfoStrings));

  Future sendAnnouncePeerResponse(String ip, int port, List<int> transactionId) => sendMessage(ip, port, KrpcAnnounce.createResponse(transactionId, this._nodeId.value));

  Future sendErrorResponse(String ip, int port, int errorCode, List<int> transactionId, [String errorDescription = null]) => sendMessage(ip, port, KrpcError.createResponse(transactionId, errorCode));

  Future sendMessage(String ip, int port, KrpcMessage message, {waitByResponse:false}) {
    Completer c = new Completer();
    new Future(() {
      if (message.isQuery) {
        if(waitByResponse == false) {
          c.complete({});
          c = null;
        }
        queryInfo.add(new KSendInfo(message.transactionIdAsString, message.queryAsString, c));
      } else {
        c.complete({});
      }
      log("--->send [${_nodeDebugId}] ${ip}:${port} ${message}");
      return _udpSocket.send(message.messageAsBencode, ip, port);
    }).catchError(c.completeError);
    return c.future;
  }
  
  log(String message) {
    if(_verbose) {
      print(".n.:${message}");
    }
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
