library hetimatorrent.extra.torrentengine;

import 'dart:async';
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimanet/hetimanet.dart';
import 'package:hetimatorrent/hetimatorrent.dart';
import '../client/torrentclient.dart';
import '../tracker/trackerclient.dart';
import 'torrentengineai.dart';
import 'torrentdhtai.dart';

abstract class TorrentEngineCommand {
  Future<CommandResult> execute(TorrentEngine engine, {List<String> args: null});
  static String get help => "";
}

class TorrentEngineCommandBuilder {
  Function builder = null; //TorrentEngineCommand builder(List<String> list);
  String help = "";
  TorrentEngineCommandBuilder(Function builder, String help) {
    this.builder = builder;
    this.help = help;
  }
}

class CommandResult {
  String message = "";
  CommandResult(String message) {
    this.message = message;
  }
}

class TorrentEngineDHTMane {
  //
  // dht is singleton
  static TorrentEngineDHT _dht = null;

  bool _startDHTIsNow = false;
  HetiSocketBuilder _socketBuilder = null;
  TorrentEngineDHTMane(HetiSocketBuilder socketBuilder) {
    this._socketBuilder = socketBuilder;
  }

  Future<TorrentEngineDHT> startDHT({String localIp: "0.0.0.0", int localPort: 38080, bool useUpnp: false}) {
    if (_startDHTIsNow == true) {
      throw {"error": "now starting DHT"};
    }
    if(_dht == null) {
      _dht = new TorrentEngineDHT(_socketBuilder, "dht",useUpnp:useUpnp);
    }
    return _dht.start().then((_) {
      return _dht;
    }).whenComplete(() {
      _startDHTIsNow = true;
    });
  }

  Future<TorrentEngineDHT> stopDHT() {
    if (_startDHTIsNow == true) {
      _startDHTIsNow = false;
      return _dht.stop();
    } else {
      return new Future((){});
    }
  }
}

class TorrentEngine {
  TorrentClient _torrentClient = null;
  TrackerClient _trackerClient = null;
  UpnpPortMapHelper _upnpPortMapClient = null;
  HetiSocketBuilder _builder = null;

  HetiSocketBuilder get socketBuilder => _builder;
  TorrentClient get torrentClient => _torrentClient;
  TrackerClient get trackerClient => _trackerClient;
  UpnpPortMapHelper get upnpPortMapClient => _upnpPortMapClient;

  TorrentEngineAI ai = null;

  int get localPort => _torrentClient.localPort;
  String get localIp => _torrentClient.localAddress;
  int get globalPort => _torrentClient.globalPort;
  String get globalIp => _torrentClient.globalIp;

  TorrentEngineDHTMane _dhtMane = null;
  TorrentEngine._empty() {}

  Stream<TorrentEngineAIProgress> get onProgress => ai.onProgress;

  static Future<TorrentEngine> createTorrentEngine(HetiSocketBuilder builder, TorrentFile torrentfile, HetimaData downloadedData, {appid: "hetima_torrent_engine", haveAllData: false,
      int localPort: 18085, int globalPort: 18085, String globalIp: "0.0.0.0", String localIp: "0.0.0.0", int retryNum: 10, bool useUpnp: false, bool useDht: false, List<int> bitfield: null}) {
    return new Future(() {
      TorrentEngine engine = new TorrentEngine._empty();
      return TrackerClient.createTrackerClient(builder, torrentfile).then((TrackerClient trackerClient) {
        engine._builder = builder;
        engine._trackerClient = trackerClient;
        //
        engine._upnpPortMapClient = new UpnpPortMapHelper(builder, appid);
        engine.ai = new TorrentEngineAI(engine._trackerClient, engine._upnpPortMapClient);
        engine.ai.baseLocalAddress = localIp;
        engine.ai.baseLocalPort = localPort;
        engine.ai.baseGlobalPort = globalPort;
        engine.ai.baseNumOfRetry = retryNum;
        engine.ai.usePortMap = useUpnp;
        engine.ai.useDht = useDht;
        engine.ai.baseGlobalIp = globalIp;
        //
        engine._torrentClient = new TorrentClient(
            builder, trackerClient.peerId, trackerClient.infoHash, torrentfile.info.pieces, torrentfile.info.piece_length, torrentfile.info.files.dataSize, downloadedData,
            ai: engine.ai, haveAllData: haveAllData, bitfield: bitfield);

        engine._dhtMane = new TorrentEngineDHTMane(builder);
        return engine;
      });
    });
  }

  bool _isGO = false;
  bool get isGo => _isGO;

  Future start({usePortMap: false}) {
    ai.usePortMap = usePortMap;
    return ai.start().then((v) {
      _isGO = true;
      if (this.ai.useDht) {
        return _dhtMane.startDHT(useUpnp:usePortMap).then((_) {
          return v;
        });
      } else {
        return v;
      }
    }).catchError((e) {
      throw e;
    });
  }

  Future stop() {
    return ai.stop().whenComplete(() {
      _isGO = false;
      return _dhtMane.stopDHT();
    });
  }
}
