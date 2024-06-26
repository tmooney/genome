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
use Genome::Test::Factory::InstrumentData::Solexa;
use Genome::Test::Factory::Model::ImportedReferenceSequence;
use Genome::Test::Factory::Build;
use Genome::Test::Factory::SoftwareResult::User;
use Genome::Test::Factory::DiskAllocation;
use Genome::Test::Data qw(get_test_file);
use Sub::Override;
use Cwd qw(abs_path);

my $pkg = 'Genome::InstrumentData::AlignmentResult::Speedseq';
use_ok($pkg);

my @speedseq_versions = Genome::Model::Tools::Speedseq::Base->available_versions;
for my $version (@speedseq_versions) {
    my $sub = sub { return $version; };
    my $fake_refindex = bless {}, "DummyIndex";
    *DummyIndex::aligner_version = $sub;
    lives_ok {
        Genome::InstrumentData::AlignmentResult::Speedseq->bwa_version($fake_refindex);
    } "BWA version found for Speedseq version $version";
}

my $test_data_dir = __FILE__.'.d';

my $ref_seq_model = Genome::Test::Factory::Model::ImportedReferenceSequence->setup_object;
my $ref_seq_build = Genome::Test::Factory::Build->setup_object(
    model_id => $ref_seq_model->id,
    id => 'a77284b86c934615baaf2d1344399498',
);
use Genome::Model::Build::ReferenceSequence;
my $override = Sub::Override->new(
    'Genome::Model::Build::ReferenceSequence::full_consensus_path',
    sub { return abs_path(get_test_file('NA12878', 'human_g1k_v37_20_42220611-42542245.fasta')); }
);
use Genome::InstrumentData::AlignmentResult;
my $override2 = Sub::Override->new(
    'Genome::InstrumentData::AlignmentResult::_prepare_reference_sequences',
    sub { return 1; }
);

my $instrument_data = Genome::Test::Factory::InstrumentData::Solexa->setup_object(
    flow_cell_id => '12345ABXX',
    lane => '2',
    subset_name => '2',
    run_name => 'example',
    id => 'NA12878',
    run_type => 'Paired',
    fwd_read_length => 100,
    rev_read_length => 100,
    fwd_clusters => 10,
    rev_clusters => 10,
);
$instrument_data->bam_path(get_test_file('NA12878', 'NA12878.20slice.30X.bam'));

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(
    reference_sequence_build => $ref_seq_build,
);

my $merged_alignment_result = Genome::InstrumentData::AlignmentResult::Merged::Speedseq->__define__();
$merged_alignment_result->add_input(
    name => 'instrument_data-1',
    value_id => $instrument_data->id,
);
$merged_alignment_result->add_param(
    name => 'instrument_data_count',
    value_id=> 1,
);
$merged_alignment_result->add_param(
    name => 'instrument_data_md5',
    value_id => Genome::Sys->md5sum_data($instrument_data->id)
);
$merged_alignment_result->lookup_hash($merged_alignment_result->calculate_lookup_hash());
my $override4 = Sub::Override->new(
    'Genome::InstrumentData::AlignmentResult::Merged::Speedseq::merged_alignment_bam_path',
    sub { return File::Spec->join($test_data_dir, 'merged_alignment_result.bam'); }
);

my $merged_allocation = Genome::Test::Factory::DiskAllocation->generate_obj(owner => $merged_alignment_result);
ok($merged_allocation, 'Disk allocation generated ok for merged result');

my $alignment_result = $pkg->create(
    instrument_data => $instrument_data,
    reference_build => $ref_seq_build,
    picard_version => '1.46',
    samtools_version => 'r963',
    aligner_name => 'speedseq',
    aligner_version => 'test',
    aligner_params => '',
    merged_alignment_result_id => $merged_alignment_result->id,
    bam_size => 1024,
    _user_data_for_nested_results => $result_users,
);
ok($alignment_result, 'Alignment result created successfully');
isa_ok($alignment_result, $pkg, 'Alignment result is a speedseq alignment');

is(-e File::Spec->join($alignment_result->temp_staging_directory, 'all_sequences.bam'), undef, "Per-lane bam file doesn't exist in temp_staging_directory");
is(-e File::Spec->join($alignment_result->output_dir, 'all_sequences.bam'), undef, "Per-lane bam file doesn't exist in output_dir");

ok(!(-e $alignment_result->bam_flagstat_path), "Flagstat file doesn't exist after initial object creation");
ok(!(-e $alignment_result->bam_header_path), "Header file doesn't exist after initial object creation");
ok(!($alignment_result->_revivified_bam_file_path), "Bam file hasn't been revivified-created during initial object creation");

my $bam_file = $alignment_result->get_bam_file;
ok($bam_file, 'Bam file got created');

my $cmp = Genome::Model::Tools::Sam::Compare->execute(
    file1 => $bam_file,
    file2 => File::Spec->join($test_data_dir, 'alignment_result.bam'),
);
ok($cmp->result, 'Per-lane bam as expected');

ok(-e $alignment_result->bam_flagstat_path, 'Flagstat file exists');
ok(-e $alignment_result->bam_header_path, 'Header file exists');

$alignment_result->_revivified_bam_file_path(undef);
ok($alignment_result->get_bam_file, 'Subsequent revivifications work correctly');

done_testing;
