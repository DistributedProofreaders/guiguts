package HTML::Form;

# $Id: Form.pm,v 1.38 2003/10/23 19:11:32 uid39246 Exp $

use strict;
use URI;
use Carp ();

use vars qw($VERSION);
$VERSION = sprintf("%d.%03d", q$Revision: 1.38 $ =~ /(\d+)\.(\d+)/);

my %form_tags = map {$_ => 1} qw(input textarea button select option);

my %type2class = (
 text     => "TextInput",
 password => "TextInput",
 hidden   => "TextInput",
 textarea => "TextInput",

 button   => "IgnoreInput",
 "reset"  => "IgnoreInput",

 radio    => "ListInput",
 checkbox => "ListInput",
 option   => "ListInput",

 submit   => "SubmitInput",
 image    => "ImageInput",
 file     => "FileInput",
);

sub parse
{
    my($class, $html, $base_uri) = @_;
    require HTML::TokeParser;
    my $p = HTML::TokeParser->new(ref($html) ? $html->content_ref : \$html);
    eval {
	# optimization
	$p->report_tags(qw(form input textarea select optgroup option));
    };

    unless (defined $base_uri) {
	if (ref($html)) {
	    $base_uri = $html->base;
	}
	else {
	    Carp::croak("HTML::Form::parse: No \$base_uri provided");
	}
    }

    my @forms;
    my $f;  # current form

    while (my $t = $p->get_tag) {
	my($tag,$attr) = @$t;
	if ($tag eq "form") {
	    my $action = delete $attr->{'action'};
	    $action = "" unless defined $action;
	    $action = URI->new_abs($action, $base_uri);
	    $f = $class->new($attr->{'method'},
			     $action,
			     $attr->{'enctype'});
	    $f->{attr} = $attr;
	    push(@forms, $f);
	    while (my $t = $p->get_tag) {
		my($tag, $attr) = @$t;
		last if $tag eq "/form";
		if ($tag eq "input") {
		    my $type = delete $attr->{type} || "text";
		    $attr->{value_name} = $p->get_phrase;
		    $f->push_input($type, $attr);
		}
		elsif ($tag eq "textarea") {
		    $attr->{textarea_value} = $attr->{value}
		        if exists $attr->{value};
		    my $text = $p->get_text("/textarea");
		    $attr->{value} = $text;
		    $f->push_input("textarea", $attr);
		}
		elsif ($tag eq "select") {
		    $attr->{select_value} = $attr->{value}
		        if exists $attr->{value};
		    while ($t = $p->get_tag) {
			my $tag = shift @$t;
			last if $tag eq "/select";
			next if $tag =~ m,/?optgroup,;
			next if $tag eq "/option";
			if ($tag eq "option") {
			    my %a = (%$attr, %{$t->[0]});
			    $a{value_name} = $p->get_trimmed_text;
			    $a{value} = delete $a{value_name}
				unless defined $a{value};
			    $f->push_input("option", \%a);
			}
			else {
			    Carp::carp("Bad <select> tag '$tag'") if $^W;
			}
		    }
		}
	    }
	}
	elsif ($form_tags{$tag}) {
	    Carp::carp("<$tag> outside <form>") if $^W;
	}
    }
    for (@forms) {
	$_->fixup;
    }

    wantarray ? @forms : $forms[0];
}

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->{method} = uc(shift  || "GET");
    $self->{action} = shift  || Carp::croak("No action defined");
    $self->{enctype} = lc(shift || "application/x-www-form-urlencoded");
    $self->{inputs} = [@_];
    $self;
}


sub push_input
{
    my($self, $type, $attr) = @_;
    $type = lc $type;
    my $class = $type2class{$type};
    unless ($class) {
	Carp::carp("Unknown input type '$type'") if $^W;
	$class = "TextInput";
    }
    $class = "IgnoreInput" if exists $attr->{disabled};
    $class = "HTML::Form::$class";

    my $input = $class->new(type => $type, %$attr);
    $input->add_to_form($self);
}


BEGIN {
    # Set up some accesor
    for (qw(method action enctype)) {
	my $m = $_;
	no strict 'refs';
	*{$m} = sub {
	    my $self = shift;
	    my $old = $self->{$m};
	    $self->{$m} = shift if @_;
	    $old;
	};
    }
    *uri = \&action;  # alias
}

sub attr {
    my $self = shift;
    my $name = shift;
    return undef unless defined $name;

    my $old = $self->{attr}{$name};
    $self->{attr}{$name} = shift if @_;
    return $old;
}

sub inputs
{
    my $self = shift;
    @{$self->{'inputs'}};
}


sub find_input
{
    my($self, $name, $type, $no) = @_;
    if (wantarray) {
	my @res;
	my $c;
	for (@{$self->{'inputs'}}) {
	    if (defined $name) {
		next unless exists $_->{name};
		next if $name ne $_->{name};
	    }
	    next if $type && $type ne $_->{type};
	    $c++;
	    next if $no && $no != $c;
	    push(@res, $_);
	}
	return @res;
	
    }
    else {
	$no ||= 1;
	for (@{$self->{'inputs'}}) {
	    if (defined $name) {
		next unless exists $_->{name};
		next if $name ne $_->{name};
	    }
	    next if $type && $type ne $_->{type};
	    next if --$no;
	    return $_;
	}
	return undef;
    }
}

sub fixup
{
    my $self = shift;
    for (@{$self->{'inputs'}}) {
	$_->fixup;
    }
}


sub value
{
    my $self = shift;
    my $key  = shift;
    my $input = $self->find_input($key);
    Carp::croak("No such field '$key'") unless $input;
    local $Carp::CarpLevel = 1;
    $input->value(@_);
}

sub param {
    my $self = shift;
    if (@_) {
        my $name = shift;
        my @inputs;
        for ($self->inputs) {
            my $n = $_->name;
            next if !defined($n) || $n ne $name;
            push(@inputs, $_);
        }

        if (@_) {
            # set
            die "No '$name' parameter exists" unless @inputs;
	    my @v = @_;
	    @v = @{$v[0]} if @v == 1 && ref($v[0]);
            while (@v) {
                my $v = shift @v;
                my $err;
                for my $i (0 .. @inputs-1) {
                    eval {
                        $inputs[$i]->value($v);
                    };
                    unless ($@) {
                        undef($err);
                        splice(@inputs, $i, 1);
                        last;
                    }
                    $err ||= $@;
                }
                die $err if $err;
            }

	    # the rest of the input should be cleared
	    for (@inputs) {
		$_->value(undef);
	    }
        }
        else {
            # get
            my @v;
            for (@inputs) {
		if (defined(my $v = $_->value)) {
		    push(@v, $v);
		}
            }
            return wantarray ? @v : $v[0];
        }
    }
    else {
        # list parameter names
        my @n;
        my %seen;
        for ($self->inputs) {
            my $n = $_->name;
            next if !defined($n) || $seen{$n}++;
            push(@n, $n);
        }
        return @n;
    }
}


sub try_others
{
    my($self, $cb) = @_;
    my @try;
    for (@{$self->{'inputs'}}) {
	my @not_tried_yet = $_->other_possible_values;
	next unless @not_tried_yet;
	push(@try, [\@not_tried_yet, $_]);
    }
    return unless @try;
    $self->_try($cb, \@try, 0);
}

sub _try
{
    my($self, $cb, $try, $i) = @_;
    for (@{$try->[$i][0]}) {
	$try->[$i][1]->value($_);
	&$cb($self);
	$self->_try($cb, $try, $i+1) if $i+1 < @$try;
    }
}


sub make_request
{
    my $self = shift;
    my $method  = uc $self->{'method'};
    my $uri     = $self->{'action'};
    my $enctype = $self->{'enctype'};
    my @form    = $self->form;

    if ($method eq "GET") {
	require HTTP::Request;
	$uri = URI->new($uri, "http");
	$uri->query_form(@form);
	return HTTP::Request->new(GET => $uri);
    }
    elsif ($method eq "POST") {
	require HTTP::Request::Common;
	return HTTP::Request::Common::POST($uri, \@form,
					   Content_Type => $enctype);
    }
    else {
	Carp::croak("Unknown method '$method'");
    }
}


sub click
{
    my $self = shift;
    my $name;
    $name = shift if (@_ % 2) == 1;  # odd number of arguments

    # try to find first submit button to activate
    for (@{$self->{'inputs'}}) {
        next unless $_->can("click");
        next if $name && $_->name ne $name;
	return $_->click($self, @_);
    }
    Carp::croak("No clickable input with name $name") if $name;
    $self->make_request;
}


sub form
{
    my $self = shift;
    map { $_->form_name_value($self) } @{$self->{'inputs'}};
}


sub dump
{
    my $self = shift;
    my $method  = $self->{'method'};
    my $uri     = $self->{'action'};
    my $enctype = $self->{'enctype'};
    my $dump = "$method $uri";
    $dump .= " ($enctype)"
	if $enctype ne "application/x-www-form-urlencoded";
    $dump .= " [$self->{attr}{name}]"
    	if exists $self->{attr}{name};
    $dump .= "\n";
    for ($self->inputs) {
	$dump .= "  " . $_->dump . "\n";
    }
    print STDERR $dump unless defined wantarray;
    $dump;
}


#---------------------------------------------------
package HTML::Form::Input;

sub new
{
    my $class = shift;
    my $self = bless {@_}, $class;
    $self;
}

sub add_to_form
{
    my($self, $form) = @_;
    push(@{$form->{'inputs'}}, $self);
    $self;
}

sub fixup {}


sub type
{
    shift->{type};
}

sub name
{
    my $self = shift;
    my $old = $self->{name};
    $self->{name} = shift if @_;
    $old;
}

sub value
{
    my $self = shift;
    my $old = $self->{value};
    $self->{value} = shift if @_;
    $old;
}

sub possible_values
{
    return;
}

sub other_possible_values
{
    return;
}

sub value_names {
    return
}

sub form_name_value
{
    my $self = shift;
    my $name = $self->{'name'};
    return unless defined $name;
    my $value = $self->value;
    return unless defined $value;
    return ($name => $value);
}

sub dump
{
    my $self = shift;
    my $name = $self->name;
    $name = "<NONAME>" unless defined $name;
    my $value = $self->value;
    $value = "<UNDEF>" unless defined $value;
    my $dump = "$name=$value";

    my $type = $self->type;
    return $dump if $type eq "text";

    $type = ($type eq "text") ? "" : " ($type)";
    my $menu = $self->{menu} || "";
    my $value_names = $self->{value_names};
    if ($menu) {
	my @menu;
	for (0 .. @$menu-1) {
	    my $opt = $menu->[$_];
	    $opt = "<UNDEF>" unless defined $opt;
	    substr($opt,0,0) = "*" if $self->{seen}[$_];
	    $opt .= "/$value_names->[$_]"
		if $value_names && defined $value_names->[$_]
		    && $value_names->[$_] ne $opt;
	    push(@menu, $opt);
	}
	$menu = "[" . join("|", @menu) . "]";
    }
    sprintf "%-30s %-10s %s", $dump, $type, $menu;
}


#---------------------------------------------------
package HTML::Form::TextInput;
@HTML::Form::TextInput::ISA=qw(HTML::Form::Input);

#input/text
#input/password
#input/hidden
#textarea

sub value
{
    my $self = shift;
    my $old = $self->{value};
    $old = "" unless defined $old;
    if (@_) {
	if (exists($self->{readonly}) || $self->{type} eq "hidden") {
	    Carp::carp("Input '$self->{name}' is readonly") if $^W;
	}
	$self->{value} = shift;
    }
    $old;
}

#---------------------------------------------------
package HTML::Form::IgnoreInput;
@HTML::Form::IgnoreInput::ISA=qw(HTML::Form::Input);

#input/button
#input/reset

sub value { return }


#---------------------------------------------------
package HTML::Form::ListInput;
@HTML::Form::ListInput::ISA=qw(HTML::Form::Input);

#select/option   (val1, val2, ....)
#input/radio     (undef, val1, val2,...)
#input/checkbox  (undef, value)
#select-multiple/option (undef, value)

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    my $value = delete $self->{value};
    my $value_name = delete $self->{value_name};
    
    if ($self->type eq "checkbox") {
	$value = "on" unless defined $value;
	$self->{menu} = [undef, $value];
	$self->{value_names} = ["off", $value_name];
	$self->{current} = (exists $self->{checked}) ? 1 : 0;
	delete $self->{checked};
    }
    else {
	$self->{menu} = [$value];
	my $checked = exists $self->{checked} || exists $self->{selected};
	delete $self->{checked};
	delete $self->{selected};
	if (exists $self->{multiple}) {
	    unshift(@{$self->{menu}}, undef);
	    $self->{value_names} = ["off", $value_name];
	    $self->{current} = $checked ? 1 : 0;
	}
	else {
	    $self->{value_names} = [$value_name];
	    $self->{current} = 0 if $checked;
	}
    }
    $self;
}

sub add_to_form
{
    my($self, $form) = @_;
    my $type = $self->type;
    return $self->SUPER::add_to_form($form)
	if $type eq "checkbox" ||
	   ($type eq "option" && exists $self->{multiple});

    my $prev = $form->find_input($self->{name}, $self->{type});
    return $self->SUPER::add_to_form($form) unless $prev;

    # merge menues
    push(@{$prev->{menu}}, @{$self->{menu}});
    push(@{$prev->{value_names}}, @{$self->{value_names}});
    $prev->{current} = @{$prev->{menu}} - 1 if exists $self->{current};
}

sub fixup
{
    my $self = shift;
    if ($self->{type} eq "option" && !(exists $self->{current})) {
	$self->{current} = 0;
    }
    $self->{seen} = [(0) x @{$self->{menu}}];
    $self->{seen}[$self->{current}] = 1 if exists $self->{current};
}

sub value
{
    my $self = shift;
    my $old;
    $old = $self->{menu}[$self->{current}] if exists $self->{current};
    if (@_) {
	my $i = 0;
	my $val = shift;
	my $cur;
	for (@{$self->{menu}}) {
	    if ((defined($val) && defined($_) && $val eq $_) ||
		(!defined($val) && !defined($_))
	       )
	    {
		$cur = $i;
		last;
	    }
	    $i++;
	}
	unless (defined $cur) {
	    if (defined $val) {
		# try to search among the alternative names as well
		my $i = 0;
		my $cur_ignorecase;
		my $lc_val = lc($val);
		for (@{$self->{value_names}}) {
		    if (defined $_) {
			if ($val eq $_) {
			    $cur = $i;
			    last;
			}
			if (!defined($cur_ignorecase) && $lc_val eq lc($_)) {
			    $cur_ignorecase = $i;
			}
		    }
		    $i++;
		}
		unless (defined $cur) {
		    $cur = $cur_ignorecase;
		    unless (defined $cur) {
			my $n = $self->name;
		        Carp::croak("Illegal value '$val' for field '$n'");
		    }
		}
	    }
	    else {
		my $n = $self->name;
	        Carp::croak("The '$n' field can't be unchecked");
	    }
	}
	$self->{current} = $cur;
	$self->{seen}[$cur] = 1;
    }
    $old;
}

sub check
{
    my $self = shift;
    $self->{current} = 1;
    $self->{seen}[1] = 1;
}

sub possible_values
{
    my $self = shift;
    @{$self->{menu}};
}

sub other_possible_values
{
    my $self = shift;
    map { $self->{menu}[$_] }
        grep {!$self->{seen}[$_]}
             0 .. (@{$self->{seen}} - 1);
}

sub value_names {
    my $self = shift;
    my @names;
    for my $i (0 .. @{$self->{menu}} - 1) {
	my $n = $self->{value_names}[$i];
	$n = $self->{menu}[$i] unless defined $n;
	push(@names, $n);
    }
    @names;
}


#---------------------------------------------------
package HTML::Form::SubmitInput;
@HTML::Form::SubmitInput::ISA=qw(HTML::Form::Input);

#input/image
#input/submit

sub click
{
    my($self,$form,$x,$y) = @_;
    for ($x, $y) { $_ = 1 unless defined; }
    local($self->{clicked}) = [$x,$y];
    return $form->make_request;
}

sub form_name_value
{
    my $self = shift;
    return unless $self->{clicked};
    return $self->SUPER::form_name_value(@_);
}


#---------------------------------------------------
package HTML::Form::ImageInput;
@HTML::Form::ImageInput::ISA=qw(HTML::Form::SubmitInput);

sub form_name_value
{
    my $self = shift;
    my $clicked = $self->{clicked};
    return unless $clicked;
    my $name = $self->{name};
    return unless defined $name;
    return ("$name.x" => $clicked->[0],
	    "$name.y" => $clicked->[1]
	   );
}

#---------------------------------------------------
package HTML::Form::FileInput;
@HTML::Form::FileInput::ISA=qw(HTML::Form::TextInput);

sub file {
    my $self = shift;
    $self->value(@_);
}

sub filename {
    my $self = shift;
    my $old = $self->{filename};
    $self->{filename} = shift if @_;
    $old = $self->file unless defined $old;
    $old;
}

sub content {
    my $self = shift;
    my $old = $self->{content};
    $self->{content} = shift if @_;
    $old;
}

sub headers {
    my $self = shift;
    my $old = $self->{headers} || [];
    $self->{headers} = [@_] if @_;
    @$old;
}

sub form_name_value {
    my($self, $form) = @_;
    return $self->SUPER::form_name_value($form)
	if $form->method ne "POST" ||
	   $form->enctype ne "multipart/form-data";

    my $name = $self->name;
    return unless defined $name;

    my $file = $self->file;
    my $filename = $self->filename;
    my @headers = $self->headers;
    my $content = $self->content;
    if (defined $content) {
	$filename = $file unless defined $filename;
	$file = undef;
	unshift(@headers, "Content" => $content);
    }
    elsif (!defined($file) || length($file) == 0) {
	return;
    }

    # legacy (this used to be the way to do it)
    if (ref($file) eq "ARRAY") {
	my $f = shift @$file;
	my $fn = shift @$file;
	push(@headers, @$file);
	$file = $f;
	$filename = $fn unless defined $filename;
    }

    return ($name => [$file, $filename, @headers]);
}

1;

__END__

