# ninja

Personal Omarchy (Arch + Hyprland) setup — configs, themes, packages, system services.

## Fresh machine, one command

```sh
curl -fsSL https://raw.githubusercontent.com/thinkpad-ninja/ninja/master/setup | bash
```

Takes a raw Omarchy install to the full setup: all packages (pacman + AUR),
dotfiles, hypr/waybar/ghostty/zed/vscode configs, themes (applies roseofdune),
boot theme, snapper, services. Idempotent; overwritten files are backed up to
`~/.setup-backup-<timestamp>/`. Follow-ups it can't automate are printed at the end.

## Workflow

- `./commit` — mirror the live system into this repo, auto-tag, push
- `./setup` — restore this repo onto a machine (inverse of `commit`)
