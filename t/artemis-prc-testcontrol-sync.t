#! /usr/bin/env perl

use strict;
use warnings;

use Test::MockModule;
use YAML::Syck;


use Artemis::Model 'model';
use Artemis::Config;
use Artemis::Schema::TestTools;

use Test::More;
use Test::Deep;
use Test::MockModule;

use File::Temp;


# (XXX) need to find a way to include log4perl into tests to make sure no
# errors reported through this framework are missed
my $string = "
log4perl.rootLogger           = FATAL, root
log4perl.appender.root        = Log::Log4perl::Appender::Screen
log4perl.appender.root.stderr = 1
log4perl.appender.root.layout = SimpleLayout";
Log::Log4perl->init(\$string);


BEGIN { use_ok('Artemis::PRC::Testcontrol'); }

my $testcontrol = Artemis::PRC::Testcontrol->new();
isa_ok($testcontrol, 'Artemis::PRC::Testcontrol', 'New object');


my $output_dir = File::Temp::tempdir( CLEANUP => 1 );
$testcontrol->cfg({test_run => 1234,
                   mcp_server => 'localhost',
                   report_server => 'localhost',
                   hostname => 'localhost',
                   reboot_counter => 0,
                   max_reboot => 0,
                   guest_number => 0,
                   syncfile => '/dev/null', # just to check if set correctly in ENV
                   paths => {output_dir => $output_dir},
                   testprogram_list => [{ program => '/bin/true',
                                          runtime => 72000,
                                          timeout_testprogram => 129600,
                                          parameters => ['--tests', '-v'],
                                        }],
                  });
is($testcontrol->cfg->{test_run}, 1234, 'Setting attributes');
my $retval;

# test wait_for_sync, only if told to
SKIP:
{
        skip 'Can not test syncing without peer',1 unless $ENV{ARTEMIS_SYNC_TESTING};
        $testcontrol->cfg(Artemis::Config::subconfig);
        $retval = $testcontrol->wait_for_sync(['wotan']);
        is($retval, 0, 'Synced');
}



# Mock actual execution of testprogram
my @execute_options;
my $mock_testcontrol = Test::MockModule->new('Artemis::PRC::Testcontrol');
$mock_testcontrol->mock('testprogram_execute',sub{(undef, @execute_options) = @_;return 0});
$mock_testcontrol->mock('mcp_inform',sub{return 0;});
$retval = $testcontrol->testprogram_execute();
is($retval, 0, 'Mocking testprogram_execute');


$retval = $testcontrol->control_testprogram();
is($retval, 0, 'Running control_testprogram');
is_deeply(\@execute_options, ['/bin/true', 129600, "$output_dir/1234/test/", ('--tests','-v')], 'Calling testprogram_execute');

superhashof(\%ENV, { ARTEMIS_TESTRUN => 1234,
                     ARTEMIS_SERVER => 'localhost',
                     ARTEMIS_HOSTNAME => 'localhost',
                     ARTEMIS_REBOOT_COUNTER => 0,
                     ARTEMIS_MAX_REBOOT => 0,
                     ARTEMIS_GUEST_NUMBER => 0,
                     ARTEMIS_OUTPUT_PATH => $output_dir."/1234/test",
                     ARTEMIS_SYNC_FILE => '/dev/null'},
            'Setting environment');

done_testing();
