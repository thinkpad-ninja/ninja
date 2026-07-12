//! Colored CLI table + self-contained HTML dashboard.

use std::collections::BTreeMap;
use std::io::IsTerminal;
use std::path::{Path, PathBuf};

use crate::lang::color_for;
use crate::scan::{Kind, Project};
use crate::util::{civil, fmt_ago, fmt_stars, html_escape};

const RESET: &str = "\x1b[0m";
const DIM: &str = "\x1b[2m";
const BOLD: &str = "\x1b[1m";

fn hex_ansi(hex: &str) -> String {
    let h = hex.trim_start_matches('#');
    let r = u8::from_str_radix(&h[0..2], 16).unwrap_or(140);
    let g = u8::from_str_radix(&h[2..4], 16).unwrap_or(148);
    let b = u8::from_str_radix(&h[4..6], 16).unwrap_or(158);
    format!("\x1b[38;2;{r};{g};{b}m")
}

fn pad(s: &str, w: usize) -> String {
    let mut s: String = s.chars().take(w).collect();
    while s.chars().count() < w {
        s.push(' ');
    }
    s
}

fn rpad(s: &str, w: usize) -> String {
    let len = s.chars().count();
    if len >= w {
        s.to_string()
    } else {
        format!("{}{}", " ".repeat(w - len), s)
    }
}

pub fn print_cli(projects: &[Project]) {
    let color = std::io::stdout().is_terminal();
    let c = |text: &str, code: &str| -> String {
        if color {
            format!("{code}{text}{RESET}")
        } else {
            text.to_string()
        }
    };
    let dot = |lang: &str| -> String {
        if color {
            format!("{}●{}", hex_ansi(color_for(lang)), RESET)
        } else {
            "●".into()
        }
    };

    let (mut own, mut clone, mut local) = (0, 0, 0);
    let mut total_stars = 0i64;
    let mut langs: BTreeMap<String, usize> = BTreeMap::new();
    for p in projects {
        match p.kind {
            Kind::Own => own += 1,
            Kind::Clone => clone += 1,
            Kind::Local => local += 1,
        }
        total_stars += p.stars.unwrap_or(0);
        if let Some(l) = &p.lang {
            *langs.entry(l.clone()).or_insert(0) += 1;
        }
    }

    println!();
    println!(
        "  {}{}",
        c("PROJECT RADAR", BOLD),
        c(
            &format!(
                "   {} projects · {own} own · {clone} clones · {local} local · {}★ total",
                projects.len(),
                fmt_stars(Some(total_stars))
            ),
            DIM
        )
    );
    println!("  {}", c(&"─".repeat(72), DIM));

    let kind_glyph = |k: Kind| -> String {
        match k {
            Kind::Own => c("● own  ", "\x1b[32m"),
            Kind::Clone => c("○ clone", "\x1b[33m"),
            Kind::Local => c("· local", DIM),
        }
    };

    for p in projects {
        let lang = p.lang.clone().unwrap_or_else(|| "—".into());
        println!(
            "  {} {} {} {}  {} {}  {}★",
            dot(&lang),
            c(&pad(&p.name, 24), BOLD),
            c(&pad(&p.group, 5), DIM),
            kind_glyph(p.kind),
            pad(&lang, 16),
            c(&rpad(&fmt_ago(p.last), 5), DIM),
            rpad(&fmt_stars(p.stars), 6),
        );
    }
    println!("  {}", c(&"─".repeat(72), DIM));

    let mut top: Vec<(&String, &usize)> = langs.iter().collect();
    top.sort_by(|a, b| b.1.cmp(a.1));
    let bar: Vec<String> = top
        .iter()
        .take(6)
        .map(|(l, n)| format!("{} {} {}", dot(l), l, c(&n.to_string(), DIM)))
        .collect();
    println!("  {}{}", c("langs: ", DIM), bar.join("   "));
    println!();
}

// ── HTML ─────────────────────────────────────────────────────────────────────

pub fn render_html(projects: &[Project], out: &Path, root: &Path) -> PathBuf {
    let mut own = 0;
    let mut clone = 0;
    let mut total_stars = 0i64;
    let mut lang_count: BTreeMap<String, usize> = BTreeMap::new();
    let mut months: BTreeMap<String, BTreeMap<String, usize>> = BTreeMap::new();
    let mut groups: std::collections::BTreeSet<String> = Default::default();

    for p in projects {
        match p.kind {
            Kind::Own => own += 1,
            Kind::Clone => clone += 1,
            Kind::Local => {}
        }
        total_stars += p.stars.unwrap_or(0);
        groups.insert(p.group.clone());
        let l = p.lang.clone().unwrap_or_else(|| "—".into());
        if p.lang.is_some() {
            *lang_count.entry(l.clone()).or_insert(0) += 1;
        }
        let (y, m, _) = civil(p.last);
        let key = format!("{y:04}-{m:02}");
        *months.entry(key).or_default().entry(l).or_insert(0) += 1;
    }

    let mut lang_sorted: Vec<(&String, &usize)> = lang_count.iter().collect();
    lang_sorted.sort_by(|a, b| b.1.cmp(a.1).then(a.0.cmp(b.0)));
    let total_lang: usize = lang_count.values().sum::<usize>().max(1);

    // legend + proportional language bar
    let mut legend = String::new();
    let mut langbar = String::new();
    for (l, n) in &lang_sorted {
        legend.push_str(&format!(
            "<span class=\"chip\"><i style=\"background:{}\"></i>{} <b>{}</b></span>",
            color_for(l),
            html_escape(l),
            n
        ));
        langbar.push_str(&format!(
            "<div style=\"width:{:.2}%;background:{}\" title=\"{}: {}\"></div>",
            **n as f64 / total_lang as f64 * 100.0,
            color_for(l),
            html_escape(l),
            n
        ));
    }

    // timeline: stacked bars per month
    let max_month = months
        .values()
        .map(|d| d.values().sum::<usize>())
        .max()
        .unwrap_or(1)
        .max(1);
    let mut tl = String::new();
    for (month, d) in &months {
        let total: usize = d.values().sum();
        let mut segs: Vec<(&String, &usize)> = d.iter().collect();
        segs.sort_by(|a, b| b.1.cmp(a.1));
        let mut seg_html = String::new();
        for (l, v) in segs {
            seg_html.push_str(&format!(
                "<div class=\"seg\" style=\"height:{:.1}px;background:{}\" title=\"{}: {}\"></div>",
                *v as f64 / max_month as f64 * 140.0,
                color_for(l),
                html_escape(l),
                v
            ));
        }
        let label = &month[2..]; // yy-mm
        tl.push_str(&format!(
            "<div class=\"tcol\"><div class=\"tbars\">{seg_html}</div>\
             <div class=\"tnum\">{total}</div><div class=\"tlabel\">{label}</div></div>"
        ));
    }

    // heaviest hitters by stars
    let mut starred: Vec<&Project> =
        projects.iter().filter(|p| p.stars.unwrap_or(0) > 0).collect();
    starred.sort_by(|a, b| b.stars.cmp(&a.stars));
    starred.truncate(12);
    let maxstar = starred.first().and_then(|p| p.stars).unwrap_or(1).max(1);
    let mut stars_html = String::new();
    for p in &starred {
        let lang = p.lang.clone().unwrap_or_else(|| "—".into());
        let w = p.stars.unwrap_or(0) as f64 / maxstar as f64 * 100.0;
        let url = match (&p.host, &p.owner, &p.repo) {
            (Some(h), Some(o), Some(r)) if h == "github.com" => {
                format!("https://github.com/{o}/{r}")
            }
            _ => "#".into(),
        };
        stars_html.push_str(&format!(
            "<a class=\"srow\" href=\"{url}\" target=\"_blank\">\
             <span class=\"sname\"><i style=\"background:{col}\"></i>{name}</span>\
             <span class=\"sbar\"><span style=\"width:{w:.1}%;background:{col}\"></span></span>\
             <span class=\"snum\">{stars}★</span></a>",
            col = color_for(&lang),
            name = html_escape(&p.name),
            stars = fmt_stars(p.stars),
        ));
    }
    if stars_html.is_empty() {
        stars_html = "<div class=\"muted\">no starred repos found</div>".into();
    }

    // table rows
    let mut rows = String::new();
    for p in projects {
        let lang = p.lang.clone().unwrap_or_else(|| "—".into());
        let kind_cls = match p.kind {
            Kind::Own => "k-own",
            Kind::Clone => "k-clone",
            Kind::Local => "k-local",
        };
        let repo_link = match (&p.host, &p.owner, &p.repo) {
            (Some(h), Some(o), Some(r)) if h == "github.com" => format!(
                "<a href=\"https://github.com/{o}/{r}\" target=\"_blank\">{}/{}</a>",
                html_escape(o),
                html_escape(r)
            ),
            (_, Some(o), Some(r)) => html_escape(&format!("{o}/{r}")),
            _ => "<span class=\"muted\">— local —</span>".into(),
        };
        let bd: Vec<String> = p
            .breakdown
            .iter()
            .take(4)
            .map(|(k, v)| format!("{k} {v}"))
            .collect();
        rows.push_str(&format!(
            "<tr data-kind=\"{kind}\" data-lang=\"{langesc}\">\
             <td><i class=\"ld\" style=\"background:{col}\"></i><b>{name}</b></td>\
             <td class=\"muted\">{group}</td>\
             <td><span class=\"kbadge {kind_cls}\">{kind}</span></td>\
             <td><span class=\"lang\" style=\"color:{col}\">{langesc}</span>\
             <div class=\"bd\">{bd}</div></td>\
             <td class=\"muted\" data-sort=\"{last}\">{ago}</td>\
             <td class=\"num\" data-sort=\"{starnum}\">{stars}★</td>\
             <td class=\"repo\">{repo_link}</td></tr>",
            kind = p.kind.as_str(),
            langesc = html_escape(&lang),
            col = color_for(&lang),
            name = html_escape(&p.name),
            group = html_escape(&p.group),
            bd = html_escape(&bd.join(" · ")),
            last = p.last,
            ago = fmt_ago(p.last),
            starnum = p.stars.unwrap_or(-1),
            stars = fmt_stars(p.stars),
        ));
    }

    let (y, m, d) = civil(crate::util::now_unix());
    let generated = format!("{y:04}-{m:02}-{d:02}");
    let scanned = format!(
        "{}/{{{}}}",
        root.display(),
        groups.iter().cloned().collect::<Vec<_>>().join(",")
    );

    let mut doc = String::new();
    doc.push_str(HEAD);
    doc.push_str(&format!(
        "<h1>project <span class=\"r\">radar</span></h1>\n\
         <div class=\"sub\">a map of what nerd-sniped you · scanned <code>{}</code> · {}</div>\n\
         <div class=\"stats\">\
         <div class=\"stat\"><div class=\"v\">{}</div><div class=\"l\">projects</div></div>\
         <div class=\"stat\"><div class=\"v\" style=\"color:#3fb950\">{}</div><div class=\"l\">your own</div></div>\
         <div class=\"stat\"><div class=\"v\" style=\"color:#d29922\">{}</div><div class=\"l\">clones</div></div>\
         <div class=\"stat\"><div class=\"v\">{}</div><div class=\"l\">languages</div></div>\
         <div class=\"stat\"><div class=\"v\">{}★</div><div class=\"l\">stars combined</div></div>\
         </div>\n",
        html_escape(&scanned),
        generated,
        projects.len(),
        own,
        clone,
        lang_count.len(),
        fmt_stars(Some(total_stars)),
    ));
    doc.push_str(&format!(
        "<div class=\"card\"><h2>obsessions over time — projects by month last touched</h2>\
         <div class=\"tl\">{tl}</div></div>\n"
    ));
    doc.push_str(&format!(
        "<div class=\"card\"><h2>language mix</h2>\
         <div class=\"langbar\">{langbar}</div><div>{legend}</div></div>\n"
    ));
    doc.push_str(&format!(
        "<div class=\"card\"><h2>heaviest hitters — top by stars</h2>{stars_html}</div>\n"
    ));
    doc.push_str(&format!(
        "<div class=\"card\"><h2>all projects</h2>\
         <div class=\"controls\" id=\"filters\">\
         <button data-f=\"all\" class=\"on\">all</button>\
         <button data-f=\"own\">own</button>\
         <button data-f=\"clone\">clones</button>\
         <button data-f=\"local\">local</button></div>\
         <table id=\"tbl\"><thead><tr>\
         <th data-c=\"0\">project</th><th data-c=\"1\">group</th><th data-c=\"2\">kind</th>\
         <th data-c=\"3\">language</th><th data-c=\"4\">touched</th>\
         <th data-c=\"5\" class=\"num\">stars</th><th data-c=\"6\">remote</th>\
         </tr></thead><tbody>{rows}</tbody></table></div>\n"
    ));
    doc.push_str(TAIL);

    std::fs::write(out, doc).expect("write html");
    out.to_path_buf()
}

const HEAD: &str = r#"<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>project radar</title>
<style>
:root{--bg:#0d1117;--panel:#161b22;--line:#21262d;--fg:#e6edf3;--muted:#8b949e;--accent:#58a6ff}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
 font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:1100px;margin:0 auto;padding:32px 20px 80px}
h1{font-size:26px;margin:0 0 2px;letter-spacing:-.5px}
h1 .r{color:var(--accent)}
.sub{color:var(--muted);margin-bottom:24px;font-size:13px}
.sub code{color:var(--fg)}
.stats{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin-bottom:28px}
.stat{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
.stat .v{font-size:24px;font-weight:700}
.stat .l{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.5px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:20px;margin-bottom:22px}
.card h2{font-size:13px;text-transform:uppercase;letter-spacing:1px;color:var(--muted);margin:0 0 16px;font-weight:600}
.langbar{display:flex;height:12px;border-radius:6px;overflow:hidden;margin-bottom:14px}
.langbar div{min-width:2px}
.chip{display:inline-flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);margin:0 14px 6px 0}
.chip i{width:10px;height:10px;border-radius:50%;display:inline-block}
.chip b{color:var(--fg);font-weight:600}
.tl{display:flex;align-items:flex-end;gap:6px;overflow-x:auto;padding-bottom:4px}
.tcol{display:flex;flex-direction:column;align-items:center;min-width:30px}
.tbars{display:flex;flex-direction:column-reverse;justify-content:flex-start;height:140px;width:20px;border-radius:4px;overflow:hidden}
.seg{width:100%}
.tnum{font-size:11px;color:var(--fg);margin-top:6px}
.tlabel{font-size:10px;color:var(--muted);margin-top:2px;white-space:nowrap;transform:rotate(-45deg);transform-origin:center;height:26px}
.srow{display:flex;align-items:center;gap:12px;text-decoration:none;color:var(--fg);padding:5px 0}
.srow:hover .sname{color:var(--accent)}
.sname{width:200px;display:flex;align-items:center;gap:8px;font-size:13px}
.sname i,.ld{width:10px;height:10px;border-radius:50%;display:inline-block;flex:none}
.sbar{flex:1;height:8px;background:var(--line);border-radius:4px;overflow:hidden}
.sbar span{display:block;height:100%}
.snum{width:60px;text-align:right;color:var(--muted);font-size:12px;font-variant-numeric:tabular-nums}
.controls{display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap}
.controls button{background:var(--panel);border:1px solid var(--line);color:var(--muted);padding:5px 12px;border-radius:20px;cursor:pointer;font-size:12px}
.controls button.on{color:var(--fg);border-color:var(--accent)}
table{width:100%;border-collapse:collapse}
th{text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:.5px;color:var(--muted);padding:8px 10px;border-bottom:1px solid var(--line);cursor:pointer;user-select:none}
td{padding:9px 10px;border-bottom:1px solid var(--line);vertical-align:top}
tr:hover td{background:#1c2330}
.ld{margin-right:8px;vertical-align:middle}
.lang{font-weight:600;font-size:13px}
.bd{color:var(--muted);font-size:11px;margin-top:2px}
.num{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
.muted{color:var(--muted)}
.repo a{color:var(--accent);text-decoration:none}.repo a:hover{text-decoration:underline}
.kbadge{font-size:11px;padding:2px 8px;border-radius:20px;font-weight:600}
.k-own{background:rgba(46,160,67,.15);color:#3fb950}
.k-clone{background:rgba(187,128,9,.15);color:#d29922}
.k-local{background:rgba(139,148,158,.12);color:#8b949e}
.foot{color:var(--muted);font-size:12px;margin-top:30px;text-align:center}
</style></head><body><div class="wrap">
"#;

const TAIL: &str = r#"<div class="foot">project radar · regenerate with <code>radar</code></div>
</div>
<script>
const tb=document.querySelector('#tbl tbody');
document.querySelectorAll('#filters button').forEach(b=>b.onclick=()=>{
  document.querySelectorAll('#filters button').forEach(x=>x.classList.remove('on'));
  b.classList.add('on');const f=b.dataset.f;
  [...tb.rows].forEach(r=>r.style.display=(f==='all'||r.dataset.kind===f)?'':'none');
});
document.querySelectorAll('#tbl th').forEach(th=>th.onclick=()=>{
  const c=+th.dataset.c, rows=[...tb.rows];
  const asc=th.dataset.asc==='1';th.dataset.asc=asc?'0':'1';
  rows.sort((a,b)=>{
    let x=a.cells[c],y=b.cells[c];
    let xv=x.dataset.sort??x.innerText, yv=y.dataset.sort??y.innerText;
    let nx=parseFloat(xv),ny=parseFloat(yv);
    if(!isNaN(nx)&&!isNaN(ny))return asc?nx-ny:ny-nx;
    return asc?(''+xv).localeCompare(yv):(''+yv).localeCompare(xv);
  });
  rows.forEach(r=>tb.appendChild(r));
});
</script>
</body></html>"#;
