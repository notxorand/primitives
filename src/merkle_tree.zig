const std = @import("std");
const crypto = std.crypto;
const testing = std.testing;

pub const Hash = [32]u8;
const MerkleTreeImpl = struct {
    const Self = @This();

    const Node = struct {
        const NodeSelf = @This();

        hash: Hash,
        left: ?Node,
        right: ?Node,

        pub fn init(hash: [32]u8) NodeSelf {
            return NodeSelf{
                .hash = hash,
                .left = null,
                .right = null,
            };
        }

        pub fn deinit(self: *Self) void {
            self.left = null;
            self.right = null;
        }
    };

    nodes: std.ArrayList(Node),
    root: ?Node,

    pub fn init() Self {
        return Self{
            .nodes = std.ArrayList(Node).init(std.testing.allocator),
            .root = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.nodes.deinit();
        self.root = null;
    }

    pub fn push(self: *Self, value: []u8) void {
        self.push_leaf(@as(Hash, crypto.hash.Blake3.hash(value)));
    }

    pub fn push_leaf(self: *Self, leaf: Hash) void {
        self.nodes.append(Node.init(leaf)) catch unreachable;
        if (self.root == null) {
            self.root = self.nodes.at(0);
        }
    }

    pub fn pop_leaf(self: *Self, leaf: Hash) void {
        var i: usize = 0;
        while (i < self.nodes.items.len) : (i += 1) {
            if (std.mem.eql(u8, self.nodes.items[i].hash, leaf)) {
                self.nodes.swapRemove(i);
                return;
            }
        }
        std.debug.panic("leaf not found", .{});
    }

    pub fn commit(self: *Self) void {
    }

    fn build(nodes: []Node) []Hash {

    }

    pub fn leaves(self: *Self) []const [32]u8 {
        var out = std.ArrayList([32]u8).init(std.testing.allocator);
        defer out.deinit();
        for (self.nodes.items) |node| {
            out.appendSlice(node.hash[0..]) catch unreachable;
        }
        return out.toOwnedSlice();
    }

    pub fn root_hash(self: *Self) [32]u8 {
        if (self.root) |root| {
            return root.hash;
        } else {
            return [_]u8{0} ** 32;
        }
    }

    fn hash_node(_: *Self, left: Node, right: ?Node) [32]u8 {
        var out: [32]u8 = undefined;
        crypto.hash.Blake3.init(.{});
        crypto.hash.Blake3.update(left.hash[0..]);
        if (right) |node| {
            crypto.hash.Blake3.update(node.hash[0..]);
        }
        crypto.hash.Blake3.final(&out);
        return out;
    }
};
