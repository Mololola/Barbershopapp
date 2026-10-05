import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/designer_controller.dart';
import '../data/designer_repository.dart';
import '../domain/hair_parameters.dart';
import 'cap_reached_dialog.dart';
import 'color_picker.dart';

const _hairSwatches = [
  '#0a0a0a', '#2b1a10', '#3b2314', '#6b4423', '#8a5a36', '#c8a165',
  '#e6cf9a', '#8a3324', '#b5502a', '#b5b5b5', '#e9e4dc', '#3a5fcd',
];
const _skinToneSwatches = ['#3d2314', '#6b4226', '#8d5524', '#c68642', '#e0ac69', '#f1c27d', '#ffdbac'];

/// Real clipper guard lengths, in mm — must match CLIPPER_GUARD_LENGTHS in
/// groom.js (which stores them in 0.5 cm units).
const _guardMillimetres = [0, 3, 6, 10, 13, 16, 19, 22, 25];

const _headCredit =
    '3D head: "Infinite, 3D Head Scan" by Lee Perry-Smith (ir-ltd.net), licensed under '
    'Creative Commons Attribution 3.0, based on a work at triplegangers.com.';

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
  String _name = 'My design';
  HairParameters _parameters = const HairParameters(preset: 'fade');
  bool _isPublic = false;
  bool _webViewReady = false;
  bool _initializedFromExisting = false;
  int _strokeCount = 0;
  Completer<String>? _snapshotCompleter;
  Completer<String>? _designStateCompleter;

  // Tool state — pushed to designer.js via setToolMode() on any change.
  String _tool = 'look';
  int _guard = 2;
  double _radius = 0.04;
  bool _mirror = false;
  String _dyeColorHex = '#b5502a';
  double _wind = 0;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('SnapshotChannel', onMessageReceived: _onSnapshotReceived)
      ..addJavaScriptChannel('DesignStateChannel', onMessageReceived: _onDesignStateReceived)
      ..addJavaScriptChannel('ParametersChannel', onMessageReceived: _onParametersReceived)
      ..addJavaScriptChannel('EditChannel', onMessageReceived: _onEditReceived)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _webViewReady = true);
            if (!kReleaseMode) _run('enableProfiling()');
            if (widget.designId == null) {
              _run("setPreset('${_parameters.preset}')");
            } else if (_initializedFromExisting) {
              _pushDesign();
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/haircut_designer/index.html');
    // The designer's own log (errors, and frame timings — see enableProfiling
    // in designer.js) in `flutter run`'s output.
    if (!kReleaseMode) {
      _webViewController.setOnConsoleMessage((message) => debugPrint('[designer] ${message.message}'));
    }
  }

  void _run(String script) {
    if (_webViewReady) _webViewController.runJavaScript(script);
  }

  /// A JSON value as a JavaScript string literal, for the bridge functions
  /// (which take a string and JSON.parse it themselves).
  String _literal(Object value) => jsonEncode(jsonEncode(value));

  void _onSnapshotReceived(JavaScriptMessage message) {
    _snapshotCompleter?.complete(message.message);
    _snapshotCompleter = null;
  }

  void _onDesignStateReceived(JavaScriptMessage message) {
    _designStateCompleter?.complete(message.message);
    _designStateCompleter = null;
  }

  /// A preset was chosen: designer.js reports the parameters it starts from.
  void _onParametersReceived(JavaScriptMessage message) {
    final json = jsonDecode(message.message) as Map<String, dynamic>;
    setState(() => _parameters = HairParameters.fromJson(json));
  }

  void _onEditReceived(JavaScriptMessage message) {
    _strokeCount = int.tryParse(message.message) ?? 0;
  }

  Future<String> _captureSnapshot() async {
    final completer = Completer<String>();
    _snapshotCompleter = completer;
    await _webViewController.runJavaScript('captureSnapshot()');
    return completer.future.timeout(const Duration(seconds: 5));
  }

  /// The design as designer.js has it — the source of truth for strokes
  /// while editing, so this is the only place they reach Flutter before a save.
  Future<HairParameters> _pullDesignState() async {
    final completer = Completer<String>();
    _designStateCompleter = completer;
    await _webViewController.runJavaScript('requestDesignState()');
    final json = await completer.future.timeout(const Duration(seconds: 5));
    return HairParameters.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  void _pushDesign() => _run('loadDesign(${_literal(_parameters.toJson())})');

  void _updateParameters(HairParameters next) {
    setState(() => _parameters = next);
    final json = next.toJson()..remove('strokes');
    _run('updateParameters(${_literal(json)})');
  }

  Future<void> _choosePreset(String id) async {
    if (id == _parameters.preset) return;
    if (_strokeCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start from this cut?'),
          content: const Text('Your cuts, clipper work and dye on this design will be cleared.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start over')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _parameters = _parameters.copyWith(preset: id));
    _run("setPreset('$id')");
  }

  void _pushToolMode() {
    final config = <String, dynamic>{'tool': _tool, 'radius': _radius, 'mirror': _mirror};
    if (_tool == 'clipper') config['guard'] = _guard;
    if (_tool == 'dye') config['colorHex'] = _dyeColorHex;
    _run('setToolMode(${_literal(config)})');
  }

  void _selectTool(String tool) {
    setState(() {
      _tool = tool;
      // Razor is a precision liner — small, fixed width.
      if (tool == 'razor') _radius = 0.008;
      if (tool == 'clipper') _radius = 0.05;
      if (tool == 'dye') _radius = 0.04;
    });
    _pushToolMode();
  }

  Future<void> _save() async {
    final designState = await _pullDesignState();
    if (!mounted) return;
    final details = await showDialog<({String name, bool isPublic})>(
      context: context,
      builder: (context) => _SaveDialog(name: _name, isPublic: _isPublic, canPublish: widget.designId != null),
    );
    if (details == null || !mounted) return;
    setState(() {
      _name = details.name;
      _isPublic = details.isPublic;
    });
    final thumbnailBytes = DesignerRepository.decodeDataUrl(await _captureSnapshot());

    final notifier = ref.read(designEditControllerProvider.notifier);
    if (widget.designId == null) {
      final result = await notifier.saveNewDesign(name: _name, parameters: designState, thumbnailPngBytes: thumbnailBytes);
      if (!mounted) return;
      if (result.capReached) {
        showCapReachedDialog(context, ref);
      } else {
        Navigator.of(context).pop();
      }
    } else {
      await notifier.updateDesign(
        designId: widget.designId!,
        name: _name,
        parameters: designState,
        thumbnailPngBytes: thumbnailBytes,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  void _showCredit() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About the designer'),
        content: const Text(_headCredit),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.designId != null && !_initializedFromExisting) {
      ref.watch(designProvider(widget.designId!)).whenData((design) {
        if (design == null || _initializedFromExisting) return;
        _initializedFromExisting = true;
        _name = design.name;
        _parameters = design.parameters;
        _isPublic = design.isPublic;
        _pushDesign();
      });
    }

    final actionState = ref.watch(designEditControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design editor'),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), tooltip: 'About', onPressed: _showCredit),
          IconButton(
            icon: actionState.isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: actionState.isLoading ? null : _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _ViewButtons(onSelect: (view) => _run("setView('$view')")),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    // The app's tab theme is for its dark app bars; this panel is light.
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    tabs: const [Tab(text: 'Cut'), Tab(text: 'Shape'), Tab(text: 'Tools'), Tab(text: 'Colour'), Tab(text: 'Motion')],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [_buildCutTab(), _buildShapeTab(), _buildToolsTab(), _buildColourTab(), _buildMotionTab()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCutTab() {
    final groups = <String, List<({String id, String label, String group})>>{};
    for (final preset in haircutPresets) {
      (groups[preset.group] ??= []).add(preset);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in groups.entries) ...[
          Text(entry.key, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in entry.value)
                ChoiceChip(
                  label: Text(preset.label),
                  selected: _parameters.preset == preset.id,
                  onSelected: (_) => _choosePreset(preset.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (_parameters.preset == 'custom')
          const Text('This design was made before cuts existed — it keeps its own shape until you pick a cut.'),
      ],
    );
  }

  Widget _buildShapeTab() {
    final p = _parameters;
    final curlLabel = p.curl < 0.15 ? 'Straight' : p.curl < 0.45 ? 'Wavy' : p.curl < 0.8 ? 'Curly' : 'Coily';
    final partLabel = p.partOffset.abs() < 0.05 ? 'Centre' : (p.partOffset < 0 ? 'Left' : 'Right');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabeledSlider(
          label: 'Length on top',
          valueLabel: '${(p.length / 2).toStringAsFixed(1)} cm',
          value: p.length,
          min: 0,
          max: 100,
          onChanged: (v) => _updateParameters(p.copyWith(length: v)),
        ),
        _LabeledSlider(
          label: 'Fade',
          valueLabel: p.fadeHeight < 0.02 ? 'Off' : (p.fadeHeight < 0.4 ? 'Low' : (p.fadeHeight < 0.7 ? 'Mid' : 'High')),
          value: p.fadeHeight,
          min: 0,
          max: 1,
          onChanged: (v) => _updateParameters(p.copyWith(fadeHeight: v)),
        ),
        _LabeledSlider(
          label: 'Parting',
          valueLabel: partLabel,
          value: p.partOffset,
          min: -1,
          max: 1,
          onChanged: (v) => _updateParameters(p.copyWith(partOffset: v)),
        ),
        _LabeledSlider(
          label: 'Texture',
          valueLabel: curlLabel,
          value: p.curl,
          min: 0,
          max: 1,
          onChanged: (v) => _updateParameters(p.copyWith(curl: v)),
        ),
        _LabeledSlider(
          label: 'Thickness',
          valueLabel: p.volume < 0.7 ? 'Fine' : (p.volume < 1.3 ? 'Medium' : 'Thick'),
          value: p.volume,
          min: 0.2,
          max: 2,
          onChanged: (v) => _updateParameters(p.copyWith(volume: v)),
        ),
      ],
    );
  }

  Widget _buildToolsTab() {
    const tools = [
      ('look', Icons.threed_rotation, 'Look'),
      ('move', Icons.accessibility_new, 'Move'),
      ('cut', Icons.content_cut, 'Scissors'),
      ('clipper', Icons.straighten, 'Clipper'),
      ('razor', Icons.edit, 'Razor'),
      ('dye', Icons.palette, 'Dye'),
    ];
    final brush = _tool == 'clipper' || _tool == 'razor' || _tool == 'dye';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (id, icon, label) in tools)
              ChoiceChip(
                avatar: Icon(icon, size: 18),
                label: Text(label),
                selected: _tool == id,
                onSelected: (_) => _selectTool(id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ..._toolOptions(),
        if (brush) ...[
          if (_tool != 'razor')
            _LabeledSlider(
              label: 'Brush size',
              valueLabel: '',
              value: _radius.clamp(0.01, 0.12),
              min: 0.01,
              max: 0.12,
              onChanged: (r) => setState(() => _radius = r),
              onChangeEnd: (_) => _pushToolMode(),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mirror both sides'),
            value: _mirror,
            onChanged: (value) {
              setState(() => _mirror = value);
              _pushToolMode();
            },
          ),
        ],
        Row(
          children: [
            OutlinedButton.icon(onPressed: () => _run('undoLastStroke()'), icon: const Icon(Icons.undo), label: const Text('Undo')),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _run('clearStrokes()'),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Undo all edits'),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _toolOptions() {
    switch (_tool) {
      case 'move':
        return const [Text('Drag to turn and tilt the head — watch the hair swing.')];
      case 'cut':
        return const [Text('Swipe across the hair to cut it where your finger crosses it. Two fingers still zoom.')];
      case 'clipper':
        return [
          const Text('Guard'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var g = 0; g < _guardMillimetres.length; g++)
                ChoiceChip(
                  label: Text(g == 0 ? 'Skin' : '#$g · ${_guardMillimetres[g]} mm'),
                  selected: _guard == g,
                  onSelected: (_) {
                    setState(() => _guard = g);
                    _pushToolMode();
                  },
                ),
            ],
          ),
        ];
      case 'razor':
        return const [Text('A thin, skin-close line — for edge-ups, part lines and designs.')];
      case 'dye':
        return [
          ColorPicker(
            hex: _dyeColorHex,
            swatches: _hairSwatches,
            onChanged: (hex) {
              setState(() => _dyeColorHex = hex);
              _pushToolMode();
            },
          ),
        ];
      default:
        return const [
          Text('Drag to look around · pinch to zoom · two fingers to move · double-tap to reset.'),
        ];
    }
  }

  Widget _buildColourTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hair colour', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ColorPicker(
          hex: _parameters.colorHex,
          swatches: _hairSwatches,
          onChanged: (hex) => _updateParameters(_parameters.copyWith(colorHex: hex)),
        ),
        const SizedBox(height: 16),
        Text('Skin tone', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in _skinToneSwatches)
              SwatchButton(
                hex: hex,
                selected: _parameters.faceParams.skinTone == hex,
                onTap: () => _updateParameters(
                  _parameters.copyWith(faceParams: _parameters.faceParams.copyWith(skinTone: hex)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMotionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabeledSlider(
          label: 'Wind',
          valueLabel: _wind < 0.02 ? 'Off' : '${(_wind * 100).round()}%',
          value: _wind,
          min: 0,
          max: 1,
          onChanged: (v) {
            setState(() => _wind = v);
            _run('setWind($v)');
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _run('shake()');
              },
              icon: const Icon(Icons.vibration),
              label: const Text('Shake head'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Or pick Move in Tools and drag the head yourself.'),
      ],
    );
  }
}

class _SaveDialog extends StatefulWidget {
  const _SaveDialog({required this.name, required this.isPublic, required this.canPublish});

  final String name;
  final bool isPublic;

  /// Publishing is offered once a design exists (it has to be saved first).
  final bool canPublish;

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  late final _controller = TextEditingController(text: widget.name);
  late bool _isPublic = widget.isPublic;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save design'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
          if (widget.canPublish)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Public (others can browse and fork it)'),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            Navigator.pop(context, (name: name.isEmpty ? 'My design' : name, isPublic: _isPublic));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Jumps the camera to a standard angle — the ones a barber checks a cut from.
class _ViewButtons extends StatelessWidget {
  const _ViewButtons({required this.onSelect});

  final ValueChanged<String> onSelect;

  static const _views = [('front', 'Front'), ('left', 'Left'), ('right', 'Right'), ('back', 'Back'), ('top', 'Top')];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (id, label) in _views)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ActionChip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.black54,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              side: BorderSide.none,
              onPressed: () => onSelect(id),
            ),
          ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged, onChangeEnd: onChangeEnd),
      ],
    );
  }
}
