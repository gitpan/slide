package App::Slide;

=head1 NAME

App::Slide - Support functions for the slide program

=head1 VERSION

Version 0.01

    $Header: /home/cvs/slide/Slide.pm,v 1.1.1.1 2004/01/08 03:51:31 andy Exp $

=cut

our $VERSION = 0.01;

=head1 SYNOPSIS

Helper functions for F<slide>.

=cut

use File::Spec::Functions qw[splitpath rel2abs];
use Pod::POM;
use Template;
use Config::General;

sub new {
    my ($class, %args) = @_;

    my $self = $class->_init( %args );
}

sub _init {
    my ($class, %args) = @_;
    return bless {
	parser    => Pod::POM->new,
	template  => Template->new(
	    INCLUDE_PATH => $args{template_dir},
	    PROCESS      => 'main',
	),
	%args,
	slide_dir => rel2abs( $args{slide_dir} ),
    }, $class;
}


sub generate {
    my ($self) = @_;
    $self->{pom} =
	$self->{parser}->parse_file( $self->{pod_file} )
		|| die $self->{parser}->error . "\n";

    $self->restructure;
    $self->write_toc;
    $self->write_intro;
    
    $self->write_slide( $_ => $self->{slides}->[$_] )
	foreach 0 .. $#{$self->{slides}};
}

sub restructure {
    my $self = shift;

    foreach my $slide ( $self->{pom}->head1 ) {
        if ( $slide->title->present eq 'conf' ) {
            $self->conf_slides( $slide->content );
        } else {
            my @slides;
            my $slide_content = $slide->content;

            foreach my $chunk ( split /=for\s+continue.+\n/, $slide->content ) {
                push @slides, $slides[-1] . $chunk;
            }

            push @{$self->{slides}}, map {
                my $pom = $self->{parser}->parse_text( $slides[$_] );
                {
                    title     => $slide->title,
                    pom       => $pom,
                    continued => $_ == $#slides ? 0 : 1,
                };
            } 0 .. $#slides;
        }
    }
}

sub conf_slides {
    my ($self, $content) = @_;
    $self->{conf} = {
	Config::General->new(
	    -String         => $content,
	    -LowerCaseNames => 1,
	)->getall
    };
}

sub write_toc {
    my $self = shift;
    my @slides = ( [ index => 'Introduction' ] );
    foreach my $num ( 0 .. $#{$self->{slides}} ) {
	my $slide = $self->{slides}->[$num];
	push @slides, [ $num => $slide->{title} ];
    }
    $self->_write_file(
	toc    => 'toc.html',
	slides => \@slides,
	title  => 'Table of Contents',
	prev   => 'index',
	'next'   => 0,
    );
}

sub write_intro {
    my $self = shift;
    
    $self->_write_file(
	index => 'index.html',
	title => 'Introduction',
	'next'  => 'toc',
    );
}

sub write_slide {
    my ($self, $num, $slide) = @_;
    my $prev = ( $num == 0                   ? 'toc'   : $num - 1 );
    my $next = ( $num == $#{$self->{slides}} ? 'index' : $num + 1 );
    
    $self->_write_file(
	slide     => "$num.html",
	title     => $slide->{title},
	continued => $slide->{continued},
	prev      => $prev,
	'next'    => $next,
	slide     => $slide->{pom},
	slod      => $self,
    );
}

sub _write_file {
    my ($self, $template, $ofile, %vars) = @_;
    
    mkdir $self->{slide_dir} unless -e $self->{slide_dir};

    $self->{template}->process(
	$template,
	{ %vars, conf => $self->{conf} },
	join '/', $self->{slide_dir}, $ofile,
    ) || die $self->{template}->error . "\n";
}

sub usage {
    my $program = (splitpath( $0 ))[-1];
    die "Usage: $program slidefile.slod slide_dir \n";
}


1;
