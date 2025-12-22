/// Interpretive semantic classification of events.
pub const EventKind = enum {
    SessionLifecycle,
    UserAction,
    EngineActivity,
    Snapshot,
    Unknown, // currently unused; reserved for future expansion
};
