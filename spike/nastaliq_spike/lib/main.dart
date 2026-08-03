import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import 'biodata_page.dart';
import 'pipeline_a.dart';
import 'pipeline_b.dart';
import 'pipeline_c.dart';
import 'samples.dart';
import 'spec.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(debugShowCheckedModeBanner: false, home: SpikeHome());
}

class SpikeHome extends StatefulWidget {
  const SpikeHome({super.key});

  @override
  State<SpikeHome> createState() => _SpikeHomeState();
}

class _SpikeHomeState extends State<SpikeHome> {
  final _boundaryKey = GlobalKey();
  final _log = <String>[];
  final _results = <PipelineResult>[];

  int _renderIndex = 0;
  bool _running = false;
  String? _outDir;

  @override
  void initState() {
    super.initState();
    // Auto-run so the spike can be driven headlessly in profile mode, where
    // the timings are meaningful (debug-mode Dart timings are not).
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _say(String s) {
    debugPrint('SPIKE $s');
    setState(() => _log.add(s));
    final d = _outDir;
    if (d != null) {
      // Logcat is unreliable on a busy emulator; keep a copy on disk.
      try {
        File('$d/spike-log.txt').writeAsStringSync('${_log.join('\n')}\n');
      } catch (_) {}
    }
  }

  Future<Directory> _outputs() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/out');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    return dir;
  }

  /// Writes the PDF plus a 150dpi PNG of every page, so the output can be
  /// eyeballed without a PDF viewer. Returns page count.
  Future<int> _writeArtifacts(Directory dir, String name, Uint8List pdf) async {
    await File('${dir.path}/$name.pdf').writeAsBytes(pdf);
    var page = 0;
    try {
      await for (final raster in Printing.raster(pdf, dpi: 150)) {
        page++;
        await File(
          '${dir.path}/${name}_p$page.png',
        ).writeAsBytes(await raster.toPng());
      }
    } catch (e) {
      _say('  raster failed for $name: $e');
    }
    return page;
  }

  Future<void> _switchTo(int index) async {
    setState(() => _renderIndex = index);
    await WidgetsBinding.instance.endOfFrame;
    // Give font resolution a beat on a cold frame.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await WidgetsBinding.instance.endOfFrame;
  }

  int _median(List<int> xs) {
    xs.sort();
    return xs[xs.length ~/ 2];
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _log.clear();
      _results.clear();
    });

    final dir = await _outputs();
    _outDir = dir.path;
    _say('output dir: ${dir.path}');

    final info = await Printing.info();
    _say(
      'printing caps: raster=${info.canRaster} html=${info.canConvertHtml}',
    );

    for (var i = 0; i < samples.length; i++) {
      final doc = samples[i];
      await _switchTo(i);
      _say('--- ${doc.name} (${doc.code}) ---');

      // Pipeline A: vector text via Arabic presentation forms.
      await _timed('A', doc, dir, () => PipelineA.build(doc));

      // Pipeline B: rasterized Flutter widget at ~300dpi.
      await _timed('B', doc, dir, () async {
        final png = await PipelineB.capturePng(_boundaryKey);
        return PipelineB.build(png);
      });
      _say('  B capture: ${PipelineB.lastCaptureSize}px');

      // Pipeline B extra: WhatsApp-sized capture, for the 9.1 size sanity check.
      try {
        final wa = await PipelineB.capturePng(
          _boundaryKey,
          pixelRatio: PipelineB.whatsAppRatio(),
        );
        await File('${dir.path}/B_${doc.code}_whatsapp.png').writeAsBytes(wa);
        _say('  B whatsapp-size png: ${_kb(wa.length)}');
      } catch (e) {
        _say('  B whatsapp capture failed: $e');
      }

      // Pipeline C: Android WebView print-to-PDF. Time-boxed — a hang here is
      // itself a result worth recording.
      await _timed(
        'C',
        doc,
        dir,
        () => PipelineC.build(doc).timeout(const Duration(seconds: 20)),
        runs: 1,
      );
    }

    // Resolution sweep on Urdu only: the 3s budget lives or dies on capture
    // resolution, so measure the curve rather than guessing at it.
    await _switchTo(0);
    _say('--- resolution sweep (Urdu, Pipeline B) ---');
    for (final dpi in [150.0, 200.0, 250.0, 300.0]) {
      final ratio = dpi / 72.0;
      final times = <int>[];
      Uint8List? pdf;
      for (var i = 0; i < 2; i++) {
        final sw = Stopwatch()..start();
        final png = await PipelineB.capturePng(_boundaryKey, pixelRatio: ratio);
        pdf = await PipelineB.build(png);
        sw.stop();
        times.add(sw.elapsedMilliseconds);
      }
      _say(
        '  ${dpi.toInt()}dpi (${PipelineB.lastCaptureSize}): '
        '${times.reduce((a, b) => a < b ? a : b)}ms '
        '${_kb(pdf!.length)}',
      );
    }

    final report = const JsonEncoder.withIndent(
      '  ',
    ).convert(_results.map((r) => r.toJson()).toList());
    await File('${dir.path}/report.json').writeAsString(report);
    _say('wrote report.json');
    setState(() => _running = false);
  }

  Future<void> _timed(
    String pipeline,
    SampleDoc doc,
    Directory dir,
    Future<Uint8List> Function() build, {
    int runs = 3,
  }) async {
    final times = <int>[];
    Uint8List? last;
    try {
      for (var i = 0; i < runs; i++) {
        final sw = Stopwatch()..start();
        last = await build();
        sw.stop();
        times.add(sw.elapsedMilliseconds);
      }
    } catch (e) {
      _say('  $pipeline FAILED: $e');
      _results.add(
        PipelineResult(
          pipeline: pipeline,
          langCode: doc.code,
          millis: -1,
          bytes: 0,
          pageCount: 0,
          error: e.toString(),
        ),
      );
      return;
    }

    final pages = await _writeArtifacts(dir, '${pipeline}_${doc.code}', last!);
    final ms = _median(times);
    _results.add(
      PipelineResult(
        pipeline: pipeline,
        langCode: doc.code,
        millis: ms,
        bytes: last.length,
        pageCount: pages,
      ),
    );
    _say(
      '  $pipeline: ${ms}ms (${times.join('/')}) ${_kb(last.length)} ${pages}pg',
    );
  }

  String _kb(int b) => '${(b / 1024).toStringAsFixed(0)}KB';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nastaliq PDF spike (M0)')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _running ? null : _run,
                  child: Text(_running ? 'Running…' : 'Run all pipelines'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    samples[_renderIndex].name,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          // Live widget tree used by Pipeline B. Laid out at true A4 logical
          // size; the Transform only scales the on-screen preview and is an
          // ancestor of the boundary, so it is not baked into toImage().
          Center(
            child: ClipRect(
              child: SizedBox(
                width: LayoutSpec.pageWidthPt * 0.32,
                height: LayoutSpec.pageHeightPt * 0.32,
                // FittedBox (not Transform) — it hands the child *unbounded*
                // constraints, so the page really lays out at 595x842. A
                // SizedBox alone would silently clamp to the parent's 190x269
                // and the capture would be a squeezed page scaled back up.
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: LayoutSpec.pageWidthPt,
                    height: LayoutSpec.pageHeightPt,
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: BiodataPage(doc: samples[_renderIndex]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (_outDir != null)
                  SelectableText(
                    _outDir!,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ..._log.map(
                  (l) => Text(
                    l,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
