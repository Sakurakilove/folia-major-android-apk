import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:folia_mobile/artwork/cover_url.dart';
import 'package:folia_mobile/artwork/native_url.dart';
import 'package:folia_mobile/artwork/native_artwork_descriptors.dart';

// One native FFI/provider contract; no network requests, emulator, screenshot or power claim.
void main(List<String> args) {
  final urls = NativeUrlLibrary(library: DynamicLibrary.open(args[0])),
      policy = CoverUrlPolicy(urls),
      reference = jsonDecode(
        File('test/fixtures/cover_url_reference.json').readAsStringSync(),
      ) as Map;
  void equal(dynamic a, dynamic b, String at) {
    if (a is num && b is num && a == b) return;
    if (a is Map && b is Map && a.length == b.length) {
      for (final key in b.keys) {
        equal(a[key], b[key], '$at.$key');
      }
      return;
    }
    if (a != b) throw StateError('$at: $a != $b');
  }

  for (final row in reference['cases']) {
    final size = row['size'] is num
        ? (row['size'] as num).toDouble()
        : double.parse(row['size']);
    final sized = policy.sized(row['source'], size);
    equal(sized, row['sized'], 'sized');
    equal(policy.original(row['source']), row['original'], 'original');
    equal(policy.identity(row['source']), row['identity'], 'identity');
    equal(
      policy.describe(row['source'])?.toJson(),
      row['description'],
      'description',
    );
    equal(
      policy.describe(sized)?.toJson(),
      row['resizedDescription'],
      'resized description',
    );
    equal(localCoverThumbnailSize(size), row['localSize'], 'local bucket');
    final step = resolveCoverSizeStep(size);
    equal(step.isFinite ? step : 'Infinity', row['step'], 'variant bucket');
  }
  final artwork = NativeArtworkDescriptors(
    library: DynamicLibrary.open(args[1]),
  );
  for (final row in reference['dataCases']) {
    NativeArtworkData? data;
    try {
      data = artwork.decodeDataUri(row['normalized']);
    } on StateError {
      if (row['bytes'] != null) rethrow;
      continue;
    }
    try {
      equal(
        data.bytes.toList().join(','),
        (row['bytes'] as List?)?.join(','),
        'inline bytes',
      );
    } finally {
      data.dispose();
    }
  }
  final owner = urls.parse(
    'https://example.test/getCoverArt?a=%FF&size=1&size=2',
  )!;
  owner.setParameter('size', '512');
  final copied = owner.href, origin = owner.origin;
  equal(
    copied,
    'https://example.test/getCoverArt?a=%EF%BF%BD&size=512',
    'USV replacement and duplicate deletion',
  );
  owner.dispose();
  owner.dispose();
  equal(origin, 'https://example.test', 'owned origin copied before release');
  var rejected = false;
  try {
    owner.href;
  } on StateError {
    rejected = true;
  }
  if (!rejected) throw StateError('Closed native URL owner was not rejected');
  stdout.writeln(
    '${(reference['cases'] as List).length} original provider URL cases, 15 inline byte cases and native ownership passed (Ada ${urls.version}).',
  );
}
