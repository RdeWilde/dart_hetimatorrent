library hetimatorrent.torrent.ai.basic;

import 'dart:core';
import 'dart:async';
import '../message/message.dart';
import 'package:hetimacore/hetimacore.dart';
import 'torrentclient.dart';
import 'torrentclientfront.dart';
import 'torrentclientpeerinfo.dart';
import 'torrentclientmessage.dart';
import 'torrentaichoke.dart';
import 'torrentai.dart';

class TorrentAIBasic extends TorrentAI {
  ChokeTest _chokeTest = new ChokeTest();
  int _maxUnchoke = 8;
  int _maxConnect = 20;

  TorrentAIBasic({maxUnchoke: 8, maxConnect: 20}) {
    _maxUnchoke = maxUnchoke;
    _maxConnect = maxConnect;
  }

  Future onRegistAI(TorrentClient client) {
    return new Future(() {
      print("Basic AI regist : ${client.peerId}");
    });
  }

  Future onTick(TorrentClient client) {
    return new Future(() {
      _chokeTest.chokeTest(client, _maxUnchoke);
    });
  }

  Future onReceive(TorrentClient client, TorrentClientPeerInfo info, TorrentMessage message) {
    return new Future(() {
      TorrentClientFront front = info.front;
      switch (message.id) {
        case TorrentMessage.DUMMY_SIGN_SHAKEHAND:
          {
            if (true == front.handshakeFromMe || info.amI == true) {
              return null;
            } else {
              return front.sendHandshake();
            }
          }
          break;
        case TorrentMessage.SIGN_REQUEST:
          {
            if (info.front.chokedFromMe == TorrentClientFront.STATE_ON) {
              print("wearn ; already choked ${info.id}");
              break;
            }

            MessageRequest requestMessage = message;
            int index = requestMessage.index;
            int begin = requestMessage.begin;
            int len = requestMessage.length;

            if (false == client.targetBlock.have(index)) {
              //
              //
              front.close();
              return null;
            } else {
              return client.targetBlock.readBlock(index).then((ReadResult result) {
                int end = begin + len;
                List cont = new List.filled(len, 0);
                if (len > result.buffer.length) {
                  end = result.buffer.length;
                }
//                cont.setRange(begin, end, result.buffer);
                cont.setRange(0, len, result.buffer,begin);
                return front.sendPiece(index, begin, cont).then((_) {
                  ;
                });
              });
            }
          }
          break;
        case TorrentMessage.SIGN_BITFIELD:
          {
            break;
          }
      }
    });
  }

  Future onSignal(TorrentClient client, TorrentClientPeerInfo info, TorrentClientSignal signal) {
    return new Future(() {
      switch (signal.id) {
        case TorrentClientSignal.ID_HANDSHAKED:
          info.front.sendBitfield(client.targetBlock.bitfield);
          break;
        case TorrentClientSignal.ID_ACCEPT:
        case TorrentClientSignal.ID_CONNECTED:
          break;
        case TorrentClientSignal.ID_ADD_PEERINFO:
          if (info.front == null || info.front.isClose == true) {
            List<TorrentClientPeerInfo> connects = client.rawPeerInfos.getPeerInfo((TorrentClientPeerInfo info) {
              if (info.front == null || info.front.isClose == true) {
                return true;
              }
            });
            if (connects.length < _maxConnect && (info.front == null || info.front.amI == false)) {
              return client.connect(info).then((TorrentClientFront f) {
                return f.sendHandshake();
              }).catchError((e) {
                try {
                  if(info.front != null) {
                    info.front.close();
                  }
                } catch (e) {
                  ;
                }
              });
            }
          }
          break;
      }
    });
  }

}
