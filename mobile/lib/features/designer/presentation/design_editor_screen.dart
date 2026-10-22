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
  int _redoCount = 0;
  Completer<String>? _snapshotCompleter;
  Completer<String>? _designStateCompleter;

  // Tool state — pushed to designer.js via setToolMode() on any change.
  String _tool = 'look';
  int _guard = 2;
  double _radius = 0.04;
  bool _mirror = false;
  String _dyeColorHex = '#b5502a';
  String _curlBrushType = '3B';
  bool _volumeLift = true;
  double _thinAmount = 0.5;
  double _brushLength = 8; // 0.5 cm units, like HairParameters.length
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
    final counts = jsonDecode(message.message) as Map<String, dynamic>;
    setState(() {
      _strokeCount = counts['strokes'] as int;
      _redoCount = counts['redo'] as int;
    });
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
    if (_tool == 'curl') config['hairType'] = _curlBrushType;
    if (_tool == 'volume') config['amount'] = _volumeLift ? 1 : 0;
    if (_tool == 'thin') config['amount'] = _thinAmount;
    if (_tool == 'scissors') config['length'] = _brushLength;
    _run('setToolMode(${_literal(config)})');
  }

  void _selectTool(String tool) {
    setState(() {
      _tool = tool;
      // Razor is a precision liner — small, fixed width.
      if (tool == 'razor') _radius = 0.008;
      if (tool == 'clipper') _radius = 0.05;
      if (const ['dye', 'curl', 'volume', 'thin', 'scissors'].contains(tool)) _radius = 0.04;
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

  /// A length in the design's 0.5 cm units, as a barber reads it: the
  /// clipper guard when it's one, otherwise centimetres.
  String _lengthLabel(double length) {
    final millimetres = length * 5;
    for (var g = 0; g < _guardMillimetres.length; g++) {
      if ((millimetres - _guardMillimetres[g]).abs() < 0.6) return g == 0 ? 'Skin' : '#$g (${_guardMillimetres[g]} mm)';
    }
    return '${(length / 2).toStringAsFixed(1)} cm';
  }

  Widget _buildShapeTab() {
    final p = _parameters;
    final partLabel = p.partOffset.abs() < 0.05 ? 'Centre' : (p.partOffset < 0 ? 'Left' : 'Right');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabeledSlider(
          label: 'Length',
          valueLabel: '${_lengthLabel(p.length)} on top',
          value: p.length,
          min: 0,
          max: 100,
          // The whole cut grows or shrinks together; Barber detail sets
          // each zone on its own.
          onChanged: (v) => _updateParameters(p.copyWith(
            length: v,
            zones: p.length > 0 ? p.zones.map((zone, length) => MapEntry(zone, length * v / p.length)) : null,
          )),
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
        Text('Hair type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        _HairTypePicker(selected: p.hairType, onSelected: (id) => _updateParameters(p.copyWith(hairType: id))),
        const SizedBox(height: 12),
        _LabeledSlider(
          label: 'Thickness',
          valueLabel: p.volume < 0.7 ? 'Fine' : (p.volume < 1.3 ? 'Medium' : 'Thick'),
          value: p.volume,
          min: 0.2,
          max: 2,
          onChanged: (v) => _updateParameters(p.copyWith(volume: v)),
        ),
        if (p.preset != 'custom')
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Barber detail'),
            subtitle: const Text('Each zone\'s length, the fade, the undercut and the hairline'),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: _barberDetail(p),
          ),
      ],
    );
  }

  List<Widget> _barberDetail(HairParameters p) {
    final textTheme = Theme.of(context).textTheme;
    Widget guardChips(int selected, ValueChanged<int> onSelected, {int max = 4}) => Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var g = 0; g <= max; g++)
              ChoiceChip(label: Text(g == 0 ? 'Skin' : '#$g'), selected: selected == g, onSelected: (_) => onSelected(g)),
          ],
        );
    return [
      Text('Zones', style: textTheme.titleSmall),
      for (final zone in hairZones)
        _LabeledSlider(
          label: zone.label,
          valueLabel: _lengthLabel(p.zones[zone.id] ?? p.length),
          value: p.zones[zone.id] ?? p.length,
          min: 0,
          max: 100,
          onChanged: (v) => _updateParameters(p.copyWith(zones: {...p.zones, zone.id: v})),
        ),
      if (p.fadeHeight >= 0.02) ...[
        const SizedBox(height: 8),
        Text('Fade finishes at', style: textTheme.titleSmall),
        const SizedBox(height: 4),
        guardChips(p.fadeTo, (g) => _updateParameters(p.copyWith(fadeTo: g)), max: 3),
        const SizedBox(height: 8),
        Text('Fade shape', style: textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final shape in fadeShapes)
              ChoiceChip(
                label: Text(shape.label),
                tooltip: shape.description,
                selected: p.fadeShape == shape.id,
                onSelected: (_) => _updateParameters(p.copyWith(fadeShape: shape.id)),
              ),
          ],
        ),
        Text(fadeShapes.where((s) => s.id == p.fadeShape).firstOrNull?.description ?? '', style: textTheme.bodySmall),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Undercut'),
        subtitle: const Text('A hard line, short underneath'),
        value: p.undercut.on,
        onChanged: (on) => _updateParameters(p.copyWith(undercut: p.undercut.copyWith(on: on))),
      ),
      if (p.undercut.on) ...[
        _LabeledSlider(
          label: 'Line',
          valueLabel: p.undercut.height < 0.35 ? 'Low' : (p.undercut.height < 0.7 ? 'Mid' : 'High'),
          value: p.undercut.height,
          min: 0,
          max: 1,
          onChanged: (v) => _updateParameters(p.copyWith(undercut: p.undercut.copyWith(height: v))),
        ),
        guardChips(p.undercut.guard, (g) => _updateParameters(p.copyWith(undercut: p.undercut.copyWith(guard: g)))),
        const SizedBox(height: 8),
      ],
      ..._hairlineDetail(p),
    ];
  }

  List<Widget> _hairlineDetail(HairParameters p) {
    final textTheme = Theme.of(context).textTheme;
    final edges = p.hairline;
    void update(HairlineParameters next) => _updateParameters(p.copyWith(hairline: next));
    Widget choices(String title, List<({String id, String label})> options, String selected, ValueChanged<String> onSelected) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final option in options)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: selected == option.id,
                      onSelected: (_) => onSelected(option.id),
                    ),
                ],
              ),
            ],
          ),
        );
    return [
      const Divider(),
      choices('Hairline', hairlineShapes, edges.shape, (id) => update(edges.copyWith(shape: id))),
      _LabeledSlider(
        label: 'Hairline height',
        valueLabel: edges.height < 0.35 ? 'Low' : (edges.height < 0.65 ? 'Natural' : 'High'),
        value: edges.height,
        min: 0,
        max: 1,
        onChanged: (v) => update(edges.copyWith(height: v)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Line-up'),
        subtitle: const Text('Sharp, razor-edged lines instead of soft, natural edges'),
        value: edges.lineUp,
        onChanged: (on) => update(edges.copyWith(lineUp: on)),
      ),
      choices('Sideburns', sideburnLengths, edges.sideburns, (id) => update(edges.copyWith(sideburns: id))),
      choices('Neckline', necklines, edges.neckline, (id) => update(edges.copyWith(neckline: id))),
      _LabeledSlider(
        label: 'Neckline height',
        valueLabel: edges.neckHeight < 0.35 ? 'Low' : (edges.neckHeight < 0.65 ? 'Natural' : 'High'),
        value: edges.neckHeight,
        min: 0,
        max: 1,
        onChanged: (v) => update(edges.copyWith(neckHeight: v)),
      ),
    ];
  }

  Widget _buildToolsTab() {
    const tools = [
      ('look', Icons.threed_rotation, 'Look'),
      ('move', Icons.accessibility_new, 'Move'),
      ('cut', Icons.content_cut, 'Scissors'),
      ('clipper', Icons.straighten, 'Clipper'),
      ('razor', Icons.edit, 'Razor'),
      ('dye', Icons.palette, 'Dye'),
      ('scissors', Icons.height, 'Length'),
      ('volume', Icons.air, 'Volume'),
      ('thin', Icons.grain, 'Thin'),
      ('curl', Icons.waves, 'Curl'),
    ];
    final brush = const ['clipper', 'razor', 'dye', 'curl', 'volume', 'thin', 'scissors'].contains(_tool);
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
            OutlinedButton.icon(
              onPressed: _strokeCount > 0 ? () => _run('undoLastStroke()') : null,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _redoCount > 0 ? () => _run('redoStroke()') : null,
              icon: const Icon(Icons.redo),
              label: const Text('Redo'),
            ),
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
      case 'scissors':
        return [
          const Text('Paint a length onto the hair — longer or shorter than it is.'),
          _LabeledSlider(
            label: 'Length',
            valueLabel: _lengthLabel(_brushLength),
            value: _brushLength,
            min: 0,
            max: 100,
            onChanged: (v) => setState(() => _brushLength = v),
            onChangeEnd: (_) => _pushToolMode(),
          ),
        ];
      case 'volume':
        return [
          const Text('Paint where the hair should stand up more, or lie flatter.'),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('More volume'), icon: Icon(Icons.arrow_upward)),
              ButtonSegment(value: false, label: Text('Flatten'), icon: Icon(Icons.arrow_downward)),
            ],
            selected: {_volumeLift},
            onSelectionChanged: (selection) {
              setState(() => _volumeLift = selection.first);
              _pushToolMode();
            },
          ),
        ];
      case 'thin':
        return [
          const Text('Thin the hair out for texture or a lighter look.'),
          _LabeledSlider(
            label: 'Amount',
            valueLabel: '${(_thinAmount * 100).round()}% removed',
            value: _thinAmount,
            min: 0.1,
            max: 0.8,
            onChanged: (v) => setState(() => _thinAmount = v),
            onChangeEnd: (_) => _pushToolMode(),
          ),
        ];
      case 'curl':
        return [
          const Text('Paint another hair type onto part of the head — say a curlier top or tighter sides.'),
          const SizedBox(height: 8),
          _HairTypePicker(
            selected: _curlBrushType,
            onSelected: (id) {
              setState(() => _curlBrushType = id);
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
        const SizedBox(height: 8),
        ..._ombreDetail(_parameters),
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

  List<Widget> _ombreDetail(HairParameters p) {
    final colour = p.colour;
    void update(ColourParameters next) => _updateParameters(p.copyWith(colour: next));
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ombré'),
        subtitle: const Text('The ends fade to another colour'),
        value: colour.ombre,
        onChanged: (on) => update(colour.copyWith(ombre: on)),
      ),
      if (colour.ombre) ...[
        _LabeledSlider(
          label: 'Fade starts',
          valueLabel: '${colour.ombreStart.round()} cm from the root',
          value: colour.ombreStart,
          min: 0,
          max: 30,
          onChanged: (v) => update(colour.copyWith(ombreStart: v)),
        ),
        Text('Ends', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ColorPicker(
          key: const ValueKey('ombre'),
          hex: colour.ombreHex,
          swatches: _hairSwatches,
          onChanged: (hex) => update(colour.copyWith(ombreHex: hex)),
        ),
      ],
    ];
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

/// The 1A-4C hair types, grouped by family, with what the chosen one is.
class _HairTypePicker extends StatelessWidget {
  const _HairTypePicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final families = <String, List<({String id, String family, String description})>>{};
    for (final type in hairTypes) {
      (families[type.family] ??= []).add(type);
    }
    final description = hairTypes.where((t) => t.id == selected).firstOrNull?.description ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in families.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 64, child: Text(entry.key, style: Theme.of(context).textTheme.bodySmall)),
                for (final type in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(type.id),
                      selected: selected == type.id,
                      onSelected: (_) => onSelected(type.id),
                    ),
                  ),
              ],
            ),
          ),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
