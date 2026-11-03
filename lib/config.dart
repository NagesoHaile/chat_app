/// All tunable numbers live here.
const int kTotalMessages = 100000;

/// How many messages are unread when the chat opens.
const int kUnreadCount = 100;

/// Message IDs are 1-based. This is the first unread one.
const int kFirstUnreadId = kTotalMessages - kUnreadCount + 1;

/// How many messages the "add" button brings in.
const int kNewBatchSize = 50;

/// Height shown for an image until it "finishes loading".
const double kImagePlaceholderHeight = 160;

/// When re-anchoring near the end, keep at least this many messages
/// below the anchor so the list always fills the screen.
const int kMinForwardMessages = 40;

/// Max generated messages kept in memory (LRU).
const int kCacheSize = 300;
