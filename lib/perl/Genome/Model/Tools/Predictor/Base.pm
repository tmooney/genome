package Genome::Model::Tools::Predictor::Base;

use strict;
use warnings;
use Genome;
use lib '/gsc/scripts/opt/bacterial-bioperl';
use File::Temp 'tempdir';

class Genome::Model::Tools::Predictor::Base {
    is => 'Command::V2',
    is_abstract => 1,
    attributes_have => [
        # TODO I wouldn't expect that someone defining a new predictor would understand
        # what this is about. Should probably be removed.
        predictor_specific => {
            is => 'Boolean',
            default_value => 0,
        },
    ],
    has => [
        output_directory => {
            is => 'DirectoryPath',
            is_input => 1,
            predictor_specific => 1,
            doc => 'Directory in which raw and parsed output from this predictor should go',
        },
        input_fasta_file => {
            is => 'FilePath',
            is_input => 1,
            doc => 'File containing assembly sequence (typically fasta) to be used as input to predictor',
        },
        version => {
            is => 'Text',
            predictor_specific => 1,
            is_input => 1,
            doc => 'Version of predictor',
        },
        parameters => {
            is => 'Text',
            predictor_specific => 1,
            is_input => 1,
            doc => 'Parameters to be passed to the predictor',
        },
        gram_stain => {
            is => 'Text',
            is_input => 1,
            is_optional => 1,
            valid_values => ['positive', 'negative'],
            doc => 'Gram stain of species on which prediction is to be run, if relevant',
        },
        dump_predictions_to_file => {
            is => 'Boolean',
            is_input => 1,
            default_value => 0,
            doc => 'If set, predictions are dumped to a file in the output directory',
        },
        unfiltered_bio_seq_features => {
            is => 'ARRAY',
            is_output => 1,
            is_optional => 1,
            is_many => 1,
            doc => 'Bio::SeqFeatures produced by tool prior to filtering',
        },
        bio_seq_features => {
            is => 'ARRAY',
            is_many => 1,
            is_output => 1,
            is_optional => 1,
            doc => 'Bioperl objects produced after raw predictor output is parsed',
        },
        ace_file => {
            is => 'FilePath',
            is_output => 1,
            is_optional => 1,
            doc => 'Ace file generated by predictor',
        },
    ],
};

# Return true if the input fasta needs to be split into smaller portions
# in order for prediction to successfully complete, false otherwise.
sub requires_chunking {
    die "Override in subclasses of " . __PACKAGE__;
}

# Should contain all code necessary to run the predictor tool.
sub run_predictor {
    die "Override in subclasses of " . __PACKAGE__;
}

# Should contain all code necessary to parse the raw output of the predictor.
sub parse_output {
    die "Override in subclasses of " . __PACKAGE__;
}

# Any filtering logic should go here.
sub filter_results {
    die "Override in subclasses of " . __PACKAGE__;
}

# Should return a path to the file that should be executed using the current value of version.
sub tool_path_for_version {
    die "Override in subclasses of " . __PACKAGE__;
}
    
# Should create an ace file from the raw output of the predictor
sub create_ace_file {
    die "Override in subclasses of " . __PACKAGE__;
}

# Can be overridden if custom behavior is necessary, but this default behavior should be
# sufficient in most cases. 
sub prepare_output_directory {
    my $self = shift;

    unless (-d $self->output_directory) {
        Genome::Sys->create_directory($self->output_directory);
    }

    # If the predictor requires chunking (and hence will be run in parallel), each output directory
    # needs to be unique to each instance.
    if ($self->requires_chunking) {
        my $output_directory = tempdir(
            DIR => $self->output_directory,
            CLEANUP => 0,
        );
        chmod 0770, $output_directory;
        $self->output_directory($output_directory);
    }

    return 1;
}

# Can be overrriden in subclasses for custom behavior if that's necessary. This method is responsible for taking the filtered bio seq feature outputs and dumping them to a file.
sub dump_to_file {
    my $self = shift;
    my @features = $self->bio_seq_features;

    my $path = $self->dump_output_path;
    my $fh = Genome::Sys->open_file_for_writing($path);

    require Data::Dumper;
    $fh->print(Data::Dumper::Dumper(\@features) . "\n");
    $fh->close;

    return 1;
}

# Returns the absolute path to the raw output file using the current value of output_directory.
sub raw_output_path {
    die "Override in subclasses of " . __PACKAGE__;
}

# Override if necessary in subclasses if stderr and whatnot should be captured
sub debug_output_path {
    die "Override in subclasses of " . __PACKAGE__;
}

# Override in order for predictions to be dumped to a file
sub dump_output_path {
    die "Override in subclasses of " . __PACKAGE__;
}

# Path to ace file generated from predictions
sub ace_file_path {
    die "Override in subclasses of " . __PACKAGE__;
}

#########################################################
# Nothing below here should be overridden in subclasses #
#########################################################

# Executes the prediction "workflow"
sub execute {
    my $self = shift;

    unless ($self->prepare_output_directory) {
        die "Could not prepare output directory for predictions!";
    }

    unless ($self->run_predictor) {
        die "Could not run predictor!";
    }

    unless ($self->parse_output) {
        die "Could not parse prediction output!";
    }

    unless ($self->filter_results) {
        die "Could not filter prediction results!";
    }
    
    $self->ace_file($self->ace_file_path);
    unless ($self->create_ace_file) {
        die "Could not create ace file from predictions!";
    }

    if ($self->dump_predictions_to_file) {
        unless ($self->dump_to_file) {
            die "Could not dump predictions to file!";
        }
    }

    return 1;
}

# Converts a predictor class name to a shorter name (eg, Genome::Model::Tools::Predictor::Interproscan
# to interproscan)
sub class_to_short_name {
    my $class = shift;
    $class = ref($class) if ref($class);

    my $base = __PACKAGE__;
    $base =~ s/Base//;

    my $short_class = $class;
    $short_class =~ s/$base//;
    my $short_name = Genome::Utility::Text::camel_case_to_string($short_class, '_');
    return $short_name;
}

1;

