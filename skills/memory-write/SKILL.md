---
name: memory-write
description: エージェントが学んだ教訓、調査知識、ユーザーの好みをqmdベースのメモリーシステムに書き込む。記憶を保存したい時に使用する。
---

# Memory Write — 記憶の書き込み

エージェントメモリーに新しい記憶を書き込む、または既存の類似記憶を更新する。

## コマンド

```bash
./scripts/memory-write.sh "<タイトル>" <category> "<tags>" "<内容>"
```

## 引数

| 引数 | 説明 | 例 |
|------|------|-----|
| `title` | 記憶の簡潔なタイトル（英語推奨、ファイル名になる） | `"Avoid nested ternary"` |
| `category` | `lesson` \| `knowledge` \| `preference` | `lesson` |
| `tags` | カンマ区切りのタグ | `"coding-style,readability"` |
| `content` | 記憶の詳細内容。**なぜそうすべきか**の理由を必ず含める | `"Nested ternary harms readability..."` |

## カテゴリの判断基準

| カテゴリ | いつ使う | 例 |
|----------|----------|-----|
| `lesson` | 失敗・修正から学んだ「次回はこうする」 | バグの原因、避けるべきパターン |
| `knowledge` | 調査・実験で得た再利用可能な知見 | API仕様、ツールの使い方、設定方法 |
| `preference` | ユーザーのこだわり・好み | 命名規則、フレームワーク選択、UIの好み |

## オプション

| オプション | 説明 |
|-----------|------|
| `--force` | 重複チェックをスキップし、常に新規ファイルを作成 |
| `--source` | ソース種別: `conversation`(デフォルト), `investigation`, `user-explicit` |

## パイプ入力

長い内容は stdin からパイプで渡せる:

```bash
echo "詳細な内容..." | ./scripts/memory-write.sh "タイトル" knowledge "tags"
```

## 使用例

```bash
# ユーザーの好み
./scripts/memory-write.sh \
  "User prefers Rust over Go" \
  preference \
  "language-choice,rust,go" \
  "ユーザーはGoよりRustを好む。パフォーマンスと型安全性を重視。新規CLIツールはRustで提案すること。"

# バグの教訓
./scripts/memory-write.sh \
  "Always check null before array access" \
  lesson \
  "null-safety,typescript,bug" \
  "配列アクセス前にnullチェックを忘れてランタイムエラーが発生した。Optional chainingかガード句を使うこと。"

# 調査で得た知識
./scripts/memory-write.sh \
  "SQLite WAL mode for concurrency" \
  knowledge \
  "sqlite,concurrency,performance" \
  "SQLiteのWALモードを有効にすると、読み取りと書き込みを並行して実行できる。journal_mode=WALを設定する。"

# 明示的指示（ユーザーが「覚えて」と言った場合）
./scripts/memory-write.sh \
  "Always use pnpm not npm" \
  preference \
  "package-manager,pnpm" \
  "ユーザーはnpmではなくpnpmを使うことを強く希望。すべてのプロジェクトでpnpmを使用する。" \
  --source user-explicit
```

## 動作フロー

1. 類似記憶をqmdで検索（score > 0.8 なら既存を更新）
2. YAML frontmatter 付き Markdown ファイルを作成/更新
3. `qmd embed` でインデックスを自動更新

## 記憶ファイルのフォーマット

```markdown
---
title: "Avoid nested ternary"
category: lesson
tags: [coding-style, readability]
created: 2026-07-19
updated: 2026-07-19
source: conversation
confidence: high
---

ネストされた三項演算子は可読性を大きく損なう。
1段階までに限定し、それ以上はif/elseや早期リターンを使う。
```

## 注意事項

- **プロジェクト横断の汎用知識のみ**記憶する。プロジェクト固有の情報はリポジトリのドキュメントに書く
- タイトルは英語で、内容を的確に表す短いフレーズにする
- 内容には必ず**理由（なぜそうすべきか）**を含める
- スクリプトが自動で重複チェックを行うため、重複を気にせず書き込んでよい
