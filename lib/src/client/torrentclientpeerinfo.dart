library hetimatorrent.torrent.client.peerinfo;

import 'dart:core';
import '../util/shufflelinkedlist.dart';

import 'torrentclientfront.dart';


class TorrentClientPeerInfoList {
  ShuffleLinkedList<TorrentClientPeerInfo> peerInfos;

  TorrentClientPeerInfoList() {
    peerInfos = new ShuffleLinkedList();
  }

  
  //
  // tracker --> ip , port
  // handshake --> ip, peerid,
  //
  TorrentClientPeerInfo putPeerInfoFormTracker(String ip, int port, {peerId: ""}) {
    for (int i = 0; i < peerInfos.length; i++) {
      TorrentClientPeerInfo info = peerInfos.getSequential(i);
      if (info.ip == ip && info.portAcceptable == port) {
        // alredy added in peerinfo
        print("putFormTrackerPeerInfo ${ip} ${port} --A");
        return info;
      }
    }
    TorrentClientPeerInfo info = new TorrentClientPeerInfo.fromTracker(ip, port);
    peerInfos.addLast(info);
    // alredy added in peerinfo
    print("putFormTrackerPeerInfo ${ip} ${port} --B ${peerInfos.length}");
    return info;
  }
  
  TorrentClientPeerInfo getPeerInfoFromId(int id) {
    for (int i = 0; i < peerInfos.length; i++) {
      TorrentClientPeerInfo info = peerInfos.getSequential(i);
      if (info.id == id) {
        return info;
      }
    }
    return null;
  }

  List<TorrentClientPeerInfo> getPeerInfo(Function filter) {
    List<TorrentClientPeerInfo> ret = [];
    for (int i = 0; i < peerInfos.length; i++) {
      TorrentClientPeerInfo info = peerInfos.getSequential(i);
      if(filter(info) == true) {
        ret.add(info);
      }
    }
    return ret;
  }
}

class TorrentClientPeerInfo {
  static int nid = 0;
  int id = 0;

  String ip = "";
  int portAcceptable = 0;
  List<int> peerId = [];
  TorrentClientFront front = null;


  TorrentClientPeerInfo.fromTracker(String ip, int port) {
    this.id = ++nid;
    this.ip = ip;
    this.portAcceptable = port;
  }

  TorrentClientPeerInfo.fromAccept(String ip, List<int> peerId) {
    this.id = ++nid;
    this.ip = ip;
    this.peerId.addAll(peerId);
  }

  /// per sec bytes
  int get speed {
    if (front == null) {
      return 0;
    } else {
      return front.speed;
    }
  }

  /// Me is Hetima
  int get downloadedBytesFromMe {
    if (front == null) {
      return 0;
    } else {
      return front.downloadedBytesFromMe;
    }
  }

  /// Me is Hetima
  int get uploadedBytesToMe {
    if (front == null) {
      return 0;
    } else {
      return front.uploadedBytesToMe;
    }
  }
  /// Me is Hetima
  int get chokedFromMe {
    if (front == null) {
      return 0;
    } else {
      return front.chokedFromMe;
    }
  }
  /// Me is Hetima
  int get chokedToMe {
    if (front == null) {
      return 0;
    } else {
      return front.chokedToMe;
    }
  }
  bool get amI {
    if (front == null) {
      return false;
    } else {
      return front.amI;
    }
  }
}
