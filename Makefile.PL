use ExtUtils::MakeMaker qw( WriteMakefile prompt );
use strict;


my $parms = {
    NAME	    => 'App::Slide',
    DISTNAME	    => 'slide',
    VERSION_FROM    => 'Slide.pm', # finds $VERSION
    AUTHOR	    => 'Andy Lester <andy@petdance.com>',
    PREREQ_PM	    => { # e.g., Module::Name => 1.1
			'Template'	    => 0,
			'Config::General'   => 0,
			'Pod::POM'          => 0,
			'Getopt::Long'	    => 0,
			'Pod::Usage'	    => 0,
			},
    EXE_FILES	    => [ 'slide' ],
    clean	    => { FILES => 'slide-*' },
};


WriteMakefile( %$parms );
