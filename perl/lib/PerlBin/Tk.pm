
PerlBin::Tk->new->MainLoop unless caller();


package PerlBin::Tk;
## i'll rework it to oo after i get it done ;)
use Cwd;
use Config;
use PerlBin;
use File::Basename;
use File::Path;
use File::Copy;
use File::Spec::Functions qw[ catfile rel2abs updir ];
use Tk::MainWindow();
use Tk::LabFrame();
use Tk::Button();
use Tk::MListbox(); # DOCUMENTATION NEEDS EXAMPLE!!!!
use Tk::TList;
use Tk::Dialog;
use Tk::DirTree;
use Carp;

use base qw[Tk::MainWindow];
# this didn't work, means there's more to it
#@PerlBin::Tk::ISA = qw[Tk::MainWindow];

use strict;
BEGIN{ eval q[use warnings]; $^W = 1 if $@; }

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( # tkinit
        -borderwidth => 0,
        -relief      => 'flat',
        -title       => __PACKAGE__,
    );

    my $mw = $self; # ghetto, till it straighten it all out

    $mw->geometry('+300+30');  # xpos ypos, you can read this from config as well
    $mw->minsize(450,350);  # i wonder what this does, hmmm

    my $f = $mw->LabFrame(
        -label => "*no script opened yet*",
        -labelside => "acrosstop",
    );
    $self->{scriptLabel} = $f;

    ## there ain't on reason to save these buttons, none whatsoever
    $f->Button(-text => "Open Script", -command => [\&OnOpenFile,$self] )->pack(side => 'left',-padx => 5);
    $f->Button(-text => "Add Dependency", -command => [\&OnAddDependency,$self] )->pack(side => 'left',-padx => 5);
    $f->Button(-text => "Select All", -command => [\&OnSelectAll,$self])->pack(side => 'left',-padx => 5);
    $f->Button(-text => "Invert Selection", -command => [\&OnInvertSelection,$self])->pack(side => 'left',-padx => 5);
    
    my $mlist= $mw->Scrolled(
        MListbox => 
            -columns => [
                [ -text => "File" ],
                [ -text => "Location" ],
                [ -text => "Used by 1" ],
            ],
            -selectmode => "extended",
            -sortable => 1,
            -height => 1,    # this way minsize and other widgets are properly respected
        -scrollbars => 'se', #  it will grow to max it can without trampling others
    );
    
    $mlist->columnInsert('end',-text => "Used by 2"); # so i don't have to look it up later
    $self->{list} = $mlist;
    
    my $f2 = $mw->LabFrame(
        -label => "Pick a directory in which to create your new binary and lib",
        -labelside => "acrosstop",
    );

    
    $f2->Button(-text => "Pick Outdir", -command => [\&OnOutDir,$self] )->pack(side => 'left',-padx => 2);

    $self->{outdir} = cwd();

    $f2->Entry( -textvariable => \$self->{outdir},)->pack(-fill => 'x', -expand => 'yes',);

    my $f3 = $mw->LabFrame(
        -label => "Your new binary executable's name goes here (type)" ,
        -labelside => "acrosstop",
    );

    $f3->Button(-text => "Create", -command => [\&OnCreateBinary,$self] )->pack(side => 'left',-padx => 2);

    $self->{outfile} = '';
    $f3->Entry( -textvariable => \$self->{outfile},)->pack(-fill => 'x', -expand => 'yes',);

    ## the what is in @INC i wonder, hmmm
    my $f4 = $mw->LabFrame( -label => '@INC', -labelside => "acrosstop",);
    my $f4t = $f4->Frame()->pack(-side => 'top', -fill=>'x');
    $f4t->Button(
        -text => 'Add to @INC',
        -command => [\&OnAddToInc,$self],
    )->pack(side => 'left',-padx => 2, );

    $f4t->Button(
        -text => 'Remove selected from @INC',
        -command => [\&OnRemoveFromINC,$self],
    )->pack(side => 'left',-padx => 2,-anchor => 'e');


    my $incList = $f4->Scrolled(
#        Listbox => 
        TList =>
            -selectmode => "extended", # doesn't work, daMN, maybe it's the Scrolled
            -height => 3,
        -scrollbars => 'se', #  it will grow to max it can without trampling others
    )
#    ->grid(-column => 1, -row => 0, -rowspan => 2, -sticky =>'ew');
    ->pack( -expand => 'yes', -fill => 'both', -anchor => 's',-side=>'top');

#    $incList->insert('end'=> @INC);
    $incList->insert('end', -itemtype => 'text', -text => $_) for @INC;
    $self->{incList} = $incList;
    ## the root (so to speak
    $f->pack( -fill=>'x',);
    $mlist->pack(-fill=>'both', -expand=>'yes', ); # without expand, it don't really fill both
    $f2->pack( -fill=>'x',);
    $f3->pack( -fill=>'x',);
    $f4->pack( -fill=>'x',);

    $self->bind('<Control-Key-o>', [\&OnOpenFile,$self] );
    $self->bind('<Control-Key-a>', [\&OnSelectAll,$self] );
    $self->bind('<Control-Key-i>', [\&OnInvertSelection,$self] );

    
    return $self;
}



sub ListDeps {
    my $l = $_[0]->{list};
    $l->delete(0 , $l->index('end') ); # DeleteAllItems

    my $deps = $_[0]->{deps}->{deps};

    for my $k ( keys %{$deps} ) {
        $l->insert(
            end => [
                $k,
                $deps->{$k}->{file},
                exists $deps->{$k}->{used_by} ? @{$deps->{$k}->{used_by}} : ()
            ]
        );
    }

}

sub KosherINC {
    my $l = shift;

    @INC = ();

    if( $l->index('end')  ) { # index ain't documented (grr)
        for(0 .. $l->index('end') ) {
            push @INC, $l->entrycget($_ => '-text');
        }
    }
}


sub OnSelectAll { $_[0]->{list}->selectionSet(0 , $_[0]->{list}->index('end') ); }

sub OnOpenFile {
    my $file = $_[0]->getOpenFile(
        -filetypes => [
            [ 'Perl Files' => [ qw{ .pl .t .pm .cgi .fcgi },''] ],
            [ 'All files', '*'],
        ],
    );
    
    if($file){
        $_[0]->{scriptLabel}->configure(-label => $file);
        $_[0]->{deps} = PerlBin->new($file);
        $_[0]->ListDeps();
        $_[0]->OnSelectAll();
        $file = basename $file ;
        $file =~ s{^(.*?)\.(.*?)\z}{$1$Config{exe_ext}};
        $_[0]->{outfile} = $file;

    }
}

sub OnAddDependency {
    my $self = shift;
    my $dir = "";
    my $D = $self->DialogBox(
        -title => "Enter module name (Foo::Bar)",
        -buttons => [ qw[ Ok Cancel ] ],
        -width => 400,
        -height => 10,
    );

    $D->resizable(1,0);

    $D->Entry(
        -textvariable => \$dir,
    )->pack(-fill => 'x', -expand => 'yes',);

    if( $D->Show(1) eq 'Ok' ) {
        $self->{deps}->add_deps($dir);
    }
}


sub OnInvertSelection {
    my $l = $_[0]->{list};

    if( $l->index('end') ) {
        for(0 .. $l->index('end') ) {
            if($l->selectionIncludes($_)){
                $l->selectionClear($_);
            }else{
                $l->selectionSet($_);
            }
        }
    }
}


sub OnAddToInc {
    my $self = shift;
    my $dir = "";
    my $D = $self->DialogBox(
        -title => 'Choose a directory to add to @INC',
        -buttons => [ qw[ Ok Cancel ] ],
    );

    $D->DirTree(
        -showhidden => 1,
        -browsecmd => sub { $dir = $_[0]; },
    )->pack(-fill => 'both', -expand => 'yes',);

    if( $D->Show(1) eq 'Ok' ) {
        $self->{incList}->insert('end', -itemtype => 'text', -text => $dir);
        KosherINC($self->{incList});
    }
}


sub OnRemoveFromINC {

    my $l = $_[0]->{incList};
    my @items = sort { $b <=> $a } $l->curselection();

    $l->delete($_) for @items;

    KosherINC($l);

}

sub OnOutDir {
    my $self = shift;
    my $dir = "";
    my $D = $self->DialogBox(
        -title => 'Choose a directory to add to @INC',
        -buttons => [ qw[ Ok Cancel ] ],
    );

    $D->DirTree(
        -showhidden => 1,
        -browsecmd => sub { $dir = $_[0]; },
        -value => $self->{outdir},
    )->pack(-fill => 'both', -expand => 'yes',);

    if( $D->Show(1) eq 'Ok' ) {
        $self->{outdir} = $dir;
    }
}

sub OnCreateBinary {
        
    unless(exists $_[0]->{deps} and defined $_[0]->{deps}){
        $_[0]->messageBox(
            -icon => 'info',
            -title => 'Whoops..',
            -message => "Maybe you wanna open a script first? Thought so",
            -type => 'Ok',
        );
        return;
    }

    my $script = rel2abs $_[0]->{scriptLabel}->cget(-label);
    my $outdir = rel2abs $_[0]->{outdir} || basename($script, qw[ .pl .pm .t .cgi .fcgi ]).'_perlbined';

    mkdir $outdir or carp "couldn't create $outdir ($!)";
    chdir $outdir or croak "couldn't chdir to $outdir ($!)";


    my $outfile = catfile $outdir, basename($script, qw[ .pl .pm .t .cgi .fcgi ]);;    
    $outfile .= $Config{exe_ext};


    $_[0]->{deps}->PutBinary($script => $outfile); # turn $script into $outfile
    $_[0]->{deps}->PutSO($outdir);

    # not using $_[0]->{deps}->PutDeps($outdir); cause of the entire SELECTED BUSINESS
    mkdir 'lib' or carp "couldn't create `lib' in `$outdir' ($!)";
    chdir 'lib' or croak "couldn't chdir to `lib' in `$outdir' ($!) THIS IS BAD!!!";

    my $l = $_[0]->{list};

    for($l->curselection()) {
        if($l->selectionIncludes($_)){
                my($k, $v) = $l->getRow($_);
                my $dirToMake = dirname($k);
                mkpath $dirToMake unless -e $dirToMake;
                copy( $v => $k ) or carp "Couldn't copy '$v' to '$k' : $!";
        }
    }

    $_[0]->messageBox(
        -icon => 'info',
        -title => 'Hey..',
        -message => "All done (if there were any errors, you would've seen messages)",
        -type => 'Ok',
    );
}

#sub DESTROY { use Data::Dumper; print "\n" x 3, Dumper( \@_,\%PerlBin::Tk:: ), "\n" x 3; }
#sub DESTROY { use Data::Dumper; print "\n" x 3, Dumper( \@_ ), "\n" x 3; }
1;