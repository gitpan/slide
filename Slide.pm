package App::Slide;

use 5.008003;
use strict;
use warnings;

use File::Spec::Functions qw[rel2abs];
use Pod::POM;
use Template;
use Config::General;
use Carp;
use ExtUtils::Command qw( mkpath cp );

=head1 NAME

App::Slide - Perl extension for preparing slides from POD files, using the Template Toolkit.

=head1 VERSION

Version 0.92

=cut

our $VERSION = '0.92';

=head1 SYNOPSIS

    use App::Slide;
    App::Slide->new(
        pod_file     => 'foo.pod',
        slide_dir    => 'foo/slides',
        template_dir => 'prj/tmpl',
    )->generate();

or, from the command line,

    slide foo.pod foo/slides prj/tmpl

=head1 DESCRIPTION

Each =head1 becomes a slide.

NOT IMPLEMENTED: A '=for continue Junk' introduces a new slide,
with the same title as the current one. The 'Junk' text needs to
be there, else Pod::POM won't see it.

The slide identified by '=head1 conf' may contain configuration
values, to be used in the template files as 'conf.foo'.

Check $self->error() after invoking constructor: if empty string,
no errors occurred, else error message.

Template files must have the extension F<.tt>.

Special slides: F<intro> and F<toc>, the introduction and table of
contents, respectively.

All slides are given three digit numerical IDs, starting at
F<000.html>.

Most of the display formatting is accomplished by the template
files.

The entry page in F<index.html>, with template F<index.tt>.  The
page following that is F<toc.html>, with template F<toc.tt>.

The slides template will know about the following values:

    title
    prev
    next
    slide

If you want to use a F<.css> file (for example), you must place it
yourself in the appropriate directory, probably the F<slide_dir>
one.

=head1 TEMPLATE FILES

The template dir must contain the following files:

    main.tt
    index.tt
    slide.tt
    toc.tt

=head1 METHODS

=head2 new( [%args] )

Returns a reference to a newly constructed C<App::Slide> object,
or undef if one of the required args is missing or if there is some
other problem.

=over 4

=item * template_dir

Directory where the templates are found

=item * slide_dir

Target directory for the slides

=item * pod_file

Source file with the POD slides

=back

If any of these three parms haven't been passed, or the constructor
fails for some other reason, it returns undef.

=begin maint

Members

errors
parser
pom
slide_dir
tt

=end maint

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless {
        errors => [],
    }, $class;

    for ( qw( template_dir slide_dir pod_file ) ) {
        if ( defined $args{$_} ) {
            $self->{$_} = delete $args{$_};
        } else {
            $self->_error( "$_ not set." );
        }
    }
    $self->_error( "Unknown parm $_" ) for sort keys %args;

    if ( !-r $self->{pod_file} ) {
        $self->_error( "Can't read '$self->{pod_file}'" );
    }

    if ( !-d $self->{template_dir} ) {
        $self->_error( "$self->{template_dir} is not a directory" );
    }

    $self->{slide_dir} = rel2abs($self->{slide_dir});

    return $self if $self->errors;

    $self->{parser} = Pod::POM->new();
    $self->{pom} = $self->{parser}->parse_file($self->{pod_file}) || do {
        $self->_error( $self->{parser}->error() );
        return $self;
    };
    $self->{tt} = Template->new(
        INCLUDE_PATH => $args{template_dir},
        PROCESS      => $self->_template_file( 'main.tt' ),
        RELATIVE     => 1,
    ) or do {
        $self->_error( $self->{tt}->error() );
    };

    return $self;
}

sub _error {
    my $self = shift;

    push( @{$self->{errors}}, @_ );
}

=head2 errors()

Returns the error list.

=cut

sub errors {
    my $self = shift;

    return @{$self->{errors}};
}

=head2 generate()

Generates the output pages in the appropriate directory.

Returns the number of numbered slides generated.  This excludes the
index and TOC.

=cut

sub generate {
    my $self = shift;

    $self->_restructure();
    $self->_write_toc();
    $self->_write_intro();
    my $nslides = $self->_write_slides();

    if ( my $css = $self->{conf}->{css} ) {
        local @ARGV = ( "$self->{template_dir}/$css", $self->{slide_dir} );
        cp;
    }

    return $nslides;
}


sub _restructure {
    my $self = shift;

    for my $slide ($self->{pom}->head1()) {
        if ( $slide->title->present eq 'conf' ) {
            $self->config_slides($slide->content());
        } else {
            push @{$self->{slides}}, {
                title     => $slide->title,
                pom       => $slide,
                continued => 0,
            };
        } # if
    } # for slides
}

=head2 config_slides( $content )

Takes the config section of a slide file and parses it out, using
L<Config::General>.

=cut

sub config_slides {
    my $self = shift;
    my $content = shift;

    $self->{conf} = {
        Config::General->new(
            -String         => $content,
            -LowerCaseNames => 1,
        )->getall
    };
}

sub _write_toc {
    my $self = shift;
    my @slides = ( [ index => 'Introduction' ] );
    for my $num ( 1 .. $self->_last_slide_number ) {
        my $slide = $self->{slides}->[$num-1];
        push @slides, [ sprintf('%03d', $num), $slide->{title} ];
    }
    $self->_write_file(
        'toc.tt',
        'toc.html',
        {
              slides => \@slides,
              title  => 'Table of Contents',
              prev   => 'index',
              'next' => '001',
        }
    );
}

sub _write_intro {
    my $self = shift;

    $self->_write_file( 'index.tt', 'index.html', {
        title   => 'Introduction',
        'next'  => 'toc',
    } );
}

sub _last_slide_number { scalar @{$_[0]->{slides}} }

sub _write_slides {
    my $self = shift;

    for my $i ( 1 .. $self->_last_slide_number() ) {
        my $slide = $self->{slides}[$i-1];
        my $prev = $i == 1 ? 'toc' : sprintf('%03d', $i-1);
        my $curr = sprintf '%03d', $i;
        my $next = $i == $self->_last_slide_number()
            ? undef
            : sprintf '%03d', $i + 1;
        $self->_write_file(
            'slide.tt',
            "$curr.html",
            {
                title     => $slide->{title},
                continued => $slide->{continued},
                prev      => $prev,
                'next'    => $next,
                slide     => $slide->{pom},
            }
        );
    } # for slide index

    return $self->_last_slide_number;
}


=begin maint

=head2 $self->_write_file($template, $out_file_name, $vars)

Will write to I<$out_file_name> in the C<< $self->{slide_dir} >>
directory, applying the I<$template.tt> template file, and using
C<< $self->{conf} >> values as well as any other key/values found
in I<%$vars>.

=end maint

=cut

sub _write_file {
    my $self = shift;
    my $template = shift;
    my $out_file_name = shift;
    my $vars = shift;

    my $dir = $self->{slide_dir};

    CREATE_DIR: {
        local @ARGV = $dir;
        mkpath;
    }

    my $parms = { %$vars, conf => $self->{conf} };
    my $tt = $self->{tt};
    if ($template eq 'slide') {
        for my $node ($parms->{slide}->content()) {
        }
    }

    my $filename = $self->_template_file( $template );
    $tt->process( $filename, $parms, "$dir/$out_file_name" )
        or $self->_error( $tt->error() );
}

sub _template_file {
    my $self = shift;
    my $basename = shift;

    return "$self->{template_dir}/$basename";
}

1;
