library hetimatorrent.torrent.ai.piece;

import 'dart:core';
import 'torrentclient.dart';
import 'torrentclient_front.dart';
import 'torrentclient_peerinfo.dart';
import '../util/bitfield.dart';
import '../util/blockdata.dart';
import '../util/bitfield_plus.dart';

class TorrentClientPieceTestResultA {
  List<TorrentClientPeerInfo> notinterested = [];
  List<TorrentClientPeerInfo> interested = [];

}

class TorrentClientPieceTestResultB {
  TorrentClientPeerInfo request = null;
  BlockDataGetNextBlockPartResult begineEnd = null;
  int targetBit = 0;
}

class TorrentClientPieceTest {
  List<int> requestedBit = [];
  int downloadPieceLength = 16 * 1024;
  TorrentClientPieceTest.fromTorrentClient(TorrentClient client) {
    _init(client.targetBlock.rawHead, client.targetBlock.blockSize);
  }

  TorrentClientPieceTest(Bitfield rawBlockDataInfo, int blockSize) {
    _init(rawBlockDataInfo, blockSize);
  }

  _init(Bitfield rawBlockDataInfo, int blockSize) {
    if (downloadPieceLength > blockSize) {
      downloadPieceLength = blockSize;
    }
  }

  //, Bitfield clientBlockDataInfo
  TorrentClientPieceTestResultA interestTest(BlockData blockData, TorrentClientPeerInfo info) {
    TorrentClientPieceTestResultA ret = new TorrentClientPieceTestResultA();
    if (info.amI == true) {
      return ret;
    }
    if (blockData.haveAll()) {
      if (info.interestedFromMe != TorrentClientPeerInfo.STATE_OFF) {
        ret.notinterested.add(info);
      }
      return ret;
    }

    BitfieldPlus _cash = blockData.isNotThrere(info.bitfieldToMe);
    for (int v in requestedBit) {
      _cash.setIsOn(v, false);
    }

    if (_cash.isAllOff()) {
      if (info.interestedFromMe != TorrentClientPeerInfo.STATE_OFF) {
        ret.notinterested.add(info);
      }
    } else {
      if (info.interestedFromMe != TorrentClientPeerInfo.STATE_ON) {
        ret.interested.add(info);
      }
    }
    return ret;
  }

  TorrentClientPieceTestResultB requestTest(BlockData blockData, TorrentClientPeerInfo info) {
    TorrentClientPieceTestResultB ret = new TorrentClientPieceTestResultB();
    TorrentClientFront front = info.front;
    if (info.amI == true) {
      return ret;
    }

    int targetBit = 0;
    if (front.lastRequestIndex != null && !blockData.have(front.lastRequestIndex)) {
      targetBit = front.lastRequestIndex;
    } else {
      BitfieldPlus _cash = blockData.isNotThrere(info.bitfieldToMe);
      targetBit = _cash.getOnPieceAtRandom();
    }

    BlockDataGetNextBlockPartResult bl = blockData.getNextBlockPart(targetBit, downloadPieceLength);
    ret.begineEnd = bl;
    ret.request = info;
    ret.targetBit = targetBit;
    return ret;
  }

  pieceTest(TorrentClient client, TorrentClientPeerInfo info) {
    TorrentClientFront front = info.front;
    if (front == null || front.amI == true) {
      return;
    }
    TorrentClientPieceTestResultA r = interestTest(client.targetBlock, info);
    for(TorrentClientPeerInfo i in r.interested) {
      if(i != null) {
       i.front.sendInterested();
      }
    }
    for(TorrentClientPeerInfo i in r.notinterested) {
      if(i != null) {
       i.front.sendNotInterested();
      }
    }

    //
    // if choke, then end
    if (client.targetBlock.haveAll() == true || front.chokedToMe != TorrentClientPeerInfo.STATE_OFF) {
      return;
    }

    //
    // now requesting
    if (0 < front.currentRequesting.length) {
      return;
    }

    //
    // select piece & request
   // for(int i=0;i<5;i++) {
    TorrentClientPieceTestResultB  r1 = requestTest(client.targetBlock, info);
    if(r1.request != null && r1.request.front != null) {
      r1.request.front.sendRequest(r1.targetBit, r1.begineEnd.begin,r1.begineEnd.end-r1.begineEnd.begin);
    }
   // }
  }
}
