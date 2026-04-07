# TableTools

A Perl utility module for manipulating Array of Hashes (AoH).
Provides functions for validating, grouping, expanding, sorting, and managing metadata of table structures.

[日本語版 README はこちら](README_ja.md)

## Usage

```perl
use TableTools qw(validate group expand orderby detach attach);
```

## Functions

### `validate($table, $cols)`

Validates a table and attaches metadata.

- Without `$cols`: verifies all rows have the same key set, infers column types, and returns a table with a metadata row prepended. Existing `order` in the input is preserved.
- With `$cols`: verifies all rows match the `$cols` key set, infers column types, and returns a table with metadata (`attrs` + `order`) prepended.

`group`, `expand`, and `orderby` require a validate-processed table.

```perl
my $table = validate(\@rows, ['A', 'B', 'C']);  # returns table with attrs + order metadata
my $table = validate(\@rows);                    # returns table with attrs metadata
```

### `group($table, @cols_list)`

Groups a validate-processed table in multiple levels. Input must be pre-sorted (use `orderby` first). Stores child rows under the `'@'` key. Raises an error if the same group key reappears non-consecutively.

```perl
my $sorted  = orderby($table, 'A');
my $grouped = group($sorted, ['A']);           # single-level grouping
my $grouped = group($sorted, ['A'], ['B']);    # two-level grouping
```

### `expand($table)`

Fully flattens a grouped table. Expands any depth of nesting in one call.

```perl
my $flat = expand($grouped);
```

### `orderby($table, @cols)`

Sorts a validate-processed table by the specified columns in priority order. Uses type-aware comparison (`num`: `<=>`, `str`: `cmp`).

```perl
my $sorted = orderby($table, 'A', 'B');
```

### `detach($table)`

Separates the metadata row from a table.

```perl
my ($bare, $meta) = detach($table);
# $meta is undef if no metadata row is present
```

### `attach($table, $meta)`

Prepends a metadata row to a table. Returns `$table` unchanged if `$meta` is `undef`.

```perl
my $table = attach($bare, $meta);
```

## Data Structures

### Table

```perl
# Plain AoH (no metadata)
[
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]

# AoH with metadata (returned by validate)
[
    {'#' => {attrs => {A => 'num', B => 'str', C => 'num'}, order => ['A', 'B', 'C']}},
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]
```

- `attrs`: hash of column name to type (`'num'` or `'str'`)
- `order`: array reference of column names in order (only present when `$cols` is passed to `validate`)

### Grouped Table

```perl
[
    {'#' => {attrs => {A => 'num', B => 'str', C => 'num'}, order => ['A', 'B', 'C']}},
    {A => 1, '@' => [
        {B => 'foo', C => 3},
        {B => 'bar', C => 7},
    ]},
    {A => 5, '@' => [
        {B => 'baz', C => 9},
    ]},
]
```

- `'#'`: metadata row — holds `attrs` and optional `order`
- `'@'`: array reference of child rows
