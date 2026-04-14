//! Shared data structure primitives and concurrency utilities

pub const bitmap = @import("bitmap.zig");
pub const bloom = @import("bloom.zig");
pub const skiplist = @import("skiplist.zig");
pub const arc = @import("arc.zig");
pub const mutex = @import("mutex.zig");
pub const hlc = @import("hlc.zig");
pub const lww = @import("lww.zig");

// Re-export commonly used types
pub const Arc = arc.Arc;
pub const Mutex = mutex.Mutex;
pub const Hlc = hlc.Hlc;
pub const Timestamp = hlc.Timestamp;
pub const LwwRegistry = lww.LwwRegistry;

// Re-export builders
pub const BloomBuilder = bloom.BloomBuilder;
pub const SkipListBuilder = skiplist.SkipListBuilder;

// Re-export convenience types - Skip List
pub const StringSkipList = skiplist.StringSkipList;
pub const U64SkipList = skiplist.U64SkipList;
pub const I64SkipList = skiplist.I64SkipList;

// Re-export convenience types - LWW Registry
pub const SimpleLwwRegistry = lww.SimpleLwwRegistry;
pub const DetailedLwwRegistry = lww.DetailedLwwRegistry;
pub const VoidLwwRegistry = lww.VoidLwwRegistry;
pub const SimpleCausalTag = lww.SimpleCausalTag;
pub const DetailedCausalTag = lww.DetailedCausalTag;

// Re-export Bloom defaults
pub const BloomDefaults = bloom.Defaults;

// Re-export hash functions
pub const DefaultHashFn = bloom.DefaultHashFn;
pub const AlternateHashFn = bloom.AlternateHashFn;
