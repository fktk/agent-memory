## Agent Memory System

このプロジェクトでは、エージェントメモリーシステムが有効です。
記憶の想起と保存を以下のルールに従って実行してください。

### 記憶の想起（タスク開始時）

タスクを開始する**前に**、必ず以下のコマンドを実行して関連する過去の記憶を確認する:

```bash
~/.local/bin/memory-search.sh "<タスクの要約や関連キーワード>"
```

検索結果があれば、その内容を考慮してタスクを実行する。特に以下の記憶カテゴリに注意:
- **lesson**: 過去の失敗から学んだ教訓。同じ過ちを繰り返さない
- **preference**: ユーザーの好み。ユーザーが期待するスタイルに合わせる
- **knowledge**: 調査済みの知識。車輪の再発明を避ける

### 記憶の書き込み（自動発火条件）

以下の状況を検出したら、**自動的に**記憶を書き込む。ユーザーへの確認は不要:

1. **教訓 (lesson)**: バグ修正後、根本原因と対策が明確になった時
2. **調査知識 (knowledge)**: 複雑な調査の結果、再利用可能な知見を得た時
3. **ユーザーの好み (preference)**: ユーザーがコーディングスタイル、技術選択、ワークフローについて明確な好みを示した時
4. **明示的指示**: ユーザーが「覚えて」「記憶して」「remember this」等と指示した時

書き込みコマンド:

```bash
~/.local/bin/memory-write.sh "<タイトル>" "<category>" "<tags>" "<内容>"
```

**引数の説明:**
- `title`: 記憶の簡潔なタイトル（英語推奨、ファイル名になる）
- `category`: `lesson` | `knowledge` | `preference` のいずれか
- `tags`: カンマ区切りのタグ（例: `"coding-style,readability,typescript"`）
- `content`: 記憶の内容（詳細な説明、コンテキスト、具体例を含める）

**書き込みの例:**

```bash
# ユーザーがRustを好むことがわかった
~/.local/bin/memory-write.sh \
  "User prefers Rust over Go" \
  preference \
  "language-choice,rust,go" \
  "ユーザーはGoよりRustを好む。パフォーマンスと型安全性を重視。新規CLIツールはRustで提案すること。"

# バグの教訓
~/.local/bin/memory-write.sh \
  "Always check null before array access" \
  lesson \
  "null-safety,typescript,bug" \
  "配列アクセス前にnullチェックを忘れてランタイムエラーが発生した。Optional chainingかガード句を使うこと。"

# 調査で得た知識
~/.local/bin/memory-write.sh \
  "SQLite WAL mode for concurrency" \
  knowledge \
  "sqlite,concurrency,performance" \
  "SQLiteのWALモードを有効にすると、読み取りと書き込みを並行して実行できる。journal_mode=WALを設定する。"
```

### カテゴリの判断基準

| カテゴリ | いつ使う | 例 |
|----------|----------|-----|
| `lesson` | 失敗・修正から学んだ「次回はこうする」 | バグの原因、避けるべきパターン |
| `knowledge` | 調査・実験で得た再利用可能な知見 | API仕様、ツールの使い方、設定方法 |
| `preference` | ユーザーのこだわり・好み | 命名規則、フレームワーク選択、UIの好み |

### 注意事項

- **プロジェクト横断の汎用知識のみ記憶する**。特定プロジェクト固有の情報はリポジトリのドキュメントに書く
- 記憶の書き込み時、スクリプトが自動で重複チェックを行う。類似記憶があれば更新される
- 記憶の書き込みは**コンテキストを汚さないよう**、簡潔にコマンド1回で完了させる
- タイトルは英語で、内容を的確に表現する短いフレーズにする
- 記憶の内容には必ず**なぜそうすべきか**の理由を含める

### その他のコマンド

```bash
# ステータス確認
~/.local/bin/memory-status.sh

# 記憶の削除
~/.local/bin/memory-delete.sh "<filename-or-title>"
```
