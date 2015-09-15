package Genome::Model::Event::Build::ReferenceAlignment::MergeAlignments;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::MergeAlignments {
    is => ['Genome::Model::Event'],
};

sub bsub_rusage {
    return Genome::Config::get('lsf_resource_merged_alignments');
}

sub shortcut {
    my $self = shift;

    #try to get using the lock in order to wait here in shortcut if another process is creating this alignment result
    my $alignment = $self->build->merged_alignment_result_with_lock;
    unless($alignment) {
        $self->debug_message('No existing alignment found.');
        return;
    }

    $self->_link_build_to_merged_alignment($alignment);
    $self->debug_message('Using existing alignment ' . $alignment->__display_name__);
    return 1;
}


sub execute {
    my $self = shift;

    my $alignment = $self->build->generate_merged_alignment_result;
    unless($alignment) {
        $self->error_message('Failed to generate merged alignment.');
        die $self->error_message;
    }

    $self->_link_build_to_merged_alignment($alignment);
    $self->debug_message('Generated merged alignment');
    return 1;
}

sub _link_build_to_merged_alignment {
    my $self = shift;
    my $alignment = shift;

    my $link = $alignment->add_user(user => $self->build, label => 'uses');
    if ($link) {
        $self->debug_message("Linked alignment " . $alignment->id . " to the build");
    }
    else {
        $self->error_message(
            "Failed to link the build to the alignment " 
            . $alignment->__display_name__ 
            . "!"
        );
        die $self->error_message;
    }

    Genome::Sys->create_symlink($alignment->output_dir, $self->build->accumulated_alignments_directory);

    return 1;
}

1;
 
