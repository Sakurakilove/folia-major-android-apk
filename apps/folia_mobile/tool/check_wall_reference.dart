import 'dart:convert';
import 'dart:io';

import 'package:folia_mobile/library/bravais/bravais_frame.dart';
import 'package:folia_mobile/library/bravais/bravais_plate_geometry.dart';
import 'package:folia_mobile/library/bravais/bravais_wall_wave.dart';
import 'package:folia_mobile/library/bravais/poster_safe_area.dart';
import 'package:folia_mobile/library/wall/flip_plan.dart';
import 'package:folia_mobile/library/wall/start_tile.dart';
import 'package:folia_mobile/library/wall/wall_reflow_motion.dart';
import 'package:folia_mobile/library/wall/block_reserved_slots.dart';
import 'package:folia_mobile/library/wall/block_templates.dart';
import 'package:folia_mobile/library/wall/finite_wall.dart';
import 'package:folia_mobile/library/wall/lattice_layout.dart';
import 'package:folia_mobile/library/wall/seam_plan.dart';
import 'package:folia_mobile/library/wall/wall_pan_motion.dart';
import 'package:folia_mobile/library/wall/wall_slots.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';
import 'package:folia_mobile/library/wall/wall_view.dart';
import 'package:folia_mobile/visualizer/motion/inertia.dart';

// A single source-contract check, deliberately separate from final wall animation/pixel/device acceptance.
double n(dynamic value) => (value as num).toDouble();
WallMetrics metrics(dynamic value) =>
    WallMetrics(n(value['cellSize']), n(value['gap']));
WallPoint point(dynamic v) => WallPoint(n(v['x']), n(v['y']));
WallView view(dynamic v) => WallView(
  n(v['width']),
  n(v['height']),
  n(v['scale']),
  lineX: v['lineX'] == null ? null : n(v['lineX']),
);
WallBounds bounds(dynamic v) =>
    WallBounds(n(v['left']), n(v['right']), n(v['top']), n(v['bottom']));
void equal(dynamic a, dynamic b, String at) {
  if (a is num && b is num && (a - b).abs() <= 1e-7 * (1 + b.abs())) return;
  if (a is List && b is List && a.length == b.length) {
    for (var i = 0; i < a.length; i++) {
      equal(a[i], b[i], '$at[$i]');
    }
    return;
  }
  if (a is Map && b is Map && a.length == b.length) {
    for (final k in b.keys) {
      equal(a[k], b[k], '$at.$k');
    }
    return;
  }
  if (a != b) throw StateError('$at: $a != $b');
}

void main() {
  final data = jsonDecode(
    File('test/fixtures/wall_reference.json').readAsStringSync(),
  ) as Map;
  for (final row in data['blockCases']) {
    final int c = row['column'], r = row['row'];
    final m = metrics(row['metrics']);
    equal(
      blockTemplate(c, r).map((s) => s.toJson()).toList(),
      row['template'],
      'template',
    );
    equal(blockSlotShuffle(c, r), row['shuffle'], 'shuffle');
    equal(
      blockSlots(c, r, m).map((s) => s.toJson()).toList(),
      row['slots'],
      'seats',
    );
    for (var i = 0; i < 12; i++) {
      equal(
        layoutFocusedBlock(c, r, i, m)!.map((s) => s.toJson()).toList(),
        row['reflows'][i],
        'reflow',
      );
    }
  }
  for (final row in data['finiteCases']) {
    final i = row['input'],
        m = metrics(i['metrics']),
        v = view(i['view']),
        o = point(i['origin']),
        input = FiniteWallInput(
          itemCount: i['itemCount'],
          metrics: m,
          view: v,
          origin: o,
          reservedPerBlock: n(i['reservedPerBlock']),
          startSlotKey: i['startSlotKey'],
        ),
        plan = planFiniteWall(input),
        content = rankedContentBounds(plan.order, input.itemCount);
    equal(plan.world.toJson(), row['world'], 'finite world');
    equal(plan.order.map((s) => s.key).toList(), row['order'], 'strict rank');
    equal(content?.toJson(), row['content'], 'occupied');
    equal(
      finiteCameraRange(
        contentBounds: content,
        anchor: o,
        view: v,
        seamWidth: 120,
      ).toJson(),
      row['range'],
      'range',
    );
    final seam = blockSeamPlan(
          cameraX: o.x,
          openWidth: 300,
          view: v,
          metrics: m,
        ),
        geo = seamGeometry(anchorX: -4, cameraX: o.x, openWidth: 300, view: v),
        offsets = seamSplitOffsets(120, v.scale, m);
    equal(
      {'x': seam.x, 'cameraX': seam.cameraX, 'shift': seam.shift},
      row['seam'],
      'seam',
    );
    equal(
      {
        'screenX': geo.screenX,
        'width': geo.width,
        'collapsed': geo.collapsed,
        'side': geo.side.name,
      },
      row['geometry'],
      'seam geometry',
    );
    equal(
      {'left': offsets.left, 'right': offsets.right},
      row['offsets'],
      'split',
    );
  }
  for (final row in data['latticeCases']) {
    final int count = row['count'];
    final m = metrics(row['metrics']),
        g = latticeGeometry(count, m),
        nearest = locateNearestInstance(
          g,
          count,
          count - 1,
          const WallPoint(-3000, 815),
          m,
        );
    equal(g.toJson(), row['geometry'], 'lattice geometry');
    equal(
      layoutLattice(
        g,
        count,
        bounds(row['bounds']),
        300,
        m,
      ).map((s) => s.toJson()).toList(),
      row['layout'],
      'lattice cull',
    );
    equal(nearest?.toJson(), row['nearest'], 'nearest queue copy');
    final expanded = nearest == null
        ? []
        : layoutExpandedBlock(g, count, nearest, m).entries
              .map(
                (e) => [
                  e.key,
                  {
                    'x': e.value.x,
                    'y': e.value.y,
                    'width': e.value.width,
                    'height': e.value.height,
                  },
                ],
              )
              .toList();
    equal(expanded, row['expanded'], 'queue expansion');
  }
  for (final row in data['viewCases']) {
    final v = view(row['view']),
        c = row['camera'],
        camera = WallCamera(n(c['x']), n(c['y']), n(c['scale'])),
        center = viewCenterFromCamera(camera, v),
        p = row['pair'],
        q = row['next'];
    equal(center.toJson(), row['center'], 'camera centre');
    equal(
      cameraFromViewCenter(center, v).toJson(),
      camera.toJson(),
      'camera roundtrip',
    );
    equal(
      viewWorldBounds(center, v, seamWidth: 120, overscan: 300).toJson(),
      row['bounds'],
      'view bounds',
    );
    equal(
      pinchWallCamera(
        camera,
        WallTouchPair(n(p['x']), n(p['y']), n(p['distance'])),
        WallTouchPair(n(q['x']), n(q['y']), n(q['distance'])),
      ).toJson(),
      row['pinch'],
      'pinch',
    );
  }
  for (final row in data['frameCases']) {
    final i = row['input'],
        v = view(i['view']),
        c = point(i['center']),
        frame = computeBravaisFrame(
          center: c,
          view: v,
          anchorX: i['anchorX'] == null ? null : n(i['anchorX']),
          openWidth: n(i['openWidth']),
          contentWidth: n(i['contentWidth']),
          hidden: i['hidden'],
          poster: i['poster'],
          tiltDeg: n(i['tiltDeg']),
        ),
        reach = tiltReach(v, frame.tilt),
        safe = posterSafeArea(520, 844, n(i['tiltDeg'])),
        opening = planPosterOpening(center: c, view: v, width: 520);
    equal(frame.toJson(), row['frame'], 'Bravais split frame');
    equal(reach.toJson(), row['reach'], 'inverse tilt culling reach');
    equal(
      {'scale': safe.scale, 'offsetY': safe.offsetY},
      row['safe'],
      'poster safe area',
    );
    equal(
      {'anchorX': opening.anchorX, 'center': opening.center.toJson()},
      row['opening'],
      'poster opening',
    );
  }
  WallSlot seat(dynamic s) => WallSlot(
    s['column'],
    s['row'],
    s['slotIndex'],
    n(s['x']),
    n(s['y']),
    n(s['width']),
    n(s['height']),
    s['area'],
  );
  for (final row in data['transitionCases']) {
    final changes = [
          for (final c in row['changes'])
            WallFaceChange(seat(c['slot']), c['from'], c['to']),
        ],
        o = row['origin'],
        origin = o['kind'] == 'point'
            ? WallFlipOrigin.point(n(o['x']), n(o['y']))
            : WallFlipOrigin.seamEdges(n(o['x'])),
        m = metrics(row['metrics']),
        visible = bounds(row['visible']);
    equal(
      planWallFlip(
        changes,
        origin,
        visible,
        m,
        maxTiles: row['maxTiles'],
      ).toJson(),
      row['flip'],
      'split flap scheduling',
    );
    equal(
      planBravaisWallWave(
        changes,
        bounds(row['viewport']),
        visible,
        m,
        maxTiles: row['maxTiles'],
      ).toJson(),
      row['wave'],
      'home wave scheduling',
    );
  }
  for (final row in data['wrapCases']) {
    final int count = row['count'];
    final reserved = n(row['reservedPerBlock']),
        a = row['address'],
        offset = startWallWrapOffset(
          (
            column: a['column'] as int,
            row: a['row'] as int,
            slotIndex: a['slotIndex'] as int,
          ),
          count,
          reservedPerBlock: reserved,
        ),
        period = wallWrapPeriod(count, reservedPerBlock: reserved);
    equal(offset, row['offset'], 'clicked first item');
    equal(
      {
        'blocksPerRow': period.blocksPerRow,
        'blockRows': period.blockRows,
        'perBlock': period.perBlock,
      },
      row['period'],
      'home repeat period',
    );
    for (final item in row['indices']) {
      final a = item['slot'];
      equal(
        infiniteWallItem(
          a['column'],
          a['row'],
          a['slotIndex'],
          count,
          offset,
          reservedPerBlock: reserved,
        ),
        item['index'],
        'home item seat',
      );
    }
  }
  for (final row in data['reflowCases']) {
    final curve = WallReflowCurve(n(row['distance']));
    equal(curve.durationMs, row['duration'], 'reflow settle');
    equal(curve.css, row['css'], 'CSS spring samples');
    for (final sample in row['samples']) {
      equal(
        curve.ease(n(sample['p'])),
        sample['value'],
        'reflow interpolation',
      );
    }
  }
  WallRect rect(dynamic r) =>
      WallRect(n(r['x']), n(r['y']), n(r['width']), n(r['height']));
  for (final row in data['plates']['plateCases']) {
    final frame = bravaisPlateFrame(
          row['column'],
          row['row'],
          row['anchorX'] == null ? null : n(row['anchorX']),
          blockWidth: n(row['width']),
        ),
        holes = [for (final h in row['holes']) rect(h)];
    equal(frame.toJson(), row['frame'], 'plate seam bleed');
    equal(
      disjointPlateRects(holes).map((r) => r.toJson()).toList(),
      row['disjoint'],
      'overlapping window union',
    );
    equal(
      buildBravaisPlatePath(frame, holes),
      row['d'],
      'exact original SVG backing path',
    );
  }
  final classifier = WallWheelClassifier();
  for (final row in data['wheelCases']) {
    final s = row['sample'],
        sample = WallWheelSample(
          n(s['deltaX']),
          n(s['deltaY']),
          n(s['timeStamp']),
          deltaMode: s['deltaMode'],
          shift: s['shiftKey'],
        ),
        delta = wallWheelDelta(sample, 844);
    equal(classifier.classify(sample).name, row['source'], 'wheel source');
    equal({'dx': delta.x, 'dy': delta.y}, row['delta'], 'wheel delta');
  }
  for (final row in data['wheelSteps']) {
    // Source record's pending field contains the remaining displacement, not the input.
    final step = stepWallWheel(const WallPoint(48, -160), n(row['dt']));
    equal(step.step.toJson(), row['step'], 'wheel step');
    equal(step.pending.toJson(), row['pending'], 'wheel pending');
  }
  for (final row in data['inertiaCases']) {
    final o = row['options'],
        motion = MotionInertia(
          0,
          velocity: n(o['velocity']),
          power: o['power'] == null ? .8 : n(o['power']),
          timeConstant: o['timeConstant'] == null ? 325 : n(o['timeConstant']),
          restDelta: o['restDelta'] == null ? .5 : n(o['restDelta']),
          min: o['min'] == null ? null : n(o['min']),
          max: o['max'] == null ? null : n(o['max']),
          bounceDamping: o['bounceDamping'] == null
              ? 10
              : n(o['bounceDamping']),
          bounceStiffness: o['bounceStiffness'] == null
              ? 500
              : n(o['bounceStiffness']),
        );
    for (final sample in row['samples']) {
      final t = n(sample['t']);
      equal(motion.x(t), sample['value'], 'inertia x@$t');
      equal(motion.isDone(t), sample['done'], 'inertia done@$t');
    }
  }
  stdout.writeln(
    'Original wall geometry/rank/culling, wheel classification and inertia contracts passed.',
  );
}
