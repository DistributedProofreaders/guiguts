package Tk::Browser;  
my $RCSRevKey = '$Revision: 0.81 $';
$RCSRevKey =~ /Revision: (.*?) /;
$VERSION=0.80;
@ISA = qw( Tk::Widget DB );

use base qw(Tk::Widget);
use vars qw( @ISA $VERSION );
require Carp;
use Tk qw(Ev);
use Tk::DialogBox;
use Tk::Dialog;
use Tk::FileSelect;
use DB;
use IO::File;
use POSIX qw( tmpnam );
use Pod::Text;
use Lib::Module;
Construct Tk::Widget 'Tk::Browser';

my $menufont="*-helvetica-medium-r-*-*-12-*";
my $errordialogfont="*-helvetica-medium-r-*-*-14-*";
my $defaulttextfont="*-courier-medium-r-*-*-12-*";

my @modulenames = qw( Tk::Browser Lib::Module Lib::ModuleSym Lib::SymbolRef);

sub new {
    my $proto = shift;
    my $class = ref( $proto ) || $proto;
    my $self = {
	window => undef,
	filelist => undef, 
	symbollist => undef,
	listframe => undef,
	moduleframe => undef,
	symbolframe => undef,
	editor => undef,
	directories => [],
	# menubar menus
	menubar => undef,
	filemenu => undef,
	editmenu => undef,
	modulemenu => undef,	
	viewmenu => undef,
	symbolmenu => undef,
	helpmenu => undef,
	# Popup menus one for each panel.
	modulepopupmenu => undef,
	# this is derived from the text popup menu
	textpopupmenu => undef,
	symbolpopupmenu => undef,
	# parameters for current list search
	searchtext => undef,
	# index into filelist
	modulematched => undef,
	# index into symbollist
	symbolmatched => undef,
	# index of previous match in text.  necessary because
	# Tk::Text::FindNet wraps to the beginning of the 
	#file, instead of halting at the end.
	textmatched => undef,
	list_matched => undef,
	# radiobuttons 
	searchv => undef,
	symbolrefs => undef,
	# search options... 
	searchopts => (),
	#UNIVERSAL superclass
	defaultclass => undef,
	# Package selected in file list.  
	# App shouldn't have multiple selections unless they
        # can be constrained to separate listboxes...
	selectedpackage => undef,
	modview => undef,
	symbolview => undef,
    };
    $self -> {defaultclass} = new Lib::Module;
    ($self -> {defaultclass}) -> basename('');
    ($self -> {defaultclass}) -> packagename('');
    $self -> {defaultclass} -> pathname('');
    bless( $self, $class );
    return $self;
}

sub open {
    my $b = shift;
    my $w = $b -> window(new MainWindow);
    $b -> listframe($w -> Frame(-container => '0'));
    $b -> moduleframe(($b -> listframe) -> Frame(-container => '0'));
    $b -> symbolframe(($b -> listframe) -> Frame(-container => '0'));
    $b -> {filelist} = ($b -> moduleframe) -> 
		    Scrolled( 'Listbox', -font => $menufont, -width => 35,
			      -selectmode => 'single',
			      -scrollbars => 'se' );
    $b -> {symbollist} = ($b -> symbolframe) -> 
		      Scrolled( 'Listbox', -font => $menufont, -width => 35,
				-selectmode => 'single',
				-scrollbars => 'se' );
    $b -> {editor} = $w -> 
		   Scrolled( 'Text', -font => $defaulttextfont, -width => 80,
			     -exportselection => '1',
			    -scrollbars => 'se' );
    my $f = $b -> {filelist};
    my $s = $b -> {symbollist};
    my $e = $b -> {editor};
    foreach ( $f, $s, $e ) {
      $_ -> Subwidget('yscrollbar') -> configure(-width=>10);
      $_ -> Subwidget('xscrollbar') -> configure(-width=>10);
    }
    &menus($b, $w);
    $b -> listframe -> pack( -expand => '1', -fill => 'x');
    $b -> moduleframe -> pack(-side => 'left');
    $b -> symbolframe -> pack(-side => 'left',-expand => '1', -fill => 'x');
    $f -> pack( -anchor => 'w');
    $s -> pack( -anchor => 'w', -expand => '1', -fill => 'x');
    $e -> pack;
    $f -> bind( '<1>', sub{view_event( $f, $b )} );
    $w -> update;
    $b -> watchcursor;

    # parse out valid args.
    my (%args) = @_;
    my $def = $b -> defaultclass;
    if ( exists $args{package} ) { 
      my $pkg = $args{package};
      # match on either the file's basename or the "package"
      # name, so we're not dependent on the Perl lib hierarchy
      # here...
      &Tk::Event::DoOneEvent(255);
      $def -> libdirs;
      $def -> module_paths;
      my @allpaths = $def -> modulepathnames;
      my @matched_paths;
      # Unix-specific for the moment
      my $path = $pkg;
      $path =~ s/\:\:/\//;
      @matched_paths = grep /$path/, @allpaths;
      $def -> modinfo($matched_paths[0]);
      $f -> insert( 'end', $b -> defaultclass -> packagename);
      $b -> selectModule( 0 );
      &view_event( $f, $b );
    } elsif ( exists $args{pathname} ) {
      $def -> modinfo($args{pathname});
      $f -> insert( 'end', $b -> defaultclass -> packagename);
      $b -> selectModule( 0 );
      &view_event( $f, $b );
    } else { #invalid or non-existent arguments
      $f -> insert( 'end', 'Reading Library Modules...' );
      $def -> libdirs;
      $def -> module_paths;
      $def -> scanlibs;
      $f -> delete( 0 );
      $f -> insert( 'end', $def -> basename);
      foreach ( @{$def -> children}) {
	$b -> filelist -> insert( 'end', $_ -> basename );
      }
      $b -> modulematched( 0 );
      $b -> symbolmatched( 0 );
      $b -> textmatched( '1.0' );
    } 
    $b -> defaultcursor;
}

sub view_event {
  my( $self, $b) = @_;
  my $m = $b -> modview;
  $b -> selectedpackage( $self -> get ( $self -> curselection ) );
  $b -> window -> 
    configure( -title => 
	       "Browser [".$b -> selectedpackage."]" );
  $b -> window -> update;
  $b -> watchcursor;
  if ( $m =~ /source/ ) {
    &viewtext( $b );
  }
  if ( $m =~ /doc/ ) {
    &viewpod( $b );
  }
  if ( $m =~ /info/ ) {
    &viewinfo( $b );
  }
  $b -> defaultcursor;
}

sub viewmain {
  my ($b) = @_;
  &exported_key_list( $b, "main\:\:", 1 );
}

sub packagestashes {
  my ($b) = @_;
  my @oldlist;
  my @newlist;
  my $max = $b -> symbollist -> size;
  my $i;
  for( $i = 0; $i < $max; $i++ ) {
    push @oldlist, ($b -> symbollist -> get( $i ) );
  }
  @newlist = grep /\:\: => \{/, @oldlist;
  $b -> symbollist -> delete( 0, $max );
  foreach( @newlist ) { $b -> symbollist -> insert( 'end', $_ ) }
}

sub view_symbols {
  my $b = shift;
  my ($package) = @_;
  my $pkg = "main\:\:".$package."\:\:";
  if ( $b -> symbolrefs =~ /stash/ ) {
    &exported_key_list( $b, $pkg, 1 );
  } elsif ( $b -> symbolrefs =~ /lexical/ ) {
    &exported_key_list( $b, $pkg, 0 );
    &lexical_key_list( $b );
  } elsif ( $b -> symbolrefs =~ /xrefs/ ) {
    &exported_key_list( $b, $pkg, 0 );
    &lexical_key_list( $b );
  }
}

sub viewtext {
  my ($b) = @_;
  my $e = $b -> editor;
  my $lb = $b -> filelist;
  $e -> delete( '1.0', 'end' );
  my @text;
  my $m = new Lib::Module;
  if ( ! $b -> selectedpackage ) {
    return;
  }
  $m =  $b -> defaultclass -> retrieve_module( $b -> selectedpackage );
  $b -> view_symbols( $m -> packagename );
  @text = $m -> readfile;
  foreach ( @text ) { $e -> insert( 'end', $_ ) }
}

sub viewpod {
  my ($b) = @_;
  my $e = $b -> editor;
  my $lb = $b -> filelist;
  $e -> delete( '1.0', 'end' );
  my @text;
  my $m = new Lib::Module;
  if ( ! $b -> selectedpackage ) {
    return;
  }
  $m = $b -> defaultclass -> retrieve_module( $b -> selectedpackage );
  $b -> view_symbols( $m -> packagename );
  @text = podtext( $m );
  foreach( @text ) { $e -> insert( 'end', $_ ) }
}

sub viewinfo {
  my ($b) = @_;
  my $e = $b -> editor;
  my $lb = $b -> filelist;
  if ( ! $b -> selectedpackage ) {
    return;
  }
  my $m = new Lib::Module;
  $m = $b -> defaultclass -> retrieve_module( $b -> selectedpackage );
  $b -> view_symbols( $m -> packagename );
  $e -> delete( '1.0', 'end' );
  $e -> insert( 'end', "Name:         ".$m -> basename."\n" );
  $e -> insert( 'end', "Package:      ".$m -> packagename."\n");
  $e -> insert( 'end', "Version:      ".$m -> version."\n");
  $e -> insert( 'end', "Filename:     ".$m -> pathname."\n");
  $e -> insert( 'end', "Superclasses: ".$m -> superclasses."\n");
}

sub listimports {
  my ($b) = @_;
  my $d = 
    $b -> window -> DialogBox( -title => "Imported Modules from main::",
			       -buttons => ["View", "Close" ] );
  my $imlist = $d -> Scrolled( 'Listbox', -font => $menufont, 
			       -width => 80, -height => 15, 
			       -scrollbars => 'se' )
    -> pack;

  while ( my ( $key, $val ) = each %{*{"main\:\:"}} ) {
    if ( $key =~ /\_\</ ) {
      $key =~ s/\_\<//;
      $imlist -> insert( 'end', $key );
    }
  }
  my $resp = $d -> Show;
  if ( $resp =~ /View/ ) {
    &view_import( $imlist );
  }
}

sub view_import {
  my ($imlist) = @_; 
  my $bnew = new Tk::Browser;
  $bnew -> open( pathname => $imlist -> get( $imlist -> curselection) );
}

sub podtext {
  my ($m) = @_;
  my $modulepathname = $m -> pathname;
  my $help_text;
  my $helpwindow;
  my $textwidget;
  my $tmpfilename = "/tmp/$$.tmp";
  $help_text = 
    "Unable to process help text for $modulepathname."; 
  `pod2text $modulepathname $tmpfilename`;
  @help_text = $m -> readfile( $tmpfilename );
  unlink( $tmpfilename );
  return @help_text;
}

sub lexical_key_list {
  my ($b) = @_;
  my $kl = $b -> symbollist;
  my $fl = $b -> filelist;
  my $n = $fl -> get( $fl -> curselection );
  $kl -> delete( 0, $kl -> index( 'end' ) );
  if( $n eq '' ) { return; }
  my $m = new Lib::Module;
  my $contents;
  my @crossrefs;
  my $nrefs;
  $m = $b -> defaultclass -> retrieve_module( $n );
  foreach ( @{$m -> {symbols}} ) {
    $contents = $_->{name};
    $contents =~ s/^.*:://;
    next if( $contents eq '' );
    &Tk::Event::DoOneEvent(255);
    if( $b -> symbolrefs =~ /xrefs/ ) {
      @crossrefs = $m -> moduleinfo -> xrefs( $contents );
      if( ( $nrefs = @crossrefs ) > 0) {
	  $contents .= " <-- ";
	  foreach( @crossrefs ) {
	    $contents .= "$_, ";
	  }
       }
      $contents =~ s/, //;
    }
    $kl -> insert( 'end', $contents );
  }
}

# Call with browser object, name of stash, flag to display 
# results in list window. 
sub exported_key_list {
  my ($b, $stash, $list ) = @_;
  my $kl = $b -> symbollist;
  my $fl = $b -> filelist;
  my $n = $fl -> get( $fl -> curselection );
  if( $list ) {
    $kl -> delete( 0, $kl -> index( 'end') )
  }
  my $m = new Lib::Module;
  if ( $n ) { 
    $m = $b -> defaultclass -> retrieve_module( $n );
    &modImport( $m -> packagename );
  }
  $m -> exportedkeys( $stash );
  my $contents;
  $m -> moduleinfo -> xrefcache(()) if $b -> symbolrefs =~ /xrefs/;
  foreach my $s ( @{$m -> {symbols}} ) {
    if( $list ) {
      # Makes the scrollbar update weirdly.
      &Tk::Event::DoOneEvent(255);
    }
    $contents = '';
    # Lvalue globbing dereferencing deja
    # Devel::Symdump.pm and dumpvar.pl
    local (*v) = $s -> {name};

    if ( defined *v{ARRAY} ) { 
      $contents = '[ ';
      foreach ( @{*v{ARRAY}} ) {
	$contents .= "$_ ";
      }
      $contents .= ' ]';
      if( $list ) {
	$kl -> insert( 'end', $s -> {name}." => $contents" );
      }
    } elsif ( defined *v{CODE} ) { 
      if( $list ) {
	$kl -> insert( 'end', $s -> {name}." => sub" );
      }
    } elsif ( defined *v{HASH} && $key !~ /::/) { 
      $contents = '{ ';
      while ( my ($key_h, $val_h ) = each %{*v{HASH}} ) {
	$contents .= "$key_h => $val_h ";
      }
      $contents .= ' }';
      if( $list ) {
	$kl -> insert( 'end', $s -> {name}." => $contents" );
      }
    } elsif ( defined *v{IO} ) {
      $contents = '<'.$key.'>';
      if( $list ) {
	$kl -> insert( 'end', $s -> {name}." => $contents" );
      }
    } elsif ( defined ${*v{SCALAR}} ) {
      # If it's uninitialized don't list it.
      $contents = "\'${*v{SCALAR}}\'";
      if( $list ) {
	$kl -> insert( 'end', $s -> {name}." => $contents" );
      }
    }
  }
  return @{$m -> symbols};
}

sub modImport {
  my ($pkg) = @_;
  eval "package $pkg";
  eval "use $pkg";
  eval "require $pkg";
}

sub menus {
  my ($b, $w) = @_;
  my $items;
  $b -> {menubar} = $w -> Menu ( -type => 'menubar',
				 -font => $menufont );
  $b -> {filemenu}   = $b -> {menubar} -> Menu( -font => $menufont );
  $b -> {editmenu}   = $b -> {menubar} -> Menu( -font => $menufont );
  $b -> {modulemenu} = $b -> {menubar} -> Menu( -font => $menufont );
  $b -> {viewmenu}   = $b -> {menubar} -> Menu( -font => $menufont );
  $b -> {symbolmenu} = $b -> {menubar} -> Menu( -font => $menufont );
  $b -> {helpmenu}   = $b -> {menubar} -> Menu( -font => $menufont );

  $b -> menubar -> add ('cascade', -label => 'File', 
			-menu => $b -> {filemenu} );
  $b -> menubar ->add ('cascade', -label => 'Edit',
		       -menu => $b -> {editmenu} );
  $b -> menubar -> add ('cascade', -label => 'View',
			-menu => $b -> {viewmenu} );
  $b -> menubar ->add ('cascade', -label => 'Library',
		       -menu => $b -> {modulemenu} );
  $b -> menubar -> add ('cascade', -label => 'Package',
			-menu => $b -> {symbolmenu} );
  $b -> menubar -> add ('separator');
  $b -> menubar -> add ('cascade', -label => 'Help',
			-menu => $b -> {helpmenu} );
  $b -> menubar -> pack( -anchor => 'w', -fill => 'x' );
  $b -> filemenu -> add( 'command', -label => 'Open Selected Module',
			 -command => sub{ openSelectedModule( $b ) } );
  $b -> filemenu -> add( 'command', -label => 'Save Info...',
			 -command => sub{ saveInfo( $b ) } );
  $b -> filemenu -> add ('separator');
  $b -> filemenu -> add( 'command', -label => 'Exit',
			 -command => sub{ $b->window->WmDeleteWindow});
  $b -> editmenu -> add( 'command', -label => 'Copy',
			 -command => sub{$b->editor->clipboardCopy});
  $b -> editmenu -> add( 'command', -label => 'Cut',
			 -command => sub{$b->editor->clipboardCut});
  $b -> editmenu -> add( 'command', -label => 'Paste',
			 -command => sub{$b->editor->clipboardPaste});
  $b -> modulemenu -> add ( 'command', -label => 'Read Again',
			    -state => normal,
			    -command => sub{mod_reload($b)});
  $b -> modulemenu -> add ( 'command', -label => 'List Imported',
			    -state => normal,
			    -command => sub{listimports($b)});
  $b -> viewmenu -> add( 'radiobutton', -label => 'Source',
			 -variable => \$b -> {modview},
			 -value => 'source');
  $b -> viewmenu -> add( 'radiobutton', -label => 'POD Documentation',
			 -variable => \$b -> {modview},
			 -value => 'doc');
  $b -> viewmenu -> add( 'radiobutton', -label => 'Module Info',
			 -variable => \$b -> {modview},
			 -value => 'info');
  $b -> viewmenu -> invoke( 1 );
  $b -> viewmenu -> add ('separator');
  $b -> viewmenu -> add( 'command', -label => '*main:: Stash',
			 -state => normal,
			 -command => sub{viewmain($b)} );
  $b -> viewmenu -> add( 'command', -label => 'Package Stashes',
			 -state => normal,
			 -command => sub{packagestashes($b)} );
  $b -> symbolmenu -> add( 'radiobutton', -label => 'Symbol Table Imports',
			 -variable => \$b -> {symbolrefs},
			 -value => 'stash');
  $b -> symbolmenu -> add( 'radiobutton', -label => 'Lexical',
			 -variable => \$b -> {symbolrefs},
			 -value => 'lexical');
  $b -> symbolmenu -> add( 'radiobutton', -label => 'Cross References',
			 -variable => \$b -> {symbolrefs},
			 -value => 'xrefs');
  $b -> symbolmenu -> invoke( 1 );
  $b -> helpmenu -> add ( 'command', -label => 'About...',
			  -state => normal,
			  -command => sub{about($b)});
  $b -> helpmenu -> add ( 'command', -label => 'Help...',
			  -state => normal,
			  -accelerator => "F1",
			  -command => sub{self_help(__FILE__)});

  $b -> window -> SUPER::bind('<F1>', 
			      sub{self_help( __FILE__)});
  $b->modulepopupmenu($b->filelist->Menu(-type=>'normal',-tearoff => '',
					 -font=>$menufont ));
  $b->textpopupmenu($b->editor->Menu(-type=>'normal',-tearoff => '',
				     -font => $menufont ));
  $b->symbolpopupmenu($b->symbollist->Menu(-type=>'normal',-tearoff => '',
					   -font => $menufont ) );
  $b -> filelist -> bind( '<ButtonPress-3>',[\&postpopupmenu, 
					     $b -> modulepopupmenu,Ev('X'), Ev('Y') ] );
  $b -> symbollist -> bind( '<ButtonPress-3>',[\&postpopupmenu, 
					       $b -> symbolpopupmenu,Ev('X'), Ev('Y') ] );
  $b -> window -> bind('Tk::Text', '<3>','' );
  $b -> editor -> bind( '<ButtonPress-3>',[\&postpopupmenu, 
					   $b -> textpopupmenu,Ev('X'), Ev('Y') ] );
  $b -> modulepopupmenu -> add( 'command', -label => 'Find...',
				-command => [\&findModule, $b ]);
  $b -> modulepopupmenu -> add( 'command', -label => 'Selected Module',
				-command => [\&openSelectedModule, $b ]);
  $b -> symbolpopupmenu -> add( 'command', -label => 'Find...',
				-command => [\&findSymbol, $b]);
  $b -> textpopupmenu -> add( 'command', -label => 'Find...',
			      -command => [\&findText, $b]);
}

sub postpopupmenu {
  my $c = shift;
  my $m = shift;
  my $x = shift;
  my $y = shift;
  $m -> post( $x, $y );
}

sub findModule {
  my ($b) = @_;
  return unless $b -> searchdialog;
  my $max = $b -> filelist -> size;
  my $n = findfileliststring( $b, $b -> filelist );
  if ( $n ) {
    $b -> selectModule( $n );
    &view_event( $b -> filelist, $b );
#    $b -> view_symbols( $b );
  } else {
    &searchNotFound( $b );
    $b -> modulematched( 0 );
  }
}

sub openSelectedModule {
  my ($b) = @_;
  my $fl = $b -> {filelist};
  my $n = $fl -> get( $fl -> curselection );
  if( ! n ) { return; }
  my $module = $b -> defaultclass -> retrieve_module( $n );
  if( !$module) { &moduleNotFound($b); return; }
  my $newpathname = $module -> pathname;
  my $bnew = new Tk::Browser;
  $bnew -> open( pathname => $newpathname );
}

sub saveInfo {
  my ($b) = @_;
  my $f = $b -> filelist;
  my $s = $b -> symbollist;
  my $e = $b -> editor;
  my $fn;
  my $i;
  my $max;
  my $d = ($b -> window) -> FileSelect( -directory => '.');
  $d -> configure( -title => 'Save Information to File:' );
  $fn = $d -> Show;
  my $FileErr = 0;
  my $n;
  my $m;
  open FILE, ">>$fn" or 
    $FileErr = &fileError( $b, "Couldn't open $fn: $!\n" );
  if( ! $FileErr ) {
    $max = $f -> size;
    print FILE "\nModules:\n------------------------\n";
    for( $i = 0; $i < $max; $i++ ) {
      print FILE $f -> get( $i )."\n";
    }
    print FILE "\n\nSelected Module:\n------------------------\n";
    $n = $f -> get( $f -> curselection );
    if( $n ) { 
      $m = $b -> defaultclass -> retrieve_module( $n );
      if( $m ) {
	print FILE "Name:         ".$m -> basename."\n";
	print FILE "Package:      ".$m -> packagename."\n";
	print FILE "Version:      ".$m -> version."\n";
	print FILE "Filename:     ".$m -> pathname."\n";
	print FILE "Superclasses: ".$m -> superclasses."\n";
      }
    }
    print FILE "\n\nSymbols:\n------------------------\n";
    $max = $s -> size;
    for( $i = 0; $i < $max; $i++ ) {
      print FILE $s -> get( $i )."\n";
    }
    print FILE "\n\nText:\n------------------------\n\n";
    print FILE $e -> get( '1.0', 'end' );
    close FILE;
  }
}

sub fileError {
  my ($b, $text) = @_;
  my $d = $b -> window -> Dialog( -title => 'File Error',
				  -text => $text,
				  -bitmap => 'info',
				  -buttons => [qw/Ok/] );
  $d -> configure( -font => $errordialogfont );
  $d -> Show;
  return 1;
}

sub findSymbol {
  my ($b) = @_;
  my $s = $b -> symbollist;
  return unless $b -> searchdialog;
  my $max = $b -> symbollist -> size;
  my $n = findsymbolliststring( $b, $b -> symbollist );
  if ( $n ) {
    $s -> selectionClear( 0, $max );
    $s -> see( $n );
    $s -> selectionSet( $n );
  } else {
    &searchNotFound( $b );
  }
  
}

sub findsymbolliststring {
  my ($b, $l) = @_;
  my $m; my $n; my $e;
  my $w = $b -> window;
  my $st = $b -> searchtext;

  $n = $l -> size;
  for ( $m = ( $b -> symbolmatched + 1); $m < $n;  $m++ ) {
    $e = $l -> get( $m) ;
    if ( $e =~ /$st/ ) {
      $b -> symbolmatched( $m );
      return $m;
    }
  }
  $b -> symbolmatched( 0 );
  return 0;
}

sub findText {
  my ($b) = @_;
  my $e = $b -> editor;
  return unless $b -> searchdialog;
  my $findex;
  my $l = length $b -> searchtext;
  if ( ($findex = &find_next( $b) ) != '' ) {
    $e -> tagRemove( 'sel', '1.0', 'end' );
    $b -> textmatched( $findex );
    $e -> markSet( 'insert', $findex );
    $e -> see( $findex );
    $e -> tagAdd( 'sel', 'insert', 
		  ( $e -> index('insert') + "0\.$l" ) ); 
  } else {
    &searchNotFound( $b );
    $b -> textmatched( '1.0' );
  }
}

sub find_next {
  my ($b ) = @_;
  $b -> textmatched( ($b -> textmatched) + '0.1' );
  return $b -> editor -> search( '-forward','-exact','-nocase',
				 $b -> searchtext, 
				 $b -> textmatched,
				 'end' );
}

sub searchdialog {
  my $b = shift;
  my $w = $b -> window;
  my $l = $b -> filelist;
  my $d = $w -> DialogBox( -title => 'Find Library Text',
			-buttons => ["Search" , "Cancel" ] );
  my $labl = $d -> add( 'Label', -justify => 'left',
		     -text => 'Enter the text to search for.',
		     -font => $menufont ) -> pack( -anchor => 'w' );
  my $e = $d -> add( 'Entry' ) -> pack( -expand => '1',
				     -fill => 'both');
  my $resp = $d -> Show;
  $b -> searchtext( $e -> get );
  if ( ( $b -> searchtext ) && ( $resp =~ /Search/ ) ) {
    return $b -> searchtext;
  } else {
    return undef;
  }
}

sub filedialog {
  my $b = shift;
  my $w = $b -> window;
  my $l = $b -> filelist;
  my $d; 
  my $e; my $labl; my $labl2; my $labl3; my $m; my $n; my $e;
  my $st;
  $d = $w -> DialogBox( -title => 'Open Browser',
			-buttons => ["Ok" , "Cancel" ] );
  $labl = $d -> add( 'Label', -justify => 'left',
		     -text => 'Enter the module name to search for.',
		     -font => $menufont ) -> pack( -anchor => 'w' );
  $e = $d -> add( 'Entry' ) -> pack( -expand => '1',
				     -fill => 'both');
  my $resp = $d -> Show;
  my $modulename = $e -> get ;
  if ( ( $modulename ) && ( $resp =~ /Ok/ ) ) {
    return $modulename;
  } else {
    return undef;
  }
}

sub selectModule {
  my $b = shift;
  my $n = shift;
  my $l = $b -> filelist;
  my $w = $b -> window;
  $l -> selectionClear( 0, $l -> size );
  $l -> see( $n );
  $l -> selectionSet( $n );
  &viewtext( $b );
  $b -> selectedpackage( $l -> get ( $l -> curselection ) );
  $w -> configure( -title => 
		   "Browser [".$b -> selectedpackage."]" );
}

sub searchNotFound {
  my ($b) = @_;
  my $w = $b -> window;
  $d = $w -> Dialog( -title => 'Not Found', 
		     -text => 'The search text was not found.',
		     -font => $errordialogfont,
		     -bitmap => 'info' );
  $d -> Show;
}

sub moduleNotFound {
  my ($b) = @_;
  my $w = $b -> window;
  $d = $w -> Dialog( -title => 'Not Found', 
		     -text => 'The module was not found.',
		     -font => $errordialogfont,
		     -bitmap => 'info' );
  $d -> Show;
}

sub findfileliststring {
  my ($b, $l) = @_;
  my $m; my $n; my $e;
  my $w = $b -> window;
  my $st = $b -> searchtext;

  $n = $l -> size;
  for ( $m = ( $b -> modulematched + 1); $m < $n;  $m++ ) {
    $e = $l -> get( $m) ;
    if ( $e =~ /$st/ ) {
      $b -> modulematched( $m );
      return $m;
    }
  }
  $b -> modulematched( 0 );
  return 0;
}

sub mod_reload {
  my ($b) = @_;
  my $i;
  $b -> {filelist} -> delete( 0, $b -> {filelist} -> index( 'end') );
  $b -> {filelist} -> insert( 'end', 'Reading Library Modules...' );

 Lib:Module -> DESTROY( $b -> {defaultclass} );
  ($b -> {defaultclass}) = Lib::Module -> new;
  $b -> watchcursor;
  $b -> {defaultclass} -> scanlibs;
  $b -> {filelist} -> delete( 0 );
  ($b -> {filelist}) -> insert( 'end', $b -> {defaultclass} -> {basename} );
  foreach ( @{$b -> {defaultclass} -> {children}}) {
    $b -> {filelist} -> insert( 'end', $_ -> {basename} );
  }
  $b -> defaultcursor;
}

sub about {
  my $self = shift;
  my $aboutdialog;
  my $title_text;
  my $version_text;
  my $line_space;		# blank label as separator.

  $aboutdialog = 
    ($self -> {window}) -> 
      DialogBox( -buttons => ["Ok"],
		 -title => 'About' );
  $title_text = $aboutdialog -> add ('Label');
  $version_text = $aboutdialog -> add ('Label');
  $line_space = $aboutdialog -> add ('Label');

  $title_text -> configure ( -font => $menufont,
			     -text => 
			     'Browser.pm by rkiesling@mainmatter.com <Robert Kiesling>' );
  $version_text -> configure ( -font => $menufont,
			       -text => "Version $VERSION");
  $line_space -> configure ( -font =>$menufont,
			     -text => '');

  $line_space -> pack;
  $title_text -> pack;
  $version_text -> pack;
  $aboutdialog -> Show;
}

# Instance variable methods.  Refer to the perltoot
# man page.

sub window {
  my $self = shift;
  if (@_) {
    $self -> {window} = shift;
  }
  return $self -> {window}
}

sub filelist {
  my $self = shift;
  if (@_) {
    $self -> {filelist} = shift;
  }
  return $self -> {filelist}
}

sub symbollist {
  my $self = shift;
  if (@_) {
    $self -> {symbollist} = shift;
  }
  return $self -> {symbollist}
}

sub symbolrefs {
  my $self = shift;
  if (@_) {
    $self -> {symbolrefs} = shift;
  }
  return $self -> {symbolrefs}
}

sub listframe {
  my $self = shift;
  if (@_) {
    $self -> {listframe} = shift;
  }
  return $self -> {listframe}
}

sub moduleframe {
  my $self = shift;
  if (@_) {
    $self -> {moduleframe} = shift;
  }
  return $self -> {moduleframe}
}

sub symbolframe {
  my $self = shift;
  if (@_) {
    $self -> {symbolframe} = shift;
  }
  return $self -> {symbolframe}
}

sub modulepopupmenu {
  my $self = shift;
  if (@_) {
    $self -> {modulepopupmenu} = shift;
  }
  return $self -> {modulepopupmenu}
}

sub textpopupmenu {
  my $self = shift;
  if (@_) {
    $self -> {textpopupmenu} = shift;
  }
  return $self -> {textpopupmenu}
}

sub symbolpopupmenu {
  my $self = shift;
  if (@_) {
    $self -> {symbolpopupmenu} = shift;
  }
  return $self -> {symbolpopupmenu}
}

sub editor {
  my $self = shift;
  if (@_) {
    $self -> {editor} = shift;
  }
  return $self -> {editor}
}

sub directories {
  my $self = shift;
  if (@_) {
    $self -> {directories} = shift;
  }
  return $self -> {directories}
}

sub menubar {
  my $self = shift;
  if (@_) {
    $self -> {menubar} = shift;
  }
  return $self -> {menubar}
}

sub filemenu {
  my $self = shift;
  if (@_) {
    $self -> {filemenu} = shift;
  }
  return $self -> {filemenu}
}

sub editmenu {
  my $self = shift;
  if (@_) {
    $self -> {editmenu} = shift;
  }
  return $self -> {editmenu}
}

sub modulemenu {
  my $self = shift;
  if (@_) {
    $self -> {modulemenu} = shift;
  }
  return $self -> {modulemenu}
}

sub searchmenu {
  my $self = shift;
  if (@_) {
    $self -> {searchmenu} = shift;
  }
  return $self -> {searchmenu}
}

sub viewmenu {
  my $self = shift;
  if (@_) {
    $self -> {viewmenu} = shift;
  }
  return $self -> {viewmenu}
}

sub symbolmenu {
  my $self = shift;
  if (@_) {
    $self -> {symbolmenu} = shift;
  }
  return $self -> {symbolmenu}
}

sub helpmenu {
  my $self = shift;
  if (@_) {
    $self -> {helpmenu} = shift;
  }
  return $self -> {helpmenu}
}

sub textmenu {
  my $self = shift;
  if (@_) {
    $self -> {textmenu} = shift;
  }
  return $self -> {textmenu}
}

sub textfilemenu {
  my $self = shift;
  if (@_) {
    $self -> {textfilemenu} = shift;
  }
  return $self -> {textfilemenu}
}

sub searchtext {
  my $self = shift;
  if (@_) {
    $self -> {searchtext} = shift;
  }
  return $self -> {searchtext}
}

sub modulematched {
  my $self = shift;
  if (@_) {
    $self -> {modulematched} = shift;
  }
  return $self -> {modulematched}
}

sub symbolmatched {
  my $self = shift;
  if (@_) {
    $self -> {symbolmatched} = shift;
  }
  return $self -> {symbolmatched}
}

sub textmatched {
  my $self = shift;
  if (@_) {
    $self -> {textmatched} = shift;
  }
  return $self -> {textmatched}
}

sub list_matched {
  my $self = shift;
  if (@_) {
    $self -> {list_matched} = shift;
  }
  return $self -> {list_matched}
}

sub searchv {
  my $self = shift;
  if (@_) {
    $self -> {searchv} = shift;
  }
  return $self -> {searchv}
}

sub defaultclass {
  my $self = shift;
  if (@_) {
    $self -> {defaultclass} = shift;
  }
  return $self -> {defaultclass}
}

sub modview {
  my $self = shift;
  if (@_) {
    $self -> {modview} = shift;
  }
  return $self -> {modview}
}

sub symbolview {
  my $self = shift;
  if (@_) {
    $self -> {symbolview} = shift;
  }
  return $self -> {symbolview}
}

sub selectedpackage {
  my $self = shift;
  if (@_) {
    $self -> {selectedpackage} = shift;
  }
  return $self -> {selectedpackage}
}

# for each subwidget
sub watchcursor {
  my $app = shift;
  $app -> window -> Busy( -recurse => '1' );
}

sub defaultcursor {
  my $app = shift;
  $app -> window -> Unbusy( -recurse => '1' );
}

sub self_help {
  my ($appfilename) = @_;
  my $help_text;
  my $helpwindow;
  my $textwidget;

  open( HELP, ("pod2text < $appfilename |") ) or $help_text = 
    "Unable to process help text for $appfilename."; 
  while (<HELP>) {
    $help_text .= $_;
  }
  close( HELP );

  $helpwindow = new MainWindow( -title => "$appfilename Help" );
  my $textframe = $helpwindow -> Frame( -container => 0, 
					-borderwidth => 1 ) -> pack;
    my $buttonframe = $helpwindow -> Frame( -container => 0, 
					  -borderwidth => 1 ) -> pack;
    $textwidget = $textframe  
	-> Scrolled( 'Text', 
		     -font => $defaulttextfont,
		     -scrollbars => 'e' ) -> pack( -fill => 'both',
						   -expand => 1 );
    $textwidget -> insert( 'end', $help_text );

    $buttonframe -> Button( -text => 'Close',
			    -font => $menufont,
			    -command => sub{$helpwindow -> DESTROY} ) ->
				pack;
}


1;

