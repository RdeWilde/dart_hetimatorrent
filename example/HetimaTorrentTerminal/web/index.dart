library app;

import 'dart:html' as html;
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimacore/hetimacore_cl.dart';
import 'package:hetimanet/hetimanet.dart';
import 'package:hetimanet/hetimanet_chrome.dart';

import 'package:hetimatorrent/hetimatorrent.dart';
import 'terminal.dart';
import 'dialogtab.dart';

Tab tab = new Tab({"#m00_clone": "#con-clone"});
Dialog dialog = new Dialog();

Map<String, TorrentFile> managedTorrentFile = {};
Map<String, TorrentEngine> managedEngine = {};




bool upnpIsUse = false;
String selectKey = null;

TorrentClient torrentClient = null;

void main() {
  html.InputElement fileInput = html.querySelector("#fileinput");
  html.InputElement managedfile = html.querySelector("#managedfile");

// TrackerServer trackerServer = new TrackerServer(new HetiSocketBuilderChrome());
  UpnpPortMapHelper portMapHelder = new UpnpPortMapHelper(new HetiSocketBuilderChrome(), "HetimaTorrentTracker");

  //
  //
  html.SpanElement torrentHashSpan = html.querySelector("#torrent-hash");
  html.SpanElement torrentRemoveBtn = html.querySelector("#torrent-remove-btn");
  html.InputElement torrentSeedFile= html.querySelector("#torrent-seeddata");
  
  
  print("hello world");
  
  tab.init();
  dialog.init();

  torrentRemoveBtn.onClick.listen((html.MouseEvent e) {
    if(selectKey != null) {
      tab.remove(selectKey);
      managedTorrentFile.remove(selectKey);
      print("##===> ${managedTorrentFile.length}");
      selectKey = null;
      managedTorrentFile.remove(selectKey);
      managedEngine.remove(selectKey);
    }
  });

  torrentSeedFile.onChange.listen((html.Event e) {
     if(torrentSeedFile == null || torrentSeedFile.files.length == 0) {
       return;
     }
     torrentSeedFile.style.display = "none";
     html.File targetFile = torrentSeedFile.files[0];
     managedEngine[selectKey].torrentClient.targetBlock.writeFullData(new HetimaDataBlob(targetFile)).then((WriteResult r) {
       torrentSeedFile.style.display = "block";       
     });
  });

  int  v = 0;
  fileInput.onChange.listen((html.Event e) {
    print("=finle selected=");
    List<html.File> s = [];
    print("##===> ${fileInput.files}");
    s.addAll(fileInput.files);
    while (s.length > 0) {
      html.File n = s.removeAt(0);
      print("#${n.name} ${e}");
      TorrentFile.createTorrentFileFromTorrentFile(new HetimaFileToBuilder(new HetimaDataBlob(n))).then((TorrentFile f) {
        return f.createInfoSha1().then((List<int> infoHash) {
          String key = PercentEncode.encode(infoHash);
          tab.add("${key}", "con-termi");
          return TorrentEngine.createTorrentEngine(new HetiSocketBuilderChrome(), f, new HetimaDataFS("aZ${v++}",erace:true)).then((TorrentEngine engine) {
            Terminal terminal = new Terminal(engine, '#command-input-line', '#command-output', '#command-cmdline');
            Terminal terminalReceive = new Terminal(engine,'#event-input-line', '#event-output', '#event-cmdline');
 
            terminal.addCommand(StartTorrentClientCommand.name, StartTorrentClientCommand.builder());
            terminal.addCommand(GetLocalIpCommand.name, GetLocalIpCommand.builder());
            terminal.addCommand(StartUpnpPortMapCommand.name, StartUpnpPortMapCommand.builder());
            terminal.addCommand(StopUpnpPortMapCommand.name, StopUpnpPortMapCommand.builder());
            terminal.addCommand(GetUpnpPortMapInfoCommand.name, GetUpnpPortMapInfoCommand.builder());
            terminal.addCommand(TrackerCommand.name, TrackerCommand.builder());
            terminal.addCommand(GetPeerInfoCommand.name, GetPeerInfoCommand.builder());
            terminal.addCommand(HandshakeCommand.name, HandshakeCommand.builder());
            terminal.addCommand(ConnectCommand.name, ConnectCommand.builder());
            terminal.addCommand(BitfieldCommand.name, BitfieldCommand.builder());
            
            engine.torrentClient.onReceiveEvent.listen((TorrentClientMessage info) {
              print("[receive message :  ${info.message.id}");
              terminalReceive.append("receive message : ${info.message.id}");
            });
            managedTorrentFile[key] = f;
            managedEngine[key] = engine;

          });
        });
      }).catchError((e) {
        dialog.show("failed parse torrent");
      });
    }
  });

  tab.onShow.listen((TabInfo info) {
    String t = info.cont;
    print("=t= ${t}");

      String key = info.key;
      if (managedTorrentFile.containsKey(key)) {
        torrentHashSpan.setInnerHtml("${key}");
        selectKey = key;
//        List<int> infoHash = PercentEncode.decode(info.key);
//        torrentNumOfPeerSpan.setInnerHtml("${trackerServer.numOfPeer(infoHash)}");
      }
  });

}

