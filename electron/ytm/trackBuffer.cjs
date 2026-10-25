// electron/ytm/trackBuffer.cjs
// One download fills a track's buffer front to back, and every reader (the audio element, the
// caches, automix) is answered from it.

const READ_CHUNK_BYTES = 256 * 1024;

class TrackBuffer {
  constructor(total, mimeType, storage = null) {
    this.total = total;
    this.mimeType = mimeType;
    this.storage = storage;
    this.bytes = storage ? null : Buffer.alloc(total);
    this.filled = 0;
    this.error = null;
    this.waiters = [];
    this.readers = 0;
    this.onIdle = null;
  }

  wake() {
    for (const resolve of this.waiters.splice(0)) resolve();
  }

  push(chunk) {
    if (this.filled + chunk.length > this.total) throw new Error('Track is longer than its declared length');
    if (this.error) throw this.error;
    const commit = () => { this.filled += chunk.length; this.wake(); };
    if (this.storage) return this.storage.write(chunk, this.filled).then(commit);
    this.bytes.set(chunk, this.filled);
    commit();
  }

  fail(error) {
    this.error = error instanceof Error ? error : new Error('Track download failed');
    this.wake();
  }

  dispose() {
    this.fail(new Error('Track was released'));
    return this.storage?.close();
  }

  // Streams bytes [start, end], waiting for the download where it has not reached them yet.
  // A failed download errors the stream, which the reader sees as a network error.
  read(start, end) {
    let position = start;
    let cancelled = false;
    let waiting = null;
    let released = false;
    this.readers += 1;
    const release = () => {
      if (released) return;
      released = true;
      this.readers -= 1;
      if (this.readers === 0) this.onIdle?.();
    };
    return new ReadableStream({
      pull: async controller => {
        while (this.filled <= position && !this.error && !cancelled) {
          await new Promise(resolve => {
            waiting = resolve;
            this.waiters.push(resolve);
          });
          waiting = null;
        }
        if (cancelled) return;
        if (this.filled <= position) { release(); controller.error(this.error); return; }
        const upTo = Math.min(this.filled, end + 1, position + READ_CHUNK_BYTES);
        let bytes;
        try {
          bytes = this.storage
            ? await this.storage.read(position, upTo - position)
            : new Uint8Array(this.bytes.subarray(position, upTo));
        } catch (error) { if (!cancelled) { release(); controller.error(error); } return; }
        if (cancelled) return;
        controller.enqueue(bytes);
        position = upTo;
        if (position > end) { release(); controller.close(); }
      },
      cancel: () => {
        cancelled = true;
        if (waiting) {
          const index = this.waiters.indexOf(waiting);
          if (index !== -1) this.waiters.splice(index, 1);
          waiting();
          waiting = null;
        }
        release();
      },
    });
  }
}

// Keeps the most recently used entries within a byte budget; the newest entry always stays.
// `onDrop(value)` is told about every entry that leaves, however it leaves.
function createByteLru(maxBytes, onDrop = () => {}) {
  const entries = new Map();
  let total = 0;
  return {
    get(key) {
      const entry = entries.get(key);
      if (!entry) return undefined;
      entries.delete(key);
      entries.set(key, entry);
      return entry.value;
    },
    set(key, value, size) {
      this.delete(key);
      entries.set(key, { value, size });
      total += size;
      for (const [oldKey, old] of entries) {
        if (total <= maxBytes || oldKey === key) break;
        entries.delete(oldKey);
        total -= old.size;
        onDrop(old.value, 'eviction');
      }
    },
    delete(key) {
      const entry = entries.get(key);
      if (!entry) return;
      entries.delete(key);
      total -= entry.size;
      onDrop(entry.value);
    },
    clear() {
      const dropped = [...entries.values()];
      entries.clear();
      total = 0;
      for (const entry of dropped) onDrop(entry.value);
    },
    keys() { return [...entries.keys()]; },
    get size() { return entries.size; },
  };
}

module.exports = { TrackBuffer, createByteLru };
