use strict;
use warnings;

use above 'Genome';
use Test::More;
use Test::Deep;
use File::Basename qw(basename);
use Data::Dump qw(pp);
use Genome::Ptero::Utils qw(
    test_data_directory
    get_test_inputs
    get_test_outputs
    get_test_xml_filename
);

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use_ok('Genome::WorkflowBuilder::DAG');

Genome::Config::set_env('workflow_builder_backend', 'inline');
run_tests($ARGV[0] || '*');
done_testing();

sub run_tests {
    my $test_pattern = shift;
    my @test_directories = (glob test_data_directory($test_pattern));
    note(sprintf("Found test_pattern: %s so the following tests will run %s",
        $test_pattern, pp(@test_directories)));

    for my $test_directory (@test_directories) {
        my $test_name = basename($test_directory);

        subtest $test_name, sub {
            my $workflow = Genome::WorkflowBuilder::DAG->from_xml_filename(
                get_test_xml_filename($test_name));
            ok($workflow, "Constructed workflow from xml file.");

            my $outputs = $workflow->execute(inputs => get_test_inputs($test_name));

            my $expected = get_test_outputs($test_name);
            cmp_deeply($outputs, get_test_outputs($test_name),
                sprintf("Workflow: %s produced expected outputs", $test_name),
            ) || note(sprintf("Got: %s\nExpected: %s",
                    pp($outputs), pp($expected)));
        };
    }
}


1;
