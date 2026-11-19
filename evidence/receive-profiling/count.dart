import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  final uri = Uri.parse(File(args.single).readAsStringSync().trim());
  final socket = uri.replace(scheme: 'ws', pathSegments: [...uri.pathSegments.where((s) => s.isNotEmpty), 'ws']);
  final vm = await vmServiceConnectUri(socket.toString());
  final isolate = (await vm.getVM()).isolates!.firstWhere((i) => i.name == 'main');
  final id = isolate.id!;
  final clock = Stopwatch()..start();
  vm.onGCEvent.where((e) => e.isolate?.id == id).listen((e) {
    print(jsonEncode({'ms': clock.elapsedMilliseconds, 'event': 'gc', 'type': e.gcType}));
  });
  await vm.streamListen(EventStreams.kGC);
  Future<void> sample(String label, {bool collect = false}) async {
    final profile = await vm.getAllocationProfile(id, gc: collect ? true : null);
    final result = <String, dynamic>{'ms': clock.elapsedMilliseconds, 'event':label,
      'heapUsed':profile.memoryUsage?.heapUsage};
    for (final c in profile.members ?? <ClassHeapStats>[]) {
      final name = c.classRef?.name;
      if (['NewReceivePage','_NewReceivePageState','ReceiveLabelModal','_ReceiveLabelModalState','TextEditingController'].contains(name)) {
        result[name!] = c.instancesCurrent;
      }
    }
    print(jsonEncode(result));
  }
  await sample('initial', collect: true);
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line == 'stop') break;
    await sample(line, collect: true);
  }
  await vm.dispose();
}
