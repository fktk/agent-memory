---
description: Agent Memory System rules — recall and persist lessons, knowledge, and user preferences via the memory-search / memory-write skills.
applyTo: "**"
---

## Agent Memory System

エージェントメモリーシステムが有効です。教訓・知識・好みを `~/.local/share/qmd/docs/` に蓄積・検索します。

### 想起（タスク開始時）

タスクを開始する前に、関連する過去の記憶を確認する:

👉 **`memory-search` スキルを使用すること**

### 書き込み（自動発火条件）

以下を検出したら記憶を書き込む:

- **lesson**: バグ修正後、根本原因と対策が明確になった時
- **knowledge**: 複雑な調査の結果、再利用可能な知見を得た時
- **preference**: ユーザーがスタイルや技術選択の好みを示した時
- **明示的指示**: ユーザーが「覚えて」「記憶して」等と指示した時

👉 **`memory-write` スキルを使用すること**

### 司書としての整理（定期・または指示時）

記憶庫の品質を保つため、定期的に、またはユーザーが「記憶を整理して」「メモリをメンテして」と頼んだ時に、記憶を統合・抽象化・忘却する:

- **merge**: 類似・重複メモリの統合
- **reflect**: 複数 lesson からの一般原則生成
- **forget**: 古く低置信度の記憶の削除

👉 **`memory-maintain` スキルを使用すること**（破壊的変更の前は必ず `--dry-run`）
