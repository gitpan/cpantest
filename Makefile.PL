use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'          => 'cpantest',
    'VERSION_FROM'  => 'cpantest.PL',
    'EXE_FILES'     => [ 'cpantest' ],
    'clean'         => { FILES => 'cpantest' },
);

