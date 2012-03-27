#############################################################################
# Pod/ParseUtils.pm -- helpers for POD parsing and conversion
#
# Copyright (C) 1999-2000 by Marek Rouchal. All rights reserved.
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::ParseUtils;

use vars qw($VERSION);
$VERSION = 0.30;   ## Current version of this package
require  5.005;    ## requires this Perl version or later

#-----------------------------------------------------------------------------
# Pod::List
#
# class to hold POD list info (=over, =item, =back)
#-----------------------------------------------------------------------------

package Pod::List;

use Carp;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my %params = @_;
    my $self = {%params};
    bless $self, $class;
    $self->initialize();
    return $self;
}

sub initialize {
    my $self = shift;
    $self->{-file} ||= 'unknown';
    $self->{-start} ||= 'unknown';
    $self->{-indent} ||= 4; # perlpod: "should be the default"
    $self->{_items} = [];
    $self->{-type} ||= '';
}

# The POD file name the list appears in
sub file {
   return (@_ > 1) ? ($_[0]->{-file} = $_[1]) : $_[0]->{-file};
}

# The line in the file the node appears
sub start {
   return (@_ > 1) ? ($_[0]->{-start} = $_[1]) : $_[0]->{-start};
}

# indent level
sub indent {
   return (@_ > 1) ? ($_[0]->{-indent} = $_[1]) : $_[0]->{-indent};
}

# The type of the list (UL, OL, ...)
sub type {
   return (@_ > 1) ? ($_[0]->{-type} = $_[1]) : $_[0]->{-type};
}

# The regular expression to simplify the items
sub rx {
   return (@_ > 1) ? ($_[0]->{-rx} = $_[1]) : $_[0]->{-rx};
}

# The individual =items of this list
sub item {
    my ($self,$item) = @_;
    if(defined $item) {
        push(@{$self->{_items}}, $item);
        return $item;
    }
    else {
        return @{$self->{_items}};
    }
}

# possibility for parsers/translators to store information about the
# lists's parent object
sub parent {
   return (@_ > 1) ? ($_[0]->{-parent} = $_[1]) : $_[0]->{-parent};
}

# possibility for parsers/translators to store information about the
# list's object
sub tag {
   return (@_ > 1) ? ($_[0]->{-tag} = $_[1]) : $_[0]->{-tag};
}

#-----------------------------------------------------------------------------
# Pod::Hyperlink
#
# class to manipulate POD hyperlinks (L<>)
#-----------------------------------------------------------------------------

package Pod::Hyperlink;

use Carp;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = +{};
    bless $self, $class;
    $self->initialize();
    if(defined $_[0]) {
        if(ref($_[0])) {
            # called with a list of parameters
            %$self = %{$_[0]};
            $self->_construct_text();
        }
        else {
            # called with L<> contents
            return undef unless($self->parse($_[0]));
        }
    }
    return $self;
}

sub initialize {
    my $self = shift;
    $self->{-line} ||= 'undef';
    $self->{-file} ||= 'undef';
    $self->{-page} ||= '';
    $self->{-node} ||= '';
    $self->{-alttext} ||= '';
    $self->{-type} ||= 'undef';
    $self->{_warnings} = [];
}

sub parse {
    my $self = shift;
    local($_) = $_[0];
    # syntax check the link and extract destination
    my ($alttext,$page,$node,$type,$quoted) = (undef,'','','',0);

    $self->{_warnings} = [];

    # collapse newlines with whitespace
    s/\s*\n+\s*/ /g;

    # strip leading/trailing whitespace
    if(s/^[\s\n]+//) {
        $self->warning("ignoring leading whitespace in link");
    }
    if(s/[\s\n]+$//) {
        $self->warning("ignoring trailing whitespace in link");
    }
    unless(length($_)) {
        _invalid_link("empty link");
        return undef;
    }

    ## Check for different possibilities. This is tedious and error-prone
    # we match all possibilities (alttext, page, section/item)
    #warn "DEBUG: link=$_\n";

    # only page
    # problem: a lot of people use (), or (1) or the like to indicate
    # man page sections. But this collides with L<func()> that is supposed
    # to point to an internal funtion...
    my $page_rx = '[\w.-]+(?:::[\w.-]+)*(?:[(](?:\d\w*|)[)]|)';
    # page name only
    if(m!^($page_rx)$!o) {
        $page = $1;
        $type = 'page';
    }
    # alttext, page and "section"
    elsif(m!^(.*?)\s*[|]\s*($page_rx)\s*/\s*"(.+)"$!o) {
        ($alttext, $page, $node) = ($1, $2, $3);
        $type = 'section';
        $quoted = 1; #... therefore | and / are allowed
    }
    # alttext and page
    elsif(m!^(.*?)\s*[|]\s*($page_rx)$!o) {
        ($alttext, $page) = ($1, $2);
        $type = 'page';
    }
    # alttext and "section"
    elsif(m!^(.*?)\s*[|]\s*(?:/\s*|)"(.+)"$!) {
        ($alttext, $node) = ($1,$2);
        $type = 'section';
        $quoted = 1;
    }
    # page and "section"
    elsif(m!^($page_rx)\s*/\s*"(.+)"$!o) {
        ($page, $node) = ($1, $2);
        $type = 'section';
        $quoted = 1;
    }
    # page and item
    elsif(m!^($page_rx)\s*/\s*(.+)$!o) {
        ($page, $node) = ($1, $2);
        $type = 'item';
    }
    # only "section"
    elsif(m!^/?"(.+)"$!) {
        $node = $1;
        $type = 'section';
        $quoted = 1;
    }
    # only item
    elsif(m!^\s*/(.+)$!) {
        $node = $1;
        $type = 'item';
    }
    # non-standard: Hyperlink
    elsif(m!^((?:http|ftp|mailto|news):.+)$!i) {
        $node = $1;
        $type = 'hyperlink';
    }
    # alttext, page and item
    elsif(m!^(.*?)\s*[|]\s*($page_rx)\s*/\s*(.+)$!o) {
        ($alttext, $page, $node) = ($1, $2, $3);
        $type = 'item';
    }
    # alttext and item
    elsif(m!^(.*?)\s*[|]\s*/(.+)$!) {
        ($alttext, $node) = ($1,$2);
    }
    # nonstandard: alttext and hyperlink
    elsif(m!^(.*?)\s*[|]\s*((?:http|ftp|mailto|news):.+)$!) {
        ($alttext, $node) = ($1,$2);
        $type = 'hyperlink';
    }
    # must be an item or a "malformed" section (without "")
    else {
        $node = $_;
        $type = 'item';
    }
    # collapse whitespace in nodes
    $node =~ s/\s+/ /gs;

    # empty alternative text expands to node name
    if(defined $alttext) {
        if(!length($alttext)) {
          $alttext = $node | $page;
        }
    }
    else {
        $alttext = '';
    }

    if($page =~ /[(]\w*[)]$/) {
        $self->warning("(section) in '$page' deprecated");
    }
    if(!$quoted && $node =~ m:[|/]:) {
        $self->warning("node '$node' contains non-escaped | or /");
    }
    if($alttext =~ m:[|/]:) {
        $self->warning("alternative text '$node' contains non-escaped | or /");
    }
    $self->{-page} = $page;
    $self->{-node} = $node;
    $self->{-alttext} = $alttext;
    #warn "DEBUG: page=$page section=$section item=$item alttext=$alttext\n";
    $self->{-type} = $type;
    $self->_construct_text();
    1;
}

sub _construct_text {
    my $self = shift;
    my $alttext = $self->alttext();
    my $type = $self->type();
    my $section = $self->node();
    my $page = $self->page();
    my $page_ext = '';
    $page =~ s/([(]\w*[)])$// && ($page_ext = $1);
    if($alttext) {
        $self->{_text} = $alttext;
    }
    elsif($type eq 'hyperlink') {
        $self->{_text} = $section;
    }
    else {
        $self->{_text} = ($section || '') .
            (($page && $section) ? ' in ' : '') .
            "$page$page_ext";
    }
    # for being marked up later
    # use the non-standard markers P<> and Q<>, so that the resulting
    # text can be parsed by the translators. It's their job to put
    # the correct hypertext around the linktext
    if($alttext) {
        $self->{_markup} = "Q<$alttext>";
    }
    elsif($type eq 'hyperlink') {
        $self->{_markup} = "Q<$section>";
    }
    else {
        $self->{_markup} = (!$section ? '' : "Q<$section>") .
            ($page ? ($section ? ' in ':'') . "P<$page>$page_ext" : '');
    }
}

#' retrieve/set markuped text
sub markup {
    return (@_ > 1) ? ($_[0]->{_markup} = $_[1]) : $_[0]->{_markup};
}

# The complete link's text
sub text {
    $_[0]->{_text};
}

# Set/retrieve warnings
sub warning {
    my $self = shift;
    if(@_) {
        push(@{$self->{_warnings}}, @_);
        return @_;
    }
    return @{$self->{_warnings}};
}

# The line in the file the link appears
sub line {
    return (@_ > 1) ? ($_[0]->{-line} = $_[1]) : $_[0]->{-line};
}

# The POD file name the link appears in
sub file {
    return (@_ > 1) ? ($_[0]->{-file} = $_[1]) : $_[0]->{-file};
}

# The POD page the link appears on
sub page {
    if (@_ > 1) {
        $_[0]->{-page} = $_[1];
        $_[0]->_construct_text();
    }
    $_[0]->{-page};
}

# The link destination
sub node {
    if (@_ > 1) {
        $_[0]->{-node} = $_[1];
        $_[0]->_construct_text();
    }
    $_[0]->{-node};
}

# Potential alternative text
sub alttext {
    if (@_ > 1) {
        $_[0]->{-alttext} = $_[1];
        $_[0]->_construct_text();
    }
    $_[0]->{-alttext};
}

# The type: item or headn
sub type {
    return (@_ > 1) ? ($_[0]->{-type} = $_[1]) : $_[0]->{-type};
}

# The link itself
sub link {
    my $self = shift;
    my $link = $self->page() || '';
    if($self->node()) {
        my $node = $self->node();
        $text =~ s/\|/E<verbar>/g;
        $text =~ s:/:E<sol>:g;
        if($self->type() eq 'section') {
            $link .= ($link ? '/' : '') . '"' . $node . '"';
        }
        elsif($self->type() eq 'hyperlink') {
            $link = $self->node();
        }
        else { # item
            $link .= '/' . $node;
        }
    }
    if($self->alttext()) {
        my $text = $self->alttext();
        $text =~ s/\|/E<verbar>/g;
        $text =~ s:/:E<sol>:g;
        $link = "$text|$link";
    }
    $link;
}

sub _invalid_link {
    my ($msg) = @_;
    # this sets @_
    #eval { die "$msg\n" };
    #chomp $@;
    $@ = $msg; # this seems to work, too!
    undef;
}

#-----------------------------------------------------------------------------
# Pod::Cache
#
# class to hold POD page details
#-----------------------------------------------------------------------------

package Pod::Cache;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = [];
    bless $self, $class;
    return $self;
}

sub item {
    my ($self,%param) = @_;
    if(%param) {
        my $item = Pod::Cache::Item->new(%param);
        push(@$self, $item);
        return $item;
    }
    else {
        return @{$self};
    }
}

sub find_page {
    my ($self,$page) = @_;
    foreach(@$self) {
        if($_->page() eq $page) {
            return $_;
        }
    }
    undef;
}

package Pod::Cache::Item;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my %params = @_;
    my $self = {%params};
    bless $self, $class;
    $self->initialize();
    return $self;
}

sub initialize {
    my $self = shift;
    $self->{-nodes} = [] unless(defined $self->{-nodes});
}

# The POD page
sub page {
   return (@_ > 1) ? ($_[0]->{-page} = $_[1]) : $_[0]->{-page};
}

# The POD description, taken out of NAME if present
sub description {
   return (@_ > 1) ? ($_[0]->{-description} = $_[1]) : $_[0]->{-description};
}

# The file path
sub path {
   return (@_ > 1) ? ($_[0]->{-path} = $_[1]) : $_[0]->{-path};
}

# The POD file name
sub file {
   return (@_ > 1) ? ($_[0]->{-file} = $_[1]) : $_[0]->{-file};
}

# The POD nodes
sub nodes {
    my ($self,@nodes) = @_;
    if(@nodes) {
        push(@{$self->{-nodes}}, @nodes);
        return @nodes;
    }
    else {
        return @{$self->{-nodes}};
    }
}

sub find_node {
    my ($self,$node) = @_;
    my @search;
    push(@search, @{$self->{-nodes}}) if($self->{-nodes});
    push(@search, @{$self->{-idx}}) if($self->{-idx});
    foreach(@search) {
        if($_->[0] eq $node) {
            return $_->[1]; # id
        }
    }
    undef;
}

# The POD index entries
sub idx {
    my ($self,@idx) = @_;
    if(@idx) {
        push(@{$self->{-idx}}, @idx);
        return @idx;
    }
    else {
        return @{$self->{-idx}};
    }
}

1;
