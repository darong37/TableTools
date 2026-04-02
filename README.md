# TableTools

A Perl utility module for manipulating Array of Hashes (AoH).
Provides functions for validating, grouping, expanding, and managing metadata of table structures.

[日本語版 README はこちら](README_ja.md)

## Usage

```perl
use TableTools qw(validate group expand detach attach);
```

## Functions

### `validate($table, $cols)`

Validates a table.

- Without `$cols`: verifies that all rows have the same key set and returns the input as-is
- With `$cols`: verifies that all rows match the `$cols` key set and returns a table with a metadata row prepended

```perl
my $table = validate(\@rows, ['A', 'B', 'C']);  # returns table with metadata
my $table = validate(\@rows);                    # validation only
```

### `group($table, @cols_list)`

Groups a table in multiple levels. Sorts rows by group key values and stores child rows under the `'@'` key.

```perl
my $grouped = group($table, ['A']);           # single-level grouping
my $grouped = group($table, ['A'], ['B']);    # two-level grouping
```

### `expand($table)`

Fully flattens a grouped table. Expands any depth of nesting in one call.

```perl
my $flat = expand($grouped);
```

### `detach($table)`

Separates the metadata row from a table.

```perl
my ($meta, $bare) = detach($table);
```

### `attach($table, $meta)`

Prepends a metadata row to a table. Does nothing if `$meta` is `undef`.

```perl
my $table = attach($bare, $meta);
```

## Data Structures

### Table

```perl
# Plain AoH
[
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]

# AoH with metadata (returned by validate($table, $cols))
[
    {'#' => [{col => 'A', attr => 'num'}, {col => 'B', attr => 'str'}, {col => 'C', attr => 'num'}]},
    {A => 1, B => 'foo', C => 3},
    {A => 5, B => 'bar', C => 7},
]
```

### Grouped Table

```perl
[
    {'#' => [...]},
    {A => 1, '@' => [
        {B => 'foo', C => 3},
        {B => 'bar', C => 7},
    ]},
]
```

- `'#'`: metadata row — holds column names and type info (`'num'` / `'str'`)
- `'@'`: array reference of child rows
