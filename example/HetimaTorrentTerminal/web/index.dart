library app;

import 'dart:html' as html;
import 'dart:async';
import 'package:chrome/chrome_app.dart' as chrome;
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimacore/hetimacore_cl.dart';
import 'package:hetimanet/hetimanet.dart';
import 'package:hetimanet/hetimanet_chrome.dart';

import 'package:hetimatorrent/hetimatorrent.dart';
import 'terminal.dart';

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

// TrackerServer trackerServer = new TrackerServer(new HetiSocketBuilderChrome());
UpnpPortMapHelper portMapHelder = new UpnpPortMapHelper(new HetiSocketBuilderChrome(), "HetimaTorrentTracker");

//
//
html.SpanElement torrentHashSpan = html.querySelector("#torrent-hash");
html.SpanElement torrentRemoveBtn = html.querySelector("#torrent-remove-btn");
html.SpanElement torrentNumOfPeerSpan = html.querySelector("#torrent-num-of-peer");

bool upnpIsUse = false;
String selectKey = null;

TorrentClient torrentClient = null;

void main() {
  /*

*/
  print("hello world");
  
  tab.init();
  dialog.init();

  torrentRemoveBtn.onClick.listen((html.MouseEvent e) {
    if(selectKey != null) {
      tab.remove(selectKey);
      managedTorrentFile.remove(selectKey);
      print("##===> ${managedTorrentFile.length}");
      selectKey = null;
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
          tab.add("${key}", "con-termi");
          TorrentEngine.createTorrentEngine(new HetiSocketBuilderChrome(), f).then((TorrentEngine engine) {
            Terminal terminal = new Terminal(engine, '#command-input-line', '#command-output', '#command-cmdline');
            Terminal terminalReceive = new Terminal(engine,'#event-input-line', '#event-output', '#event-cmdline');
            
            terminal.addCommand("startTorrent", StartTorrentClientCommand.builder);
            terminal.addCommand("portMap", UpnpPortMapCommand.builder);
            terminal.addCommand("getLocalIp", GetLocalIpCommand.builder);
          }).catchError((e){
            ;
          });
        });
      }).catchError((e) {
        dialog.show("failed parse torrent");
      });
    }
  });
/*
  startServerBtn.onClick.listen((html.MouseEvent e) {
    if(torrentClient == null) {
      torrentClient = new TorrentClient(new HetiSocketBuilderChrome());
    }
    torrentClient.localAddress = inputLocalAddress.value;
    torrentClient.port = int.parse(inputLocalPort.value);
    torrentClient.start().then((_){
      startServerBtn.style.display = "none";
      loadServerBtn.style.display = "none";
      stopServerBtn.style.display = "block";

      print("torrent client started");
      if(upnpIsUse) {
        portMapHelder.basePort = torrentClient.port;
        portMapHelder.numOfRetry = 0;
        portMapHelder.startPortMap();
      }
      outputLocalAddressSpn.setInnerHtml(torrentClient.localAddress);
      outputLocalPortSpn.setInnerHtml("${torrentClient.port}");
    }).catchError((e){
      startServerBtn.style.display = "block";
      loadServerBtn.style.display = "none";      
    });
    startServerBtn.style.display = "none";
    loadServerBtn.style.display = "block";
  });

  stopServerBtn.onClick.listen((html.MouseEvent e) {
    startServerBtn.style.display = "block";
    loadServerBtn.style.display = "none";
    stopServerBtn.style.display = "none";

    portMapHelder.deleteAllPortMap();
    torrentClient.stop().then((_){
      print("torrent client stoped");
    });
  });
*/
  tab.onShow.listen((TabInfo info) {
    String t = info.cont;
    print("=t= ${t}");

      String key = info.key;
      if (managedTorrentFile.containsKey(key)) {
        torrentHashSpan.setInnerHtml("${info.key}");
        selectKey = key;
//        List<int> infoHash = PercentEncode.decode(info.key);
//        torrentNumOfPeerSpan.setInnerHtml("${trackerServer.numOfPeer(infoHash)}");
      }
  });
/*
  // Adds a click event for each radio button in the group with name "gender"
  html.querySelectorAll('[name="upnpon"]').forEach((html.InputElement radioButton) {
    radioButton.onClick.listen((html.MouseEvent e) {
      html.InputElement clicked = e.target;
      print("The user is ${clicked.value}");
      if(clicked.value == "Use") {
        upnpIsUse = true;
      } else {
        upnpIsUse = false;
      }
    });
  });
  
  portMapHelder.onUpdateGlobalIp.listen((String globalIP) {
    outputGlobalAddressSpn.setInnerHtml(globalIP);
  });

  portMapHelder.onUpdateGlobalPort.listen((String globalPort) {
    outputGlobalPortSpn.setInnerHtml(globalPort);    
  });

  print("=s=");
  
  
  portMapHelder.startGetLocalIp().then((StartGetLocalIPResult result) {
     inputLocalAddress.value = result.localIP;
   });
  */
}

class Dialog {
  html.Element dialog = html.querySelector('#dialog');
  html.ButtonElement dialogBtn = html.querySelector('#dialog-btn');
  html.ButtonElement dialogMessage = html.querySelector('#dialog-message');

  Dialog() {
    init();
  }

  void init() {
    dialogBtn.onClick.listen((html.MouseEvent e) {
      dialog.style.display = "none";
    });
  }

  void show(String message) {
    dialog.style.left = "${html.window.innerWidth/2-100}px";
    dialog.style.top = "${html.window.innerHeight/2-100}px";
    dialog.style.position = "absolute";
    dialog.style.display = "block";
    dialog.style.width = "200px";
    dialog.style.zIndex = "50";
    dialogMessage.value = message;
  }
}

class Tab {
  html.InputElement tabContainer = html.querySelector("#tabcont");
  Map<String, String> tabs = {
    "#m00_clone": "#con-clone",
//    "#m00_termi": "#con-termi"
  };

  html.Element current = null;

  int v = 100;
  Map<String, String> keyManager = {};
  void add(String key, String cont) {
    keyManager[key] = "#d00_${v++}";
    tabs[keyManager[key]] = "#${cont}";
    html.Element e = new html.Element.html("""<li id="${(keyManager[key]).substring(1)}">${key.substring(0,4)}</li>""");
    tabContainer.append(e);
    updateTab();
  }

  void remove(String key) {
    tabs.remove(keyManager[key]);
    html.Element t = html.querySelector(keyManager[key]);
    if (t != null) {
      tabContainer.nodes.remove(t);
    }
    updateTab();
  }

  void selectTab(String id) {
    html.Element i = html.querySelector(id);
    print("##click ${i}");

    display([id]);
    i.classes.add("selected");
    if (current != null && current != i) {
      current.classes.remove("selected");
    }
    current = i;

    update([id]);
  }

  void init() {
    updateTab();
  }

  void updateTab() {
    for (String t in tabs.keys) {
      html.Element i = html.querySelector(t);
      i.onClick.listen((html.MouseEvent e) {
        selectTab(t);
      });
    }
  }

  void display(List<String> displayList) {
    List<html.Element> blockList = [];
    for (String t in tabs.keys) {
      if (displayList.contains(t)) {
        html.Element tt = html.querySelector(tabs[t]);
        if (tt != null) {
          blockList.add(tt);
        }
      } else {
        html.Element tt = html.querySelector(tabs[t]);
        if (tt != null) {
          tt.style.display = "none";
        }
      }
    }
    for(html.Element tt in blockList) {
      tt.style.display = "block";
    }
  }

  StreamController<TabInfo> _controller = new StreamController<TabInfo>();
  Stream<TabInfo> get onShow => _controller.stream;
  void update(List<String> ids) {
    for (String id in ids) {
      if (tabs.containsKey(id)) {
        TabInfo ret = new TabInfo()
                  ..cont = tabs[id]
                  ..key = id;
        if(keyManager.containsValue(id)){
          for(String key in keyManager.keys) {
            if(keyManager[key] == id) {
              ret.key = key;
              break;
            }
          }
        }
        _controller.add(ret);
      }
    }
  }
}

class TabInfo {
  String key;
  String cont;
}
