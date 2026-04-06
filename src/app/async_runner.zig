const std = @import("std");

pub fn AsyncRunner(comptime Msg: type) type {
    return struct {
        allocator: std.mem.Allocator,
        mutex: std.Thread.Mutex = .{},
        results: std.ArrayList(Msg) = .empty,
        next_id: u32 = 1,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.results.deinit(self.allocator);
        }

        pub fn spawn(self: *Self, func: *const fn () ?Msg) !u32 {
            const id = self.next_id;
            self.next_id += 1;

            const Task = struct {
                runner: *Self,
                callback: *const fn () ?Msg,

                fn run(task: *@This()) void {
                    defer task.runner.allocator.destroy(task);
                    if (task.callback()) |msg| task.runner.push(msg);
                }
            };

            const task = try self.allocator.create(Task);
            task.* = .{ .runner = self, .callback = func };
            _ = try std.Thread.spawn(.{}, Task.run, .{task});
            return id;
        }

        pub fn spawnWithArg(self: *Self, comptime Arg: type, arg: Arg, func: *const fn (Arg) ?Msg) !u32 {
            const id = self.next_id;
            self.next_id += 1;

            const Task = struct {
                runner: *Self,
                arg: Arg,
                callback: *const fn (Arg) ?Msg,

                fn run(task: *@This()) void {
                    defer task.runner.allocator.destroy(task);
                    if (task.callback(task.arg)) |msg| task.runner.push(msg);
                }
            };

            const task = try self.allocator.create(Task);
            task.* = .{ .runner = self, .arg = arg, .callback = func };
            _ = try std.Thread.spawn(.{}, Task.run, .{task});
            return id;
        }

        pub fn poll(self: *Self) ![]Msg {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.results.toOwnedSlice(self.allocator);
        }

        fn push(self: *Self, msg: Msg) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.results.append(self.allocator, msg) catch {};
        }
    };
}

test "async runner collects finished messages" {
    const Msg = enum(u8) { done };
    const Runner = AsyncRunner(Msg);
    var runner = Runner.init(std.testing.allocator);
    defer runner.deinit();

    const Fn = struct {
        fn call() ?Msg {
            return .done;
        }
    }.call;

    _ = try runner.spawn(Fn);
    std.Thread.sleep(10 * std.time.ns_per_ms);
    const results = try runner.poll();
    defer std.testing.allocator.free(results);
    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expectEqual(Msg.done, results[0]);
}
