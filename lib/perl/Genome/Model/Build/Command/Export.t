#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test qw(compare_dirs);
use Genome::Test::Factory::Model::SingleSampleGenotype;
use Genome::Test::Factory::Build;
use Genome::Test::Factory::DiskAllocation;
use Genome::Test::Factory::InstrumentData::AlignmentResult;
use Sub::Override;

my $pkg = 'Genome::Model::Build::Command::Export';
use_ok($pkg);

subtest 'symlink to internal file' => sub {
    my $build_data_directory = Genome::Sys->create_temp_directory;
    my $build = _create_build($build_data_directory);

    my $symlink_target = File::Spec->join($build_data_directory, 'file');
    Genome::Sys->write_file($symlink_target, 'A file');
    Genome::Sys->create_symlink($symlink_target, File::Spec->join($build_data_directory, 'symlink_pointer'));

    _run_test($build, $build_data_directory, $build_data_directory);
};

subtest 'symlink to external file' => sub {
    my $build_data_directory = Genome::Sys->create_temp_directory;
    my $build = _create_build($build_data_directory);

    my $symlink_target = Genome::Sys->create_temp_file_path;
    Genome::Sys->write_file($symlink_target, 'A file');
    Genome::Sys->create_symlink($symlink_target, File::Spec->join($build_data_directory, 'symlink_pointer'));

    my $expected_export_directory = Genome::Sys->create_temp_directory;
    Genome::Sys->copy_file($symlink_target, File::Spec->join($expected_export_directory, 'symlink_pointer'));

    _run_test($build, $build_data_directory, $expected_export_directory);
};

subtest 'symlink to external directory' => sub {
    my $build_data_directory = Genome::Sys->create_temp_directory;
    my $build = _create_build($build_data_directory);

    my $symlink_target = Genome::Sys->create_temp_directory;
    my $file = File::Spec->join($symlink_target, 'file');
    Genome::Sys->write_file($file, 'A file in a directory');
    Genome::Sys->create_symlink($symlink_target, File::Spec->join($build_data_directory, 'symlink_pointer'));

    my $expected_export_directory = Genome::Sys->create_temp_directory;
    Genome::Sys->rsync_directory(source_directory => $symlink_target, target_directory => File::Spec->join($expected_export_directory, 'symlink_pointer'));

    _run_test($build, $build_data_directory, $expected_export_directory);
};

subtest 'symlink to active allocation' => sub {
    my $build_data_directory = Genome::Sys->create_temp_directory;
    my $build = _create_build($build_data_directory);

    my $symlinked_allocation_data_dir = Genome::Sys->create_temp_directory;
    my $file = File::Spec->join($symlinked_allocation_data_dir, 'file');
    Genome::Sys->write_file($file, 'A file in an allocation');
    my $symlinked_allocation = Genome::Test::Factory::DiskAllocation->generate_obj(
        owner => $build,
        allocation_path => $symlinked_allocation_data_dir
    );
    Genome::Sys->create_symlink($symlinked_allocation_data_dir, File::Spec->join($build_data_directory, 'symlink_pointer'));

    my $expected_export_directory = Genome::Sys->create_temp_directory;
    Genome::Sys->create_directory(File::Spec->join($expected_export_directory, 'symlink_pointer'));
    Genome::Sys->copy_file($file, File::Spec->join($expected_export_directory, 'symlink_pointer', 'file'));

    _run_test($build, $build_data_directory, $expected_export_directory);
};

subtest 'symlink to active allocation with nested active allocation' => sub {
    my $build_data_directory = Genome::Sys->create_temp_directory;
    my $build = _create_build($build_data_directory);

    my $symlinked_allocation_data_dir = Genome::Sys->create_temp_directory;
    my $symlinked_allocation = Genome::Test::Factory::DiskAllocation->generate_obj(owner => $build, allocation_path => $symlinked_allocation_data_dir);
    Genome::Sys->create_symlink($symlinked_allocation_data_dir, File::Spec->join($build_data_directory, 'symlink_pointer'));

    my $nested_symlinked_allocation_data_dir = Genome::Sys->create_temp_directory;
    my $file = File::Spec->join($nested_symlinked_allocation_data_dir, 'file');
    Genome::Sys->write_file($file, 'A file in an allocation');
    my $nested_symlinked_allocation = Genome::Test::Factory::DiskAllocation->generate_obj(
        owner => $build,
        allocation_path => $nested_symlinked_allocation_data_dir
    );
    Genome::Sys->create_symlink($nested_symlinked_allocation_data_dir, File::Spec->join($symlinked_allocation_data_dir, 'nested_symlink_pointer'));

    my $expected_export_directory = Genome::Sys->create_temp_directory;
    Genome::Sys->create_directory(File::Spec->join($expected_export_directory, 'symlink_pointer'));
    Genome::Sys->create_directory(File::Spec->join($expected_export_directory, 'symlink_pointer', 'nested_symlink_pointer'));
    Genome::Sys->copy_file($file, File::Spec->join($expected_export_directory, 'symlink_pointer', 'nested_symlink_pointer', 'file'));

    _run_test($build, $build_data_directory, $expected_export_directory);
};

subtest 'dangling symlink to nonexistent file' => sub {
    my $build_data_directory = Genome::Sys->create_temp_directory;
    my $build = _create_build($build_data_directory);

    my $symlink_target = Genome::Sys->create_temp_directory;
    my $file = File::Spec->join($symlink_target, 'file');
    Genome::Sys->create_symlink($file, File::Spec->join($build_data_directory, 'symlink_pointer'));
    unlink $file;

    my $expected_export_directory = Genome::Sys->create_temp_directory;
    my $replacement_file = File::Spec->join($expected_export_directory, 'symlink_pointer');
    Genome::Sys->write_file($replacement_file, sprintf("Symlink target (%s) does not exist.\n", $file));

    _run_test($build, $build_data_directory, $expected_export_directory);
};

subtest 'dangling symlink to purged allocation' => sub {
    my $build_data_directory = Genome::Sys->create_temp_directory;
    my $build = _create_build($build_data_directory);

    my $symlinked_allocation_data_dir = Genome::Sys->create_temp_directory;
    my $software_result = Genome::Test::Factory::InstrumentData::AlignmentResult->setup_object();
    my $symlinked_allocation = Genome::Test::Factory::DiskAllocation->generate_obj(
        owner => $software_result,
        allocation_path => $symlinked_allocation_data_dir,
        status => 'purged'
    );
    Genome::Sys->create_symlink($symlinked_allocation_data_dir, File::Spec->join($build_data_directory, 'symlink_pointer'));
    rmdir $symlinked_allocation_data_dir;

    my $expected_export_directory = Genome::Sys->create_temp_directory;
    my $replacement_file = File::Spec->join($expected_export_directory, 'symlink_pointer');
    my $text = sprintf("Allocation (%s) has been purged and its data cannot be recovered.\n", $symlinked_allocation->id);
    $text .= sprintf("This allocation belongs to software result (%s) of class (%s) with test name (%s).\n", $software_result->id, $software_result->class, $software_result->test_name);
    Genome::Sys->write_file($replacement_file, $text);

    _run_test($build, $build_data_directory, $expected_export_directory);
};

subtest 'dangling symlink to active allocation' => sub {
    my $build_data_directory = Genome::Sys->create_temp_directory;
    my $build = _create_build($build_data_directory);

    my $archived_allocation_data_dir = Genome::Sys->create_temp_directory;
    my $file = File::Spec->join($archived_allocation_data_dir, 'file');
    Genome::Sys->write_file($file, 'A file in an allocation');

    my $symlinked_allocation_data_dir = Genome::Sys->create_temp_directory;
    my $symlinked_allocation = Genome::Test::Factory::DiskAllocation->generate_obj(
        owner => $build,
        allocation_path => $symlinked_allocation_data_dir,
    );
    Genome::Sys->create_symlink($symlinked_allocation_data_dir, File::Spec->join($build_data_directory, 'symlink_pointer'));
    rmdir $symlinked_allocation_data_dir;

    my $expected_export_directory = Genome::Sys->create_temp_directory;
    Genome::Sys->create_directory(File::Spec->join($expected_export_directory, 'symlink_pointer'));
    Genome::Sys->copy_file($file, File::Spec->join($expected_export_directory, 'symlink_pointer', 'file'));

    use Genome::Disk::Allocation;
    my $override = Sub::Override->new(
        'Genome::Disk::Allocation::get_allocation_for_path',
        sub {
            my ($class, $path) = @_;
            return Genome::Disk::Allocation->get(allocation_path => $path);
        },
    );
    my $override2 = Sub::Override->new(
        'Genome::Disk::Allocation::absolute_path',
        sub {
            my $self = shift;
            if ($self->id eq $symlinked_allocation->id) {
                return $archived_allocation_data_dir;
            }
            else {
                return $self->allocation_path;
            }
        },
    );

    my $cmd = $pkg->create(
        build => $build,
        target_export_directory => Genome::Sys->create_temp_directory,
    );
    $cmd->execute;
    compare_dirs($cmd->export_directory, $expected_export_directory, 'Export directory as expected');
    $override->restore;
    $override2->restore;
};

sub _create_build {
    my $build_data_directory = shift;

    my $model = Genome::Test::Factory::Model::SingleSampleGenotype->setup_object();
    my $build = Genome::Test::Factory::Build->setup_object(
        model_id => $model->id,
        data_directory => $build_data_directory,
    );
    my $allocation = Genome::Test::Factory::DiskAllocation->generate_obj(
        owner => $build,
        allocation_path => $build_data_directory,
    );

    return $build;
}

sub _run_test {
    my $build = shift;
    my $build_data_directory = shift;
    my $expected_export_directory = shift;

    use Genome::Disk::Allocation;
    my $override = Sub::Override->new(
        'Genome::Disk::Allocation::get_allocation_for_path',
        sub {
            my ($class, $path) = @_;
            return Genome::Disk::Allocation->get(allocation_path => $path);
        },
    );
    my $override2 = Sub::Override->new(
        'Genome::Disk::Allocation::absolute_path',
        sub { my $self = shift; return $self->allocation_path; },
    );

    my $cmd = $pkg->create(
        build => $build,
        target_export_directory => Genome::Sys->create_temp_directory,
    );
    $cmd->execute;
    compare_dirs($cmd->export_directory, $expected_export_directory, 'Export directory as expected');
    $override->restore;
    $override2->restore;
}

done_testing;