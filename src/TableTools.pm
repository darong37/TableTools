package TableTools;

# Terms:
# AoH はハッシュリファレンスの配列リファレンス
# rows はメタデータを持たない AoH
# table は先頭行にメタデータを持つ AoH
# table のメタデータは '#' に置く
# attrs はカラム名をキーに持つハッシュで、値は num または str
# order はカラム名の並びを表す配列リファレンス
#
# Rules:
# detach() と attach() を除く API は rows でも table でも受け取れる
# detach() を除く API の出力は table とする
# データ rows が 0 件の場合は、table を作らず [] を返す
# validate() は rows が 0 件かどうかを必ず確認し、0 件なら [] を返す
# attach() は validate() を呼ばず、rows と meta から table を組み立てる
# attrs は必須で、order は列順を指定した validate() のときだけ付く
# validate() は undef の値を空文字 '' に置き換える
# orderby() は attrs に従って num は数値、str は文字列として並べる
# group() は入力順をそのまま使うので、必要なら先に orderby() を使う
# group() では非連続な同一キーの再出現をエラーにする
# expand() は group() 済みの table を平坦化して table を返す
# count は validate() が生成する meta に必ず含まれ、table の rows 件数を表す
# orderby() は行数不変なので meta をそのまま維持する
# group() と expand() は rows 件数が変わるので count を再計算した新 meta を生成する

use strict;
use warnings;
use parent 'Exporter';
use Scalar::Util qw(looks_like_number);

our @EXPORT_OK = qw(validate group expand orderby detach attach);

sub _check_cols {
    my ($attrs, @cols) = @_;
    for my $col (@cols) {
        die "unknown column '$col'" unless exists $attrs->{$col};
    }
}

sub _normalize_rows {
    my ($rows) = @_;
    for my $row (@$rows) {
        for my $key (keys %$row) {
            $row->{$key} = '' unless defined $row->{$key};
        }
    }
}

sub validate {
    my ($aoh, $cols) = @_;
    # meta と rows を分離する
    my ($rows, $meta) = detach($aoh);
    return [] unless @$rows;

    # undef は空文字へ正規化する
    _normalize_rows($rows);

    # attrs 付き table + $cols なし → 同一参照をそのまま返す（アーリーリターン）
    # ただしその前に undef の空文字正規化は行う
    if (!$cols && $meta && $meta->{'#'}{attrs}) {
        return $aoh;
    }

    $meta //= {'#' => {}};
    my $attrs = $meta->{'#'}{attrs};
    my $order = $meta->{'#'}{order};
    if (!$attrs) {
        my @keys = $cols ? @$cols : keys %{$rows->[0]};
        $attrs = { map { $_ => 'unknown' } @keys };
    }
    if ($cols) {
        die "cols count mismatch" unless @$cols == scalar keys %$attrs;
        _check_cols($attrs, @$cols);
        $order = [@$cols];
    }
    my $new_meta = {'#' => {attrs => $attrs, count => scalar(@$rows)}};
    $new_meta->{'#'}{order} = $order if $order;

    my $col_count = scalar keys %$attrs;

    # 列集合を検証する
    for my $i (0 .. $#$rows) {
        my $row      = $rows->[$i];
        my @row_keys = keys %$row;
        die "Row $i: column count mismatch" unless @row_keys == $col_count;
        for my $k (@row_keys) {
            die "Row $i: unexpected column '$k'" unless defined $attrs->{$k};
            my $val = $row->{$k};
            next if $val eq '';
            my $is_str = !looks_like_number($val);
            # attrs を確定する
            if ($attrs->{$k} eq 'unknown') {
                $attrs->{$k} = $is_str ? 'str' : 'num?';
            } elsif ($attrs->{$k} eq 'num?') {
                $attrs->{$k} = 'str' if $is_str;
            } elsif ($attrs->{$k} eq 'num' && $is_str) {
                die "Row $i: column '$k' is num but got non-numeric value";
            }
        }
    }

    for my $k (keys %$attrs) {
        $attrs->{$k} = 'num' if $attrs->{$k} eq 'num?';
        $attrs->{$k} = 'str' if $attrs->{$k} eq 'unknown';
    }

    # attach() で meta を戻して返す
    return attach($rows, $new_meta);
}

sub group {
    my ($aoh, @cols_list) = @_;
    # validate を内部で呼ぶ（rows でも table でも受け取れる）
    my $table = validate($aoh);
    return $table unless @$table;
    return $table unless @cols_list;
    my ($rows, $meta) = detach($table);
    my $attrs = $meta->{'#'}{attrs};

    _check_cols($attrs, map { @$_ } @cols_list);

    # 入力順のまま連続行をまとめる
    my $grouped = _group_rows($rows, $attrs, @cols_list);
    # attach() で meta を戻して返す
    return attach($grouped, $meta);
}

sub orderby {
    my ($aoh, $cols) = @_;
    # validate を内部で呼ぶ（rows でも table でも受け取れる）
    my $table = validate($aoh);
    return $table unless @$table;
    return $table unless $cols && @$cols;
    my ($rows, $meta) = detach($table);
    my $attrs = $meta->{'#'}{attrs};

    _check_cols($attrs, @$cols);

    # attrs を見て rows をソートする
    my @sorted = sort {
        for my $col (@$cols) {
            my $cmp = $attrs->{$col} eq 'num'
                ? (($a->{$col} // 0) <=> ($b->{$col} // 0))
                : (($a->{$col} // '') cmp ($b->{$col} // ''));
            return $cmp if $cmp;
        }
        return 0;
    } @$rows;

    # attach() で meta を戻して返す
    return attach(\@sorted, $meta);
}

sub _group_rows {
    my ($rows, $attrs, @cols_list) = @_;

    my $level_cols = $cols_list[0];
    my @rest       = @cols_list[1 .. $#cols_list];

    my @grouped;
    my ($current_key, $current_group);
    my %seen_keys;

    for my $row (@$rows) {
        my $key = join "\0", map { $row->{$_} // '' } @$level_cols;
        if (!defined $current_key || $key ne $current_key) {
            if (defined $current_group) {
                push @grouped, $current_group;
                $seen_keys{$current_key} = 1;
            }
            die "out of order: key reappeared\n" if $seen_keys{$key};
            $current_key   = $key;
            $current_group = { map { $_ => $row->{$_} } @$level_cols };
            # 子行を '@' に入れる
            $current_group->{'@'} = [];
        }
        my %child = %$row;
        delete $child{$_} for @$level_cols;
        push @{ $current_group->{'@'} }, \%child;
    }
    push @grouped, $current_group if defined $current_group;

    if (@rest) {
        # 必要なら再帰する
        for my $parent (@grouped) {
            $parent->{'@'} = _group_rows($parent->{'@'}, $attrs, @rest);
        }
    }

    return \@grouped;
}

sub expand {
    my ($aoh) = @_;
    # validate を内部で呼ぶ（rows でも table でも受け取れる）
    my $table = validate($aoh);
    return $table unless @$table;
    my ($rows, $meta) = detach($table);
    # '@' を再帰的に展開する
    my @flat = _expand_rows($rows, {});

    # attach() で meta を戻して返す
    return attach(\@flat, $meta);
}

sub _expand_rows {
    my ($rows, $parent) = @_;
    my @result;
    for my $row (@$rows) {
        # 親子をマージして平坦な行へ戻す
        my %base = (%$parent, %$row);
        if (exists $base{'@'}) {
            my $children = delete $base{'@'};
            push @result, _expand_rows($children, \%base);
        } else {
            push @result, \%base;
        }
    }
    return @result;
}

sub detach {
    my ($aoh) = @_;
    # 先頭の meta を分離する
    if (@$aoh && exists $aoh->[0]{'#'}) {
        my ($meta, @rows) = @$aoh;
        return (\@rows, $meta);
    }
    return ($aoh, undef);
}

sub attach {
    my ($rows, $meta) = @_;
    return $rows unless defined $meta;
    # meta があれば先頭に付ける
    return [$meta, @$rows];
}

1;
