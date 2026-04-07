# TableTools Implementation Sketch
Date: 2026-04-07

## package TableTools

```perl
# Rules:
# TableTools は validate 済みテーブルを前提に orderby / group / expand を扱う
# メタデータは '#', 子行は '@' に置く
# group は入力順をそのまま使うので、必要なら先に orderby する
# 非連続な同一キーの再出現はエラーにする
# expand は group 済み構造を平坦化する
```

### validate
```perl
sub validate($table, $cols = undef) {
    # meta と rows を分離する
    # rows を走査して列集合を検証する
    # 値を見て attrs を確定する
    # attach() で meta を戻して返す
}
```

### orderby
```perl
sub orderby($table, @cols) {
    # meta と rows を分離する
    # attrs を見て rows を sort する
    # attach() で meta を戻して返す
}
```

### group
```perl
sub group($table, @cols_list) {
    # meta と rows を分離する
    # 入力順のまま連続行をまとめる
    # 子行を '@' に入れる
    # 必要なら再帰する
    # attach() で meta を戻して返す
}
```

### expand
```perl
sub expand($table) {
    # meta と rows を分離する
    # '@' を再帰的に展開する
    # 親子をマージして平坦な行へ戻す
    # attach() で meta を戻して返す
}
```

### detach
```perl
sub detach($table) {
    # 先頭の meta を分離する
}
```

### attach
```perl
sub attach($table, $meta) {
    # meta があれば先頭に付ける
}
```
