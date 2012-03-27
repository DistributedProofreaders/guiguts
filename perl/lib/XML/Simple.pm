# $Id: Simple.pm,v 1.16 2003/09/09 09:33:43 grantm Exp $

package XML::Simple;

# See after __END__ for more POD documentation


# Load essentials here, other modules loaded on demand later

use strict;
use Carp;
require Exporter;


##############################################################################
# Define some constants
#

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $PREFERRED_PARSER);

@ISA               = qw(Exporter);
@EXPORT            = qw(XMLin XMLout);
@EXPORT_OK         = qw(xml_in xml_out);
$VERSION           = '2.09';
$PREFERRED_PARSER  = undef;

my $StrictMode     = 0;
my %CacheScheme    = (
                       storable => [ \&StorableSave, \&StorableRestore ],
                       memshare => [ \&MemShareSave, \&MemShareRestore ],
                       memcopy  => [ \&MemCopySave,  \&MemCopyRestore  ]
                     );

my @KnownOptIn     = qw(keyattr keeproot forcecontent contentkey noattr
                        searchpath forcearray cache suppressempty parseropts
                        grouptags nsexpand datahandler varattr variables
                        normalisespace normalizespace);

my @KnownOptOut    = qw(keyattr keeproot contentkey noattr
                        rootname xmldecl outputfile noescape suppressempty
                        grouptags nsexpand handler noindent);

my @DefKeyAttr     = qw(name key id);
my $DefRootName    = qq(opt);
my $DefContentKey  = qq(content);
my $DefXmlDecl     = qq(<?xml version='1.0' standalone='yes'?>);

my $xmlns_ns       = 'http://www.w3.org/2000/xmlns/';
my $bad_def_ns_jcn = '{' . $xmlns_ns . '}';     # LibXML::SAX workaround


##############################################################################
# Globals for use by caching routines
#

my %MemShareCache  = ();
my %MemCopyCache   = ();


##############################################################################
# Wrapper for Exporter - handles ':strict'
#

sub import {

  # Handle the :strict tag
  
  $StrictMode = 1 if grep(/^:strict$/, @_);

  # Pass everything else to Exporter.pm

  __PACKAGE__->export_to_level(1, grep(!/^:strict$/, @_));
}


##############################################################################
# Constructor for optional object interface.
#

sub new {
  my $class = shift;

  if(@_ % 2) {
    croak "Default options must be name=>value pairs (odd number supplied)";
  }

  my %known_opt;
  @known_opt{@KnownOptIn, @KnownOptOut} = (undef) x 100;

  my %raw_opt = @_;
  my %def_opt;
  while(my($key, $val) = each %raw_opt) {
    my $lkey = lc($key);
    $lkey =~ s/_//g;
    croak "Unrecognised option: $key" unless(exists($known_opt{$lkey}));
    $def_opt{$lkey} = $val;
  }
  my $self = { def_opt => \%def_opt };

  return(bless($self, $class));
}


##############################################################################
# Sub/Method: XMLin()
#
# Exported routine for slurping XML into a hashref - see pod for info.
#
# May be called as object method or as a plain function.
#
# Expects one arg for the source XML, optionally followed by a number of
# name => value option pairs.
#

sub XMLin {

  # If this is not a method call, create an object

  my $self;
  if($_[0]  and  UNIVERSAL::isa($_[0], 'XML::Simple')) {
    $self = shift;
  }
  else {
    $self = new XML::Simple();
  }


  my $string = shift;

  $self->handle_options('in', @_);


  # If no XML or filename supplied, look for scriptname.xml in script directory

  unless(defined($string))  {
    
    # Translate scriptname[.suffix] to scriptname.xml

    require File::Basename;

    my($ScriptName, $ScriptDir, $Extension) =
      File::Basename::fileparse($0, '\.[^\.]+');

    $string = $ScriptName . '.xml';


    # Add script directory to searchpath
    
    if($ScriptDir) {
      unshift(@{$self->{opt}->{searchpath}}, $ScriptDir);
    }
  }
  

  # Are we parsing from a file?  If so, is there a valid cache available?

  my($filename, $scheme);
  unless($string =~ m{<.*?>}s  or  ref($string)  or  $string eq '-') {

    require File::Basename;
    require File::Spec;

    $filename = $self->find_xml_file($string, @{$self->{opt}->{searchpath}});

    if($self->{opt}->{cache}) {
      foreach $scheme (@{$self->{opt}->{cache}}) {
        croak "Unsupported caching scheme: $scheme"
          unless($CacheScheme{$scheme});

        my $opt = $CacheScheme{$scheme}->[1]->($filename);
        return($opt) if($opt);
      }
    }
  }
  else {
    delete($self->{opt}->{cache});
    if($string eq '-') {
      # Read from standard input

      local($/) = undef;
      $string = <STDIN>;
    }
  }


  # Parsing is required, so let's get on with it

  my $tree =  $self->build_tree($filename, $string);


  # Now work some magic on the resulting parse tree

  my($ref);
  if($self->{opt}->{keeproot}) {
    $ref = $self->collapse({}, @$tree);
  }
  else {
    $ref = $self->collapse(@{$tree->[1]});
  }

  if($self->{opt}->{cache}) {
    $CacheScheme{$self->{opt}->{cache}->[0]}->[0]->($ref, $filename);
  }

  return($ref);
}


##############################################################################
# Method: build_tree()
#
# This routine will be called if there is no suitable pre-parsed tree in a
# cache.  It parses the XML and returns an XML::Parser 'Tree' style data
# structure (summarised in the comments for the collapse() routine below).
#
# XML::Simple requires the services of another module that knows how to
# parse XML.  If XML::SAX is installed, the default SAX parser will be used,
# otherwise XML::Parser will be used.
#
# This routine expects to be passed a 'string' as argument 1 or a filename as
# argument 2.  The 'string' might be a string of XML or it might be a 
# reference to an IO::Handle.  (This non-intuitive mess results in part from
# the way XML::Parser works but that's really no excuse).
#

sub build_tree {
  my $self     = shift;
  my $filename = shift;
  my $string   = shift;


  my $preferred_parser = $PREFERRED_PARSER;
  unless(defined($preferred_parser)) {
    $preferred_parser = $ENV{XML_SIMPLE_PREFERRED_PARSER} || '';
  }
  if($preferred_parser eq 'XML::Parser') {
    return($self->build_tree_xml_parser($filename, $string));
  }

  eval { require XML::SAX; };      # We didn't need it until now
  if($@) {                         # No XML::SAX - fall back to XML::Parser
    if($preferred_parser) {        # unless a SAX parser was expressly requested
      croak "XMLin() could not load XML::SAX";
    }
    return($self->build_tree_xml_parser($filename, $string));
  }

  $XML::SAX::ParserPackage = $preferred_parser if($preferred_parser);

  my $sp = XML::SAX::ParserFactory->parser(Handler => $self);
  
  $self->{nocollapse} = 1;
  my($tree);
  if($filename) {
    $tree = $sp->parse_uri($filename);
  }
  else {
    if(ref($string)) {
      $tree = $sp->parse_file($string);
    }
    else {
      $tree = $sp->parse_string($string);
    }
  }

  return($tree);
}


##############################################################################
# Method: build_tree_xml_parser()
#
# This routine will be called if XML::SAX is not installed, or if XML::Parser
# was specifically requested.  It takes the same arguments as build_tree() and
# returns the same data structure (XML::Parser 'Tree' style).
#

sub build_tree_xml_parser {
  my $self     = shift;
  my $filename = shift;
  my $string   = shift;


  eval {
    local($^W) = 0;      # Suppress warning from Expat.pm re File::Spec::load()
    require XML::Parser; # We didn't need it until now
  };
  if($@) {
    croak "XMLin() requires either XML::SAX or XML::Parser";
  }

  if($self->{opt}->{nsexpand}) {
    carp "'nsexpand' option requires XML::SAX";
  }

  my $xp = new XML::Parser(Style => 'Tree', @{$self->{opt}->{parseropts}});
  my($tree);
  if($filename) {
    # $tree = $xp->parsefile($filename);  # Changed due to prob w/mod_perl
    local(*XML_FILE);
    open(XML_FILE, "<$filename") || croak qq($filename - $!);
    $tree = $xp->parse(*XML_FILE);
    close(XML_FILE);
  }
  else {
    $tree = $xp->parse($string);
  }

  return($tree);
}


##############################################################################
# Sub: StorableSave()
#
# Wrapper routine for invoking Storable::nstore() to cache a parsed data
# structure.
#

sub StorableSave {
  my($data, $filename) = @_;

  my $cachefile = $filename;
  $cachefile =~ s{(\.xml)?$}{.stor};

  require Storable;           # We didn't need it until now

  # If the following line fails for you, your Storable.pm is old - upgrade
  
  Storable::lock_nstore($data, $cachefile);
  
}


##############################################################################
# Sub: StorableRestore()
#
# Wrapper routine for invoking Storable::retrieve() to read a cached parsed
# data structure.  Only returns cached data if the cache file exists and is
# newer than the source XML file.
#

sub StorableRestore {
  my($filename) = @_;
  
  my $cachefile = $filename;
  $cachefile =~ s{(\.xml)?$}{.stor};

  return unless(-r $cachefile);
  return unless((stat($cachefile))[9] > (stat($filename))[9]);

  unless($INC{'Storable.pm'}) {
    require Storable;           # We didn't need it until now
  }
  
  return(Storable::lock_retrieve($cachefile));
  
}


##############################################################################
# Sub: MemShareSave()
#
# Takes the supplied data structure reference and stores it away in a global
# hash structure.
#

sub MemShareSave {
  my($data, $filename) = @_;

  $MemShareCache{$filename} = [time(), $data];
}


##############################################################################
# Sub: MemShareRestore()
#
# Takes a filename and looks in a global hash for a cached parsed version.
#

sub MemShareRestore {
  my($filename) = @_;
  
  return unless($MemShareCache{$filename});
  return unless($MemShareCache{$filename}->[0] > (stat($filename))[9]);

  return($MemShareCache{$filename}->[1]);
  
}


##############################################################################
# Sub: MemCopySave()
#
# Takes the supplied data structure and stores a copy of it in a global hash
# structure.
#

sub MemCopySave {
  my($data, $filename) = @_;

  unless($INC{'Storable.pm'}) {
    require Storable;           # We didn't need it until now
  }
  
  $MemCopyCache{$filename} = [time(), Storable::dclone($data)];
}


##############################################################################
# Sub: MemCopyRestore()
#
# Takes a filename and looks in a global hash for a cached parsed version.
# Returns a reference to a copy of that data structure.
#

sub MemCopyRestore {
  my($filename) = @_;
  
  return unless($MemCopyCache{$filename});
  return unless($MemCopyCache{$filename}->[0] > (stat($filename))[9]);

  return(Storable::dclone($MemCopyCache{$filename}->[1]));
  
}


##############################################################################
# Sub/Method: XMLout()
#
# Exported routine for 'unslurping' a data structure out to XML.
#
# Expects a reference to a data structure and an optional list of option
# name => value pairs.
#

sub XMLout {

  # If this is not a method call, create an object

  my $self;
  if($_[0]  and  UNIVERSAL::isa($_[0], 'XML::Simple')) {
    $self = shift;
  }
  else {
    $self = new XML::Simple();
  }


  my $ref = shift;

  $self->handle_options('out', @_);


  # If namespace expansion is set, XML::NamespaceSupport is required

  if($self->{opt}->{nsexpand}) {
    require XML::NamespaceSupport;
    $self->{nsup} = XML::NamespaceSupport->new();
    $self->{ns_prefix} = 'aaa';
  }


  # Wrap top level arrayref in a hash

  if(UNIVERSAL::isa($ref, 'ARRAY')) {
    $ref = { anon => $ref };
  }


  # Extract rootname from top level hash if keeproot enabled

  if($self->{opt}->{keeproot}) {
    my(@keys) = keys(%$ref);
    if(@keys == 1) {
      $ref = $ref->{$keys[0]};
      $self->{opt}->{rootname} = $keys[0];
    }
  }
  
  # Ensure there are no top level attributes if we're not adding root elements

  elsif($self->{opt}->{rootname} eq '') {
    if(UNIVERSAL::isa($ref, 'HASH')) {
      my $refsave = $ref;
      $ref = {};
      foreach (keys(%$refsave)) {
        if(ref($refsave->{$_})) {
          $ref->{$_} = $refsave->{$_};
        }
        else {
          $ref->{$_} = [ $refsave->{$_} ];
        }
      }
    }
  }


  # Encode the hashref and write to file if necessary

  $self->{_ancestors} = [];
  my $xml = $self->value_to_xml($ref, $self->{opt}->{rootname}, '');
  delete $self->{_ancestors};

  if($self->{opt}->{xmldecl}) {
    $xml = $self->{opt}->{xmldecl} . "\n" . $xml;
  }

  if($self->{opt}->{outputfile}) {
    if(ref($self->{opt}->{outputfile})) {
      return($self->{opt}->{outputfile}->print($xml));
    }
    else {
      local(*OUT);
      open(OUT, ">$self->{opt}->{outputfile}") ||
        croak "open($self->{opt}->{outputfile}): $!";
      print OUT $xml || croak "print: $!";
      close(OUT);
    }
  }
  elsif($self->{opt}->{handler}) {
    require XML::SAX;
    my $sp = XML::SAX::ParserFactory->parser(
               Handler => $self->{opt}->{handler}
             );
    return($sp->parse_string($xml));
  }
  else {
    return($xml);
  }
}


##############################################################################
# Method: handle_options()
#
# Helper routine for both XMLin() and XMLout().  Both routines handle their
# first argument and assume all other args are options handled by this routine.
# Saves a hash of options in $self->{opt}.
#
# If default options were passed to the constructor, they will be retrieved
# here and merged with options supplied to the method call.
#
# First argument should be the string 'in' or the string 'out'.
#
# Remaining arguments should be name=>value pairs.  Sets up default values
# for options not supplied.  Unrecognised options are a fatal error.
#

sub handle_options  {
  my $self = shift;
  my $dirn = shift;


  # Determine valid options based on context

  my %known_opt; 
  if($dirn eq 'in') {
    @known_opt{@KnownOptIn} = @KnownOptIn;
  }
  else {
    @known_opt{@KnownOptOut} = @KnownOptOut;
  }


  # Store supplied options in hashref and weed out invalid ones

  if(@_ % 2) {
    croak "Options must be name=>value pairs (odd number supplied)";
  }
  my %raw_opt  = @_;
  my $opt      = {};
  $self->{opt} = $opt;

  while(my($key, $val) = each %raw_opt) {
    my $lkey = lc($key);
    $lkey =~ s/_//g;
    croak "Unrecognised option: $key" unless($known_opt{$lkey});
    $opt->{$lkey} = $val;
  }


  # Merge in options passed to constructor

  if($self->{def_opt}) {
    foreach (keys(%known_opt)) {
      unless(exists($opt->{$_})) {
        if(exists($self->{def_opt}->{$_})) {
          $opt->{$_} = $self->{def_opt}->{$_};
        }
      }
    }
  }


  # Set sensible defaults if not supplied
  
  if(exists($opt->{rootname})) {
    unless(defined($opt->{rootname})) {
      $opt->{rootname} = '';
    }
  }
  else {
    $opt->{rootname} = $DefRootName;
  }
  
  if($opt->{xmldecl}  and  $opt->{xmldecl} eq '1') {
    $opt->{xmldecl} = $DefXmlDecl;
  }

  if(exists($opt->{contentkey})) {
    if($opt->{contentkey} =~ m{^-(.*)$}) {
      $opt->{contentkey} = $1;
      $opt->{collapseagain} = 1;
    }
  }
  else {
    $opt->{contentkey} = $DefContentKey;
  }

  unless(exists($opt->{normalisespace})) {
    $opt->{normalisespace} = $opt->{normalizespace};
  }
  $opt->{normalisespace} = 0 unless(defined($opt->{normalisespace}));

  # Cleanups for values assumed to be arrays later

  if($opt->{searchpath}) {
    unless(ref($opt->{searchpath})) {
      $opt->{searchpath} = [ $opt->{searchpath} ];
    }
  }
  else  {
    $opt->{searchpath} = [ ];
  }

  if($opt->{cache}  and !ref($opt->{cache})) {
    $opt->{cache} = [ $opt->{cache} ];
  }
  if($opt->{cache}) {
    $_ = lc($_) foreach (@{$opt->{cache}});
  }
  
  if(exists($opt->{parseropts})) {
    if($^W) {
      carp "Warning: " .
           "'ParserOpts' is deprecated, contact the author if you need it";
    }
  }
  else {
    $opt->{parseropts} = [ ];
  }

  
  # Special cleanup for {forcearray} which could be regex, arrayref or boolean
  # or left to default to 0

  if(exists($opt->{forcearray})) {
    if(ref($opt->{forcearray}) eq 'Regexp') {
      $opt->{forcearray} = [ $opt->{forcearray} ];
    }

    if(ref($opt->{forcearray}) eq 'ARRAY') {
      my @force_list = @{$opt->{forcearray}};
      if(@force_list) {
        $opt->{forcearray} = {};
        foreach my $tag (@force_list) {
          if(ref($tag) eq 'Regexp') {
            push @{$opt->{forcearray}->{_regex}}, $tag;
          }
          else {
            $opt->{forcearray}->{$tag} = 1;
          }
        }
      }
      else {
        $opt->{forcearray} = 0;
      }
    }
    else {
      $opt->{forcearray} = ( $opt->{forcearray} ? 1 : 0 );
    }
  }
  else {
    if($StrictMode  and  $dirn eq 'in') {
      croak "No value specified for 'ForceArray' option in call to XML$dirn()";
    }
    $opt->{forcearray} = 0;
  }


  # Special cleanup for {keyattr} which could be arrayref or hashref or left
  # to default to arrayref

  if(exists($opt->{keyattr}))  {
    if(ref($opt->{keyattr})) {
      if(ref($opt->{keyattr}) eq 'HASH') {

        # Make a copy so we can mess with it

        $opt->{keyattr} = { %{$opt->{keyattr}} };

        
        # Convert keyattr => { elem => '+attr' }
        # to keyattr => { elem => [ 'attr', '+' ] } 

        foreach my $el (keys(%{$opt->{keyattr}})) {
          if($opt->{keyattr}->{$el} =~ /^(\+|-)?(.*)$/) {
            $opt->{keyattr}->{$el} = [ $2, ($1 ? $1 : '') ];
            if($StrictMode  and  $dirn eq 'in') {
              next if($opt->{forcearray} == 1);
              next if(ref($opt->{forcearray}) eq 'HASH'
                      and $opt->{forcearray}->{$el});
              croak "<$el> set in KeyAttr but not in ForceArray";
            }
          }
          else {
            delete($opt->{keyattr}->{$el}); # Never reached (famous last words?)
          }
        }
      }
      else {
        if(@{$opt->{keyattr}} == 0) {
          delete($opt->{keyattr});
        }
      }
    }
    else {
      $opt->{keyattr} = [ $opt->{keyattr} ];
    }
  }
  else  {
    if($StrictMode) {
      croak "No value specified for 'KeyAttr' option in call to XML$dirn()";
    }
    $opt->{keyattr} = [ @DefKeyAttr ];
  }


  # make sure there's nothing weird in {grouptags}

  if($opt->{grouptags} and !UNIVERSAL::isa($opt->{grouptags}, 'HASH')) {
    croak "Illegal value for 'GroupTags' option - expected a hashref";
  }


  # Check the {variables} option is valid and initialise variables hash

  if($opt->{variables} and !UNIVERSAL::isa($opt->{variables}, 'HASH')) {
    croak "Illegal value for 'Variables' option - expected a hashref";
  }

  if($opt->{variables}) { 
    $self->{_var_values} = { %{$opt->{variables}} };
  }
  elsif($opt->{varattr}) { 
    $self->{_var_values} = {};
  }

}


##############################################################################
# Method: find_xml_file()
#
# Helper routine for XMLin().
# Takes a filename, and a list of directories, attempts to locate the file in
# the directories listed.
# Returns a full pathname on success; croaks on failure.
#

sub find_xml_file  {
  my $self = shift;
  my $file = shift;
  my @search_path = @_;


  my($filename, $filedir) =
    File::Basename::fileparse($file);

  if($filename ne $file) {        # Ignore searchpath if dir component
    return($file) if(-e $file);
  }
  else {
    my($path);
    foreach $path (@search_path)  {
      my $fullpath = File::Spec->catfile($path, $file);
      return($fullpath) if(-e $fullpath);
    }
  }

  # If user did not supply a search path, default to current directory

  if(!@search_path) {
    if(-e $file) {
      return($file);
    }
    croak "File does not exist: $file";
  }

  croak "Could not find $file in ", join(':', @search_path);
}


##############################################################################
# Method: collapse()
#
# Helper routine for XMLin().  This routine really comprises the 'smarts' (or
# value add) of this module.
#
# Takes the parse tree that XML::Parser produced from the supplied XML and
# recurses through it 'collapsing' unnecessary levels of indirection (nested
# arrays etc) to produce a data structure that is easier to work with.
#
# Elements in the original parser tree are represented as an element name
# followed by an arrayref.  The first element of the array is a hashref
# containing the attributes.  The rest of the array contains a list of any
# nested elements as name+arrayref pairs:
#
#  <element name>, [ { <attribute hashref> }, <element name>, [ ... ], ... ]
#
# The special element name '0' (zero) flags text content.
#
# This routine cuts down the noise by discarding any text content consisting of
# only whitespace and then moves the nested elements into the attribute hash
# using the name of the nested element as the hash key and the collapsed
# version of the nested element as the value.  Multiple nested elements with
# the same name will initially be represented as an arrayref, but this may be
# 'folded' into a hashref depending on the value of the keyattr option.
#

sub collapse {
  my $self = shift;


  # Start with the hash of attributes
  
  my $attr  = shift;
  if($self->{opt}->{noattr}) {                    # Discard if 'noattr' set
    $attr = {};
  }
  elsif($self->{opt}->{normalisespace} == 2) {
    while(my($key, $value) = each %$attr) {
      $attr->{$key} = $self->normalise_space($value)
    }
  }


  # Do variable substitutions

  if(my $var = $self->{_var_values}) {
    while(my($key, $val) = each(%$attr)) {
      $val =~ s{\$\{(\w+)\}}{ $self->get_var($1) }ge;
      $attr->{$key} = $val;
    }
  }


  # Add any nested elements

  my($key, $val);
  while(@_) {
    $key = shift;
    $val = shift;

    if(ref($val)) {
      $val = $self->collapse(@$val);
      next if(!defined($val)  and  $self->{opt}->{suppressempty});
    }
    elsif($key eq '0') {
      next if($val =~ m{^\s*$}s);  # Skip all whitespace content

      $val = $self->normalise_space($val)
        if($self->{opt}->{normalisespace} == 2);

      # do variable substitutions

      if(my $var = $self->{_var_values}) { 
        $val =~ s{\$\{(\w+)\}}{ $self->get_var($1) }ge;
      }

      
      # look for variable definitions

      if(my $var = $self->{opt}->{varattr}) { 
        if(exists $attr->{$var}) {
          $self->set_var($attr->{$var}, $val);
        }
      }


      # Collapse text content in element with no attributes to a string

      if(!%$attr  and  !@_) {
        return($self->{opt}->{forcecontent} ? 
          { $self->{opt}->{contentkey} => $val } : $val
        );
      }
      $key = $self->{opt}->{contentkey};
    }


    # Combine duplicate attributes into arrayref if required

    if(exists($attr->{$key})) {
      if(UNIVERSAL::isa($attr->{$key}, 'ARRAY')) {
        push(@{$attr->{$key}}, $val);
      }
      else {
        $attr->{$key} = [ $attr->{$key}, $val ];
      }
    }
    elsif(defined($val)  and  UNIVERSAL::isa($val, 'ARRAY')) {
      $attr->{$key} = [ $val ];
    }
    else {
      if( $key ne $self->{opt}->{contentkey} 
          and (
            ($self->{opt}->{forcearray} == 1)
            or ( 
              (ref($self->{opt}->{forcearray}) eq 'HASH')
              and (
                $self->{opt}->{forcearray}->{$key}
                or (grep $key =~ $_, @{$self->{opt}->{forcearray}->{_regex}})
              )
            )
          )
        ) {
        $attr->{$key} = [ $val ];
      }
      else {
        $attr->{$key} = $val;
      }
    }

  }


  # Turn arrayrefs into hashrefs if key fields present

  my $count = 0;
  if($self->{opt}->{keyattr}) {
    while(($key,$val) = each %$attr) {
      if(defined($val)  and  UNIVERSAL::isa($val, 'ARRAY')) {
        $attr->{$key} = $self->array_to_hash($key, $val);
      }
      $count++;
    }
  }


  # disintermediate grouped tags

  if($self->{opt}->{grouptags}) {
    while(my($key, $val) = each(%$attr)) {
      next unless(UNIVERSAL::isa($val, 'HASH') and (keys %$val == 1));
      next unless(exists($self->{opt}->{grouptags}->{$key}));

      my($child_key, $child_val) =  %$val;

      if($self->{opt}->{grouptags}->{$key} eq $child_key) {
        $attr->{$key}= $child_val;
      }
    }
  }


  # Fold hashes containing a single anonymous array up into just the array

  if($count == 1 
     and  exists $attr->{anon}  
     and  UNIVERSAL::isa($attr->{anon}, 'ARRAY')
  ) {
    return($attr->{anon});
  }


  # Do the right thing if hash is empty, otherwise just return it

  if(!%$attr  and  exists($self->{opt}->{suppressempty})) {
    if(defined($self->{opt}->{suppressempty})  and
       $self->{opt}->{suppressempty} eq '') {
      return('');
    }
    return(undef);
  }

  return($attr)

}


##############################################################################
# Method: set_var()
#
# Called when a variable definition is encountered in the XML.  (A variable
# definition looks like <element attrname="name">value</element> where attrname
# matches the varattr setting).
#

sub set_var {
  my($self, $name, $value) = @_;

  $self->{_var_values}->{$name} = $value;
}


##############################################################################
# Method: get_var()
#
# Called during variable substitution to get the value for the named variable.
#

sub get_var {
  my($self, $name) = @_;

  my $value = $self->{_var_values}->{$name};
  return $value if(defined($value));

  return '${' . $name . '}';
}


##############################################################################
# Method: normalise_space()
#
# Strips leading and trailing whitespace and collapses sequences of whitespace
# characters to a single space.
#

sub normalise_space {
  my($self, $text) = @_;

  $text =~ s/^\s+//s;
  $text =~ s/\s+$//s;
  $text =~ s/\s\s+/ /sg;

  return $text;
}


##############################################################################
# Method: array_to_hash()
#
# Helper routine for collapse().
# Attempts to 'fold' an array of hashes into an hash of hashes.  Returns a
# reference to the hash on success or the original array if folding is
# not possible.  Behaviour is controlled by 'keyattr' option.
#

sub array_to_hash {
  my $self     = shift;
  my $name     = shift;
  my $arrayref = shift;

  my $hashref  = {};

  my($i, $key, $val, $flag);


  # Handle keyattr => { .... }

  if(ref($self->{opt}->{keyattr}) eq 'HASH') {
    return($arrayref) unless(exists($self->{opt}->{keyattr}->{$name}));
    ($key, $flag) = @{$self->{opt}->{keyattr}->{$name}};
    for($i = 0; $i < @$arrayref; $i++)  {
      if(UNIVERSAL::isa($arrayref->[$i], 'HASH') and
         exists($arrayref->[$i]->{$key})
      ) {
        $val = $arrayref->[$i]->{$key};
        if(ref($val)) {
          if($StrictMode) {
            croak "<$name> element has non-scalar '$key' key attribute";
          }
          if($^W) {
            carp "Warning: <$name> element has non-scalar '$key' key attribute";
          }
          return($arrayref);
        }
        $val = $self->normalise_space($val)
          if($self->{opt}->{normalisespace} == 1);
        $hashref->{$val} = { %{$arrayref->[$i]} };
        $hashref->{$val}->{"-$key"} = $hashref->{$val}->{$key} if($flag eq '-');
        delete $hashref->{$val}->{$key} unless($flag eq '+');
      }
      else {
        croak "<$name> element has no '$key' key attribute" if($StrictMode);
        carp "Warning: <$name> element has no '$key' key attribute" if($^W);
        return($arrayref);
      }
    }
  }


  # Or assume keyattr => [ .... ]

  else {
    ELEMENT: for($i = 0; $i < @$arrayref; $i++)  {
      return($arrayref) unless(UNIVERSAL::isa($arrayref->[$i], 'HASH'));

      foreach $key (@{$self->{opt}->{keyattr}}) {
        if(defined($arrayref->[$i]->{$key}))  {
          $val = $arrayref->[$i]->{$key};
          return($arrayref) if(ref($val));
          $val = $self->normalise_space($val)
            if($self->{opt}->{normalisespace} == 1);
          $hashref->{$val} = { %{$arrayref->[$i]} };
          delete $hashref->{$val}->{$key};
          next ELEMENT;
        }
      }

      return($arrayref);    # No keyfield matched
    }
  }
  
  # collapse any hashes which now only have a 'content' key

  if($self->{opt}->{collapseagain}) {
    $hashref = $self->collapse_content($hashref);
  }
 
  return($hashref);
}


##############################################################################
# Method: collapse_content()
#
# Helper routine for array_to_hash
# 
# Arguments expected are:
# - an XML::Simple object
# - a hasref
# the hashref is a former array, turned into a hash by array_to_hash because
# of the presence of key attributes
# at this point collapse_content avoids over-complicated structures like
# dir => { libexecdir    => { content => '$exec_prefix/libexec' },
#          localstatedir => { content => '$prefix' },
#        }
# into
# dir => { libexecdir    => '$exec_prefix/libexec',
#          localstatedir => '$prefix',
#        }

sub collapse_content {
  my $self       = shift;
  my $hashref    = shift; 

  my $contentkey = $self->{opt}->{contentkey};

  # first go through the values,checking that they are fit to collapse
  foreach my $val (values %$hashref) {
    return $hashref unless (     (ref($val) eq 'HASH')
                             and (keys %$val == 1)
                             and (exists $val->{$contentkey})
                           );
  }

  # now collapse them
  foreach my $key (keys %$hashref) {
    $hashref->{$key}=  $hashref->{$key}->{$contentkey};
  }

  return $hashref;
}
  

##############################################################################
# Method: value_to_xml()
#
# Helper routine for XMLout() - recurses through a data structure building up
# and returning an XML representation of that structure as a string.
# 
# Arguments expected are:
# - the data structure to be encoded (usually a reference)
# - the XML tag name to use for this item
# - a string of spaces for use as the current indent level
#

sub value_to_xml {
  my $self = shift;;


  # Grab the other arguments

  my($ref, $name, $indent) = @_;

  my $named = (defined($name) and $name ne '' ? 1 : 0);

  my $nl = "\n";

  if($self->{opt}->{noindent}) {
    $indent = '';
    $nl     = '';
  }



  # Convert to XML
  
  if(ref($ref)) {
    croak "circular data structures not supported"
      if(grep($_ == $ref, @{$self->{_ancestors}}));
    push @{$self->{_ancestors}}, $ref;
  }
  else {
    if($named) {
      return(join('',
              $indent, '<', $name, '>',
              ($self->{opt}->{noescape} ? $ref : $self->escape_value($ref)),
              '</', $name, ">", $nl
            ));
    }
    else {
      return("$ref$nl");
    }
  }


  # Unfold hash to array if possible

  if(UNIVERSAL::isa($ref, 'HASH')      # It is a hash
     and %$ref                         # and it's not empty
     and $self->{opt}->{keyattr}       # and folding is enabled
     and $indent                       # and its not the root element
  ) {
    $ref = $self->hash_to_array($name, $ref);
  }

  
  my @result = ();
  my($key, $value);


  # Handle hashrefs

  if(UNIVERSAL::isa($ref, 'HASH')) {

    # Reintermediate grouped values if applicable

    if($self->{opt}->{grouptags}) {
      while(my($key, $val) = each %$ref) {
        if($self->{opt}->{grouptags}->{$key}) {
          $ref->{$key} = { $self->{opt}->{grouptags}->{$key} => $val };
        }
      }
    }


    # Scan for namespace declaration attributes

    my $nsdecls = '';
    my $default_ns_uri;
    if($self->{nsup}) {
      $ref = { %$ref };                # Make a copy before we mess with it
      $self->{nsup}->push_context();

      # Look for default namespace declaration first

      if(exists($ref->{xmlns})) {
        $self->{nsup}->declare_prefix('', $ref->{xmlns});
        $nsdecls .= qq( xmlns="$ref->{xmlns}"); 
        delete($ref->{xmlns});
      }
      $default_ns_uri = $self->{nsup}->get_uri('');


      # Then check all the other keys

      foreach my $qname (keys(%$ref)) {
        my($uri, $lname) = $self->{nsup}->parse_jclark_notation($qname);
        if($uri) {
          if($uri eq $xmlns_ns) {
            $self->{nsup}->declare_prefix($lname, $ref->{$qname});
            $nsdecls .= qq( xmlns:$lname="$ref->{$qname}"); 
            delete($ref->{$qname});
          }
        }
      }

      # Translate any remaining Clarkian names

      foreach my $qname (keys(%$ref)) {
        my($uri, $lname) = $self->{nsup}->parse_jclark_notation($qname);
        if($uri) {
          if($default_ns_uri  and  $uri eq $default_ns_uri) {
            $ref->{$lname} = $ref->{$qname};
            delete($ref->{$qname});
          }
          else {
            my $prefix = $self->{nsup}->get_prefix($uri);
            unless($prefix) {
              # $self->{nsup}->declare_prefix(undef, $uri);
              # $prefix = $self->{nsup}->get_prefix($uri);
              $prefix = $self->{ns_prefix}++;
              $self->{nsup}->declare_prefix($prefix, $uri);
              $nsdecls .= qq( xmlns:$prefix="$uri"); 
            }
            $ref->{"$prefix:$lname"} = $ref->{$qname};
            delete($ref->{$qname});
          }
        }
      }
    }


    my @nested = ();
    my $text_content = undef;
    if($named) {
      push @result, $indent, '<', $name, $nsdecls;
    }

    if(keys %$ref) {
      while(($key, $value) = each(%$ref)) {
	next if(substr($key, 0, 1) eq '-');
        if(!defined($value)) {
          unless(exists($self->{opt}->{suppressempty})
             and !defined($self->{opt}->{suppressempty})
          ) {
            carp 'Use of uninitialized value' if($^W);
          }
          $value = {};
        }
        if(ref($value)  or  $self->{opt}->{noattr}) {
          push @nested,
            $self->value_to_xml($value, $key, "$indent  ");
        }
        else {
          $value = $self->escape_value($value) unless($self->{opt}->{noescape});
          if($key eq $self->{opt}->{contentkey}) {
            $text_content = $value;
          }
          else {
            push @result, ' ', $key, '="', $value , '"';
          }
        }
      }
    }
    else {
      $text_content = '';
    }

    if(@nested  or  defined($text_content)) {
      if($named) {
        push @result, ">";
        if(defined($text_content)) {
          push @result, $text_content;
          $nested[0] =~ s/^\s+// if(@nested);
        }
        else {
          push @result, $nl;
        }
        if(@nested) {
          push @result, @nested, $indent;
        }
        push @result, '</', $name, ">", $nl;
      }
      else {
        push @result, @nested;             # Special case if no root elements
      }
    }
    else {
      push @result, " />", $nl;
    }
    $self->{nsup}->pop_context() if($self->{nsup});
  }


  # Handle arrayrefs

  elsif(UNIVERSAL::isa($ref, 'ARRAY')) {
    foreach $value (@$ref) {
      if(!ref($value)) {
        push @result,
             $indent, '<', $name, '>',
             ($self->{opt}->{noescape} ? $value : $self->escape_value($value)),
             '</', $name, ">$nl";
      }
      elsif(UNIVERSAL::isa($value, 'HASH')) {
        push @result, $self->value_to_xml($value, $name, $indent);
      }
      else {
        push @result,
               $indent, '<', $name, ">$nl",
               $self->value_to_xml($value, 'anon', "$indent  "),
               $indent, '</', $name, ">$nl";
      }
    }
  }

  else {
    croak "Can't encode a value of type: " . ref($ref);
  }


  pop @{$self->{_ancestors}} if(ref($ref));

  return(join('', @result));
}


##############################################################################
# Method: escape_value()
#
# Helper routine for automatically escaping values for XMLout().
# Expects a scalar data value.  Returns escaped version.
#

sub escape_value {
  my($self, $data) = @_;

  return '' unless(defined($data));

  $data =~ s/&/&amp;/sg;
  $data =~ s/</&lt;/sg;
  $data =~ s/>/&gt;/sg;
  $data =~ s/"/&quot;/sg;

  return($data);
}


##############################################################################
# Method: hash_to_array()
#
# Helper routine for value_to_xml().
# Attempts to 'unfold' a hash of hashes into an array of hashes.  Returns a
# reference to the array on success or the original hash if unfolding is
# not possible.
#

sub hash_to_array {
  my $self    = shift;
  my $parent  = shift;
  my $hashref = shift;

  my $arrayref = [];

  my($key, $value);

  foreach $key (keys(%$hashref)) {
    $value = $hashref->{$key};
    return($hashref) unless(UNIVERSAL::isa($value, 'HASH'));

    if(ref($self->{opt}->{keyattr}) eq 'HASH') {
      return($hashref) unless(defined($self->{opt}->{keyattr}->{$parent}));
      push(@$arrayref, { $self->{opt}->{keyattr}->{$parent}->[0] => $key,
                         %$value });
    }
    else {
      push(@$arrayref, { $self->{opt}->{keyattr}->[0] => $key, %$value });
    }
  }

  return($arrayref);
}


##############################################################################
# Methods required for building trees from SAX events
##############################################################################

sub start_document {
  my $self = shift;

  $self->handle_options('in') unless($self->{opt});

  $self->{lists} = [];
  $self->{curlist} = $self->{tree} = [];
}


sub start_element {
  my $self    = shift;
  my $element = shift;

  my $name = $element->{Name};
  if($self->{opt}->{nsexpand}) {
    $name = $element->{LocalName} || '';
    if($element->{NamespaceURI}) {
      $name = '{' . $element->{NamespaceURI} . '}' . $name;
    }
  }
  my $attributes = {};
  if($element->{Attributes}) {  # Might be undef
    foreach my $attr (values %{$element->{Attributes}}) {
      if($self->{opt}->{nsexpand}) {
        my $name = $attr->{LocalName} || '';
        if($attr->{NamespaceURI}) {
          $name = '{' . $attr->{NamespaceURI} . '}' . $name
        }
        $name = 'xmlns' if($name eq $bad_def_ns_jcn);
        $attributes->{$name} = $attr->{Value};
      }
      else {
        $attributes->{$attr->{Name}} = $attr->{Value};
      }
    }
  }
  my $newlist = [ $attributes ];
  push @{ $self->{lists} }, $self->{curlist};
  push @{ $self->{curlist} }, $name => $newlist;
  $self->{curlist} = $newlist;
}


sub characters {
  my $self  = shift;
  my $chars = shift;

  my $text  = $chars->{Data};
  my $clist = $self->{curlist};
  my $pos = $#$clist;
  
  if ($pos > 0 and $clist->[$pos - 1] eq '0') {
    $clist->[$pos] .= $text;
  }
  else {
    push @$clist, 0 => $text;
  }
}


sub end_element {
  my $self    = shift;

  $self->{curlist} = pop @{ $self->{lists} };
}


sub end_document {
  my $self = shift;

  delete($self->{curlist});
  delete($self->{lists});

  my $tree = $self->{tree};
  delete($self->{tree});


  # Return tree as-is to XMLin()

  return($tree) if($self->{nocollapse});


  # Or collapse it before returning it to SAX parser class
  
  if($self->{opt}->{keeproot}) {
    $tree = $self->collapse({}, @$tree);
  }
  else {
    $tree = $self->collapse(@{$tree->[1]});
  }

  if($self->{opt}->{datahandler}) {
    return($self->{opt}->{datahandler}->($self, $tree));
  }

  return($tree);
}

*xml_in  = \&XMLin;
*xml_out = \&XMLout;

1;

__END__


