dewire_hook() {
  local gset="$1" base="$2" tmp
  command -v jq >/dev/null 2>&1 || { echo "  warn: jq no está; quita a mano '$base' de $gset"; return; }
  [ -f "$gset" ] || return
  tmp="$(mktemp)" || return
  if jq --arg pat "$base\\.sh" '
      if (.hooks|type)=="object" then
        .hooks |= ( to_entries
          | map(.value |= [ .[] | select((([.hooks[]?.command]|join(" "))|test($pat))|not) ])
          | map(select((.value|type)=="array" and (.value|length)>0)) | from_entries )
        | (if (.hooks|length)==0 then del(.hooks) else . end)
      else . end
    ' "$gset" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then mv "$tmp" "$gset"; else rm -f "$tmp"; echo "  warn: no pude de-cablear ($base)"; fi
}
