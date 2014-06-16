#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Test::Exception;
use Genome::File::Vcf::Entry;

my $pkg = "Genome::VariantReporting::Filter::MaxGmafFilter";
use_ok($pkg);

subtest "Filter fails" => sub {
    my $filter = $pkg->create(
        max_gmaf => ".1",
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my $entry = create_entry('.3');

    my %expected_return_values = (
        C => 0,
        G => 0,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values);
};

subtest "No GMAF for entry" => sub {
    my $filter = $pkg->create(
        max_gmaf => ".1",
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my $entry = create_entry();

    my %expected_return_values = (
        C => 1,
        G => 1,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values);
};

sub create_vcf_header {
    my $header_txt = <<EOS;
##fileformat=VCFv4.1
##INFO=<ID=GMAF,Number=1,Type=Float,Description="GMAF">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO
EOS
    my @lines = split("\n", $header_txt);
    my $header = Genome::File::Vcf::Header->create(lines => \@lines);
    return $header
}

sub create_entry {
    my $gmaf = shift;
    my @fields = (
        '1',            # CHROM
        10,             # POS
        '.',            # ID
        'A',            # REF
        'C,G',            # ALT
        '10.3',         # QUAL
        'PASS',         # FILTER
    );
    if (defined $gmaf) {
        push @fields, "GMAF=$gmaf";
    }
    else {
        push @fields, ".";
    }

    my $entry_txt = join("\t", @fields);
    my $entry = Genome::File::Vcf::Entry->new(create_vcf_header(), $entry_txt);
    return $entry;
}
done_testing;

