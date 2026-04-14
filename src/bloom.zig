//! A simple bloom filter implementation.
//!
//! Bloom filter is a space-efficient probabilistic data structure that is used to test whether an element is a member of a set. False positives are possible, but false negatives are not.
//! This has insertion and membership checking. There are 2 variants of this data structure:
//!
//! * `Bloom`: A bloom filter with a fixed size and a single hash function.
//! * `BloomMultiHash`: A bloom filter with a fixed size and multiple hash functions.
//!
//! There's plans for a counting bloom filter and eventually a cuckoo filter.

const std = @import("std");
const testing = std.testing;

const bitmap = @import("bitmap.zig");

fn BloomImpl(comptime size: usize, comptime HashFn: type) type {
    return struct {
        const Self = @This();

        mask: bitmap.Bitmap(size),
        /// Initialise a bloom filter with a given size and hash function.
        pub fn init() Self {
            return Self{
                .mask = bitmap.Bitmap(size).init(),
            };
        }

        /// Deinitialise the bloom filter.
        pub fn deinit(self: *Self) void {
            self.mask.deinit();
        }

        /// Insert a value into the bloom filter.
        pub fn insert(self: *Self, value: []const u8) void {
            const hash_value = HashFn.hash(value);
            const index = if (comptime std.math.isPowerOfTwo(size))
                hash_value & (size - 1)
            else
                hash_value % size;
            self.mask.prepare();
            self.mask.set(index);
            self.mask.commit();
        }

        /// Check if a value is in the bloom filter.
        pub fn contains(self: *Self, value: []const u8) bool {
            const hash_value = HashFn.hash(value);
            const index = if (comptime std.math.isPowerOfTwo(size))
                hash_value & (size - 1)
            else
                hash_value % size;
            return self.mask.get(index);
        }

        /// Get the length of the bloom filter.
        pub fn len(self: *Self) usize {
            return self.mask.len();
        }

        /// Reset the bloom filter (clear all bits).
        pub fn reset(self: *Self) void {
            @memset(&self.mask.bits, 0);
        }
    };
}

fn BloomMutliHashFn(comptime size: usize, comptime HashFn: []const type) type {
    comptime {
        if (HashFn.len == 0) {
            @compileError("Need at least one hash function");
        } else if (HashFn.len == 1) {
            @compileLog("It's suggested to use `Bloom` instead of `BloomMutliHash` for a single hash function");
        }
    }
    return struct {
        const Self = @This();

        mask: bitmap.Bitmap(size),

        /// Initialise a bloom filter with a given size and hash functions.
        pub fn init() Self {
            return Self{
                .mask = bitmap.Bitmap(size).init(),
            };
        }

        /// Deinitialise the bloom filter.
        pub fn deinit(self: *Self) void {
            self.mask.deinit();
        }

        /// Insert a value into the bloom filter.
        pub fn insert(self: *Self, value: []const u8) void {
            inline for (HashFn) |hash_fn| {
                const hash_value = hash_fn.hash(value);
                const index = if (comptime std.math.isPowerOfTwo(size))
                    hash_value & (size - 1)
                else
                    hash_value % size;
                self.mask.prepare();
                self.mask.set(index);
                self.mask.commit();
            }
        }

        /// Check if a value is in the bloom filter.
        pub fn contains(self: *Self, value: []const u8) bool {
            inline for (HashFn) |hash_fn| {
                const hash_value = hash_fn.hash(value);
                const index = if (comptime std.math.isPowerOfTwo(size))
                    hash_value & (size - 1)
                else
                    hash_value % size;
                if (!self.mask.get(index)) {
                    return false;
                }
            }
            return true;
        }

        /// Get the length of the bloom filter.
        pub fn len(self: *Self) usize {
            return self.mask.len();
        }

        /// Get the number of hash functions.
        pub fn hashers(_: *Self) usize {
            return HashFn.len;
        }
    };
}

/// A simple bloom filter implementation supporting a single hash function.
pub const Bloom = BloomImpl;
/// A simple bloom filter implementation supporting multiple hash functions.
///
pub const BloomMultiHash = BloomMutliHashFn;

pub const DefaultHashFn = struct {
    pub fn hash(value: []const u8) usize {
        return @as(usize, @truncate(std.hash.Wyhash.hash(0, value)));
    }
};

pub const AlternateHashFn = struct {
    pub fn hash(value: []const u8) usize {
        return @as(usize, @truncate(std.hash.XxHash3.hash(0, value)));
    }
};

/// Sensible defaults for common Bloom filter sizes
pub const Defaults = struct {
    /// Small filter for ~100 items with ~1% false positive rate
    pub const Small = Bloom(1024, DefaultHashFn);

    /// Medium filter for ~10k items with ~1% false positive rate
    pub const Medium = Bloom(131072, DefaultHashFn);

    /// Large filter for ~1M items with ~1% false positive rate
    pub const Large = Bloom(9437184, DefaultHashFn);
};

/// Builder for Bloom filters with sensible defaults
pub const BloomBuilder = struct {
    size: usize = 4096,
    hash_fn: type = DefaultHashFn,

    /// Start building a Bloom filter
    pub fn new() BloomBuilder {
        return .{};
    }

    /// Set the size of the bloom filter (in bits)
    pub fn withSize(self: BloomBuilder, size: usize) BloomBuilder {
        return .{
            .size = size,
            .hash_fn = self.hash_fn,
        };
    }

    /// Set the hash function to use
    pub fn withHashFunction(self: BloomBuilder, comptime hash_fn: type) BloomBuilder {
        return .{
            .size = self.size,
            .hash_fn = hash_fn,
        };
    }

    /// Estimate size based on expected item count and false positive rate
    /// FPR is expressed as a fraction (e.g., 0.01 for 1%)
    pub fn forItemCount(self: BloomBuilder, item_count: usize, fpr: f64) BloomBuilder {
        // Formula: size = -1 / ln(2)^2 * n * ln(p)
        const ln2_sq = 0.4804530139592104;
        const ln_fpr = std.math.ln(fpr);
        const calculated_size = @as(usize, @intFromFloat(-ln_fpr / ln2_sq * @as(f64, @floatFromInt(item_count))));

        // Round up to nearest power of 2 for efficient modulo
        const size = std.math.ceilPowerOfTwo(usize, calculated_size) catch calculated_size;

        return .{
            .size = size,
            .hash_fn = self.hash_fn,
        };
    }

    /// Build a small filter (good for ~100 items)
    pub fn small() BloomBuilder {
        return .{ .size = 1024 };
    }

    /// Build a medium filter (good for ~10k items)
    pub fn medium() BloomBuilder {
        return .{ .size = 131072 };
    }

    /// Build a large filter (good for ~1M items)
    pub fn large() BloomBuilder {
        return .{ .size = 9437184 };
    }

    /// Build the Bloom filter with configured parameters
    pub fn build(self: BloomBuilder) Bloom(self.size, self.hash_fn) {
        return Bloom(self.size, self.hash_fn).init();
    }
};

test "Bloom: insert/contains" {
    var bloom = Bloom(100, DefaultHashFn).init();
    defer bloom.deinit();

    bloom.insert("hello");
    bloom.insert("world");

    try testing.expect(bloom.contains("hello"));
    try testing.expect(bloom.contains("world"));
    try testing.expect(!bloom.contains("foo"));
    try testing.expect(bloom.len() == 100);
}

test "Bloom: multi hash" {
    var bloom = BloomMultiHash(100, &.{ DefaultHashFn, AlternateHashFn }).init();
    defer bloom.deinit();

    bloom.insert("hello");
    bloom.insert("world");

    try testing.expect(bloom.contains("hello"));
    try testing.expect(bloom.contains("world"));
    try testing.expect(!bloom.contains("foo"));
    try testing.expect(bloom.len() == 100);
    try testing.expect(bloom.hashers() == 2);
}

test "BloomBuilder: default" {
    var bloom = BloomBuilder.new().build();
    defer bloom.deinit();

    bloom.insert("test");
    try testing.expect(bloom.contains("test"));
}

test "BloomBuilder: small" {
    var bloom = BloomBuilder.new().small().build();
    defer bloom.deinit();

    bloom.insert("data");
    try testing.expect(bloom.contains("data"));
}

test "BloomBuilder: forItemCount" {
    var bloom = BloomBuilder.new().forItemCount(1000, 0.01).build();
    defer bloom.deinit();

    bloom.insert("item");
    try testing.expect(bloom.contains("item"));
}

test "BloomBuilder: withHashFunction" {
    var bloom = BloomBuilder.new().withSize(1024).withHashFunction(AlternateHashFn).build();
    defer bloom.deinit();

    bloom.insert("hashed");
    try testing.expect(bloom.contains("hashed"));
}
