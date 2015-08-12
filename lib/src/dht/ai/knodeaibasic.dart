library hetimatorrent.dht.knodeaibasic;

import 'dart:core';
import 'package:hetimanet/hetimanet.dart';

import '../kid.dart';
import '../message/krpcmessage.dart';
import '../kpeerinfo.dart';
import '../knode.dart';
import 'knodeaifindnode.dart';
import 'knodeiannounce.dart';
import 'knodeai.dart';

class KNodeAIBasic extends KNodeAI {
  bool _isStart = false;
  bool get isStart => _isStart;

  KNodeAIFindNode findNodeAI = new KNodeAIFindNode();
  KNodeAIAnnounce announceAI = new KNodeAIAnnounce();

  KNodeAIBasic({bool verbose: false}) {}

  start(KNode node) {
    findNodeAI.start(node);
    announceAI.start(node);
  }

  stop(KNode node) {
    findNodeAI.stop(node);
    announceAI.stop(node);
  }

  updateP2PNetwork(KNode node) {
    findNodeAI.updateP2PNetwork(node);
    announceAI.updateP2PNetwork(node);
  }

  startSearchValue(KNode node, KId infoHash, int port, {getPeerOnly: false}) {
    return announceAI.startSearchValue(node, infoHash, port);
  }

  researchSearchPeer(KNode node, KId infoHash) {
    announceAI.researchSearchPeer(node, infoHash);
  }

  stopSearchValue(KNode node, KId infoHash) {
    announceAI.stopSearchValue(node, infoHash);
  }

  onTicket(KNode node) {
    findNodeAI.onTicket(node);
    announceAI.onTicket(node);
  }

  onAddNodeFromIPAndPort(KNode node, String ip, int port) {
    findNodeAI.onAddNodeFromIPAndPort(node, ip, port);
    announceAI.onAddNodeFromIPAndPort(node, ip, port);
  }

  onReceiveQuery(KNode node, HetiReceiveUdpInfo info, KrpcMessage query) {
    node.rootingtable.update(new KPeerInfo(info.remoteAddress, info.remotePort, query.nodeIdAsKId));
    switch (query.queryAsString) {
      case KrpcMessage.QUERY_PING:
        return node.sendPingResponse(info.remoteAddress, info.remotePort, query.transactionId).catchError((_) {});
      case KrpcMessage.QUERY_FIND_NODE:
      case KrpcMessage.QUERY_ANNOUNCE:
      case KrpcMessage.QUERY_GET_PEERS:
        break;
      default:
        return node.sendErrorResponse(info.remoteAddress, info.remotePort, KrpcMessage.METHOD_ERROR, query.transactionId).catchError((_) {});
    }
    findNodeAI.onReceiveQuery(node, info, query);
    announceAI.onReceiveQuery(node, info, query);
  }

  onReceiveResponse(KNode node, HetiReceiveUdpInfo info, KrpcMessage response) {
    findNodeAI.onReceiveResponse(node, info, response);
    announceAI.onReceiveResponse(node, info, response);
  }

  onReceiveError(KNode node, HetiReceiveUdpInfo info, KrpcMessage message) {
    findNodeAI.onReceiveError(node, info, message);
    announceAI.onReceiveError(node, info, message);
  }

  onReceiveUnknown(KNode node, HetiReceiveUdpInfo info, KrpcMessage message) {
    findNodeAI.onReceiveUnknown(node, info, message);
    announceAI.onReceiveUnknown(node, info, message);
  }
}
