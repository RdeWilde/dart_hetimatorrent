library hetimatorrent.torrent.file.iso;

import "dart:isolate";
import 'package:hetimatorrent/hetimatorrent.dart';

void main(List<String> args, SendPort sendPort) {
  SHA1IsoSub sub = new SHA1IsoSub();
  sub.main(args, sendPort);
}
