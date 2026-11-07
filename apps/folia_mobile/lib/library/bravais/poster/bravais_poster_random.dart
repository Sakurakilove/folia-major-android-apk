// The source FNV-1a hashes UTF-16 code units; mulberry32 retains low 32 bits after every JavaScript imul/unsigned shift.
int hashBravaisPosterSeed(String seed) {
  var hash = 2166136261;
  for (final unit in seed.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0xffffffff;
  }
  return hash;
}

double Function() createBravaisPosterRandom(int seed) {
  var state = seed & 0xffffffff;
  return () {
    state = (state + 0x6d2b79f5) & 0xffffffff;
    var value = ((state ^ (state >> 15)) * (state | 1)) & 0xffffffff;
    value =
        (value ^
            (value + (((value ^ (value >> 7)) * (value | 61)) & 0xffffffff))) &
        0xffffffff;
    return ((value ^ (value >> 14)) & 0xffffffff) / 4294967296;
  };
}
