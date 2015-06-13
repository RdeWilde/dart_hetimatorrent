library hetimatorrent.torrent.trackerpeerinfo;
import 'dart:math' as math;
import 'dart:core';
import 'package:hetimacore/hetimacore.dart';


class TrackerPeerInfo {
  List<int> peerId;
  String address;
  List<int> ip;
  int port;
  int _time = 0;

  int get time => _time;
  TrackerPeerInfo(List<int> _peerId, String _address, List<int> _ip, int _port) {
    peerId = new List.from(_peerId);
    address = _address;
    ip = new List.from(_ip);
    port = _port;
    update();
  }

  void update() {
    _time = (new DateTime.now()).millisecondsSinceEpoch;
  }

  bool operator == (other) {
    if (other is TrackerPeerInfo) {
      if (other.peerId.length != peerId.length) {
        return false;
      }
      for (int i = 0; i < peerId.length; i++) {
        if (other.peerId[i] != peerId[i]) {
          return false;
        }
      }
      return true;
    } else {
      return false;
    }
  }

  String get peerIdAsString => PercentEncode.encode(peerId);
  String get portdAsString => port.toString();
  String get ipAsString {
    return "" + ip[0].toString() + "." + ip[1].toString() + "." + ip[2].toString() + "." + ip[3].toString();
  }
}

class PeerIdCreator {
  static math.Random _random = new math.Random(new DateTime.now().millisecond);
  static List<int> createPeerid(String id) {
    List<int> output = new List<int>(20);
    for (int i = 0; i < 20; i++) {
      output[i] = _random.nextInt(0xFF);
    }
    List<int> idAsCode = id.codeUnits;
    for (int i = 0; i < 5 && i < idAsCode.length; i++) {
      output[i + 1] = idAsCode[i];
    }
    return output;
  }
}
