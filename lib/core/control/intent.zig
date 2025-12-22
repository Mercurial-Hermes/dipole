const std = @import("std");
const feed = @import("semantic_feed");
const ctl = @import("controller");

pub const IntentVersion = struct {
    major: u16,
    minor: u16,
};

pub const IntentKind = enum(u8) {
    Ping,
};

/// Immutable, typed, versioned intent representation.
pub const Intent = struct {
    kind: IntentKind,
    version: IntentVersion,
};

/// Marker type proving validation has occurred. Carries no additional authority.
pub const ValidatedIntent = struct {
    intent: Intent,
};

// TS4-local error namespace: do not reuse in TS3 or emit as Events.
pub const ValidateError = error{
    UnknownIntent,
    UnknownIntentVersion,
    MissingSemanticFrame,
};

pub const ping_intent_name = "intent.ping";
pub const ping_intent_version = IntentVersion{ .major = 1, .minor = 0 };

fn versionsEqual(a: IntentVersion, b: IntentVersion) bool {
    return a.major == b.major and a.minor == b.minor;
}

fn frameSupportsValidation(frame: feed.Frame) bool {
    // NOTE: v0.2 exemplar only. Validation is deliberately coupled to event.kind@1.0
    // to exercise the TS4 path; do not generalize semantic coupling here.
    if (!std.mem.eql(u8, frame.projection_id, "event.kind")) return false;
    if (frame.version) |v| return v.major == 1 and v.minor == 0;
    return true;
}

pub fn intentName(kind: IntentKind) []const u8 {
    return switch (kind) {
        .Ping => ping_intent_name,
    };
}

pub fn pingIntent() Intent {
    return .{ .kind = .Ping, .version = ping_intent_version };
}

/// Pure, deterministic validation over derived Frames only.
pub fn validateIntent(intent_value: Intent, frames: []const feed.Frame) ValidateError!ValidatedIntent {
    if (intent_value.kind != .Ping) return error.UnknownIntent;
    if (!versionsEqual(intent_value.version, ping_intent_version)) return error.UnknownIntentVersion;

    for (frames) |frame| {
        if (frameSupportsValidation(frame)) {
            return ValidatedIntent{ .intent = intent_value };
        }
    }

    return error.MissingSemanticFrame;
}

/// Execution is routed through the existing Controller/Driver membrane.
pub fn executeIntent(controller: *ctl.Controller, validated: ValidatedIntent) !void {
    _ = validated; // single exemplar intent
    try controller.issueRawCommand(ping_intent_name);
}
