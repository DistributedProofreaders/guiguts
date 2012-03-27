package CGI::Pretty;

# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.

# You can run this file through either pod2man or pod2html to produce pretty
# documentation in manual or html file format (these utilities are part of the
# Perl 5 distribution).

use strict;
use CGI ();

$CGI::Pretty::VERSION = '1.08';
$CGI::DefaultClass = __PACKAGE__;
$CGI::Pretty::AutoloadClass = 'CGI';
@CGI::Pretty::ISA = qw( CGI );

initialize_globals();

sub _prettyPrint {
    my $input = shift;
    return if !$$input;
    return if !$CGI::Pretty::LINEBREAK || !$CGI::Pretty::INDENT;

#    print STDERR "'", $$input, "'\n";

    foreach my $i ( @CGI::Pretty::AS_IS ) {
	if ( $$input =~ m{</$i>}si ) {
	    my ( $a, $b, $c ) = $$input =~ m{(.*)(<$i[\s/>].*?</$i>)(.*)}si;
	    next if !$b;
	    $a ||= "";
	    $c ||= "";

	    _prettyPrint( \$a ) if $a;
	    _prettyPrint( \$c ) if $c;
	    
	    $b ||= "";
	    $$input = "$a$b$c";
	    return;
	}
    }
    $$input =~ s/$CGI::Pretty::LINEBREAK/$CGI::Pretty::LINEBREAK$CGI::Pretty::INDENT/g;
}

sub comment {
    my($self,@p) = CGI::self_or_CGI(@_);

    my $s = "@p";
    $s =~ s/$CGI::Pretty::LINEBREAK/$CGI::Pretty::LINEBREAK$CGI::Pretty::INDENT/g if $CGI::Pretty::LINEBREAK; 
    
    return $self->SUPER::comment( "$CGI::Pretty::LINEBREAK$CGI::Pretty::INDENT$s$CGI::Pretty::LINEBREAK" ) . $CGI::Pretty::LINEBREAK;
}

sub _make_tag_func {
    my ($self,$tagname) = @_;

    # As Lincoln as noted, the last else clause is VERY hairy, and it
    # took me a while to figure out what I was trying to do.
    # What it does is look for tags that shouldn't be indented (e.g. PRE)
    # and makes sure that when we nest tags, those tags don't get
    # indented.
    # For an example, try print td( pre( "hello\nworld" ) );
    # If we didn't care about stuff like that, the code would be
    # MUCH simpler.  BTW: I won't claim to be a regular expression
    # guru, so if anybody wants to contribute something that would
    # be quicker, easier to read, etc, I would be more than
    # willing to put it in - Brian

    my $func = qq"
	sub $tagname {";

    $func .= q'
            shift if $_[0] && 
                    (ref($_[0]) &&
                     (substr(ref($_[0]),0,3) eq "CGI" ||
                    UNIVERSAL::isa($_[0],"CGI")));
	    my($attr) = "";
	    if (ref($_[0]) && ref($_[0]) eq "HASH") {
		my(@attr) = make_attributes(shift()||undef,1);
		$attr = " @attr" if @attr;
	    }';

    if ($tagname=~/start_(\w+)/i) {
	$func .= qq! 
            return "<\L$1\E\$attr>\$CGI::Pretty::LINEBREAK";} !;
    } elsif ($tagname=~/end_(\w+)/i) {
	$func .= qq! 
            return "<\L/$1\E>\$CGI::Pretty::LINEBREAK"; } !;
    } else {
	$func .= qq#
	    return ( \$CGI::XHTML ? "<\L$tagname\E\$attr />" : "<\L$tagname\E\$attr>" ) .
                   \$CGI::Pretty::LINEBREAK unless \@_;
	    my(\$tag,\$untag) = ("<\L$tagname\E\$attr>","</\L$tagname>\E");

            my \%ASIS = map { lc("\$_") => 1 } \@CGI::Pretty::AS_IS;
            my \@args;
            if ( \$CGI::Pretty::LINEBREAK || \$CGI::Pretty::INDENT ) {
   	      if(ref(\$_[0]) eq 'ARRAY') {
                 \@args = \@{\$_[0]}
              } else {
                  foreach (\@_) {
		      \$args[0] .= \$_;
                      \$args[0] .= \$CGI::Pretty::LINEBREAK if \$args[0] !~ /\$CGI::Pretty::LINEBREAK\$/ && 0;
                      chomp \$args[0] if exists \$ASIS{ "\L$tagname\E" };
                      
  	              \$args[0] .= \$" if \$args[0] !~ /\$CGI::Pretty::LINEBREAK\$/ && 1;
		  }
                  chop \$args[0];
	      }
            }
            else {
              \@args = ref(\$_[0]) eq 'ARRAY' ? \@{\$_[0]} : "\@_";
            }

            my \@result;
            if ( exists \$ASIS{ "\L$tagname\E" } ) {
		\@result = map { "\$tag\$_\$untag\$CGI::Pretty::LINEBREAK" } 
		 \@args;
	    }
	    else {
		\@result = map { 
		    chomp; 
		    my \$tmp = \$_;
		    CGI::Pretty::_prettyPrint( \\\$tmp );
                    \$tag . \$CGI::Pretty::LINEBREAK .
                    \$CGI::Pretty::INDENT . \$tmp . \$CGI::Pretty::LINEBREAK . 
                    \$untag . \$CGI::Pretty::LINEBREAK
                } \@args;
	    }
	    local \$" = "" if \$CGI::Pretty::LINEBREAK || \$CGI::Pretty::INDENT;
	    return "\@result";
	}#;
    }    

    return $func;
}

sub start_html {
    return CGI::start_html( @_ ) . $CGI::Pretty::LINEBREAK;
}

sub end_html {
    return CGI::end_html( @_ ) . $CGI::Pretty::LINEBREAK;
}

sub new {
    my $class = shift;
    my $this = $class->SUPER::new( @_ );

    if ($CGI::MOD_PERL) {
        my $r = Apache->request;
        if ($CGI::MOD_PERL == 1) {
            $r->register_cleanup(\&CGI::Pretty::_reset_globals);
        }
        else {
            $r->pool->cleanup_register(\&CGI::Pretty::_reset_globals);
        }
    }
    $class->_reset_globals if $CGI::PERLEX;

    return bless $this, $class;
}

sub initialize_globals {
    # This is the string used for indentation of tags
    $CGI::Pretty::INDENT = "\t";
    
    # This is the string used for seperation between tags
    $CGI::Pretty::LINEBREAK = $/;

    # These tags are not prettify'd.
    @CGI::Pretty::AS_IS = qw( a pre code script textarea td );

    1;
}
sub _reset_globals { initialize_globals(); }

1;

