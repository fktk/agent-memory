# Agent Memory System

LLMエージェント（GitHub Copilot）が自律的に記憶を書き込み・読み込みするシステム。  
[qmd](https://github.com/tobi/qmd) をバックエンドに使い、エージェントが学んだ教訓・知識・ユーザーの好みをローカルに蓄積する。

## 概要

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  Copilot Agent      │────▶│  memory-search.sh    │────▶│  qmd (BM25 +    │
│  copilot-           │     │  memory-write.sh     │     │  Vector +       │
│  instructions.md    │     └──────────────────────┘     │  Reranking)     │
│  でルール定義        │                                  └────────┬────────┘
└─────────────────────┘                                           │
                                                        ┌────────▼────────┐
                                                        │ ~/.local/share/ │
                                                        │ qmd/docs/*.md   │
                                                        └─────────────────┘
```

**記憶の流れ:**
1. **想起**: タスク開始時に `memory-search.sh` で関連記憶を自動検索
2. **蓄積**: 教訓/知識/好みを検出したら `memory-write.sh` で自動書き込み
3. **検索**: qmd のハイブリッド検索（BM25 + ベクトル + リランキング）で高精度に記憶を取得

## セットアップ

### 前提条件

- [qmd](https://github.com/tobi/qmd) がインストール済み
- Python 3（JSON パース用）
- Bash

### インストール

```bash
# qmd をインストール
npm install -g @tobilu/qmd

# このリポジトリをクローン
git clone <this-repo>
cd agent-memory

# セットアップ実行
chmod +x setup.sh
./setup.sh
```

セットアップスクリプトが以下を実行します:
1. `~/.local/share/qmd/docs/` ディレクトリを作成
2. AgentSkills として `~/.github/copilot/skills/` にスキルディレクトリをインストール
3. qmd コレクション `agent-memory` を登録
4. `~/.github/copilot-instructions.md` にルールを追記
5. 初回エンベディングを実行

### アンインストール

```bash
./setup.sh --uninstall
```

### APM 経由でインストール（推奨・copilot 向け）

このリポジトリは [APM](https://microsoft.github.io/apm/) パッケージとして配布可能です。
copilot 向けには `setup.sh` は不要です。以下の APM フローで完結します。

```bash
# パッケージをビルド（build/agent-memory-<version>.zip を生成）
apm pack --target copilot --archive

# 任意のプロジェクトでインストール（skills + ルールを自動展開）
cd /path/to/your/project
apm install /path/to/agent-memory/build/agent-memory-1.0.0.zip --target copilot
```

`apm install` により `skills/` → `.agents/skills/`、`.apm/instructions/` →
`.github/instructions/` へ展開されます。

#### qmd バックエンドの初期化

skills/ルールの展開とは別に、[qmd](https://github.com/tobi/qmd) のコレクション登録と
初回エンベディングが必要です（qmd の事前インストールが必要）。
このリポジトリを clone している場合は以下を実行してください:

```bash
./scripts/init-memory.sh
```

> `apm run init-memory` は本リポジトリ（producer 側）で定義したスクリプトで、
> clone 環境から実行できます。zip のみの受け取りの場合は上記スクリプトをご利用ください。
>
> `setup.sh` は APM 非対応環境や copilot 以外の手動セットアップ用に残しています。
> copilot ユーザーは上記 APM フローを使ってください。

## 使い方

### 記憶の書き込み

```bash
memory-write.sh "<タイトル>" <カテゴリ> "<タグ>" "<内容>"
```

```bash
# 教訓を記録
memory-write.sh \
  "Avoid nested ternary operators" \
  lesson \
  "coding-style,readability" \
  "ネストされた三項演算子は可読性を大きく損なう。1段階までに限定し、それ以上はif/elseを使う。"

# ユーザーの好みを記録
memory-write.sh \
  "User prefers Rust over Go" \
  preference \
  "language-choice,rust" \
  "ユーザーはGoよりRustを好む。新規CLIツールはRustで提案すること。"

# パイプで内容を渡す
echo "詳細な調査結果..." | memory-write.sh "SQLite WAL mode" knowledge "sqlite,concurrency"
```

### 記憶の検索

```bash
memory-search.sh "<クエリ>" [--limit N] [--min-score SCORE] [--json]
```

```bash
# 基本的な検索
memory-search.sh "coding style"

# JSON出力（エージェント向け）
memory-search.sh "error handling" --json --limit 5

# 高スコアのみ
memory-search.sh "performance" --min-score 0.5
```

## 記憶ファイルフォーマット

各記憶は `~/.local/share/qmd/docs/` に Markdown ファイルとして保存されます:

```markdown
---
title: "Avoid nested ternary operators"
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

### カテゴリ

| カテゴリ | 説明 | 例 |
|----------|------|-----|
| `lesson` | 失敗・成功から学んだ教訓 | バグの原因、避けるべきパターン |
| `knowledge` | 調査で得た再利用可能な知見 | API仕様、ツールの使い方 |
| `preference` | ユーザーの好み・こだわり | 命名規則、技術選択 |

## カスタマイズ

環境変数で設定を変更できます:

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `AGENT_MEMORY_DIR` | `~/.local/share/qmd/docs` | 記憶ファイルの保存先 |
| `AGENT_MEMORY_COLLECTION` | `agent-memory` | qmd コレクション名 |
| `AGENT_MEMORY_DEDUP_THRESHOLD` | `0.8` | 重複判定の閾値 (0-1) |

## ライセンス

MIT
