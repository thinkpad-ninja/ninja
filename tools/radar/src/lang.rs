//! Language detection + GitHub linguist colors.

/// GitHub linguist colors (subset, matches github.com swatches).
pub fn color_for(lang: &str) -> &'static str {
    match lang {
        "Python" => "#3572A5",
        "C++" => "#f34b7d",
        "C" => "#555555",
        "Rust" => "#dea584",
        "Go" => "#00ADD8",
        "TypeScript" => "#3178c6",
        "JavaScript" => "#f1e05a",
        "Java" => "#b07219",
        "Kotlin" => "#A97BFF",
        "Swift" => "#F05138",
        "C#" => "#178600",
        "Ruby" => "#701516",
        "Shell" => "#89e051",
        "HTML" => "#e34c26",
        "CSS" => "#563d7c",
        "SCSS" => "#c6538c",
        "Vue" => "#41b883",
        "Cuda" => "#3A4E3A",
        "Lua" => "#000080",
        "PHP" => "#4F5D95",
        "Scala" => "#c22d40",
        "Haskell" => "#5e5086",
        "Elixir" => "#6e4a7e",
        "Clojure" => "#db5855",
        "Dart" => "#00B4AB",
        "Objective-C" => "#438eff",
        "Perl" => "#0298c3",
        "R" => "#198CE7",
        "Julia" => "#a270ba",
        "Zig" => "#ec915c",
        "Nim" => "#ffc200",
        "OCaml" => "#3be133",
        "Assembly" => "#6E4C13",
        "Makefile" => "#427819",
        "CMake" => "#DA3434",
        "Dockerfile" => "#384d54",
        "Jupyter Notebook" => "#DA5B0B",
        "TeX" => "#3D6117",
        "Vim Script" => "#199f4b",
        "PowerShell" => "#012456",
        "Solidity" => "#AA6746",
        "Protocol Buffer" => "#555555",
        "Markdown" => "#083fa1",
        "JSON" => "#292929",
        "YAML" => "#cb171e",
        "GLSL" => "#5686a5",
        "Metal" => "#8f14e9",
        "Batchfile" => "#C1F12E",
        _ => "#8b949e",
    }
}

/// Map a file extension (lowercase, with dot) to a linguist language name.
pub fn lang_for_ext(ext: &str) -> Option<&'static str> {
    Some(match ext {
        ".py" | ".pyi" => "Python",
        ".ipynb" => "Jupyter Notebook",
        ".cc" | ".cpp" | ".cxx" | ".hpp" | ".hh" | ".hxx" => "C++",
        ".c" | ".h" => "C",
        ".rs" => "Rust",
        ".go" => "Go",
        ".ts" | ".tsx" => "TypeScript",
        ".js" | ".jsx" | ".mjs" | ".cjs" => "JavaScript",
        ".java" => "Java",
        ".kt" | ".kts" => "Kotlin",
        ".swift" => "Swift",
        ".cs" => "C#",
        ".rb" => "Ruby",
        ".sh" | ".bash" | ".zsh" => "Shell",
        ".html" | ".htm" => "HTML",
        ".css" => "CSS",
        ".scss" | ".sass" => "SCSS",
        ".vue" => "Vue",
        ".cu" | ".cuh" => "Cuda",
        ".lua" => "Lua",
        ".php" => "PHP",
        ".scala" => "Scala",
        ".hs" => "Haskell",
        ".ex" | ".exs" => "Elixir",
        ".clj" => "Clojure",
        ".dart" => "Dart",
        ".m" | ".mm" => "Objective-C",
        ".pl" | ".pm" => "Perl",
        ".r" => "R",
        ".jl" => "Julia",
        ".zig" => "Zig",
        ".nim" => "Nim",
        ".ml" | ".mli" => "OCaml",
        ".asm" | ".s" => "Assembly",
        ".tex" => "TeX",
        ".vim" => "Vim Script",
        ".ps1" => "PowerShell",
        ".sol" => "Solidity",
        ".proto" => "Protocol Buffer",
        ".md" => "Markdown",
        ".yml" | ".yaml" => "YAML",
        ".glsl" | ".vert" | ".frag" => "GLSL",
        ".metal" => "Metal",
        ".bat" | ".cmd" => "Batchfile",
        _ => return None,
    })
}

/// Map a bare filename to a language (for extension-less build files).
pub fn lang_for_filename(name: &str) -> Option<&'static str> {
    Some(match name {
        "Makefile" => "Makefile",
        "CMakeLists.txt" => "CMake",
        "Dockerfile" => "Dockerfile",
        _ => return None,
    })
}

/// Languages that are noise when guessing what a project *is*.
pub fn is_noise(lang: &str) -> bool {
    matches!(
        lang,
        "Markdown" | "YAML" | "JSON" | "Batchfile" | "Makefile" | "CMake"
            | "Dockerfile" | "TeX"
    )
}

pub const SKIP_DIRS: &[&str] = &[
    ".git", "node_modules", "vendor", "third_party", "build", "dist", "target",
    ".venv", "venv", "__pycache__", ".mypy_cache", ".idea", ".cache", "out",
    "bin", "obj", ".next", "deps", "_build",
];
