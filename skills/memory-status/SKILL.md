---
name: memory-status
description: エージェントメモリーの状態（ファイル数、カテゴリ別統計、qmdインデックス状態）を確認する。
---

# Memory Status — 記憶の状態確認

エージェントメモリーのファイル数、カテゴリ別統計、qmd インデックスの状態を表示する。

## コマンド

```bash
./scripts/memory-status.sh [--json]
```

## オプション

| オプション | 説明 |
|-----------|------|
| `--json` | JSON形式で出力 |

## 出力例

```
=== Agent Memory Status ===

Memory directory: /home/user/.local/share/qmd/docs
Collection:       agent-memory

--- Files ---
Total:      12
  lesson:     5
  knowledge:  4
  preference: 3
  other:      0

--- qmd Index ---
Collections: 1
Documents: 12
...

--- Recent Memories (last 5) ---
  • Avoid nested ternary operators
  • User prefers Rust over Go
  • SQLite WAL mode for concurrency
  • Always use pnpm not npm
  • React Server Components caveats
```
