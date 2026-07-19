---
name: memory-delete
description: 不要になったエージェントメモリーを削除する。ファイル名またはタイトルで指定できる。
---

# Memory Delete — 記憶の削除

不要になった記憶ファイルを削除し、qmd インデックスを更新する。

## コマンド

```bash
./scripts/memory-delete.sh "<ファイル名またはタイトル>"
```

## 引数

| 引数 | 説明 | 例 |
|------|------|-----|
| `target` | ファイル名、`.md` なしのファイル名、またはタイトル（あいまい検索） | `"avoid-nested-ternary.md"` |

## 使用例

```bash
# ファイル名で指定
./scripts/memory-delete.sh "avoid-nested-ternary.md"

# .md 省略可
./scripts/memory-delete.sh "avoid-nested-ternary"

# タイトルの一部であいまい検索
./scripts/memory-delete.sh "nested ternary"
```

## 動作フロー

1. ファイル名で直接マッチを試みる
2. マッチしなければタイトルをスラッグ化してあいまい検索
3. ファイルを削除
4. `qmd embed` でインデックスを更新
