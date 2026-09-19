#!/usr/bin/env python3
"""Skip meson run_command(pod2man) — Dopamine cannot posix_spawn perl scripts."""
from pathlib import Path
import sys

p = Path(sys.argv[1])
t = p.read_text()
if "MAYFLOWER_SKIP_POD2MAN" in t:
    sys.exit(0)
old = """  run_command('pod2man',
    ['--date=2024-01-01', 'src/spy/pcsc-spy.pod', 'pcsc-spy.1'],
    check : true)
  install_data('pcsc-spy.1',
    install_dir : join_paths(get_option('mandir'), 'man1'))"""
new = """  # MAYFLOWER_SKIP_POD2MAN: Dopamine cannot posix_spawn perl scripts from meson
  message('skipping pod2man for pcsc-spy.1')"""
if old not in t:
    raise SystemExit(f"skip-pod2man: block not found in {p}")
p.write_text(t.replace(old, new, 1))
