# TableTools Concept
Date: 2026-04-07

## Concept
`TableTools` は、Array of Hashes を正規テーブルとして扱うための小さな関数群である。
AoH は配列リファレンスにハッシュリファレンスが並ぶ形だが、
データ行だけでは `orderby()` や `group()` のような cols 系の処理に必要な前提が足りない。
そのため `TableTools` では、AoH を正規テーブルとして使うために
メタ情報をテーブルと一緒に持つことを前提にする。

また、特に `group()` では行の並び順そのものが結果に影響する。
入力は必要な順に並んでいることを前提にし、並んでいない場合は先に `orderby()` で整える。

メタ情報として持つのは、少なくとも
- どんなカラムがあるか
- カラムの属性が `num` か `str` か
- 必要に応じたカラム順

である。

## Rules
- `orderby()` / `group()` / `expand()` を使う前には `validate()` を通す
- メタデータは `'#'`、子行は `'@'` に置く
- `group()` は入力順をそのまま使うので、必要なら先に `orderby()` で並べる
- 非連続な同一キーの再出現はエラーにする
- `expand()` は `group()` 済み構造を平坦化する

## API
| API | 役割 | 説明 |
|---|---|---|
| `validate($table)` | 検証 | 列集合を検証し、`attrs` を付ける |
| `validate($table, $cols)` | 検証 | 列集合を検証し、`attrs` と `order` を付ける |
| `orderby($table, @cols)` | 整列 | 型情報に従って並べ替える |
| `group($table, @cols_list)` | 構造化 | 連続行を多段グループにまとめる |
| `expand($table)` | 展開 | グループ化された構造を平坦に戻す |
| `detach($table)` | 分離 | メタデータ行を外す |
| `attach($table, $meta)` | 付与 | メタデータ行を先頭に戻す |
