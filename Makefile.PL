use ExtUtils::MakeMaker;
#
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
#
# If any modules outside of the core perl distribution are required,
# these should be included as an item, for example,
#
#   'PREREQ_PM' => { MOD1 => 1, MOD2 => 5 },
#
# in WriteMakefile below. This will require the modules 
# MOD1 and MOD2 to be installed, with minimal versions 1 and 2,
# respectively. If the version number is 0, any version is sufficient.
#
# As well, if you wish to force a minimal perl version to run the
# script, insert a line, for example,
#
#   BEGIN {require 5.004}
#
# below.

WriteMakefile(
    'NAME'	=> 'cpantest',
    'VERSION_FROM' => 'cpantest', # finds $VERSION
    'dist'  => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    'EXE_FILES' => [ 'cpantest' ], # scripts to install
);

