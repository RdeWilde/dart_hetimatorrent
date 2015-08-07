library hetimatorrent.torrent.ai.basic;

import 'dart:core';
import 'dart:async';
import 'message/message.dart';
import 'package:hetimacore/hetimacore.dart';
import 'torrentclient.dart';
import 'torrentclientfront.dart';
import 'torrentclientpeerinfo.dart';
import 'torrentclientmessage.dart';
import 'torrentai_choke.dart';
import 'torrentai_piece.dart';
import 'torrentai.dart';
import 'torrentai_connect.dart';

class TorrentAIBasic extends TorrentAI {
  ChokeTest _chokeTest = new ChokeTest();
  PieceTest _pieceTest = null;
  ConnectTest _connectTest = new ConnectTest();
  int _maxUnchoke = 8;
  int _maxConnect = 20;

  bool _useDht = false;
  bool get useDht => _useDht;

  int _dhtPort = null;
  int get dhtPort => _dhtPort;

  TorrentAIBasic({maxUnchoke: 8, maxConnect: 20, useDht: false, int dhtPort: null}) {
    this._maxUnchoke = maxUnchoke;
    this._maxConnect = maxConnect;
    this._useDht = useDht;
    this._dhtPort = dhtPort;
  }

  Future onTick(TorrentClient client) {
    return new Future(() {
      {
        bool haveAll = client.targetBlock.haveAll();
        List<TorrentClientPeerInfo> infos = client.rawPeerInfos.getPeerInfo((TorrentClientPeerInfo info) {
          if (info.front == null || info.front.isClose) {
            return false;
          }
          if (info.amI) {
            return true;
          }
          if (haveAll == true && info.front.bitfieldToMe.isAllOn()) {
            return true;
          }
          return false;
        });
        //
        // close
        //
        for (TorrentClientPeerInfo info in infos) {
          new Future.delayed(new Duration(seconds: 5)).then((_) {
            info.front.close();
          });
        }
      }
      _chokeTest.chokeTest(client, _maxUnchoke);
    });
  }

  Future onReceive(TorrentClient client, TorrentClientPeerInfo info, TorrentMessage message) {
    return new Future(() {
      TorrentClientFront front = info.front;
      switch (message.id) {
        case TorrentMessage.DUMMY_SIGN_SHAKEHAND:
          {
            MessageHandshake handshake = message;
            if (true == front.handshakeFromMe || info.amI == true) {
              return null;
            } else {
              return front.sendHandshake();
            }
            if (useDht == true) {
              if (handshake.reserved[7] & 0x01 == 0x01) {
                if (_dhtPort == null) {
                  front.sendPort(client.globalPort);
                } else {
                  front.sendPort(_dhtPort);
                }
              }
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
                List cont = new List.filled(len, 0);
                if (len > result.buffer.length) {
                  len = result.buffer.length;
                }
                cont.setRange(0, len, result.buffer, begin);
                return front.sendPiece(index, begin, cont).then((_) {
                  ;
                });
              });
            }
          }
          break;
        case TorrentMessage.SIGN_BITFIELD:
        //
        // targetBlock 'does not reflect. check ID_SET_PIECE_A_PART;
        // case TorrentMessage.SIGN_PIECE:
        case TorrentMessage.SIGN_UNCHOKE:
          if (_pieceTest == null) {
            _pieceTest = new PieceTest(client);
          }
          _pieceTest.pieceTest(client, front);
          break;
        case TorrentMessage.SIGN_PORT:
        {

        }
        break;
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
          _connectTest.connectTest(info, client, _maxConnect);
          break;
        case TorrentClientSignal.ID_SET_PIECE_A_PART:
        case TorrentClientSignal.ID_SET_PIECE:
          if (_pieceTest == null) {
            _pieceTest = new PieceTest(client);
          }
          _pieceTest.pieceTest(client, info.front);
          break;
      }
    });
  }
}
