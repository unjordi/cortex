#!/usr/bin/env bash
S="$1"; LIB="$2"
rm -rf "$S/h1"; mkdir -p "$S/h1/home"; export HOME="$S/h1/home"
cd "$S/h1" && git init -q -b develop r && cd r && git -c user.email=a@b -c user.name=x commit -q --allow-empty -m i && git worktree add -q ../wt -b chore/x
cd "$S/h1/r"
. "$LIB"
P='push'
for c in "for r in a:b; do cd $S/h1/wt && git add -A && git $P; done" "cd $S/h1/wt && git $P" "cd $S/h1/r && git $P" "git $P"; do
  acg_push_toca_base "$c" "$S/h1/r"; echo "rc=$? :: $c"
done
