---
name: memory-maintain
description: 司書(librarian)として記憶を整理する。類似メモリの統合(merge)、複数lessonから一般原則を生成(reflect)、古く低置信度の記憶の忘却(forget)を実行する。記憶庫の品質を保つために定期的に、またはユーザーが「記憶を整理して」「メモリをメンテして」と頼んだ時に使用する。
---

# Memory Maintain — 司書としての記憶整理

エージェントメモリーの司書。記憶を**統合・抽象化・忘却**し、記憶庫が小さく高シグナルに保たれるよう務める。LLMによる判断（merge / reflect）は**エージェント自身が実行**し、このスキルのスクリプトは「候補の収集」「判断結果の書き戻し」「TTL忘却」のみを担う。

## いつ使うか

- ユーザーが「記憶を整理して」「メモリをメンテして」「司書として働いて」と指示した時
- 定期メンテナンス（コミット前、日次/週次の目安）
- 記憶数が増えすぎた時、重複が目立つ時

## モードと手順

### 1. collect — 候補を収集

```bash
./scripts/memory-maintain.sh collect [--category lesson] [--tag coding-style] [--limit 200]
```

全メモリ（または絞り込み）を JSON で出力する。この JSON を読み、以下の判断を行う。

### 2. merge — 類似メモリの統合（LLM判断）

collect の出力を見て、**同じ話題・重複・矛盾**しているメモリを特定する。それらを1つの要約にまとめる。元の「なぜ」の理由を保持し、情報を失わないこと。

### 3. reflect — 一般原則の生成（LLM判断）

複数の `lesson` から、より抽象度の高い原則（「次回はこういう類いの時にこうする」）を導く。新規メモリとして書き出す（`category: lesson`、抽象度高）。

### 4. apply — 計画を書き戻し

merge / reflect / delete の判断を **plan JSON** にまとめ、`apply` で反映する。**必ず `--dry-run` で先にプレビュー**する。

plan JSON の形式:

```json
[
  {
    "action": "merge",
    "target": "/home/user/.local/share/qmd/docs/old-slug.md",
    "meta": { "title": "統合後のタイトル", "category": "lesson", "tags": ["coding-style"], "confidence": "medium" },
    "content": "統合された要約。元の理由を保持する。",
    "merged_from": ["old-slug.md", "another-slug.md"]
  },
  {
    "action": "reflect",
    "title": "General principle about X",
    "category": "lesson",
    "tags": ["meta-lesson"],
    "confidence": "medium",
    "content": "複数のlessonから導いた一般原則。"
  },
  {
    "action": "delete",
    "target": "/home/user/.local/share/qmd/docs/stale-slug.md"
  }
]
```

`target` は collect が出力した `path` をそのまま使う。`action` は `merge` / `reflect` / `delete` のいずれか。

```bash
# 安全確認
./scripts/memory-maintain.sh apply plan.json --dry-run
# 問題なければ適用
./scripts/memory-maintain.sh apply plan.json
```

### 5. forget — 忘却（LLM不要）

```bash
./scripts/memory-maintain.sh forget --max-age 180 --min-confidence low --dry-run
./scripts/memory-maintain.sh forget --max-age 180 --min-confidence low
```

`updated`（なければ `created`）が `max-age` 日より古く、かつ `confidence` が `min-confidence` 以下のメモリを削除する。LLMを使わず日付と置信度だけで判断する。

## 司書の判断プロンプト（エージェントがcollect結果を分析する時）

> 以下の記憶リストをレビューせよ。
> 1. **統合(merge)**: 同じ話題・重複・矛盾するメモリを特定し、情報損失なく1つにまとめよ。原則として「なぜ」の理由を保持せよ。
> 2. **抽象化(reflect)**: 複数の lesson から導ける、より一般的な原則を1〜数件提案せよ。
> 3. **削除(delete)**: もはや誤り、あるいは他のメモリに完全に吸収されたものを候補に挙げよ。
> 出力は上記 plan JSON 形式で。各 memory の path は正確に。

## 注意事項

- **破壊的変更の前は必ず `--dry-run`**。merge は既存ファイルを上書きし、delete/forget はファイルを消す。
- apply 後はスクリプトが自動で `qmd embed` を実行する。
- プロジェクト横断の汎用知識のみが対象。プロジェクト固有情報は触らない。
- 司書の書き込みは `source: librarian-merge` / `librarian-reflect` と記録される。
