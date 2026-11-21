#!/bin/bash
# Build AlterEgo.dll from Windows via WSL using llvm-mingw (UCRT).
# UCRT is REQUIRED: Hoard & Seek uses it, and mixing with msvcrt corrupts the heap
# (game crash 0xc0000374). See README_LOCAL.md.
# Run from PowerShell:  wsl -d Ubuntu-22.04 -- bash /mnt/c/w/alter_ego/tools/wsl_build.sh
export PATH="$HOME/llvm-mingw/bin:/usr/bin:/bin:/usr/local/bin"
set -e
rm -rf ~/ae_build2 && mkdir ~/ae_build2 && cd ~/ae_build2
cmake /mnt/c/w/alter_ego >/dev/null
make -j"$(nproc)" 2>&1 | grep -E 'error|Built target' | head -20
mkdir -p /mnt/c/w/alter_ego/build
cp AlterEgo.dll /mnt/c/w/alter_ego/build/AlterEgo.dll
ls -l /mnt/c/w/alter_ego/build/AlterEgo.dll
