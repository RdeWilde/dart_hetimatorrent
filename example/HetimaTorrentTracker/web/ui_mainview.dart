library app.mainview;

import 'dart:html' as html;
import 'package:hetimacore/hetimacore.dart';
import 'package:hetimacore/hetimacore_cl.dart';
import 'package:hetimanet/hetimanet.dart';
import 'package:hetimatorrent/hetimatorrent.dart';
import 'ui_dialog.dart';
import 'model_tracker.dart';

class MainItem {
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

  void init(TrackerModel model, Map<String, TorrentFile> managedTorrentFile, Tab tab, Dialog dialog) {
    fileInput.onChange.listen((html.Event e) {
      print("==");
      if (fileInput.files != null && fileInput.files.length > 0) {
        html.File n = fileInput.files[0];
        TorrentFile.createTorrentFileFromTorrentFile(new HetimaFileToBuilder(new HetimaDataBlob(n))).then((TorrentFile f) {
          return f.createInfoSha1().then((List<int> infoHash) {
            String key = PercentEncode.encode(infoHash);
            managedTorrentFile[key] = f;
            tab.add("${key}", "con-now");
            model.addInfoHashFromTracker(f);
          });
        }).catchError((e) {
          dialog.show("Failed to parse torrent");
        });
      }
    });

    startServerBtn.onClick.listen((html.MouseEvent e) {
      loadServerBtn.style.display = "block";
      stopServerBtn.style.display = "none";
      startServerBtn.style.display = "none";

      model.startTracker(inputLocalAddress.value, int.parse(inputLocalPort.value), int.parse(inputGlobalPort.value)).then((List<String> v) {
        outputLocalPortSpn.innerHtml = v[1];
        outputLocalAddressSpn.innerHtml = v[0];
        stopServerBtn.style.display = "block";
        startServerBtn.style.display = "none";
        loadServerBtn.style.display = "none";
      }).catchError((e) {
        stopServerBtn.style.display = "none";
        startServerBtn.style.display = "block";
        loadServerBtn.style.display = "none";
        dialog.show("Failed to start tracker");
      });
    });

    stopServerBtn.onClick.listen((html.MouseEvent e) {
      loadServerBtn.style.display = "block";
      stopServerBtn.style.display = "none";
      startServerBtn.style.display = "none";

      model.stopTracker().then((StopResult r) {
        startServerBtn.style.display = "block";
        stopServerBtn.style.display = "none";
        loadServerBtn.style.display = "none";
      }).catchError((e) {
        startServerBtn.style.display = "none";
        stopServerBtn.style.display = "block";
        loadServerBtn.style.display = "none";
        dialog.show("Failed to stop tracker");
      });
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
}
