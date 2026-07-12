// Never restore previous session / tabs, under any circumstances.
// user.js is re-applied on every Firefox startup, so these prefs can't drift.

// Startup shows home page (1). 0 = blank, 3 = restore previous session (never want 3).
user_pref("browser.startup.page", 1);

// After a crash or hard reboot, do NOT restore the old session.
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.sessionstore.resume_session_once", false);
user_pref("browser.sessionstore.max_resumed_crashes", 0);
