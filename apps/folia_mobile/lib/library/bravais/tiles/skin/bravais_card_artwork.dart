part of 'bravais_card_content.dart';

// Keep artistic cover assembly separate from the card's content/lifecycle entry.
List<Widget> _cardArtwork(BravaisCardContent w, bool active) {
  final r = w.resources,
      look = w.look,
      p = look.palette,
      item = look.face.item,
      heading = look.face.kind == BravaisTileKind.heading,
      art = !look.face.seeThrough && !look.isExpanded ? item?.coverArt : null,
      slot = parseWallSlotKey(w.slotKey),
      size = math.max(w.rect.width, w.rect.height) * w.pixelScale;
  return [
    if (item != null &&
        item.form == BravaisTileForm.portrait &&
        !look.face.seeThrough &&
        !heading)
      BravaisArtistArtwork(
        itemKey: item.key,
        cover: item.coverUrl,
        sizePx: size,
        palette: p,
        samples: r.samples,
        program: r.program,
        store: r.store,
        frames: r.frames,
        nowMs: r.nowMs,
        restored: look.portraitRestored,
        reducedMotion: w.reducedMotion,
        active: active,
      ),
    if (item != null && art != null && !heading)
      BravaisAlbumArtwork(
        art: art,
        itemKey: item.key,
        rect: w.rect,
        column: slot?.column ?? 0,
        row: slot?.row ?? 0,
        pixelScale: w.pixelScale,
        accent: r.albumAccent,
        block: r.albumBlock,
        samples: r.samples,
        store: r.store,
        program: r.program,
        frames: r.frames,
        nowMs: r.nowMs,
        restored: look.shardRestored,
        active: active,
      ),
  ];
}
