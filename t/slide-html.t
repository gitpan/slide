#!perl -w

use Test::More tests => 83;
use Test::Pod;

BEGIN {
    use_ok( 'App::Slide' );
}

my @files = <example/*.pod>;
is( @files, 3, "Three examples" );

my $template_dir = "templates/default";
ok( -d $template_dir );

for my $pod_file ( @files ) {
    my $slide_dir = $pod_file;
    $slide_dir =~ s/\.pod$// or die "Couldn't drop the .pod";
    my $set =
        App::Slide->new(
            pod_file     => $pod_file,
            slide_dir    => $slide_dir,
            template_dir => $template_dir,
        );
    isa_ok( $set, 'App::Slide' );
    is( $set->errors, 0, "No errors" );
    diag( $_ ) for $set->errors;

    my $nslides = $set->generate;
    cmp_ok( $nslides, '>', 0, "Non-zero slide counts" );
    is( $set->errors, 0, "No errors" );
    diag( $_ ) for $set->errors;

    my @html = glob( "$slide_dir/*.html" );
    is( @html, $nslides+2, "Includes 2 HTML files for index and TOC" );

    for my $html_file ( @html ) {
        pod_file_ok( $html_file );
    }
}
