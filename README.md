# zig primitives

A collection of common data structures, trees, and concurrency primitives in Zig. Most of these exist in the Rust ecosystem already (not standardised), so I'm porting them over.

## Implemented

### Data Structures
- **Bitmap** - Efficient bit manipulation and storage with prepare/commit pattern
- **Bloom Filter** - Probabilistic membership testing with builder pattern and sensible defaults
- **Skip List** - Probabilistic balanced search structure with generic key/value types

### Concurrency & Synchronization
- **Arc(T)** - Atomic reference counted smart pointer for shared ownership across threads
- **Mutex(T)** - Generic mutex with RAII Guard pattern preventing use-after-unlock bugs

### Time & Ordering
- **Hybrid Logical Clock (HLC)** - Causally consistent timestamping for distributed systems
- **Last-Write-Wins (LWW) Registry** - Conflict-free replicated registry using HLC with generic causal tags

## Quick Start

### Bloom Filter

```zig
const primitives = @import("primitives");

// Using defaults for common sizes
var bloom = primitives.bloom.Defaults.Small.init();
defer bloom.deinit();

bloom.insert("user:1234");
if (bloom.contains("user:1234")) {
    // Probably in the set (false positives possible)
}

// Using builder pattern for custom sizing
var bloom_custom = primitives.bloom.BloomBuilder
    .new()
    .forItemCount(10000, 0.01)  // 10k items, 1% false positive rate
    .build();
defer bloom_custom.deinit();

bloom_custom.insert("key");
if (bloom_custom.contains("key")) { }

// Configure hash function
var bloom_xxhash = primitives.bloom.BloomBuilder
    .new()
    .withSize(1024)
    .withHashFunction(primitives.bloom.AlternateHashFn)
    .build();
defer bloom_xxhash.deinit();
```

### Skip List

```zig
const primitives = @import("primitives");
const allocator = gpa.allocator();

// String key/value skip list (default)
var sl = try primitives.skiplist.StringSkipList.init(allocator, @intCast(std.time.microTimestamp()));
defer sl.deinit();

_ = try sl.insert("alice", "engineer");
_ = try sl.insert("bob", "designer");

if (sl.search("alice")) |node| {
    std.debug.print("Found: {s}\n", .{node.value});
}

// Using builder for custom configuration
var sl_large = try primitives.skiplist.SkipListBuilder
    .new()
    .large()  // Optimized for millions of items
    .build(allocator);
defer sl_large.deinit();

// Custom seed for reproducible structure
var sl_deterministic = try primitives.skiplist.SkipListBuilder
    .new()
    .withMaxLevel(20)
    .withSeed(12345)
    .build(allocator);
defer sl_deterministic.deinit();
```

### Arc (Atomic Reference Counting)

```zig
const primitives = @import("primitives");

// Simple usage
var shared = try primitives.arc.Arc(u32).init(allocator, 42);
var clone1 = shared.clone();
var clone2 = shared.clone();

std.debug.print("Refcount: {}\n", .{shared.refcount()}); // 3

clone1.release();
clone2.release();
shared.release();

// With Mutex for mutable shared state
var data = try primitives.arc.Arc(primitives.Mutex(u32)).init(
    allocator,
    primitives.Mutex(u32).init(0),
);
defer data.release();

{
    var guard = data.getMut().lock();
    defer guard.deinit();
    guard.get().* += 1;
}
```

### Mutex

```zig
const primitives = @import("primitives");

var counter = primitives.Mutex(u32).init(0);

{
    var guard = counter.lock();
    defer guard.deinit();
    guard.get().* += 1;
}

// Try lock (non-blocking)
if (counter.try_lock()) |guard| {
    defer guard.deinit();
    counter_value = guard.get().*;
}
```

### Last-Write-Wins Registry

```zig
const primitives = @import("primitives");

// With SimpleCausalTag (default - just a cause ID)
var registry: primitives.lww.SimpleLwwRegistry = undefined;
registry = primitives.lww.SimpleLwwRegistry.init(allocator);
defer registry.deinit();

const ts = primitives.hlc.Timestamp{ .wall = 100, .logical = 0, .node_id = 1 };
try registry.put("config:timeout", ts, .{ .Int = 30 }, .{ .cause = 1 });

if (registry.get("config:timeout")) |entry| {
    std.debug.print("Value: {}\n", .{entry.value.Int});
    std.debug.print("Set by cause: {}\n", .{entry.cause.cause});
}

// With no causal tracking (void tag)
var simple_lww: primitives.lww.VoidLwwRegistry = undefined;
simple_lww = primitives.lww.VoidLwwRegistry.init(allocator);
defer simple_lww.deinit();

try simple_lww.put("key", ts, .{ .Bool = true }, {});

// With detailed causal information
var detailed_lww: primitives.lww.DetailedLwwRegistry = undefined;
detailed_lww = primitives.lww.DetailedLwwRegistry.init(allocator);
defer detailed_lww.deinit();

const tag: primitives.lww.DetailedCausalTag = .{
    .cause = 42,
    .entity = 100,
    .node = "node-1",
};
try detailed_lww.put("metric", ts, .{ .Float = 3.14 }, tag);
```

### Hybrid Logical Clock

```zig
const primitives = @import("primitives");

var clock = primitives.hlc.Hlc.init(1); // node_id = 1

// Generate timestamp before sending
const send_ts = clock.send();

// On receiving a remote timestamp, advance past it
const remote_ts = primitives.hlc.Timestamp{ .wall = 500, .logical = 0, .node_id = 2 };
const recv_ts = clock.recv(remote_ts);

// All subsequent timestamps are causally after remote_ts
const next_ts = clock.send();
std.debug.print("Causal order: {} < {}\n", .{remote_ts.compare(next_ts), std.math.Order.lt});
```

## Design Principles

- **Sensible Defaults**: Common sizes and configurations are pre-tuned
- **Builder Pattern**: Structures that benefit from configuration use proper builders with `.build()` methods
- **Generic Comptime Parameters**: Full flexibility for custom types while maintaining ergonomics
- **RAII & Safety**: Mutex guards, Arc reference counting, and explicit lifecycle management
- **Comprehensive Tests**: All primitives have extensive test coverage

## Architecture

### Builders (True Builders with `.build()`)
- `BloomBuilder` - Size calculation, hash function selection, preset sizes (small/medium/large)
  - Methods: `.new()`, `.withSize()`, `.withHashFunction()`, `.forItemCount()`, `.build()`
  - Presets: `.small()`, `.medium()`, `.large()`
- `SkipListBuilder` - Max levels, seed configuration
  - Methods: `.new()`, `.withMaxLevel()`, `.withSeed()`, `.build(allocator)`
  - Presets: `.small()`, `.medium()`, `.large()`

### Type Aliases for Convenience
- `StringSkipList` - `[]const u8` key/value skip list
- `U64SkipList` - `u64` key/value skip list
- `I64SkipList` - `i64` key/value skip list
- `SimpleLwwRegistry` - LwwRegistry with `SimpleCausalTag`
- `DetailedLwwRegistry` - LwwRegistry with `DetailedCausalTag`
- `VoidLwwRegistry` - LwwRegistry with no causal tracking (void tag)

### Direct Initialization (No Builder Needed)
- `Arc(T).init(allocator, value)` - Already ergonomic
- `Mutex(T).init(data)` - Already ergonomic
- Bloom `Defaults.Small/Medium/Large` - Pre-built filters
- LwwRegistry variants - Direct `.init(allocator)` calls

## Performance Characteristics

| Structure | Insertion | Search | Deletion | Space |
|-----------|-----------|--------|----------|-------|
| Bloom Filter | O(k) | O(k) | N/A | O(m) |
| Skip List | O(log n) avg | O(log n) avg | O(log n) avg | O(n) |
| Arc | O(1) | N/A | O(1)* | O(1) overhead |
| Mutex | N/A | O(1) | N/A | O(1) |
| LWW Registry | O(1) avg | O(1) avg | O(1) avg | O(n) |

*Arc deallocation is O(1) amortized across all clones

## Planned

If you want to help send in PRs. 

- [ ] ring buffer
- [ ] cuckoo filter
- [ ] merkle tree
- [ ] merkle mountain range (mmr)
- [ ] sparse merkle tree (smt)
- [ ] lamport clock
- [ ] vector clock

## Notes

- Most implementations include comprehensive test coverage
- Arc and Mutex can be composed for thread-safe shared mutable state (e.g., `Arc(Mutex(T))`)
- HLC provides total ordering of events across distributed systems with causal consistency
- LwwRegistry is generic over causal tag type for maximum flexibility
- Zig is evolving. Code patterns and APIs will tend to evolve alongside
