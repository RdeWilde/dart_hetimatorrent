library hetimatorrent.torrent.clientfront;

import 'dart:core';
import 'dart:async';
import 'dart:typed_data';
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimanet/hetimanet.dart';
import '../util/peeridcreator.dart';
import 'message/message.dart';
import 'torrentclient_peerinfo.dart';
import '../util/bitfield.dart';
import 'torrentclient_message.dart';

class TorrentClientFront {
  List<int> _myPeerId = [];
  List<int> _targetPeerId = [];
  List<int> get targetPeerId => new List.from(_targetPeerId);
  List<int> _infoHash = [];
  List<int> _targetProtocolId = [];

  EasyParser _parser = null;
  HetimaSocket _socket = null;
  bool handshaked = false;

  String _peerIp = "";
  int _peerPort = 0;
  int speed = 0; //per sec bytes
  int downloadedBytesFromMe = TorrentClientPeerInfo.STATE_NONE; // Me is Hetima
  int uploadedBytesToMe = TorrentClientPeerInfo.STATE_NONE; // Me is Hetima
  int chokedFromMe = TorrentClientPeerInfo.STATE_NONE; // Me is Hetima
  int chokedToMe = TorrentClientPeerInfo.STATE_NONE; // Me is Hetima

  int _unchokedStartTime = 0;
  int _uploadedBytesFromUnchokedStartTime = 0;

  int get unchokedStartTime => _unchokedStartTime;
  int get uploadSpeedFromUnchokeFromMe => _uploadedBytesFromUnchokedStartTime ~/ (new DateTime.now().millisecondsSinceEpoch - _unchokedStartTime);

  bool _handshakedToMe = false;
  bool _handshakedFromMe = false;
  bool get handshakeToMe => _handshakedToMe;
  bool get handshakeFromMe => _handshakedFromMe;
  bool get isClose => _socket.isClosed;

  bool _amI = false;
  bool get amI => _amI;
  int _interestedToMe = TorrentClientPeerInfo.STATE_NONE;
  int _interestedFromMe = TorrentClientPeerInfo.STATE_NONE;
  int get interestedToMe => _interestedToMe;
  int get interestedFromMe => _interestedFromMe;

  Bitfield _bitfieldToMe = null;
  Bitfield _bitfieldFromMe = null;
  Bitfield get bitfieldToMe => _bitfieldToMe;
  Bitfield get bitfieldFromMe => _bitfieldFromMe;
  Map<String, Object> tmpForAI = {};

  List<TMessageRequest> currentRequesting = [];
  StreamController<TorrentMessage> stream = new StreamController();
  Stream<TorrentMessage> get onReceiveEvent => stream.stream;

  StreamController<TorrentClientSignal> _streamSignal = new StreamController.broadcast();
  Stream<TorrentClientSignal> get onReceiveSignal => _streamSignal.stream;

  int _lastRequestIndex = null;
  int get lastRequestIndex => _lastRequestIndex;

  static int debugIdSeed = 0;
  int _debugId = 0;

  List<int> _reseved = [0, 0, 0, 0, 0, 0, 0, 0];
  List<int> get reseved => new List.from(_reseved);

  int requestedMaxPieceSize = 16 * 1024;

  bool _verbose = false;
  bool get verbose => _verbose;

  set reseved(List<int> v) {
    if (v.length != 8) {
      throw {};
    }
    _reseved.clear();
    _reseved.addAll(v);
  }

  static Future<TorrentClientFront> connect(HetimaSocketBuilder _builder, TorrentClientPeerInfo info, int bitfieldSize, List<int> infoHash,
      {List<int> peerId: null, List<int> reseved: null, bool verbose: false}) async {
    HetimaSocket socket = _builder.createClient(mode:HetimaSocketBuilder.BUFFER_ONLY);
    await socket.connect(info.ip, info.port);
    return new TorrentClientFront(socket, info.ip, info.port, socket.buffer, bitfieldSize, infoHash, peerId, reseved, verbose: verbose);
  }

  TorrentClientFront(HetimaSocket socket, String peerIp, int peerPort, HetimaReader reader, int bitfieldSize, List<int> infoHash, List<int> peerId, List<int> reseved, {bool verbose: false}) {
    if (peerId == null) {
      _myPeerId.addAll(PeerIdCreator.createPeerid("heti69"));
    } else {
      _myPeerId.addAll(peerId);
    }

    if (reseved == null) {
      this._reseved = [0, 0, 0, 0, 0, 0, 0, 0];
    } else {
      this._reseved.clear();
      this._reseved.addAll(reseved);
    }

    _debugId = debugIdSeed++;
    _peerIp = peerIp;
    _peerPort = peerPort;
    _infoHash.addAll(infoHash);
    _socket = socket;
    _parser = new EasyParser(reader);
    _handshakedFromMe = false;
    _handshakedToMe = false;
    _bitfieldToMe = new Bitfield(bitfieldSize, clearIsOne: false);
    _bitfieldFromMe = new Bitfield(bitfieldSize, clearIsOne: false);
    _socket.onClose.listen((HetimaCloseInfo info) {
      TorrentClientFrontNerve.doClose(this, 0);
    });
    _verbose = verbose;
  }

  // one peer one request.
  List<Uint8List> pieceCache = [];
  int pieceCacheIndex = 0;
  Future<TorrentMessage> parse(List<int> cash) async {
    if (handshaked == false) {
      TorrentMessage message = await TorrentMessage.parseHandshake(_parser);
      print("recv : ${message}");
      handshaked = true;
      return message;
    } else {
      (_parser.buffer as ArrayBuilder).rawbuffer8.logon = true;
      TorrentMessage message = await TorrentMessage.parseBasic(_parser, maxOfMessageSize: requestedMaxPieceSize + 20, buffer:cash, pieceBuffer: pieceCache[pieceCacheIndex]);
      print("recv [${_peerPort}]: ${message}");
      if(message.id == TorrentMessage.SIGN_PIECE) {
        pieceCacheIndex++;
        if(pieceCacheIndex >= pieceCache.length) {
          pieceCacheIndex = 0;
        }
      }
      //print("## -[1]-> ## ${_parser.index} ${(_parser.buffer as ArrayBuilder).rawbuffer8.length}");
      (_parser.buffer as ArrayBuilder).clearInnerBuffer(_parser.index, reuse:true);
      //print("## -[2]-> ##${(_parser.buffer as ArrayBuilder).rawbuffer8.rawbuffer8.length} ${_parser.stack.length}");
      return message;
    }
  }

  startReceive() async {
    try {
      pieceCache = new List.filled(5, new Uint8List(3*16*1024));
      Uint8List cash = new Uint8List(3*16*1024);
      while (true) {
        TorrentMessage message = await parse(cash);
        TorrentClientFrontNerve.doReceiveMessage(this, message);
        stream.add(message);
      }
    } catch (e) {
      stream.addError(e);
      await close();
      try {
        _socket.clearBuffer();
        _streamSignal.add(new TorrentClientSignalWithFront(this, TorrentClientSignal.ID_CLOSE,TorrentClientSignal.REASON_PAESE_ERROR, ""));
      } catch(e) {
        
      }

    }
  }

  Future sendHandshake({List<int> reseved: null}) {
    if (reseved == null) {
      reseved = new List.from(_reseved);
    }
    TMessageHandshake message = new TMessageHandshake(TMessageHandshake.ProtocolId, reseved, _infoHash, _myPeerId);
    return sendMessage(message);
  }

  Future sendBitfield(List<int> bitfield) {
    TMessageBitfield message = new TMessageBitfield(bitfield);
    return sendMessage(message);
  }

  Future sendChoke() {
    TMessageChoke message = new TMessageChoke();
    return sendMessage(message);
  }

  Future sendUnchoke() {
    TMessageUnchoke message = new TMessageUnchoke();
    return sendMessage(message);
  }

  Future sendInterested() {
    TMessageInterested message = new TMessageInterested();
    return sendMessage(message);
  }

  Future sendNotInterested() {
    TMessageNotInterested message = new TMessageNotInterested();
    return sendMessage(message);
  }

  Future sendCancel(int index, int begin, int length) {
    TMessageCancel message = new TMessageCancel(index, begin, length);
    return sendMessage(message);
  }

  Future sendHave(int index) {
    TMessageHave message = new TMessageHave(index);
    return sendMessage(message);
  }

  Future sendPort(int port) {
    TMessagePort message = new TMessagePort(port);
    return sendMessage(message);
  }

  Future sendPiece(int index, int begin, List<int> content) {
    TMessagePiece message = new TMessagePiece(index, begin, content, content.length);
    return sendMessage(message);
  }

  Future sendRequest(int index, int begin, int length) {
    if (requestedMaxPieceSize < length) {
      requestedMaxPieceSize = length;
    }
    TMessageRequest message = new TMessageRequest(index, begin, length);
    return sendMessage(message);
  }

  Future sendMessage(TorrentMessage message) async {
    List<int> data = await message.encode();
    await _socket.send(data);
    print("send [${_peerPort}]: ${message}");
    TorrentClientFrontNerve.doSendMessage(this, message);
    return {};
  }

  close() async {
    log("[${_debugId}][${_peerIp}:${_peerPort}] close");
    await _socket.close();
    TorrentClientFrontNerve.doClose(this, 0);
  }

  void log(String message) {
    if (_verbose) {
      print("...${message}");
    }
  }
}

//
//
//
class TorrentClientFrontNerve {
  int id = 0;
  int reason = 0;
  int v = 0;

  String toString() {
    return "${id} ${reason} ${v}";
  }

  static void doReceiveMessage(TorrentClientFront front, TorrentMessage message) {
    front.log("[${front._debugId} ${front._peerIp}:${front._peerPort}] receive ${message.toString()}");
    switch (message.id) {
      case TorrentMessage.DUMMY_SIGN_SHAKEHAND:
        front._handshakedToMe = true;
        front._targetPeerId.clear();
        front._targetPeerId.addAll((message as TMessageHandshake).peerId);
        front._targetProtocolId.addAll((message as TMessageHandshake).protocolId);
        _signalHandshake(front);
        _signalHandshakeOwnConnectCheck(front, message);
        _signalHandshakeInfoHashCheck(front, message);
        break;
      case TorrentMessage.SIGN_CHOKE:
        front.chokedToMe = TorrentClientPeerInfo.STATE_ON;
        break;
      case TorrentMessage.SIGN_UNCHOKE:
        front.chokedToMe = TorrentClientPeerInfo.STATE_OFF;
        break;
      case TorrentMessage.SIGN_INTERESTED:
        front._interestedToMe = TorrentClientPeerInfo.STATE_ON;
        break;
      case TorrentMessage.SIGN_NOTINTERESTED:
        front._interestedToMe = TorrentClientPeerInfo.STATE_OFF;
        break;
      case TorrentMessage.SIGN_BITFIELD:
        TMessageBitfield messageBitfile = message;
        front._bitfieldToMe.writeBytes(messageBitfile.bitfield);
        break;
      case TorrentMessage.SIGN_HAVE:
        TMessageHave messageHave = message;
        front._bitfieldToMe.setIsOn(messageHave.index, true);
        break;
      case TorrentMessage.SIGN_PIECE:
        {
          TMessagePiece req = message;
          List<TMessageRequest> removeTarge = [];
          for (TMessageRequest mes in front.currentRequesting) {
            if (mes.begin == req.begin && mes.index == req.index && mes.length == req.content.length) {
              removeTarge.add(mes);
            }
          }
          for (TMessageRequest rm in removeTarge) {
            front.currentRequesting.remove(rm);
          }
        }
        front.downloadedBytesFromMe += (message as TMessagePiece).content.length;
        front._streamSignal.add(new TorrentClientSignalWithFront(front, TorrentClientSignal.ID_PIECE_RECEIVE, 0, "", (message as TMessagePiece).content.length));
        break;
    }
  }

  static void doSendMessage(TorrentClientFront front, TorrentMessage message) {
    front.log("[${front._peerIp}:${front._peerPort} ${front.isClose}] send ${message.toString()}");
    switch (message.id) {
      case TorrentMessage.DUMMY_SIGN_SHAKEHAND:
        front._handshakedFromMe = true;
        _signalHandshake(front);
        break;
      case TorrentMessage.SIGN_CHOKE:
        front.chokedFromMe = TorrentClientPeerInfo.STATE_ON;
        front._unchokedStartTime = new DateTime.now().millisecondsSinceEpoch;
        front._uploadedBytesFromUnchokedStartTime = 0;
        break;
      case TorrentMessage.SIGN_UNCHOKE:
        front.chokedFromMe = TorrentClientPeerInfo.STATE_OFF;
        break;
      case TorrentMessage.SIGN_INTERESTED:
        front._interestedFromMe = TorrentClientPeerInfo.STATE_ON;
        break;
      case TorrentMessage.SIGN_NOTINTERESTED:
        front._interestedFromMe = TorrentClientPeerInfo.STATE_OFF;
        break;
      case TorrentMessage.SIGN_BITFIELD:
        TMessageBitfield messageBitfile = message;
        front._bitfieldFromMe.writeBytes(messageBitfile.bitfield);
        break;
      case TorrentMessage.SIGN_PIECE:
        front.uploadedBytesToMe += (message as TMessagePiece).content.length;
        front._uploadedBytesFromUnchokedStartTime += (message as TMessagePiece).content.length;
        front._streamSignal.add(new TorrentClientSignalWithFront(front, TorrentClientSignal.ID_PIECE_SEND, 0, "", (message as TMessagePiece).content.length));
        break;
      case TorrentMessage.SIGN_REQUEST:
        TMessageRequest resestMessage = message;
        front.currentRequesting.add(message);
        front._lastRequestIndex = resestMessage.index;
        break;
    }
  }

  static void _signalHandshakeInfoHashCheck(TorrentClientFront front, TorrentMessage message) {
    if (message.id != TorrentMessage.DUMMY_SIGN_SHAKEHAND) {
      return;
    }
    TMessageHandshake handshakeMessage = message;
    if (handshakeMessage.infoHash != front._infoHash) {
      doClose(front, TorrentClientSignal.REASON_UNMANAGED_INFOHASH);
    }
  }

  static void _signalHandshake(TorrentClientFront front) {
    if (front._handshakedFromMe == true && front._handshakedToMe == true) {
      front._streamSignal.add(new TorrentClientSignalWithFront(front, TorrentClientSignal.ID_HANDSHAKED, 0, ""));
    }
  }

  static void _signalHandshakeOwnConnectCheck(TorrentClientFront front, TorrentMessage message) {
    if (message.id != TorrentMessage.DUMMY_SIGN_SHAKEHAND) {
      return;
    }
    TMessageHandshake handshakeMessage = message;
    if (handshakeMessage.peerId.length == front._myPeerId.length) {
      bool eq = true;
      for (int i = 0; i < handshakeMessage.peerId.length; i++) {
        if (handshakeMessage.peerId[i] != front._myPeerId[i]) {
          eq = false;
          break;
        }
      }
      if (eq == true) {
        front._amI = true;
        doClose(front, TorrentClientSignal.REASON_OWN_CONNECTION);
      }
    }
  }

  static void doClose(TorrentClientFront front, int reason) {
    front._streamSignal.add(new TorrentClientSignalWithFront(front, TorrentClientSignal.ID_CLOSE, reason, ""));
  }
}
