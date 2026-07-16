#!/usr/bin/env bash
#
# sync.sh — 扫描子目录，解析类型，重新生成根 README.md 和 index.html
# 用法：
#   ./sync.sh          单次运行
#   ./sync.sh --watch  监听变化自动运行（需要 fswatch 或 inotifywait）

set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# ── 解析子目录，写入临时文件 ────────────────────────────────
# 格式：type\tdir\ttitle\tdesc

for dir in */; do
  dir="${dir%/}"
  [[ "$dir" == .* ]] && continue
  [[ ! -f "$dir/README.md" ]] && continue

  readme="$dir/README.md"
  title=$(grep -m1 '^# ' "$readme" | sed 's/^# //')
  type=$(grep '> 类型：' "$readme" | head -1 | sed 's/^>[[:space:]]*类型：[[:space:]]*//' || echo "未分类")
  desc=$(awk '
    /^#/ { next }
    /^>/ { next }
    /^[[:space:]]*$/ { next }
    { sub(/^[[:space:]]+/, ""); print; exit }
  ' "$readme")

  printf '%s\t%s\t%s\t%s\n' "${type:-未分类}" "$dir" "$title" "$desc" >> "$TMP"
done

# ── 生成 README.md ──────────────────────────────────────────

{
  echo "# One Page"
  echo ""
  echo "单页作品集。每个子目录都是一个独立的单页项目，可直接在浏览器中打开。"
  echo ""
  echo "---"
  echo ""

  prev_type=""
  sort -t$'\t' -k1,1 "$TMP" | while IFS=$'\t' read -r type dir title desc; do
    if [[ "$type" != "$prev_type" ]]; then
      [[ -n "$prev_type" ]] && echo ""
      echo "## $type"
      echo ""
      echo "| 项目 | 简介 |"
      echo "|------|------|"
      prev_type="$type"
    fi
    echo "| [$title]($dir/) | $desc |"
  done
  echo ""
} > README.md

# ── 生成 index.html ─────────────────────────────────────────

{
cat <<'HEADER'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>One Page</title>
<style>
  *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

  :root {
    --bg: #fafaf9;
    --surface: #ffffff;
    --text: #1c1917;
    --text-secondary: #78716c;
    --border: #e7e5e4;
    --accent: #292524;
    --radius: 12px;
    --shadow: 0 1px 3px rgba(0,0,0,.06), 0 1px 2px rgba(0,0,0,.04);
    --shadow-hover: 0 10px 25px rgba(0,0,0,.08), 0 4px 10px rgba(0,0,0,.04);
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #1c1917;
      --surface: #292524;
      --text: #fafaf9;
      --text-secondary: #a8a29e;
      --border: #44403c;
      --accent: #fafaf9;
      --shadow: 0 1px 3px rgba(0,0,0,.3);
      --shadow-hover: 0 10px 25px rgba(0,0,0,.4);
    }
  }

  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans SC", sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
    min-height: 100vh;
  }

  .container {
    max-width: 960px;
    margin: 0 auto;
    padding: 64px 24px 96px;
  }

  header { margin-bottom: 56px; }

  h1 {
    font-size: 2rem;
    font-weight: 700;
    letter-spacing: -0.02em;
    margin-bottom: 8px;
  }

  header p {
    color: var(--text-secondary);
    font-size: 1.05rem;
  }

  .category { margin-bottom: 48px; }

  .category h2 {
    font-size: 0.8rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--text-secondary);
    margin-bottom: 16px;
    padding-left: 2px;
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 12px;
  }

  .card {
    display: flex;
    flex-direction: column;
    padding: 20px 22px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    text-decoration: none;
    color: inherit;
    transition: box-shadow .2s, transform .2s, border-color .2s;
    box-shadow: var(--shadow);
    position: relative;
  }

  .card:hover {
    box-shadow: var(--shadow-hover);
    transform: translateY(-2px);
    border-color: var(--accent);
  }

  .card h3 {
    font-size: 1rem;
    font-weight: 600;
    margin-bottom: 6px;
    line-height: 1.4;
  }

  .card p {
    font-size: 0.88rem;
    color: var(--text-secondary);
    line-height: 1.5;
    flex: 1;
  }

  .card-arrow {
    position: absolute;
    top: 20px;
    right: 20px;
    font-size: 1rem;
    color: var(--text-secondary);
    opacity: 0;
    transition: opacity .2s, transform .2s;
  }

  .card:hover .card-arrow {
    opacity: 1;
    transform: translateX(3px);
  }

  footer {
    text-align: center;
    padding: 32px 0;
    color: var(--text-secondary);
    font-size: 0.82rem;
    border-top: 1px solid var(--border);
  }
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>One Page</h1>
    <p>单页作品集，直接在浏览器中体验。</p>
  </header>
HEADER

# 按类型分组输出卡片
prev_type=""
sort -t$'\t' -k1,1 "$TMP" | while IFS=$'\t' read -r type dir title desc; do
  if [[ "$type" != "$prev_type" ]]; then
    [[ -n "$prev_type" ]] && echo "    </div>" && echo "  </section>"
    cat <<SECTION
  <section class="category">
    <h2>$type</h2>
    <div class="grid">
SECTION
    prev_type="$type"
  fi
  cat <<CARD
      <a class="card" href="$dir/index.html" target="_blank">
        <h3>$title</h3>
        <p>$desc</p>
        <span class="card-arrow">&rarr;</span>
      </a>
CARD
done
echo "    </div>"
echo "  </section>"

cat <<'FOOTER'
  <footer>
    Generated by sync.sh
  </footer>
</div>
</body>
</html>
FOOTER
} > index.html

echo "[sync] README.md 和 index.html 已更新"

# ── watch 模式 ──────────────────────────────────────────────

if [[ "${1:-}" == "--watch" ]]; then
  echo "[sync] 监听模式启动，Ctrl+C 退出"

  if command -v fswatch &>/dev/null; then
    fswatch -0 --exclude '\.git' --exclude '\.DS_Store' --exclude 'index\.html' --exclude 'README\.md' . | while read -d ''; do
      echo "[sync] 检测到变化，重新生成..."
      exec "$0"
    done
  elif command -v inotifywait &>/dev/null; then
    inotifywait -m -r -e modify,create,delete --exclude '\.git|\.DS_Store' . | while read -r; do
      echo "[sync] 检测到变化，重新生成..."
      exec "$0"
    done
  else
    echo "[sync] 未找到 fswatch 或 inotifywait，使用轮询模式"
    LAST_HASH=""
    while true; do
      CURRENT_HASH=$(find . -maxdepth 2 -name 'README.md' -not -path './.git/*' -exec md5 -r {} + 2>/dev/null | sort | md5 -q)
      if [[ "$CURRENT_HASH" != "$LAST_HASH" ]]; then
        [[ -n "$LAST_HASH" ]] && { echo "[sync] 检测到变化，重新生成..."; exec "$0"; }
        LAST_HASH="$CURRENT_HASH"
      fi
      sleep 2
    done
  fi
fi
