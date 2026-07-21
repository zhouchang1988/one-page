#!/usr/bin/env bash
#
# sync.sh — 扫描子目录，解析类型，重新生成根 AGENTS.md 和 index.html
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
  [[ ! -f "$dir/AGENTS.md" ]] && continue

  readme="$dir/AGENTS.md"
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

# ── 生成根目录 AGENTS.md ─────────────────────────────────────

# 生成项目列表部分
{
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
} > "$TMP.list"

# 如果 AGENTS.md 不存在，创建基本结构
if [[ ! -f "AGENTS.md" ]]; then
  {
    echo "# One Page"
    echo ""
    echo "单页作品集。每个子目录都是一个独立的单页项目，可直接在浏览器中打开。"
    echo ""
    echo "---"
    echo ""
  } > "AGENTS.md"
fi

# 找到 "---" 行号和第一个 "## " 行号，替换中间内容
sep_line=$(grep -n '^---$' "AGENTS.md" | head -1 | cut -d: -f1)
if [[ -n "$sep_line" ]]; then
  # 找到 "---" 之后保留内容（"## 项目结构"）的行号，避免把生成的列表误判为保留内容
  content_start=$(awk -v start="$sep_line" 'NR > start && /^## 项目结构/ { print NR; exit }' "AGENTS.md")
  
  if [[ -n "$content_start" ]]; then
    # 保留 "---" 及之前的内容 + 新列表 + 从 "## " 开始的后续内容
    {
      head -n "$sep_line" "AGENTS.md"
      echo ""
      cat "$TMP.list"
      tail -n "+$content_start" "AGENTS.md"
    } > "$TMP.agents"
  else
    # 没有找到 "## "，直接追加
    {
      cat "AGENTS.md"
      cat "$TMP.list"
    } > "$TMP.agents"
  fi
  
  mv "$TMP.agents" "AGENTS.md"
fi

# ── 生成 index.html ─────────────────────────────────────────

TOTAL=$(wc -l < "$TMP" | tr -d ' ')
CATS=$(cut -f1 "$TMP" | sort -u | wc -l | tr -d ' ')

{
cat <<'HEADER'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>One Page · 单页作品集</title>
<style>
  *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

  :root {
    /* 浅色 · 宣纸 */
    --bg: #f2ecdf;
    --surface: #faf6ec;
    --text: #33302a;
    --text-secondary: #7d7466;
    --border: #ddd3bd;
    --border-strong: #c2b48f;
    --accent: #9e2b25;             /* 朱砂 */
    --gold: #a8842f;               /* 藤黄 */
    --radius: 4px;
    --shadow: 0 1px 2px rgba(51,48,42,.06);
    --shadow-hover: 0 16px 32px -14px rgba(96,72,40,.35);
    --pattern: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='44' height='44'%3E%3Cpath d='M44 0H0v44' fill='none' stroke='%236b5a3e' stroke-opacity='.055'/%3E%3C/svg%3E");
  }

  @media (prefers-color-scheme: dark) {
    :root {
      /* 深色 · 夜墨 */
      --bg: #16181c;
      --surface: #1f2227;
      --text: #e8e1d2;
      --text-secondary: #9c9482;
      --border: #33373d;
      --border-strong: #4a4f56;
      --accent: #c4554a;
      --gold: #c9a24f;
      --shadow: 0 1px 2px rgba(0,0,0,.35);
      --shadow-hover: 0 16px 32px -14px rgba(0,0,0,.6);
      --pattern: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='44' height='44'%3E%3Cpath d='M44 0H0v44' fill='none' stroke='%23c9b48a' stroke-opacity='.05'/%3E%3C/svg%3E");
    }
  }

  html { scroll-behavior: smooth; }

  body {
    font-family: "Songti SC", "STSong", "Noto Serif SC", "Source Han Serif SC", "SimSun", serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.7;
    min-height: 100vh;
  }

  ::selection { background: var(--accent); color: #faf6ec; }

  /* 顶部五色丝带 */
  body::after {
    content: "";
    position: fixed;
    top: 0; left: 0; right: 0;
    height: 3px;
    z-index: 20;
    background: linear-gradient(90deg,
      #9e2b25 0%, #9e2b25 30%,
      #a8842f 30%, #a8842f 52%,
      #486581 52%, #486581 76%,
      #4e7c5a 76%, #4e7c5a 100%);
    opacity: .85;
  }

  /* 窗棂底纹 + 顶部水墨晕染 */
  body::before {
    content: "";
    position: fixed;
    inset: 0;
    z-index: -1;
    pointer-events: none;
    background:
      radial-gradient(620px 320px at 12% -80px, color-mix(in srgb, var(--accent) 9%, transparent), transparent 68%),
      radial-gradient(540px 300px at 88% -60px, color-mix(in srgb, var(--gold) 9%, transparent), transparent 68%),
      var(--pattern);
  }

  .container {
    max-width: 1060px;
    margin: 0 auto;
    padding: 88px 24px 96px;
  }

  /* ── Hero ── */
  .hero {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 32px;
    margin-bottom: 44px;
  }

  .overline {
    font-size: 0.82rem;
    font-weight: 600;
    letter-spacing: 0.32em;
    color: var(--text-secondary);
    margin-bottom: 20px;
  }

  .overline::before { content: "「 "; color: var(--accent); }
  .overline::after  { content: " 」"; color: var(--accent); }

  .hero h1 {
    font-size: clamp(2.1rem, 5vw, 3.1rem);
    font-weight: 700;
    letter-spacing: 0.05em;
    line-height: 1.35;
    margin-bottom: 18px;
  }

  .hero h1 em {
    font-style: normal;
    color: var(--accent);
    text-decoration: underline;
    text-decoration-color: color-mix(in srgb, var(--gold) 65%, transparent);
    text-decoration-thickness: 3px;
    text-underline-offset: 7px;
  }

  .subtitle {
    color: var(--text-secondary);
    font-size: 1.02rem;
    max-width: 34em;
    margin-bottom: 24px;
  }

  .stats {
    display: flex;
    align-items: center;
    gap: 14px;
    color: var(--text-secondary);
    font-size: 0.9rem;
    letter-spacing: 0.06em;
  }

  .stats strong {
    color: var(--accent);
    font-weight: 700;
    margin-right: 2px;
  }

  .stats-sep {
    width: 4px;
    height: 4px;
    border-radius: 50%;
    background: var(--border-strong);
  }

  /* 朱砂印章 */
  .seal {
    flex: none;
    width: 88px;
    height: 88px;
    margin-top: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--accent);
    color: #faf6ec;
    border-radius: 7px;
    transform: rotate(-3deg);
    box-shadow:
      0 6px 18px color-mix(in srgb, var(--accent) 38%, transparent),
      inset 0 0 0 2px rgba(250,246,236,.35),
      inset 0 0 0 5px color-mix(in srgb, var(--accent) 82%, transparent);
  }

  .seal span {
    writing-mode: vertical-rl;
    font-size: 1.75rem;
    font-weight: 700;
    letter-spacing: 0.28em;
    text-indent: 0.28em;
  }

  @media (max-width: 640px) {
    .seal { display: none; }
  }

  /* ── 分类导航 ── */
  .nav {
    position: sticky;
    top: 0;
    z-index: 10;
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    padding: 16px 0;
    margin-bottom: 42px;
    background: color-mix(in srgb, var(--bg) 84%, transparent);
    -webkit-backdrop-filter: blur(10px);
    backdrop-filter: blur(10px);
    border-bottom: 1px solid var(--border);
  }

  .pill {
    padding: 5px 16px;
    font-size: 0.88rem;
    letter-spacing: 0.12em;
    color: var(--text-secondary);
    text-decoration: none;
    border: 1px solid var(--border);
    border-radius: 3px;
    background: var(--surface);
    transition: color .2s, border-color .2s, transform .2s;
  }

  .pill:hover {
    color: var(--accent);
    border-color: color-mix(in srgb, var(--accent) 55%, var(--border));
    transform: translateY(-1px);
  }

  /* ── 分类区块 ── */
  .category {
    margin-bottom: 56px;
    scroll-margin-top: 86px;
    --cat-ink: color-mix(in srgb, var(--cat) 78%, var(--text));
  }

  .category h2 {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 1.18rem;
    font-weight: 700;
    letter-spacing: 0.22em;
    margin-bottom: 20px;
    padding-left: 2px;
  }

  /* 方胜纹（菱形）标记 */
  .category h2 .dot {
    width: 9px;
    height: 9px;
    border-radius: 2px;
    transform: rotate(45deg);
    background: var(--cat);
    box-shadow: 0 0 0 3px color-mix(in srgb, var(--cat) 16%, transparent);
  }

  .category h2 .count {
    font-size: 0.72rem;
    font-weight: 600;
    letter-spacing: 0.08em;
    color: var(--cat-ink);
    background: color-mix(in srgb, var(--cat) 10%, transparent);
    border: 1px solid color-mix(in srgb, var(--cat) 32%, transparent);
    border-radius: 3px;
    padding: 1px 9px;
    margin-left: 2px;
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(290px, 1fr));
    gap: 16px;
  }

  /* ── 卡片 ── */
  @keyframes rise {
    from { opacity: 0; transform: translateY(14px); }
    to   { opacity: 1; transform: none; }
  }

  .card {
    position: relative;
    display: flex;
    flex-direction: column;
    padding: 20px 20px 22px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    text-decoration: none;
    color: inherit;
    box-shadow: var(--shadow);
    animation: rise .5s ease both;
    transition: box-shadow .25s, transform .25s, border-color .25s;
  }

  /* 顶部题签色条 */
  .card::before {
    content: "";
    position: absolute;
    top: -1px; left: 18px; right: 18px;
    height: 2px;
    background: var(--cat);
    opacity: 0;
    transition: opacity .25s;
  }

  .card:hover {
    box-shadow: var(--shadow-hover);
    transform: translateY(-3px);
    border-color: color-mix(in srgb, var(--cat) 45%, var(--border));
  }

  .card:hover::before { opacity: 1; }

  .card-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 13px;
  }

  .tag {
    font-size: 0.72rem;
    font-weight: 600;
    letter-spacing: 0.14em;
    color: var(--cat-ink);
    background: color-mix(in srgb, var(--cat) 8%, transparent);
    border: 1px solid color-mix(in srgb, var(--cat) 30%, transparent);
    border-radius: 3px;
    padding: 2px 10px;
  }

  .card-arrow {
    font-size: 1rem;
    color: var(--cat-ink);
    opacity: 0;
    transform: translateX(-4px);
    transition: opacity .2s, transform .2s;
  }

  .card:hover .card-arrow {
    opacity: 1;
    transform: none;
  }

  .card h3 {
    font-size: 1.06rem;
    font-weight: 700;
    letter-spacing: 0.04em;
    margin-bottom: 7px;
    line-height: 1.45;
  }

  .card p {
    font-size: 0.86rem;
    color: var(--text-secondary);
    line-height: 1.7;
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  /* ── 页脚 ── */
  footer {
    display: flex;
    justify-content: center;
    gap: 12px;
    padding: 30px 0 10px;
    color: var(--text-secondary);
    font-size: 0.82rem;
    letter-spacing: 0.1em;
    border-top: 3px double var(--border-strong);
  }

  .footer-sep { color: var(--accent); }

  @media (prefers-reduced-motion: reduce) {
    html { scroll-behavior: auto; }
    .card { animation: none; }
    .card, .pill, .card-arrow, .card::before { transition: none; }
  }
</style>
</head>
<body>
<div class="container">
HEADER

cat <<HERO
  <header class="hero">
    <div class="hero-text">
      <p class="overline">One Page · 单页作品集</p>
      <h1>每一个页面，<br>都是一方<em>小世界</em>。</h1>
      <p class="subtitle">独立单页项目合集 —— 工具、互动体验、游戏与作品展示，无需构建，直接在浏览器中打开体验。</p>
      <div class="stats">
        <span><strong>$TOTAL</strong> 个项目</span>
        <span class="stats-sep"></span>
        <span><strong>$CATS</strong> 个分类</span>
      </div>
    </div>
    <div class="seal" aria-hidden="true"><span>一页</span></div>
  </header>
  <nav class="nav">
HERO

# 分类导航
cut -f1 "$TMP" | sort -u | while IFS= read -r t; do
  printf '    <a class="pill" href="#cat-%s">%s</a>\n' "$t" "$t"
done

echo "  </nav>"

# 按类型分组输出卡片
i=0
prev_type=""
sort -t$'\t' -k1,1 "$TMP" | while IFS=$'\t' read -r type dir title desc; do
  i=$((i + 1))
  delay=$(( (i - 1) % 9 * 40 ))
  if [[ "$type" != "$prev_type" ]]; then
    if [[ -n "$prev_type" ]]; then
      echo "    </div>"
      echo "  </section>"
    fi
    case "$type" in
      工具)     accent="#486581" ;;  # 黛蓝
      互动体验) accent="#6b5b95" ;;  # 青莲
      游戏)     accent="#4e7c5a" ;;  # 松绿
      作品展示) accent="#b05a3c" ;;  # 赭红
      *)        accent="#8a7d6a" ;;
    esac
    n=$(awk -F'\t' -v t="$type" '$1 == t { c++ } END { print c }' "$TMP")
    cat <<SECTION
  <section class="category" id="cat-$type" style="--cat: $accent">
    <h2><span class="dot"></span>$type<span class="count">$n</span></h2>
    <div class="grid">
SECTION
    prev_type="$type"
  fi
  cat <<CARD
      <a class="card" href="$dir/index.html" target="_blank" style="animation-delay: ${delay}ms">
        <div class="card-top">
          <span class="tag">$type</span>
          <span class="card-arrow">&rarr;</span>
        </div>
        <h3>$title</h3>
        <p>$desc</p>
      </a>
CARD
done
echo "    </div>"
echo "  </section>"

cat <<FOOTER
  <footer>
    <span>共 $TOTAL 个项目</span>
    <span class="footer-sep">·</span>
    <span>一页一世界</span>
    <span class="footer-sep">·</span>
    <span>Generated by sync.sh</span>
  </footer>
</div>
</body>
</html>
FOOTER
} > index.html

echo "[sync] AGENTS.md 和 index.html 已更新"

# ── watch 模式 ──────────────────────────────────────────────

if [[ "${1:-}" == "--watch" ]]; then
  echo "[sync] 监听模式启动，Ctrl+C 退出"

  if command -v fswatch &>/dev/null; then
    fswatch -0 --exclude '\.git' --exclude '\.DS_Store' --exclude 'index\.html' --exclude 'AGENTS\.md' . | while read -d ''; do
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
      CURRENT_HASH=$(find . -maxdepth 2 -name 'AGENTS.md' -not -path './.git/*' -exec md5 -r {} + 2>/dev/null | sort | md5 -q)
      if [[ "$CURRENT_HASH" != "$LAST_HASH" ]]; then
        [[ -n "$LAST_HASH" ]] && { echo "[sync] 检测到变化，重新生成..."; exec "$0"; }
        LAST_HASH="$CURRENT_HASH"
      fi
      sleep 2
    done
  fi
fi
