//! Small dependency-free helpers: shell-out, paths, parallel map, time/civil.

use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

pub fn home() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}

pub fn exe_dir() -> PathBuf {
    std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("."))
}

/// Expand a leading `~` to $HOME.
pub fn expand(s: &str) -> PathBuf {
    if let Some(rest) = s.strip_prefix("~/") {
        home().join(rest)
    } else if s == "~" {
        home()
    } else {
        PathBuf::from(s)
    }
}

/// Run a command, return trimmed stdout on success, else None.
pub fn sh(cmd: &str, args: &[&str], cwd: Option<&Path>) -> Option<String> {
    let mut c = Command::new(cmd);
    c.args(args);
    if let Some(d) = cwd {
        c.current_dir(d);
    }
    let out = c.output().ok()?;
    if out.status.success() {
        Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
    } else {
        None
    }
}

pub fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// Order-preserving parallel map over a Vec using scoped threads.
///
/// Static chunking: each worker owns a contiguous, disjoint `&mut` slice of the
/// output, so there's no shared mutable state and no `unsafe`.
pub fn par_map<T, R, F>(items: Vec<T>, workers: usize, f: F) -> Vec<R>
where
    T: Send + Sync,
    R: Send,
    F: Fn(&T) -> R + Sync,
{
    let n = items.len();
    if n == 0 {
        return Vec::new();
    }
    let workers = workers.max(1).min(n);
    let chunk = n.div_ceil(workers);
    let mut out: Vec<Option<R>> = (0..n).map(|_| None).collect();

    {
        let items = &items;
        let f = &f;
        std::thread::scope(|s| {
            for (ci, slice) in out.chunks_mut(chunk).enumerate() {
                let base = ci * chunk;
                s.spawn(move || {
                    for (j, slot) in slice.iter_mut().enumerate() {
                        *slot = Some(f(&items[base + j]));
                    }
                });
            }
        });
    }

    out.into_iter().map(|o| o.unwrap()).collect()
}

/// (year, month, day) from a unix timestamp (UTC). Hinnant's civil algorithm.
pub fn civil(ts: i64) -> (i64, u32, u32) {
    let days = ts.div_euclid(86400);
    let z = days + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = z - era * 146097; // [0, 146096]
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365; // [0, 399]
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100); // [0, 365]
    let mp = (5 * doy + 2) / 153; // [0, 11]
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if m <= 2 { y + 1 } else { y }, m, d)
}

/// "today" / "12d" / "5mo" / "2y" relative to now.
pub fn fmt_ago(ts: i64) -> String {
    let days = (now_unix() - ts).max(0) / 86400;
    if days <= 0 {
        "today".into()
    } else if days < 30 {
        format!("{days}d")
    } else if days < 365 {
        format!("{}mo", days / 30)
    } else {
        format!("{}y", days / 365)
    }
}

/// "1.2k" / "812" / "·" for star counts.
pub fn fmt_stars(s: Option<i64>) -> String {
    match s {
        None => "·".into(),
        Some(n) if n >= 1000 => {
            let v = format!("{:.1}k", n as f64 / 1000.0);
            v.replace(".0k", "k")
        }
        Some(n) => n.to_string(),
    }
}

pub fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}
