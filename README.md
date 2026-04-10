# primitives

This is a compilation of common data structures, trees, and concurrency primitives in Zig. Most of these exist in the Rust ecosystem already (not standardised), so I'm mostly porting them over.

## Implemented

### Data Structures
+ [x] bitmap
+ [x] bloom filter
+ [x] skip list

### Concurrency & Synchronization
+ [x] Arc(T) - Atomic Reference Counted smart pointer
+ [x] Mutex(T) - Generic mutex with RAII Guard pattern

### Time & Ordering
+ [x] Hybrid Logical Clock (HLC) - causally consistent timestamping
+ [x] Last-Write-Wins (LWW) Registry - conflict-free replicated registry using HLC

## Planned

+ [ ] ring buffer
+ [ ] cuckoo filter
+ [ ] merkle tree
+ [ ] merkle mountain range (mmr)
+ [ ] sparse merkle tree (smt)
+ [ ] lamport clock
+ [ ] vector clock

## Notes

+ Most implementations include comprehensive test coverage.
+ Arc and Mutex can be composed for thread-safe shared mutable state (e.g., `Arc(Mutex(T))`).
+ HLC provides total ordering of events across distributed systems with causal consistency.
