use strict;
use warnings;

use Test::Builder::Tester;
use above "Genome";
use Genome::Utility::Test qw(capture_ok);
use Test::More;

BEGIN {
    use_ok 'Genome::Utility::Test', qw(sub_test compare_ok);
}

my $_compare_ok_parse_args = \&Genome::Utility::Test::_compare_ok_parse_args;

my @args_A = ('file_1', 'file_2', 'args_A');
sub_test('_compare_ok_parse_args parsed: ' . join(', ', @args_A) => sub {
    local $@ = '';
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_A) };
    ok(!$@, 'did not die');
    is($o{name}, $args_A[2], 'name matched expected value');
});

my @args_B = ('file_1', 'file_2', 'args_B', filters => [qr(/foo/)]);
sub_test('_compare_ok_parse_args parsed: ' . join(', ', @args_B) => sub {
    local $@ = '';
    $DB::single = 1;
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_B) };
    ok(!$@, 'did not die');
    is($o{name}, $args_B[2], 'name matched expected value');
    is_deeply($o{filters}, $args_B[4], 'filters matched expected value');
});

my @args_C = ('file_1', 'file_2', filters => [qr(/foo/)], name => 'args_C');
sub_test('_compare_ok_parse_args parsed: ' . join(', ', @args_C) => sub {
    local $@ = '';
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_C) };
    ok(!$@, 'did not die');
    is($o{name}, $args_C[5], 'name matched expected value');
    is_deeply($o{filters}, $args_C[3], 'filters matched expected value');
});

my @args_D = ('file_1', 'file_2', 'args_D', name => 'args_D');
sub_test('_compare_ok_parse_args did fail to parse: ' . join(', ', @args_D) => sub {
    local $@ = '';
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_D) };
    ok($@, 'did die');
});

my @args_E = ('file_1', 'file_2', 'args_E', filters => qr(/foo/));
sub_test('_compare_ok_parse_args parsed: ' . join(', ', @args_E) => sub {
    local $@ = '';
    $DB::single = 1;
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_E) };
    ok(!$@, 'did not die');
    is($o{name}, $args_E[2], 'name matched expected value');
    is_deeply($o{filters}, [$args_E[4]], 'filters matched expected value');
});

sub_test('compare_ok matches diff command' => sub {
    my $a_fh = File::Temp->new(TMPDIR => 1);
    my $a_fn = $a_fh->filename;
    $a_fh->print("a\n");
    $a_fh->close();

    my $b_fh = File::Temp->new(TMPDIR => 1);
    my $b_fn = $b_fh->filename;
    $b_fh->print("b\n");
    $b_fh->close();

    my $aa_fh = File::Temp->new(TMPDIR => 1);
    my $aa_fn = $aa_fh->filename;
    $aa_fh->print("a\n"); # like a, not aa!
    $aa_fh->close();

    {
        # STDERR is:
        # # # First diff:
        # # # --- /tmp/akzszm45QF
        # # # +++ /tmp/aM8X5Vj6pQ
        # # # - a
        # # # + b
        # # #   Failed test at Utility/Test.t/compare_ok.t line 77.
        test_out('not ok 1');
        test_err(q(/# First diff:\n# --- .*\n# \+\+\+.*\n# - a\n# \+ b\n#\s+Failed test at .+ line \d+\./));
        my $compare_ok = compare_ok($a_fn, $b_fn);
        test_test('compare_ok ran on different files');
        my $diff    = (system(qq(diff -u "$a_fn" "$b_fn" > /dev/null)) == 0 ? 1 : 0);
        is($diff, 0, 'diff detected diff between different files');
        is($compare_ok, $diff, 'compare_ok detected diff between different files');
    }

    {
        test_out('ok 1');
        my $compare_ok = compare_ok($a_fn, $aa_fn);
        test_test('compare_ok ran on similar files');
        my $diff    = (system(qq(diff -u "$a_fn" "$aa_fn" > /dev/null)) == 0 ? 1 : 0);
        is($diff, 1, 'diff did not detect diff between similar files');
        is($compare_ok, $diff, 'compare_ok did not detect diff between similar files');
    }
});

sub_test('compare_ok replace' => sub {
    my $a_fh = File::Temp->new(TMPDIR => 1);
    my $a_fn = $a_fh->filename;
    $a_fh->print("a\n");
    $a_fh->close();

    my $b_fh = File::Temp->new(TMPDIR => 1);
    my $b_fn = $b_fh->filename;
    $b_fh->print("b\n");
    $b_fh->close();

    test_out('not ok 1');
    test_err(q(/# First diff:\n# --- .*\n# \+\+\+.*\n# - a\n# \+ b\n#\s+Failed test at .+ line \d+\./));
    compare_ok($a_fn, $b_fn);
    test_test('compare_ok failed without replace');

    my $error = Genome::Utility::Test->ERRORS('REPLACE_ARRAY_REF');
    ok($error, 'got REPLACE_ARRAY_REF error string');
    eval { compare_ok($a_fn, $b_fn, replace => 'a') };
    like($@, qr/$error/,
        'got REPLACE_ARRAY_REF error with a non-array-ref replace argument');

    test_out('ok 1');
    compare_ok($a_fn, $b_fn, replace => [['a' => 'b']]);
    test_test('compare_ok passed with replace');
});

done_testing();
