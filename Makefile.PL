use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'RB3',
    VERSION           => '1.27',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       => 'RB3 configuration management tools',
       AUTHOR         => 'Ray Miller') : ()),
    EXE_FILES         => [ qw( bin/rb3 ) ],
);
