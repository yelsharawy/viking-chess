const std = @import("std");
const WebView = @import("webview").WebView;

// only to be used in the view thread
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var threadSafe = std.heap.ThreadSafeAllocator{ .child_allocator = gpa.allocator() };
const allocator = threadSafe.allocator();

const State = union(enum) {
    uninitialized: void,
    failure: anyerror,
    active: WebView,
    destroyed: void,
};

mutex: std.Thread.Mutex = .{},
on_change: std.Thread.Condition = .{},
state: State = .uninitialized,
thread: std.Thread,

pub fn setState(self: *View, state: State) void {
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.state = state;
    }
    self.on_change.signal();
}

pub fn nextState(self: *View, prev: std.meta.Tag(State)) State {
    self.mutex.lock();
    defer self.mutex.unlock();
    return self.nextStateLocked(prev);
}

pub fn nextStateLocked(self: *View, prev: std.meta.Tag(State)) State {
    while (std.meta.activeTag(self.state) == prev) {
        self.on_change.wait(&self.mutex);
    }
    return self.state;
}

pub fn checkErr(self: *View) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    return self.checkErrLocked();
}

pub fn checkErrLocked(self: *View) !void {
    switch (self.state) {
        .failure => |e| return e,
        else => return,
    }
}

const View = @This();
pub fn init() !*View {
    const view = try allocator.create(View);
    errdefer allocator.destroy(view);

    // initializes mutex, condition, and state
    view.* = View{ .thread = undefined };

    // it'd be smart to lock, but unnecessary,
    // since the thread won't need to access its own `Thread` through `view`

    view.thread = try std.Thread.spawn(
        .{ .allocator = allocator },
        start,
        .{view},
    );

    switch (view.nextState(.uninitialized)) {
        .active => return view,
        .failure => |e| return e,
        else => return error.UnexpectedState,
    }
}

fn start(view: *View) void {
    const webview = WebView.create(true, null);
    std.log.debug("setup dispatch", .{});
    webview.dispatch(setup, view);
    std.log.debug("gonna run!", .{});
    webview.run();
}

fn setup(webview: WebView, arg: ?*anyopaque) void {
    const view: *View = @ptrCast(@alignCast(arg.?));
    setupErr(webview, view) catch |e|
        view.setState(.{ .failure = e });
}

fn setupErr(webview: WebView, view: *View) !void {
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
    view.setState(.{ .active = webview });
}

pub fn deinit(view: *View) !void {
    // no matter what, this should join the thread & destroy the view memory
    defer {
        view.thread.join();
        allocator.destroy(view);
    }

    // acquire lock
    view.mutex.lock();
    defer view.mutex.unlock();

    // only dispatch teardown if currently `active`, otherwise, return error
    // (would still join on thread and destroy memory)
    switch (view.state) {
        .active => |webview| {
            webview.dispatch(teardown, view);
        },
        .failure => |e| return e,
        else => return error.UnexpectedState,
        // there shouldn't be a way for `view` to be allocated when `destroyed`
    }

    // similarly, ensure the next state is `destroyed`, otherwise error
    switch (view.nextStateLocked(.active)) {
        .destroyed => {},
        .failure => |e| return e,
        else => return error.UnexpectedState,
    }
}

fn teardown(webview: WebView, arg: ?*anyopaque) void {
    const view: *View = @ptrCast(@alignCast(arg.?));
    std.log.debug("teardown start", .{});
    webview.terminate();
    webview.destroy();
    view.setState(.destroyed);
    std.log.debug("teardown end, goodbye!", .{});
}
