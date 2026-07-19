---
name: memory-search
description: qmdハイブリッド検索で過去の記憶（教訓・知識・好み）を検索する。タスク開始時の想起や関連知識の確認に使用する。
---

# Memory Search — 記憶の検索

qmd のハイブリッド検索（BM25 + ベクトル + リランキング）でエージェントメモリーを検索する。

## コマンド

```bash
~/.local/bin/memory-search.sh "<クエリ>" [--limit N] [--min-score SCORE] [--json]
```

## 引数・オプション

| 引数/オプション | 説明 | デフォルト |
|----------------|------|-----------|
| `query` | 検索クエリ（自然言語 OK） | **必須** |
| `--limit N` | 最大結果数 | `10` |
| `--min-score SCORE` | 最低スコア (0-1) | `0.3` |
| `--json` | JSON形式で出力 | `false` |
| `--collection NAME` | 検索対象コレクション | `agent-memory` |

## 使用例

```bash
# タスク開始時の想起（推奨パターン）
~/.local/bin/memory-search.sh "TypeScript error handling patterns"

# 高スコアの記憶のみ
~/.local/bin/memory-search.sh "performance optimization" --min-score 0.5

# JSON出力（プログラム的な利用）
~/.local/bin/memory-search.sh "authentication" --json --limit 5

# 件数を絞る
~/.local/bin/memory-search.sh "React hooks" --limit 3
```

## 出力フォーマット

### 通常出力

```
=== Agent Memory Search Results ===
Query: "error handling"
---
[1] Always check null before array access (score: 0.85)
    File: qmd://agent-memory/always-check-null-before-array-access.md
    配列アクセス前にnullチェックを忘れてランタイムエラーが発生した...

[2] Use Result type for error handling (score: 0.72)
    File: qmd://agent-memory/use-result-type-for-error-handling.md
    RustのResult型パターンをTypeScriptでも採用する...

--- 2 result(s) found ---
```

### JSON出力 (`--json`)

qmd のネイティブ JSON 形式がそのまま出力される。スコア、ファイルパス、スニペット、コンテキストを含む。

## 想起のベストプラクティス

- タスクの要約やキーワードで検索する
- 検索結果の `lesson` カテゴリは特に注意して参照する（過去の失敗を繰り返さないため）
- `preference` カテゴリはユーザーの期待に合わせるために参照する
- 結果がなければ、そのまま作業を進めてよい
