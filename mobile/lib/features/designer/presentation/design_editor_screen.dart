import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/designer_controller.dart';
import '../data/designer_repository.dart';
import '../domain/hair_parameters.dart';
import 'cap_reached_dialog.dart';

const _colorSwatches = ['#0a0a0a', '#3b2314', '#6b4423', '#c8a165', '#8a3324', '#b5b5b5'];
const _skinToneSwatches = ['#3d2314', '#8d5524', '#c68642', '#e0ac69', '#f1c27d', '#ffdbac'];

/// Guard #0 (skin) .. #8 — must match CLIPPER_GUARD_LENGTHS in designer.js.
const _guardCount = 9;

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
  Completer<String>? _designStateCompleter;

  // Tool bar state — pushed to designer.js via setToolMode() on any change.
  String _tool = 'rotate';
  int _guard = 2;
  double _scissorsLength = 6;
  String _dyeColorHex = _colorSwatches[0];
  double _radius = 0.04;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('SnapshotChannel', onMessageReceived: _onSnapshotReceived)
      ..addJavaScriptChannel('DesignStateChannel', onMessageReceived: _onDesignStateReceived)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _webViewReady = true);
            _pushParametersToWebView();
            _pushStrokesToWebView();
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

  void _onDesignStateReceived(JavaScriptMessage message) {
    _designStateCompleter?.complete(message.message);
    _designStateCompleter = null;
  }

  Future<String> _captureSnapshot() async {
    final completer = Completer<String>();
    _snapshotCompleter = completer;
    await _webViewController.runJavaScript('captureSnapshot()');
    return completer.future.timeout(const Duration(seconds: 5));
  }

  /// Pulls the authoritative design state (base style + faceParams +
  /// freehand strokes) out of the WebView — designer.js, not this widget, is
  /// the source of truth for strokes while editing, so this is the only
  /// place strokes get synced back into [_parameters] before a save.
  Future<HairParameters> _pullDesignState() async {
    final completer = Completer<String>();
    _designStateCompleter = completer;
    await _webViewController.runJavaScript('requestDesignState()');
    final json = await completer.future.timeout(const Duration(seconds: 5));
    return HairParameters.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  void _pushParametersToWebView() {
    if (!_webViewReady) return;
    // Passed as a JSON *string literal* — designer.js's updateParameters
    // takes a string and JSON.parses it itself, matching the Flutter-side
    // repository/storage shape (HairParameters.toJson) exactly.
    final jsonString = jsonEncode(jsonEncode(_parameters.toJson()));
    _webViewController.runJavaScript('updateParameters($jsonString)');
  }

  void _pushStrokesToWebView() {
    if (!_webViewReady) return;
    final jsonString = jsonEncode(jsonEncode(_parameters.strokes.map((s) => s.toJson()).toList()));
    _webViewController.runJavaScript('loadStrokes($jsonString)');
  }

  void _pushToolMode() {
    if (!_webViewReady) return;
    final config = <String, dynamic>{'tool': _tool, 'radius': _radius};
    if (_tool == 'clipper') config['guard'] = _guard;
    if (_tool == 'razor') config['guard'] = 0;
    if (_tool == 'scissors') config['length'] = _scissorsLength;
    if (_tool == 'dye') config['colorHex'] = _dyeColorHex;
    final jsonString = jsonEncode(jsonEncode(config));
    _webViewController.runJavaScript('setToolMode($jsonString)');
  }

  void _selectTool(String tool) {
    setState(() {
      _tool = tool;
      // Razor is a precision liner — small fixed radius, not user-adjustable.
      if (tool == 'razor') _radius = 0.012;
      if (tool == 'clipper' || tool == 'scissors') _radius = 0.05;
      if (tool == 'dye') _radius = 0.04;
    });
    _pushToolMode();
  }

  void _undo() {
    if (!_webViewReady) return;
    _webViewController.runJavaScript('undoLastStroke()');
  }

  void _clearDrawing() {
    if (!_webViewReady) return;
    _webViewController.runJavaScript('clearStrokes()');
  }

  void _updateParameters(HairParameters next) {
    setState(() => _parameters = next);
    _pushParametersToWebView();
  }

  Future<void> _save() async {
    final designState = await _pullDesignState();
    final snapshotDataUrl = await _captureSnapshot();
    final thumbnailBytes = DesignerRepository.decodeDataUrl(snapshotDataUrl);
    final name = _nameController.text.trim().isEmpty ? 'My design' : _nameController.text.trim();

    final notifier = ref.read(designEditControllerProvider.notifier);
    if (widget.designId == null) {
      final result = await notifier.saveNewDesign(
        name: name,
        parameters: designState,
        thumbnailPngBytes: thumbnailBytes,
      );
      if (!mounted) return;
      if (result.capReached) {
        showCapReachedDialog(context, ref);
      } else {
        Navigator.of(context).pop();
      }
    } else {
      await notifier.updateDesign(
        designId: widget.designId!,
        name: name,
        parameters: designState,
        thumbnailPngBytes: thumbnailBytes,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    }
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
        _pushStrokesToWebView();
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
          _ToolBar(
            tool: _tool,
            onSelectTool: _selectTool,
            onUndo: _undo,
            onClear: _clearDrawing,
          ),
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
                _buildToolOptions(),
                const Divider(height: 32),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Base style'),
                  initiallyExpanded: false,
                  children: [
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
                    const Text('Base hair color'),
                    _ColorSwatchRow(
                      swatches: _colorSwatches,
                      selectedHex: _parameters.colorHex,
                      onSelected: (hex) => _updateParameters(_parameters.copyWith(colorHex: hex)),
                    ),
                    const SizedBox(height: 8),
                    const Text('Skin tone'),
                    _ColorSwatchRow(
                      swatches: _skinToneSwatches,
                      selectedHex: _parameters.faceParams.skinTone,
                      onSelected: (hex) => _updateParameters(
                        _parameters.copyWith(faceParams: _parameters.faceParams.copyWith(skinTone: hex)),
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

  Widget _buildToolOptions() {
    switch (_tool) {
      case 'clipper':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Guard size'),
            Wrap(
              spacing: 8,
              children: [
                for (var g = 0; g < _guardCount; g++)
                  ChoiceChip(
                    label: Text(g == 0 ? 'Skin' : '#$g'),
                    selected: _guard == g,
                    onSelected: (_) {
                      setState(() => _guard = g);
                      _pushToolMode();
                    },
                  ),
              ],
            ),
            _RadiusSlider(radius: _radius, onChanged: (r) => setState(() => _radius = r), onChangeEnd: _pushToolMode),
          ],
        );
      case 'scissors':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ParamSlider(
              label: 'Trim length',
              value: _scissorsLength,
              min: 0,
              max: 20,
              onChanged: (v) {
                setState(() => _scissorsLength = v);
                _pushToolMode();
              },
            ),
            _RadiusSlider(radius: _radius, onChanged: (r) => setState(() => _radius = r), onChangeEnd: _pushToolMode),
          ],
        );
      case 'razor':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Precision liner — shaves a thin skin-close line. Great for edge-ups, part lines, and lettering.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      case 'dye':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dye color'),
            _ColorSwatchRow(
              swatches: _colorSwatches,
              selectedHex: _dyeColorHex,
              onSelected: (hex) {
                setState(() => _dyeColorHex = hex);
                _pushToolMode();
              },
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _radius = 0.015);
                    _pushToolMode();
                  },
                  child: const Text('Streak / highlight'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _radius = 0.07);
                    _pushToolMode();
                  },
                  child: const Text('Block section'),
                ),
              ],
            ),
            _RadiusSlider(radius: _radius, onChanged: (r) => setState(() => _radius = r), onChangeEnd: _pushToolMode),
          ],
        );
      case 'rotate':
      default:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Drag to rotate the head. Pick a tool above to start drawing on it.'),
        );
    }
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.tool, required this.onSelectTool, required this.onUndo, required this.onClear});

  final String tool;
  final ValueChanged<String> onSelectTool;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  static const _tools = [
    ('rotate', Icons.threed_rotation, 'Rotate'),
    ('clipper', Icons.content_cut, 'Clipper'),
    ('scissors', Icons.cut, 'Scissors'),
    ('razor', Icons.edit, 'Razor'),
    ('dye', Icons.palette, 'Dye'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (id, icon, label) in _tools)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        avatar: Icon(icon, size: 18),
                        label: Text(label),
                        selected: tool == id,
                        onSelected: (_) => onSelectTool(id),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.undo), tooltip: 'Undo last stroke', onPressed: onUndo),
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Clear drawing', onPressed: onClear),
        ],
      ),
    );
  }
}

class _RadiusSlider extends StatelessWidget {
  const _RadiusSlider({required this.radius, required this.onChanged, required this.onChangeEnd});

  final double radius;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Brush size'),
        Slider(
          value: radius.clamp(0.01, 0.12),
          min: 0.01,
          max: 0.12,
          onChanged: onChanged,
          onChangeEnd: (_) => onChangeEnd(),
        ),
      ],
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({required this.swatches, required this.selectedHex, required this.onSelected});

  final List<String> swatches;
  final String selectedHex;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final hex in swatches)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onSelected(hex),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000),
                child: selectedHex == hex ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
              ),
            ),
          ),
      ],
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
