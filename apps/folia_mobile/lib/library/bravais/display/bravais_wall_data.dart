import '../../wall/explore/explore_lots.dart';
import '../tiles/bravais_item.dart';
import 'bravais_wall_look.dart';

// The wall-only projection of the original layer. Seam models, provider actions and navigation stay with their host; display data cannot invent those operations.
class BravaisWallData {
  const BravaisWallData({
    required this.key,
    required this.sessionKey,
    required this.mode,
    required this.items,
    this.periodCount = 0,
    this.planCount = 0,
    this.filterKey = '',
    this.isLoading = false,
    this.sections,
    this.headings = const [],
    this.nowPlayingKey,
    this.queuedKeys = const {},
  });
  final String key, sessionKey, filterKey;
  final BravaisLayerMode mode;
  final List<BravaisItem> items;
  final int periodCount, planCount;
  final bool isLoading;
  final List<ExploreSection>? sections;
  final List<BravaisItem> headings;
  final String? nowPlayingKey;
  final Set<String> queuedKeys;
  int get period => periodCount > items.length ? periodCount : items.length;
}
