//! project radar — scan ~/try* dirs and map your coding obsessions.
//!
//! Pure std. Shells out to `git` and (optionally) `gh`. No third-party crates.
//!
//! Usage:
//!   radar                  scan ~/try*  -> colored CLI table + radar.html
//!   radar --root ~/c       scan a different parent dir
//!   radar --glob 'try*'    which subdir names to scan under root
//!   radar --no-stars       skip the GitHub API (fast / offline)
//!   radar --open           open the HTML when done

mod lang;
mod render;
mod scan;
mod util;

use std::collections::{HashMap, HashSet};
use std::path::PathBuf;

use scan::Project;

struct Args {
    root: PathBuf,
    glob: String,
    out: PathBuf,
    no_stars: bool,
    open: bool,
}

fn parse_args() -> Args {
    let home = util::home();
    let mut a = Args {
        root: home.clone(),
        glob: "try*".into(),
        out: std::env::current_dir()
            .unwrap_or_else(|_| util::exe_dir())
            .join("radar.html"),
        no_stars: false,
        open: false,
    };
    let mut it = std::env::args().skip(1);
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--root" => a.root = util::expand(&it.next().unwrap_or_default()),
            "--glob" => a.glob = it.next().unwrap_or_else(|| a.glob.clone()),
            "--out" => a.out = util::expand(&it.next().unwrap_or_default()),
            "--no-stars" => a.no_stars = true,
            "--open" => a.open = true,
            "-h" | "--help" => {
                eprintln!(
                    "radar — map your ~/try* obsessions\n\
                     \n  --root DIR    parent dir (default: ~)\
                     \n  --glob PAT    subdir glob (default: try*)\
                     \n  --out FILE    html output (default: next to binary)\
                     \n  --no-stars    skip GitHub API\
                     \n  --open        open html when done"
                );
                std::process::exit(0);
            }
            other => eprintln!("(ignoring unknown arg: {other})"),
        }
    }
    a
}

fn main() {
    let args = parse_args();

    // Whose repos count as "mine".
    let mut own: HashSet<String> = ["gearonixx", "anarchic"]
        .iter()
        .map(|s| s.to_string())
        .collect();
    if !args.no_stars {
        if let Some(u) = util::sh("gh", &["api", "user", "--jq", ".login"], None) {
            if !u.is_empty() {
                own.insert(u.to_lowercase());
            }
        }
    }

    eprintln!("scanning {}/{} …", args.root.display(), args.glob);
    let mut projects = scan::scan(&args.root, &args.glob, &own);
    if projects.is_empty() {
        eprintln!("no projects found under {}/{}", args.root.display(), args.glob);
        std::process::exit(1);
    }

    if !args.no_stars {
        eprintln!("fetching stars for {} repos …", projects.len());
        fetch_stars(&mut projects);
    }

    projects.sort_by(|a, b| b.last.cmp(&a.last));
    render::print_cli(&projects);

    let path = render::render_html(&projects, &args.out, &args.root);
    eprintln!("  → dashboard: {}", path.display());

    if args.open {
        let _ = std::process::Command::new("xdg-open")
            .arg(&path)
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn();
    }
}

/// Pull stargazer counts from GitHub for every github.com remote, in parallel,
/// with a simple on-disk cache so re-runs are instant.
fn fetch_stars(projects: &mut [Project]) {
    let cache_path = util::home().join(".cache/project-radar-stars.tsv");
    let mut cache = load_cache(&cache_path);

    // Unique github repos we still need.
    let mut needed: Vec<String> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    for p in projects.iter() {
        if p.host.as_deref() == Some("github.com") {
            if let (Some(o), Some(r)) = (&p.owner, &p.repo) {
                let key = format!("{o}/{r}");
                if !cache.contains_key(&key) && seen.insert(key.clone()) {
                    needed.push(key);
                }
            }
        }
    }

    let fetched = util::par_map(needed, 8, |key| {
        let stars = util::sh("gh", &["api", &format!("repos/{key}"), "--jq",
            ".stargazers_count"], None)
            .and_then(|s| s.parse::<i64>().ok())
            .unwrap_or(-1);
        (key.clone(), stars)
    });
    for (k, v) in fetched {
        cache.insert(k, v);
    }
    save_cache(&cache_path, &cache);

    for p in projects.iter_mut() {
        if let (Some(o), Some(r)) = (&p.owner, &p.repo) {
            if let Some(&s) = cache.get(&format!("{o}/{r}")) {
                if s >= 0 {
                    p.stars = Some(s);
                }
            }
        }
    }
}

fn load_cache(path: &std::path::Path) -> HashMap<String, i64> {
    let mut m = HashMap::new();
    if let Ok(text) = std::fs::read_to_string(path) {
        for line in text.lines() {
            if let Some((k, v)) = line.split_once('\t') {
                if let Ok(n) = v.parse::<i64>() {
                    m.insert(k.to_string(), n);
                }
            }
        }
    }
    m
}

fn save_cache(path: &std::path::Path, cache: &HashMap<String, i64>) {
    if let Some(dir) = path.parent() {
        let _ = std::fs::create_dir_all(dir);
    }
    let mut out = String::new();
    for (k, v) in cache {
        out.push_str(k);
        out.push('\t');
        out.push_str(&v.to_string());
        out.push('\n');
    }
    let _ = std::fs::write(path, out);
}
