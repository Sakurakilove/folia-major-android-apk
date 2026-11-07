import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'bravais_seam_material_look.dart';
import 'bravais_seam_material_painter.dart';
import 'bravais_seam_material_program.dart';

// A stable surfaceFor handle for BravaisSeamScene. Preset/theme/DPR changes replace only the material; opening/camera/tilt never recreate grain jobs or shaders.
class BravaisSeamMaterialSurface extends CustomPainter {
  factory BravaisSeamMaterialSurface({
    required ValueListenable<BravaisSeamMaterialLook> look,
    required BravaisSeamMaterialProgram program,
    required double dpr,
  }) => BravaisSeamMaterialSurface._(_SeamMaterialState(look, program, dpr));
  BravaisSeamMaterialSurface._(this._state) : super(repaint: _state);
  final _SeamMaterialState _state;
  set dpr(double value) => _state.dpr = value;
  @override
  void paint(Canvas canvas, Size size) {
    if (!size.isEmpty) _state.painter?.paint(canvas, size);
  }

  @override
  bool shouldRepaint(BravaisSeamMaterialSurface oldDelegate) =>
      !identical(oldDelegate._state, _state);
  void dispose() => _state.dispose();
}

class _SeamMaterialState extends ChangeNotifier {
  _SeamMaterialState(this.look, this.program, this._dpr) {
    look.addListener(_changed);
  }
  final ValueListenable<BravaisSeamMaterialLook> look;
  final BravaisSeamMaterialProgram program;
  double _dpr;
  bool _closed = false;
  BravaisSeamMaterialPainter? _painter;
  // Defer native work until this retained surface is actually painted.
  BravaisSeamMaterialPainter? get painter {
    if (_closed) return null;
    return _painter ??= BravaisSeamMaterialPainter(
      look: look.value,
      program: program,
      dpr: _dpr,
    )..addListener(_ready);
  }

  set dpr(double value) {
    if (_closed || value == _dpr) return;
    _dpr = value;
    _changed();
  }

  void _ready() {
    if (!_closed) notifyListeners();
  }

  void _changed() {
    if (_closed) return;
    _clear();
    notifyListeners();
  }

  void _clear() {
    _painter?.removeListener(_ready);
    _painter?.dispose();
    _painter = null;
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    look.removeListener(_changed);
    _clear();
    super.dispose();
  }
}
