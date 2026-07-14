# --- battery (upower) ---
# Backup of upower-related snippets from ~/.bashrc
# Full battery report: charge, state, health, time to empty/full, voltage, cycles
alias battery='upower -i $(upower -e | grep BAT)'
# Quick summary: just the lines that matter
batt() { upower -i "$(upower -e | grep BAT)" | grep -E 'state|percentage|capacity:|time to|energy-rate|charge-cycles'; }
