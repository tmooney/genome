#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above 'Genome';
use Genome::VariantReporting::Expert::BamReadcount::TestHelper;
use Genome::File::Vcf::Entry;
use Test::More;
use Test::Exception;

my $pkg = 'Genome::VariantReporting::Filter::CoverageVafFilter';
use_ok($pkg) or die;

my $entry = Genome::VariantReporting::Expert::BamReadcount::TestHelper::create_entry(
    Genome::VariantReporting::Expert::BamReadcount::TestHelper::bam_readcount_line(),
);

subtest "test pass" => sub { #FIXME

    my $filter = $pkg->create(
        sample_name => 'S1',
        coverages_and_vafs => {
            10000 => 1,
            400 => 5,
            300 => 10,
            20 => 20,
        },
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    # coverages, and vaf for coverage
    is_deeply([$filter->coverages], [qw/ 10000 400 300 20 /], 'coverages sort correctly');
    is($filter->_vaf_for_coverage(10001), 1, 'vaf for coverage 10001');
    is($filter->_vaf_for_coverage(401), 5, 'vaf for coverage 401');
    is($filter->_vaf_for_coverage(400), 5, 'vaf for coverage 400');
    is($filter->_vaf_for_coverage(399), 10, 'vaf for coverage 399');
    is($filter->_vaf_for_coverage(1), undef, 'vaf for coverage 1');

    my %expected_return_values = (
        C => 0,
        G => 1,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values, "Sample 1 return values as expected");

};

subtest "test filter fail" => sub { #FIXME

    my $filter = $pkg->create(
        sample_name => 'S1',
        coverages_and_vafs => {
            400 => 99,
            300 => 100,
            200 => 99,
        }
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my %expected_return_values = (
        C => 0,
        G => 0,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values, "Sample 1 return values as expected");

};

subtest "test filter fail" => sub { #FIXME

    my $filter = $pkg->create(
        sample_name => 'S1',
        coverages_and_vafs => {
            300 => 100,
        }
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my %expected_return_values = (
        C => 0,
        G => 0,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values, "Sample 1 return values as expected");

};

subtest 'validate fails' => sub {

    my $filter = $pkg->create(sample_name => 'S1');
    throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when coverages_and_vafs is undef");

    $filter = $pkg->create(coverages_and_vafs => { 20 => 5, });
    throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when sample_name is undef");

    $filter = $pkg->create(
        sample_name => 'S1',
        coverages_and_vafs => { STRING => 10 },
    );
    throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when coverages_and_vafs coverage is a string");

    $filter = $pkg->create(
        sample_name => 'S1',
        coverages_and_vafs => { 10 => 'STRING' },
    );
    throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when coverages_and_vafs vaf is a string");

    $filter = $pkg->create(
        sample_name => 'S1',
        coverages_and_vafs => { -1 => 10, },
    );
    throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when coverages_and_vafs coverage is negative");

    $filter = $pkg->create(
        sample_name => 'S1',
        coverages_and_vafs => { 10 => -1, },
    );
    throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when coverages_and_vafs vaf is negative");

};

done_testing();
