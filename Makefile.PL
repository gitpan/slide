#!perl -w


use ExtUtils::MakeMaker;
use strict;

my $parms = {
    NAME            => 'App::Slide',
    DISTNAME        => 'slide',
    VERSION_FROM    => 'Slide.pm',
    AUTHOR          => 'Andy Lester <andy@petdance.com>',
    PREREQ_PM       => {
        'Config::General'   => 0,
        'ExtUtils::Command' => 0,
        'Getopt::Long'      => 0,
        'Pod::POM'          => 0,
        'Pod::Usage'        => 0,
        'Template'          => 0,
        'Test::Pod'         => 0,
    },
    EXE_FILES       => [ 'slide' ],
    clean           => { FILES => 'slide-*' },
};


WriteMakefile( %$parms );
