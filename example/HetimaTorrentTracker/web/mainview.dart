library app.mainview;

import 'dart:html' as html;
import 'dart:async';
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimacore/hetimacore_cl.dart';
import 'package:hetimanet/hetimanet.dart';
import 'package:hetimanet/hetimanet_chrome.dart';

import 'package:hetimatorrent/hetimatorrent.dart';
import 'dialog.dart';

class Model {
  bool upnpIsUse = false;
  String selectKey = null;

///
  TrackerServer trackerServer = new TrackerServer(new HetiSocketBuilderChrome());
  UpnpPortMapHelper portMapHelder = new UpnpPortMapHelper(new HetiSocketBuilderChrome(), "HetimaTorrentTracker");

  void onRemoveInfoHashFromTracker(List<int> removeHash) {
    trackerServer.removeInfoHash(PercentEncode.decode(selectKey));
  }

  void onAddInfoHashFromTracker(TorrentFile f) {
    trackerServer.addInfoHash(f);
  }

  Future onStop() {
    // clear
    trackerServer.trackerAnnounceAddressForTorrentFile = "";

    portMapHelder.getPortMapInfo(portMapHelder.appid).then((GetPortMapInfoResult r) {
      if (r.infos.length > 0 && r.infos[0].externalPort.length != 0) {
        int port = int.parse(r.infos[0].externalPort);
        portMapHelder.deleteAllPortMap([port]);
      }
    }).catchError((e) {
      ;
    });

    return trackerServer.stop();
  }

  Future onStart(String localIP, int localPort, int globalPort) {
    trackerServer.address = localIP;
    trackerServer.port = localPort;
    return trackerServer.start().then((StartResult r) {
      if (upnpIsUse == true) {
        portMapHelder.basePort = globalPort;
        portMapHelder.numOfRetry = 0;
        portMapHelder.localAddress = localIP;
        portMapHelder.localPort = localPort;

        portMapHelder.startGetExternalIp().then((_) {}).catchError((e) {}).whenComplete(() {
          portMapHelder.startPortMap().then((_) {
            trackerServer.trackerAnnounceAddressForTorrentFile = "http://${portMapHelder.externalIp}:${portMapHelder.externalPort}/announce";
          }).catchError((e) {
            print("error ${e}");
          });
        });
      }
      return [trackerServer.address, "${trackerServer.port}"];
    });
  }

  int onGetNumOfPeer(List<int> infoHash) {
    return trackerServer.numOfPeer(infoHash);
  }
}


//
//
//
Tab tab = new Tab();
Dialog dialog = new Dialog();
Map<String, TorrentFile> managedTorrentFile = {};

html.InputElement fileInput = html.querySelector("#fileinput");
html.InputElement managedfile = html.querySelector("#managedfile");

html.InputElement startServerBtn = html.querySelector("#startserver");
html.InputElement stopServerBtn = html.querySelector("#stopserver");
html.InputElement loadServerBtn = html.querySelector("#loaderserver");

html.SpanElement outputLocalAddressSpn = html.querySelector("#localaddress");
html.SpanElement outputLocalPortSpn = html.querySelector("#localport");
html.SpanElement outputGlobalAddressSpn = html.querySelector("#globaladdress");
html.SpanElement outputGlobalPortSpn = html.querySelector("#globalport");

html.InputElement inputLocalAddress = html.querySelector("#input-localaddress");
html.InputElement inputLocalPort = html.querySelector("#input-localport");
html.InputElement inputGlobalPort = html.querySelector("#input-globalport");

//
//
html.SpanElement torrentHashSpan = html.querySelector("#torrent-hash");
html.SpanElement torrentRemoveBtn = html.querySelector("#torrent-remove-btn");
html.SpanElement torrentNumOfPeerSpan = html.querySelector("#torrent-num-of-peer");


Model model = new Model();
//
//
//
void main() {
  print("hello world");
  tab.init();
  dialog.init();

  torrentRemoveBtn.onClick.listen((html.MouseEvent e) {
    if (model.selectKey != null) {
      tab.remove(model.selectKey);
      managedTorrentFile.remove(model.selectKey);
      model.onRemoveInfoHashFromTracker(PercentEncode.decode(model.selectKey));
      model.selectKey = null;
    }
  });

  fileInput.onChange.listen((html.Event e) {
    print("==");
    List<html.File> s = [];
    s.addAll(fileInput.files);
    while (s.length > 0) {
      html.File n = s.removeAt(0);
      print("#${n.name} ${e}");
      TorrentFile.createTorrentFileFromTorrentFile(new HetimaFileToBuilder(new HetimaDataBlob(n))).then((TorrentFile f) {
        return f.createInfoSha1().then((List<int> infoHash) {
          String key = PercentEncode.encode(infoHash);
          managedTorrentFile[key] = f;
          tab.add("${key}", "con-now");
          model.onAddInfoHashFromTracker(f);
        });
      }).catchError((e) {
        dialog.show("failed parse torrent");
      });
    }
  });

  startServerBtn.onClick.listen((html.MouseEvent e) {
    loadServerBtn.style.display = "block";
    stopServerBtn.style.display = "none";
    startServerBtn.style.display = "none";

    model.onStart(inputLocalAddress.value, int.parse(inputLocalPort.value), int.parse(inputGlobalPort.value)).then((List<String> v) {
      outputLocalPortSpn.innerHtml = v[1];
      outputLocalAddressSpn.innerHtml = v[0];
      stopServerBtn.style.display = "block";
      startServerBtn.style.display = "none";
      loadServerBtn.style.display = "none";
    }).catchError((e) {
      stopServerBtn.style.display = "none";
      startServerBtn.style.display = "block";
      loadServerBtn.style.display = "none";
    });
  });

  stopServerBtn.onClick.listen((html.MouseEvent e) {
    loadServerBtn.style.display = "block";
    stopServerBtn.style.display = "none";
    startServerBtn.style.display = "none";

    model.onStop().then((StopResult r) {
      startServerBtn.style.display = "block";
      stopServerBtn.style.display = "none";
      loadServerBtn.style.display = "none";
    }).catchError((e) {
      startServerBtn.style.display = "none";
      stopServerBtn.style.display = "block";
      loadServerBtn.style.display = "none";
    });
  });

  tab.onShow.listen((TabInfo info) {
    String t = info.cont;
    print("=t= ${t}");

    String key = info.key;
    if (managedTorrentFile.containsKey(key)) {
      torrentHashSpan.setInnerHtml("${info.key}");
      model.selectKey = key;
      List<int> infoHash = PercentEncode.decode(info.key);
      torrentNumOfPeerSpan.setInnerHtml("${model.onGetNumOfPeer(infoHash)}");
    }
  });

  // Adds a click event for each radio button in the group with name "gender"
  html.querySelectorAll('[name="upnpon"]').forEach((html.InputElement radioButton) {
    radioButton.onClick.listen((html.MouseEvent e) {
      html.InputElement clicked = e.target;
      print("The user is ${clicked.value}");
      if (clicked.value == "Use") {
        model.upnpIsUse = true;
      } else {
        model.upnpIsUse = false;
      }
    });
  });

  model.portMapHelder.onUpdateGlobalIp.listen((String globalIP) {
    outputGlobalAddressSpn.setInnerHtml(globalIP);
  });

  model.portMapHelder.onUpdateGlobalPort.listen((String globalPort) {
    outputGlobalPortSpn.setInnerHtml(globalPort);
  });

  model.portMapHelder.startGetLocalIp().then((StartGetLocalIPResult result) {
    inputLocalAddress.value = result.localIP;
  });
}
