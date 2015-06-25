library hetimatorrent.torrent.client;

import 'dart:core';
import 'dart:async';
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimanet/hetimanet.dart';
import '../message/message.dart';

import 'torrentclientfront.dart';
import '../util/blockdata.dart';
import '../util/bitfield.dart';

import '../file/torrentfile.dart';
import 'torrentclientpeerinfo.dart';
import 'torrentai.dart';


class TorrentClient {
  HetiServerSocket _server = null;
  HetiSocketBuilder _builder = null;
  List<int> _peerId = [];
  List<int> _infoHash = [];
  String localAddress = "0.0.0.0";
  int port = 8080;

  List<HetiSocket> _managedSocketList = [];
  List<int> get peerId => new List.from(_peerId);
  List<int> get infoHash  => new List.from(_infoHash);
 
  TorrentClientPeerInfoList _peerInfos;
  List<TorrentClientPeerInfo> get peerInfos => _peerInfos.peerInfos.sequential;

  StreamController<TorrentClientMessage> messageStream = new StreamController();
  Stream<TorrentClientMessage> get onReceiveEvent => messageStream.stream;

  StreamController<TorrentClientSignal> _signalStream = new StreamController.broadcast();
  Stream<TorrentClientSignal> get onReceiveSignal => _signalStream.stream;

  BlockData _targetBlock = null;
  BlockData get targetBlock => _targetBlock;

  static Future<TorrentClient> create(HetiSocketBuilder builder, List<int> peerId, TorrentFile file, HetimaData data) {
    return file.createInfoSha1().then((List<int> infoHash) {
      return new TorrentClient(builder, peerId, infoHash, file.info.pieces, file.info.piece_length, file.info.files.dataSize, data);
    });
  }

  TorrentClient(HetiSocketBuilder builder, List<int> peerId, List<int> infoHash,  List<int> piece, 
                int pieceLength, int fileSize, HetimaData data) {
    this._builder = builder;
    _peerInfos = new TorrentClientPeerInfoList();
    _infoHash.addAll(infoHash);
    _peerId.addAll(peerId);
    _targetBlock = new BlockData(data, new Bitfield(piece.length~/20,clearIsOne:false), pieceLength, fileSize);
  }

  TorrentClientPeerInfo putTorrentPeerInfo(String ip, int port, {peerId: ""}) {
    return _peerInfos.putFormTrackerPeerInfo(ip, port, peerId: peerId);
  }

  Future start() {
    return _builder.startServer(localAddress, port).then((HetiServerSocket serverSocket) {
      _server = serverSocket;
      _server.onAccept().listen((HetiSocket socket) {
        new Future(() {
          return socket.getSocketInfo().then((HetiSocketInfo socketInfo) {
            TorrentClientPeerInfo info = putTorrentPeerInfo(socketInfo.localAddress, socketInfo.localPort);
            info.front = new TorrentClientFront(socket, socketInfo.localAddress, socketInfo.localPort, socket.buffer, _infoHash, _peerId);
            _internalOnReceive(info.front, info);
            info.front.startReceive();
          });
        }).catchError((e) {
          socket.close();
        });
      });
      return {};
    });
  }

  List<TorrentClientPeerInfo> getPeerInfoFromXx(Function filter) {
    List<TorrentClientPeerInfo> ret = [];
    for(TorrentClientPeerInfo info in this.peerInfos) {
      if(true == filter(info)) {
        ret.add(info);
      }
    }
    return ret;
  }

  TorrentClientPeerInfo getPeerInfoFromId(int id) {
    return _peerInfos.getPeerInfoFromId(id);
  }

  Future<TorrentClientFront> connect(TorrentClientPeerInfo info){//, List<int> infoHash, [List<int> peerId = null]) {
    return new Future(() {
      return TorrentClientFront.connect(_builder, info, infoHash, peerId).then((TorrentClientFront front) {
        _internalOnReceive(front, info);
        front.startReceive();
        return front;
      });
    });
  }
  
  void _internalOnReceive(TorrentClientFront front, TorrentClientPeerInfo info) {
    front.onReceiveEvent.listen((TorrentMessage message) {
      messageStream.add(new TorrentClientMessage(info, message));
      _ai.onReceive(this, info, message);
    });
    front.onReceiveSignal.listen((TorrentClientFrontSignal signal) {
      TorrentClientSignal sig =  new TorrentClientSignal()..info = info..signal=signal;
      _signalStream.add(sig);
      _ai.onSignal(this, info, sig);
    });
  }

  Future stop() {
    _server.close();
    for (HetiSocket s in _managedSocketList) {
      s.close();
    }
    return new Future(() {
      return {};
    });
  }

  
  TorrentAI _ai = null;
  void set ai(TorrentAI v) {
   _ai = v;
  }
  TorrentAI get ai => _ai;

}

class TorrentClientMessage {
  TorrentMessage message;
  TorrentClientFront get front => _info.front;
  TorrentClientPeerInfo get info => _info;
  TorrentClientPeerInfo _info;  
  
  TorrentClientMessage(TorrentClientPeerInfo info, TorrentMessage message) {
    this.message = message;
    this._info = info;
  }
}

class TorrentClientSignal {
  TorrentClientPeerInfo info;
  TorrentClientFrontSignal signal;
}

