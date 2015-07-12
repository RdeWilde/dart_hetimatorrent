library app.mainview.hashitem;

import 'dart:html' as html;
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimacore/hetimacore_cl.dart';
import 'package:hetimatorrent/hetimatorrent.dart';
import 'ui_dialog.dart';
import 'model_seeder.dart';
import 'model_main.dart';
import 'package:chrome/chrome_app.dart' as chrome;
//
//
class HashItem {
  html.SpanElement torrentHashSpan = html.querySelector("#torrent-hash");
  html.SpanElement torrentRemoveBtn = html.querySelector("#torrent-remove-btn");

  html.InputElement globalAddress = html.querySelector("#torrent-input-globaladdress");
  html.InputElement localAddress = html.querySelector("#torrent-input-localaddress");
  html.InputElement localport = html.querySelector("#torrent-input-localport");
  html.InputElement globalport = html.querySelector("#torrent-input-globalport");
  html.ButtonElement startServerBtn = html.querySelector("#torrent-startserver");
  html.ButtonElement stopServerBtn = html.querySelector("#torrent-stopserver");
  html.ObjectElement loadServerBtn = html.querySelector("#torrent-loaderserver");

  html.InputElement upnpUse = html.querySelector("#torrent-upnpon-use");
  html.InputElement upnpUnuse = html.querySelector("#torrent-upnpon-unuse");


  html.AnchorElement torrentOutput = html.querySelector("#torrent-output");
  Map<String, int> seedState = {};
  Map<String, SeederModel> seedModels = {};
//  html.File seedRawFile = null;
  init(AppModel trackerModel, Map<String, TorrentFile> managedTorrentFile, Tab tab, Dialog dialog) {
    //   SeederModel model = new SeederModel();

    torrentRemoveBtn.onClick.listen((html.MouseEvent e) {
      if (trackerModel.selectKey != null) {
        tab.remove(trackerModel.selectKey);
        managedTorrentFile.remove(trackerModel.selectKey);
        trackerModel.selectKey = null;
      }
    });

    startServerBtn.onClick.listen((html.MouseEvent e) {
      String key = trackerModel.selectKey;
      loadServerBtn.style.display = "block";
      stopServerBtn.style.display = "none";
      startServerBtn.style.display = "none";
      seedState[key] = 3; //loading
      TorrentFile torrentFile = managedTorrentFile[trackerModel.selectKey];
      seedModels[key].globalPort = int.parse(globalport.value);
      seedModels[key].localPort = int.parse(localport.value);
      seedModels[key].localIp = localAddress.value;
      seedModels[key].globalIp = globalAddress.value;
      seedModels[key].startEngine(torrentFile,  new HetimaDataFS("${key}.cont", erace:false)).then((SeederModelStartResult ret) {
        seedState[key] = 2; //stop
        localAddress.value = ret.localIp;
        localport.value = "${ret.localPort}";
        globalport.value = "${ret.globalPort}";
        globalAddress.value = "${ret.globalIp}";
        stopServerBtn.style.display = "block";
        startServerBtn.style.display = "none";
        loadServerBtn.style.display = "none";
      }).catchError((e) {
        seedState[key] = 1; //start
        stopServerBtn.style.display = "none";
        startServerBtn.style.display = "block";
        loadServerBtn.style.display = "none";
        dialog.show("Failed to start torrent");
      });
    });

    stopServerBtn.onClick.listen((html.MouseEvent e) {
      String key = trackerModel.selectKey;
      loadServerBtn.style.display = "block";
      stopServerBtn.style.display = "none";
      startServerBtn.style.display = "none";
      seedState[key] = 3; //loading
      seedModels[key].stopEngine().then((StopResult r) {
        seedState[key] = 1; //start
        startServerBtn.style.display = "block";
        stopServerBtn.style.display = "none";
        loadServerBtn.style.display = "none";
      }).catchError((e) {
        seedState[key] = 2; //stop
        startServerBtn.style.display = "none";
        stopServerBtn.style.display = "block";
        loadServerBtn.style.display = "none";
        dialog.show("Failed to stop torrent");
      });
    });

    // Adds a click event for each radio button in the group with name "gender"
    html.querySelectorAll('[name="torrent-upnpon"]').forEach((html.InputElement radioButton) {
      radioButton.onClick.listen((html.MouseEvent e) {
        String key = trackerModel.selectKey;
        html.InputElement clicked = e.target;
        print("The user is ${clicked.value}");
        if (clicked.value == "Use") {
          seedModels[key].useUpnp = true;
        } else {
          seedModels[key].useUpnp = false;
        }
      });
    });

    html.querySelectorAll('[name="torrent-upnpon"]').forEach((html.InputElement radioButton) {
      radioButton.onClick.listen((html.MouseEvent e) {
        String key = trackerModel.selectKey;
        html.InputElement clicked = e.target;
        print("The user is ${clicked.value}");
        if (clicked.value == "Use") {
          seedModels[key].useUpnp = true;
        } else {
          seedModels[key].useUpnp = false;
        }
      });
    });
    
    torrentOutput.onClick.listen((_) {
      print("click");
      String key = trackerModel.selectKey;
      saveFile(seedModels[key].seed);
    });
  }

  void contain(AppModel model, Map<String, TorrentFile> managedTorrentFile, String key) {
    if (managedTorrentFile.containsKey(key)) {
      if (false == seedModels.containsKey(key)) {
        seedModels[key] = new SeederModel();
      }

      torrentHashSpan.setInnerHtml("${key}");
      model.selectKey = key;
      localAddress.style.display = "block";
      localport.style.display = "block";
      globalAddress.style.display = "block";
      globalport.style.display = "block";

      if (seedState.containsKey(key) == false || seedState[key] == 1) {
        //start
        startServerBtn.style.display = "block";
        stopServerBtn.style.display = "none";
        loadServerBtn.style.display = "none";
      } else if (seedState[key] == 2) {
        //stop
        startServerBtn.style.display = "none";
        stopServerBtn.style.display = "block";
        loadServerBtn.style.display = "none";
      } else if (seedState[key] == 3) {
        //loading
        startServerBtn.style.display = "none";
        stopServerBtn.style.display = "none";
        loadServerBtn.style.display = "block";
      }

      //
      globalAddress.value = seedModels[key].globalIp;
      localAddress.value = seedModels[key].localIp;
      localport.value = "${seedModels[key].localPort}";
      globalport.value = "${seedModels[key].globalPort}";
      if (seedModels[key].useUpnp) {
        upnpUse.checked = true;
      } else {
        upnpUnuse.checked = true;
      }
    }
  }

  void saveFile(HetimaData copyFrom) {
      chrome.fileSystem.chooseEntry(new chrome.ChooseEntryOptions(type: chrome.ChooseEntryType.SAVE_FILE, suggestedName: "rawdata")).then((chrome.ChooseEntryResult chooseEntryResult) {        
        chrome.fileSystem.getWritableEntry(chooseEntryResult.entry).then((chrome.ChromeFileEntry copyTo) {
          copyFrom.getLength().then((int length) {
            copyFrom.read(0, length).then((ReadResult readResult) {
              chrome.ArrayBuffer buffer = new chrome.ArrayBuffer.fromBytes(readResult.buffer.toList());
              copyTo.writeBytes(buffer);
            });
          });
        });
      });
  }
}
