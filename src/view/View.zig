const std = @import("std");
const WebView = @import("webview").WebView;

// only to be used in the view thread
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var threadSafe = std.heap.ThreadSafeAllocator{ .child_allocator = gpa.allocator() };
const allocator = threadSafe.allocator();

const Shared = struct {
    const State = union(enum) {
        uninitialized: void,
        failure: anyerror,
        active: WebView,
        destroyed: void,
    };
    mutex: std.Thread.Mutex = .{},
    on_change: std.Thread.Condition = .{},
    state: State = .uninitialized,

    pub fn setState(self: *Shared, state: State) void {
        {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.state = state;
        }
        self.on_change.signal();
    }

    pub fn nextState(self: *Shared, prev: std.meta.Tag(State)) State {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.nextStateLocked(prev);
    }

    pub fn nextStateLocked(self: *Shared, prev: std.meta.Tag(State)) State {
        while (std.meta.activeTag(self.state) == prev) {
            self.on_change.wait(&self.mutex);
        }
        return self.state;
    }

    pub fn checkErr(self: *Shared) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.checkErrLocked();
    }

    pub fn checkErrLocked(self: *Shared) !void {
        switch (self.state) {
            .failure => |e| return e,
            else => return,
        }
    }
};

shared: *Shared,
thread: std.Thread,
// webview: WebView,

const View = @This();

pub fn init() !View {
    const shared = try allocator.create(Shared);
    shared.* = Shared{};
    const thread = try std.Thread.spawn(
        .{ .allocator = allocator },
        start,
        .{shared},
    );

    switch (shared.nextState(.uninitialized)) {
        .active => return View{ .shared = shared, .thread = thread },
        .failure => |e| {
            allocator.destroy(shared);
            return e;
        },
        else => {
            allocator.destroy(shared);
            return error.UnexpectedState;
        },
    }
}

fn start(shared: *Shared) void {
    const webview = WebView.create(true, null);
    std.log.debug("setup dispatch", .{});
    webview.dispatch(setup, shared);
    std.log.debug("gonna run!", .{});
    webview.run();
}

fn setup(webview: WebView, arg: ?*anyopaque) void {
    const shared: *Shared = @ptrCast(@alignCast(arg.?));
    setupErr(webview, shared) catch |e|
        shared.setState(.{ .failure = e });
}

fn setupErr(webview: WebView, shared: *Shared) !void {
    std.log.debug("actually running!", .{});
    webview.setSize(720, 720, .None);
    webview.setTitle("Viking Chess");
    {
        const html: [:0]u8 = std.fs.cwd().readFileAllocOptions(
            allocator,
            "static/index.html",
            std.math.maxInt(usize),
            2000,
            @alignOf(u8),
            0,
        ) catch |e| {
            std.log.err("could not read html: {}", .{e});
            return e;
        };

        defer allocator.free(html);
        const js: [:0]u8 = std.fs.cwd().readFileAllocOptions(
            allocator,
            "static/onInit.js",
            std.math.maxInt(usize),
            2000,
            @alignOf(u8),
            0,
        ) catch |e| {
            std.log.err("could not read js: {}", .{e});
            return e;
        };
        defer allocator.free(js);
        webview.init(js);
        webview.setHtml(html);
    }
    std.log.debug("done setting up!", .{});
    shared.setState(.{ .active = webview });
}

pub fn deinit(view: View) !void {
    // no matter what, this should join the thread & destroy the shared memory
    defer {
        view.thread.join();
        allocator.destroy(view.shared);
    }

    // acquire lock
    view.shared.mutex.lock();
    defer view.shared.mutex.unlock();

    // only dispatch teardown if currently `active`, otherwise, return error
    // (would still join on thread and destroy memory)
    switch (view.shared.state) {
        .active => |webview| {
            webview.dispatch(teardown, view.shared);
        },
        .failure => |e| return e,
        else => return error.UnexpectedState,
        // there shouldn't be a way for `shared` to be allocated when `destroyed`
    }

    // similarly, ensure the next state is `destroyed`, otherwise error
    switch (view.shared.nextStateLocked(.active)) {
        .destroyed => {},
        .failure => |e| return e,
        else => return error.UnexpectedState,
    }
}

fn teardown(webview: WebView, arg: ?*anyopaque) void {
    const shared: *Shared = @ptrCast(@alignCast(arg.?));
    std.log.debug("teardown start", .{});
    webview.terminate();
    webview.destroy();
    shared.setState(.destroyed);
    std.log.debug("teardown end, goodbye!", .{});
}
