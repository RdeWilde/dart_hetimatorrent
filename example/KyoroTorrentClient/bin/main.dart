import 'package:hetimatorrent/hetimatorrent.dart';
import 'package:hetimanet/hetimanet_dartio.dart';
import 'package:hetimacore/hetimacore_dartio.dart';
import 'package:hetimacore/hetimacore.dart';
import 'package:args/args.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

main(List<String> args) async {
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
  TorrentEngine engine = new TorrentEngine(new HetimaSocketBuilderDartIO(), localPort: 18080, globalPort: 18080, useUpnp: true, useDht: true);
  stdin.asBroadcastStream().listen((List<int> v) {
    if (nowActing == true) {
      return;
    }
    nowActing = true;
    b(engine, v).then((_) {
      nowActing = false;
      print("---ok!!");
    }).catchError((_) {
      nowActing = false;
      print("---error!!");
    });
  });
}

Future b(TorrentEngine engine, List<int> v) async {
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
  return a(engine, action, args);
}

Future a(TorrentEngine engine, String action, List<String> args) async {
  print(">> action:${action} args:${args}");
  switch (action) {
    case "help":
      print("..\ngoodbye!!\n..\n");
      break;
    case "exit":
      print("..\ngoodbye!!\n..\n");
      exit(0);
      break;
    case "hello":
      print("hello");
      break;
    case "start":
      return engine.start();
    case "stop":
      return engine.stop();
    case "add":
      TorrentFile torrentfile = await TorrentFile.createFromTorrentFile(new HetimaDataToReader(new HetimaDataDartIO(args[0])));
      print("f = ${torrentfile}");
      print("f.announce = ${torrentfile.announce}");
      List<int> infohash = await torrentfile.createInfoSha1();
      return await engine.addTorrent(torrentfile, new HetimaDataDartIO("./${CryptoUtils.bytesToBase64(infohash)}.dat"));      
    case "infohashs":
      int id = 0;
      print("[ index ]  :  infohash");
      for(List<int> infohash in engine.infoHashs) {
        print("[ ${id} ]  :  ${CryptoUtils.bytesToBase64(infohash)}");
      }
      break;
    case "startclient":
      return await engine.getTorrentFromIndex(int.parse(args[0])).startTorrent(engine);
    case "stopclient":
      return await engine.getTorrentFromIndex(int.parse(args[0])).stopTorrent();
    default:
      throw "commmand not found";
  }
}


c(TorrentEngine engine, String path) async {
  print("SSS = ${path}");

}