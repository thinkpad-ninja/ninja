//! Discover projects under <root>/<glob>/* and classify each one.

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

use crate::lang;
use crate::util;

#[derive(Clone)]
pub struct Project {
    pub group: String,            // parent dir name, e.g. "try3"
    pub name: String,             // project dir name
    #[allow(dead_code)] // kept for callers/future use (e.g. local links)
    pub path: PathBuf,
    pub host: Option<String>,     // e.g. github.com
    pub owner: Option<String>,
    pub repo: Option<String>,
    pub kind: Kind,               // own / clone / local
    pub lang: Option<String>,     // primary language
    pub breakdown: Vec<(String, usize)>, // top langs by file count
    pub last: i64,                // unix ts of last activity
    pub stars: Option<i64>,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Own,
    Clone,
    Local,
}

impl Kind {
    pub fn as_str(self) -> &'static str {
        match self {
            Kind::Own => "own",
            Kind::Clone => "clone",
            Kind::Local => "local",
        }
    }
}

/// Parse a git remote URL into (host, owner, repo).
pub fn parse_remote(url: &str) -> Option<(String, String, String)> {
    let u = url.trim();
    if u.is_empty() {
        return None;
    }
    let (host, path) = if u.contains("://") {
        let rest = u.splitn(2, "://").nth(1)?;
        let mut parts = rest.splitn(2, '/');
        let mut host = parts.next()?.to_string();
        if let Some(at) = host.rfind('@') {
            host = host[at + 1..].to_string(); // strip user@
        }
        (host, parts.next().unwrap_or("").to_string())
    } else if let Some(colon) = u.find(':') {
        // scp-like: git@github.com:owner/repo.git
        let head = &u[..colon];
        let host = head.rsplit('@').next()?.to_string();
        (host, u[colon + 1..].to_string())
    } else {
        return None;
    };
    let path = path.trim_end_matches('/').trim_start_matches('/');
    let path = path.strip_suffix(".git").unwrap_or(path);
    let segs: Vec<&str> = path.split('/').filter(|s| !s.is_empty()).collect();
    if segs.len() < 2 {
        return None;
    }
    let n = segs.len();
    Some((host, segs[n - 2].to_string(), segs[n - 1].to_string()))
}

pub fn scan(root: &Path, glob: &str, own: &HashSet<String>) -> Vec<Project> {
    let mut subdirs: Vec<(String, PathBuf)> = Vec::new();
    if let Ok(entries) = std::fs::read_dir(root) {
        let mut parents: Vec<PathBuf> = entries
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.is_dir() && glob_match(glob, name_of(p)))
            .collect();
        parents.sort();
        for parent in parents {
            let gname = name_of(&parent).to_string();
            if let Ok(children) = std::fs::read_dir(&parent) {
                let mut cs: Vec<PathBuf> = children
                    .flatten()
                    .map(|e| e.path())
                    .filter(|p| p.is_dir() && !name_of(p).starts_with('.'))
                    .collect();
                cs.sort();
                for c in cs {
                    subdirs.push((gname.clone(), c));
                }
            }
        }
    }

    util::par_map(subdirs, 12, |(group, path)| build(group, path, own))
}

fn build(group: &String, path: &PathBuf, own: &HashSet<String>) -> Project {
    let remote = util::sh("git", &["-C", &path.to_string_lossy(), "remote",
        "get-url", "origin"], None);
    let parsed = remote.as_deref().and_then(parse_remote);
    let (host, owner, repo) = match &parsed {
        Some((h, o, r)) => (Some(h.clone()), Some(o.clone()), Some(r.clone())),
        None => (None, None, None),
    };
    let kind = match &owner {
        Some(o) if own.contains(&o.to_lowercase()) => Kind::Own,
        Some(_) => Kind::Clone,
        None => Kind::Local,
    };
    let (lang, breakdown) = language_of(path);
    let last = last_activity(path);
    Project {
        group: group.clone(),
        name: name_of(path).to_string(),
        path: path.clone(),
        host,
        owner,
        repo,
        kind,
        lang,
        breakdown,
        last,
        stars: None,
    }
}

/// Tally files by language; prefer a real language over docs/config noise.
fn language_of(path: &Path) -> (Option<String>, Vec<(String, usize)>) {
    let mut names: Vec<String> = Vec::new();
    if let Some(tracked) =
        util::sh("git", &["-C", &path.to_string_lossy(), "ls-files"], None)
    {
        if !tracked.is_empty() {
            names = tracked.lines().map(|s| s.to_string()).collect();
        }
    }
    if names.is_empty() {
        walk(path, &mut names, &mut 0);
    }

    let mut counts: HashMap<String, usize> = HashMap::new();
    for name in &names {
        let base = name.rsplit('/').next().unwrap_or(name);
        if let Some(l) = lang::lang_for_filename(base) {
            *counts.entry(l.to_string()).or_insert(0) += 1;
            continue;
        }
        if let Some(dot) = base.rfind('.') {
            let ext = base[dot..].to_lowercase();
            if let Some(l) = lang::lang_for_ext(&ext) {
                *counts.entry(l.to_string()).or_insert(0) += 1;
            }
        }
    }
    if counts.is_empty() {
        return (None, Vec::new());
    }

    let mut sorted: Vec<(String, usize)> =
        counts.iter().map(|(k, v)| (k.clone(), *v)).collect();
    sorted.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));

    let primary = sorted
        .iter()
        .find(|(l, _)| !lang::is_noise(l))
        .or_else(|| sorted.first())
        .map(|(l, _)| l.clone());

    sorted.truncate(8);
    (primary, sorted)
}

/// Recursive directory walk with a file cap and skip-list (non-git fallback).
fn walk(dir: &Path, out: &mut Vec<String>, count: &mut usize) {
    if *count > 60_000 {
        return;
    }
    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };
    for entry in entries.flatten() {
        let p = entry.path();
        let name = name_of(&p);
        if p.is_dir() {
            if lang::SKIP_DIRS.contains(&name) || name.starts_with('.') {
                continue;
            }
            walk(&p, out, count);
        } else {
            out.push(name.to_string());
            *count += 1;
            if *count > 60_000 {
                return;
            }
        }
    }
}

/// Last git commit time, else newest mtime among shallow contents.
fn last_activity(path: &Path) -> i64 {
    if let Some(ts) = util::sh("git", &["-C", &path.to_string_lossy(), "log",
        "-1", "--format=%ct"], None)
    {
        if let Ok(n) = ts.parse::<i64>() {
            return n;
        }
    }
    let mut newest = mtime(path);
    if let Ok(entries) = std::fs::read_dir(path) {
        for e in entries.flatten() {
            newest = newest.max(mtime(&e.path()));
        }
    }
    newest
}

fn mtime(p: &Path) -> i64 {
    p.metadata()
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn name_of(p: &Path) -> &str {
    p.file_name().and_then(|s| s.to_str()).unwrap_or("")
}

/// Minimal glob: supports a single trailing `*` (e.g. "try*") and exact match.
fn glob_match(pattern: &str, name: &str) -> bool {
    if let Some(prefix) = pattern.strip_suffix('*') {
        name.starts_with(prefix)
    } else {
        pattern == name
    }
}
