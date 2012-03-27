package CGI::Push;

# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.

# You can run this file through either pod2man or pod2html to produce pretty
# documentation in manual or html file format (these utilities are part of the
# Perl 5 distribution).

# Copyright 1995-2000, Lincoln D. Stein.  All rights reserved.
# It may be used and modified freely, but I do request that this copyright
# notice remain attached to the file.  You may modify this module as you 
# wish, but if you redistribute a modified version, please attach a note
# listing the modifications you have made.

# The most recent version and complete docs are available at:
#   http://stein.cshl.org/WWW/software/CGI/

$CGI::Push::VERSION='1.04';
use CGI;
use CGI::Util 'rearrange';
@ISA = ('CGI');

$CGI::DefaultClass = 'CGI::Push';
$CGI::Push::AutoloadClass = 'CGI';

# add do_push() and push_delay() to exported tags
push(@{$CGI::EXPORT_TAGS{':standard'}},'do_push','push_delay');

sub do_push {
    my ($self,@p) = CGI::self_or_default(@_);

    # unbuffer output
    $| = 1;
    srand;
    my ($random) = sprintf("%08.0f",rand()*1E8);
    my ($boundary) = "----=_NeXtPaRt$random";

    my (@header);
    my ($type,$callback,$delay,$last_page,$cookie,$target,$expires,$nph,@other) = rearrange([TYPE,NEXT_PAGE,DELAY,LAST_PAGE,[COOKIE,COOKIES],TARGET,EXPIRES,NPH],@p);
    $type = 'text/html' unless $type;
    $callback = \&simple_counter unless $callback && ref($callback) eq 'CODE';
    $delay = 1 unless defined($delay);
    $self->push_delay($delay);
    $nph = 1 unless defined($nph);

    my(@o);
    foreach (@other) { push(@o,split("=")); }
    push(@o,'-Target'=>$target) if defined($target);
    push(@o,'-Cookie'=>$cookie) if defined($cookie);
    push(@o,'-Type'=>"multipart/x-mixed-replace;boundary=\"$boundary\"");
    push(@o,'-Server'=>"CGI.pm Push Module") if $nph;
    push(@o,'-Status'=>'200 OK');
    push(@o,'-nph'=>1) if $nph;
    print $self->header(@o);

    $boundary = "$CGI::CRLF--$boundary";

    print "WARNING: YOUR BROWSER DOESN'T SUPPORT THIS SERVER-PUSH TECHNOLOGY.${boundary}$CGI::CRLF";

    my (@contents) = &$callback($self,++$COUNTER);

    # now we enter a little loop
    while (1) {
        print "Content-type: ${type}$CGI::CRLF$CGI::CRLF" unless $type =~ /^dynamic|heterogeneous$/i;
        print @contents;
        @contents = &$callback($self,++$COUNTER);
        if ((@contents) && defined($contents[0])) {
            print "${boundary}$CGI::CRLF";
            do_sleep($self->push_delay()) if $self->push_delay();
        } else {
            if ($last_page && ref($last_page) eq 'CODE') {
                print "${boundary}$CGI::CRLF";
                do_sleep($self->push_delay()) if $self->push_delay();
                print "Content-type: ${type}$CGI::CRLF$CGI::CRLF" unless $type =~ /^dynamic|heterogeneous$/i;
                print  &$last_page($self,$COUNTER);
            }
            print "${boundary}--$CGI::CRLF";
            last;
        }
    }
    print "WARNING: YOUR BROWSER DOESN'T SUPPORT THIS SERVER-PUSH TECHNOLOGY.$CGI::CRLF";
}

sub simple_counter {
    my ($self,$count) = @_;
    return $self->start_html("CGI::Push Default Counter"),
           $self->h1("CGI::Push Default Counter"),
           "This page has been updated ",$self->strong($count)," times.",
           $self->hr(),
           $self->a({'-href'=>'http://www.genome.wi.mit.edu/ftp/pub/software/WWW/cgi_docs.html'},'CGI.pm home page'),
           $self->end_html;
}

sub do_sleep {
    my $delay = shift;
    if ( ($delay >= 1) && ($delay!~/\./) ){
        sleep($delay);
    } else {
        select(undef,undef,undef,$delay);
    }
}

sub push_delay {
    my ($self,$delay) = CGI::self_or_default(@_);
    return defined($delay) ? $self->{'.delay'} = 
        $delay : $self->{'.delay'};
}

1;

