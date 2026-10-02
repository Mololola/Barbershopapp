import 'package:flutter/material.dart';

Color colorFromHex(String hex) => Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);

String hexFromColor(Color color) {
  String channel(double c) => (c * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}';
}

/// An exact colour: hue, saturation and brightness sliders, a hex code
/// field, and quick swatches — for hair colour and dye.
class ColorPicker extends StatefulWidget {
  const ColorPicker({super.key, required this.hex, required this.onChanged, this.swatches = const []});

  final String hex;
  final ValueChanged<String> onChanged;
  final List<String> swatches;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(colorFromHex(widget.hex));
  late final _hexController = TextEditingController(text: widget.hex);

  @override
  void didUpdateWidget(ColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hex != oldWidget.hex && widget.hex != hexFromColor(_hsv.toColor())) {
      _hsv = HSVColor.fromColor(colorFromHex(widget.hex));
      _hexController.text = widget.hex;
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _set(HSVColor hsv) {
    final hex = hexFromColor(hsv.toColor());
    setState(() {
      _hsv = hsv;
      _hexController.text = hex;
    });
    widget.onChanged(hex);
  }

  void _setHex(String text) {
    final hex = text.startsWith('#') ? text : '#$text';
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return;
    setState(() => _hsv = HSVColor.fromColor(colorFromHex(hex)));
    widget.onChanged(hex.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final hueColors = [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in widget.swatches)
              SwatchButton(hex: hex, selected: hex == widget.hex, onTap: () => _set(HSVColor.fromColor(colorFromHex(hex)))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hsv.toColor(),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _hexController,
                decoration: const InputDecoration(labelText: 'Hex', isDense: true),
                onSubmitted: _setHex,
                onChanged: (text) {
                  if (text.length >= 6) _setHex(text);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _GradientSlider(
          label: 'Hue',
          colors: hueColors,
          value: _hsv.hue / 360,
          onChanged: (v) => _set(_hsv.withHue(v * 360)),
        ),
        _GradientSlider(
          label: 'Saturation',
          colors: [_hsv.withSaturation(0).toColor(), _hsv.withSaturation(1).toColor()],
          value: _hsv.saturation,
          onChanged: (v) => _set(_hsv.withSaturation(v)),
        ),
        _GradientSlider(
          label: 'Brightness',
          colors: [Colors.black, _hsv.withValue(1).toColor()],
          value: _hsv.value,
          onChanged: (v) => _set(_hsv.withValue(v)),
        ),
      ],
    );
  }
}

/// A slider over a gradient bar showing what the values mean.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({required this.label, required this.colors, required this.value, required this.onChanged});

  final String label;
  final List<Color> colors;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                ),
                child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SwatchButton extends StatelessWidget {
  const SwatchButton({super.key, required this.hex, required this.selected, required this.onTap});

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(hex);
    return Semantics(
      button: true,
      selected: selected,
      label: hex,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: color,
          child: selected
              ? Icon(Icons.check, size: 16, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
              : null,
        ),
      ),
    );
  }
}
