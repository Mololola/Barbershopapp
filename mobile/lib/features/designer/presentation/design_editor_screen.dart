import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/designer_controller.dart';
import '../data/designer_repository.dart';
import '../domain/hair_parameters.dart';

const _colorSwatches = ['#0a0a0a', '#3b2314', '#6b4423', '#c8a165', '#8a3324', '#b5b5b5'];

class DesignEditorScreen extends ConsumerStatefulWidget {
  const DesignEditorScreen({super.key, this.designId});

  /// Null means "creating a new design"; otherwise this loads and edits an
  /// existing one (owner-only — RLS blocks anyone else from saving over it).
  final String? designId;

  @override
  ConsumerState<DesignEditorScreen> createState() => _DesignEditorScreenState();
}

class _DesignEditorScreenState extends ConsumerState<DesignEditorScreen> {
  late final WebViewController _webViewController;
  final _nameController = TextEditingController(text: 'My design');
  HairParameters _parameters = const HairParameters();
  bool _isPublic = false;
  bool _webViewReady = false;
  bool _initializedFromExisting = false;
  Completer<String>? _snapshotCompleter;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('SnapshotChannel', onMessageReceived: _onSnapshotReceived)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _webViewReady = true);
            _pushParametersToWebView();
          },
        ),
      )
      ..loadFlutterAsset('assets/haircut_designer/index.html');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onSnapshotReceived(JavaScriptMessage message) {
    _snapshotCompleter?.complete(message.message);
    _snapshotCompleter = null;
  }

  Future<String> _captureSnapshot() async {
    final completer = Completer<String>();
    _snapshotCompleter = completer;
    await _webViewController.runJavaScript('captureSnapshot()');
    return completer.future.timeout(const Duration(seconds: 5));
  }

  void _pushParametersToWebView() {
    if (!_webViewReady) return;
    // Passed as a JSON *string literal* — designer.js's updateParameters
    // takes a string and JSON.parses it itself, matching the Flutter-side
    // repository/storage shape (HairParameters.toJson) exactly.
    final jsonString = jsonEncode(jsonEncode(_parameters.toJson()));
    _webViewController.runJavaScript('updateParameters($jsonString)');
  }

  void _updateParameters(HairParameters next) {
    setState(() => _parameters = next);
    _pushParametersToWebView();
  }

  Future<void> _save() async {
    final snapshotDataUrl = await _captureSnapshot();
    final thumbnailBytes = DesignerRepository.decodeDataUrl(snapshotDataUrl);
    final name = _nameController.text.trim().isEmpty ? 'My design' : _nameController.text.trim();

    final notifier = ref.read(designEditControllerProvider.notifier);
    if (widget.designId == null) {
      final result = await notifier.saveNewDesign(
        name: name,
        parameters: _parameters,
        thumbnailPngBytes: thumbnailBytes,
      );
      if (!mounted) return;
      if (result.capReached) {
        _showCapReachedDialog();
      } else {
        Navigator.of(context).pop();
      }
    } else {
      await notifier.updateDesign(
        designId: widget.designId!,
        name: name,
        parameters: _parameters,
        thumbnailPngBytes: thumbnailBytes,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  void _showCapReachedDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Design limit reached'),
        content: Text('You can save up to $maxFreeDesigns designs for free. Delete one to make room.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.designId != null && !_initializedFromExisting) {
      final existing = ref.watch(designProvider(widget.designId!));
      existing.whenData((design) {
        if (design == null || _initializedFromExisting) return;
        _initializedFromExisting = true;
        _nameController.text = design.name;
        _parameters = design.parameters;
        _isPublic = design.isPublic;
        _pushParametersToWebView();
      });
    }

    final actionState = ref.watch(designEditControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design editor'),
        actions: [
          IconButton(
            icon: actionState.isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            onPressed: actionState.isLoading ? null : _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(flex: 3, child: WebViewWidget(controller: _webViewController)),
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                if (widget.designId != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Make public (others can browse and fork it)'),
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value),
                  ),
                _ParamSlider(
                  label: 'Length',
                  value: _parameters.length,
                  min: 0,
                  max: 20,
                  onChanged: (v) => _updateParameters(_parameters.copyWith(length: v)),
                ),
                _ParamSlider(
                  label: 'Volume',
                  value: _parameters.volume,
                  min: 0.2,
                  max: 2,
                  onChanged: (v) => _updateParameters(_parameters.copyWith(volume: v)),
                ),
                _ParamSlider(
                  label: 'Curl',
                  value: _parameters.curl,
                  min: 0,
                  max: 1,
                  onChanged: (v) => _updateParameters(_parameters.copyWith(curl: v)),
                ),
                _ParamSlider(
                  label: 'Part',
                  value: _parameters.partOffset,
                  min: -1,
                  max: 1,
                  onChanged: (v) => _updateParameters(_parameters.copyWith(partOffset: v)),
                ),
                _ParamSlider(
                  label: 'Fade height',
                  value: _parameters.fadeHeight,
                  min: 0,
                  max: 1,
                  onChanged: (v) => _updateParameters(_parameters.copyWith(fadeHeight: v)),
                ),
                const SizedBox(height: 8),
                const Text('Color'),
                Row(
                  children: [
                    for (final hex in _colorSwatches)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => _updateParameters(_parameters.copyWith(colorHex: hex)),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000),
                            child: _parameters.colorHex == hex
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParamSlider extends StatelessWidget {
  const _ParamSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
