import 'package:hetimatorrent/hetimatorrent.dart';
import 'package:hetimanet/hetimanet_dartio.dart';
import 'package:hetimacore/hetimacore_dartio.dart';
import 'package:hetimacore/hetimacore.dart';
import 'package:args/args.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DHT {
  KNode node = new KNode(new HetimaSocketBuilderDartIO(verbose: false));
  Future start(String ip, int port) {
    return node.start(ip: ip, port: port).then((_) {
      node.onGetPeerValue.listen((KGetPeerValue v) {
        print("---onGetPeerValue ${v.ipAsString} ${v.port} ${v.infoHashAsString} ");
      });
    });
  }

  Future stop() {
    return node.stop();
  }

  addNode(String ip, int port) {
    node.addBootNode(ip, port);
  }

  Future addTarget(List<int> infoHash) {
    return node.startSearchValue(new KId(infoHash), 18080, getPeerOnly: true);
  }

  Future rmTarget(List<int> infoHash) {
    return node.stopSearchPeer(new KId(infoHash));
  }

  String log() {
    return node.rootingtable.toInfo().replaceAll("\n", "<br>");
  }
  
  l() {
  }
}

main(List<String> args) async {
  aaa(args);
}

bool logOnReceiveMessage = false;

Future<DHT> aaa(List<String> args) async {
  String exec = Platform.executable;
  List<String> flags = Platform.executableArguments;
  print("hello ${exec} ${flags} ${args}");

  ArgParser parser = new ArgParser()
    ..addFlag("a", negatable: true, abbr: 'a')
    ..addFlag("b", negatable: false, abbr: 'b')
    ..addOption("c", abbr: 'c');
  ArgResults result = parser.parse(args);
  print("${result.rest} ${result['a']} ${result['b']} ${result['c']}");

  bool nowActing = false;
  DHT dht = new DHT();
  stdin.asBroadcastStream().listen((List<int> v) {
    if (nowActing == true) {
      return;
    }
    nowActing = true;
    b(dht, v).then((_) {
      nowActing = false;
      print("---ok!!");
    }).catchError((_) {
      nowActing = false;
      print("---error!!");
    });
  });
  return dht;
}

Future b(DHT dht, List<int> v) async {
  String line = UTF8.decode(v);
  List<String> lineparts = line.split(new RegExp("[ ]+|\t|\r\n|\r|\n"));
  if (lineparts.length == 0) {
    return null;
  }

  String action = lineparts[0];
  List<String> args = [];
  if (lineparts.length > 1) {
    args.addAll(lineparts.sublist(1));
  }
  return a(dht, action, args);
}

Future a(DHT dht, String action, List<String> args) async {
  print(">> action:${action} args:${args}");
  switch (action.toLowerCase()) {
    case "help":
      print("""
        exit : exit this application.
        start <ip:striing> <port:number> :
        stop :
        addBootNode <ip:string> <port:number>
        addTraget <xx.torrent path:string>:
      """);
      break;
    case "exit":
      print("..\ngoodbye!!\n..\n");
      exit(0);
      break;
    case "start":
      dht.start(args[0], int.parse(args[1]));
      break;
    case "stop":
      dht.stop();
      break;
    case "addbootnode":
      dht.addNode(args[0], int.parse(args[1]));
      break;
    case "addtarget":
      TorrentFile torrentfile = await TorrentFile.createFromTorrentFile(new HetimaDataToReader(new HetimaDataDartIO(args[0])));
      print("f = ${torrentfile}");
      print("f.announce = ${torrentfile.announce}");
      List<int> infohash = await torrentfile.createInfoSha1();
      dht.addTarget(infohash);
      break;
    case "infohashs":
      break;
    case "rmtarget":
      
      break;
    case "messageon":
      print("meesageon");
      logOnReceiveMessage = true;
      break;
    case "messageoff":
      logOnReceiveMessage = false;
      break;
    default:
      throw "commmand not found";
  }
}


onReceiveMessage(TorrentClientMessage message) {
  if(logOnReceiveMessage == true) {
    print("message = ${message}");
  }
}