
PerlBin::Wx->new->MainLoop unless caller();


package PerlBin::Wx;
use strict;
use Wx::App;
use base qw(Wx::App);

sub OnInit {
    my $self  = shift;
    my $frame = PerlBin::Wx::Frame->new();
    $self->SetTopWindow($frame);
    $frame->Show(1);

    return 1;
}

package PerlBin::Wx::Frame;

use PerlBin;

use Wx::Perl::Carp qw[ croak carp ];
use strict;
use Cwd;
use Config;
use File::Basename;
use File::Path;
use File::Copy;
use File::Spec::Functions qw[ catfile rel2abs updir ];

use Wx qw[ :everything ];
use Wx::Event qw[ :everything ];
use base qw(Wx::Frame);

$PerlBin::VERSION = 0.01;

sub new {
    my ($class) = shift;
    my $self = $class->SUPER::new(
        undef, -1, __PACKAGE__,
        [ 0,   0 ],
        [ 450, 350 ],
        wxDEFAULT_FRAME_STYLE | wxCLIP_CHILDREN
    );

    $self->SetBackgroundColour(wxWHITE);
    $self->SetSizeHints( 450, 350 );
    $self->SetIcon( Wx::GetWxPerlIcon() );

    my $root = Wx::BoxSizer->new(wxVERTICAL);
    $self->SetSizer($root);
    $self->SetAutoLayout(1);    ## ;)
    $self->Layout();

    my $list = Wx::ListCtrl->new(
        $self, -1,
        [ -1, -1 ],
        [ -1, -1 ],
        wxLC_REPORT | wxLC_AUTOARRANGE | wxNO_BORDER
    );

    $list->InsertColumn( 0, "File" );
    $list->InsertColumn( 1, "Location" );
    $list->InsertColumn( 2, "Used by 1" );
    $self->{list} = $list;

    my $toolP = Wx::Panel->new( $self );
    $toolP->SetBackgroundColour(wxWHITE); # bg colour should be inherited IMHO
    my $toolSB = Wx::StaticBox->new( $toolP, -1, '*no script opened*' );
    $self->{toolSB} = $toolSB;

    my $toolS = Wx::StaticBoxSizer->new( $toolSB, wxHORIZONTAL );
    my $b1    = Wx::Button->new( $toolP, -1, "Open Script" );
    my $b2    = Wx::Button->new( $toolP, -1, "Add Dependency" );
    my $b3    = Wx::Button->new( $toolP, -1, "Select All" );
    my $b4    = Wx::Button->new( $toolP, -1, "Invert Selection" );

    $toolS->Add( $b1, 0, wxRIGHT | wxALIGN_CENTRE, 5 );
    $toolS->Add( $b2, 0, wxLEFT | wxRIGHT | wxALIGN_CENTRE, 5 );
    $toolS->Add( $b3, 0, wxLEFT | wxRIGHT | wxALIGN_CENTRE, 5 );
    $toolS->Add( $b4, 0, wxLEFT | wxRIGHT | wxALIGN_CENTRE, 5 );
    $toolP->SetSizer($toolS);
    $toolS->Fit($toolP);


    my $incSB = Wx::StaticBox->new( $self, -1, '@INC' );
    my $incS = Wx::StaticBoxSizer->new( $incSB, wxVERTICAL );

    my $inc = Wx::ListCtrl->new( $self, -1, [ -1, -1 ], [ -1, 50 ], wxLC_LIST );
    $inc->InsertStringItem( $_, $INC[$_] ) for 0..$#INC;


    $self->{incList} = $inc;

    my $b5 = Wx::Button->new( $self, -1, 'Add to @INC' );
    my $b6 = Wx::Button->new( $self, -1, 'Remove selected from @INC' );

    my $incS2 = Wx::BoxSizer->new(wxHORIZONTAL);
    $incS2->Add( $b5, 0, wxALIGN_CENTRE, 0 );
    $incS2->Add( $b6, 0, wxALIGN_CENTRE, 0 );
    $incS->Add( $incS2, 0, wxEXPAND | wxALIGN_CENTRE, 0 );
    $incS->Add( $inc, 1, wxEXPAND | wxGROW | wxALIGN_CENTRE, 0 );

    my $outSB      = Wx::StaticBox->new( $self, -1, "Pick a directory in which to create your new binary and lib" );
    my $outS       = Wx::StaticBoxSizer->new( $outSB, wxHORIZONTAL );
    my $b7         = Wx::Button->new( $self, -1, 'Pick Outdir' );
    my $outDirText = Wx::TextCtrl->new( $self, -1, cwd() );
    my $b8         = Wx::Button->new( $self,   -1, 'Create' );
    my $binaryText = Wx::TextCtrl->new( $self, -1, "" );
    my $binarySB   = Wx::StaticBox->new( $self, -1, "Your new binary executable's name goes here (type)" );
    my $binaryS    = Wx::StaticBoxSizer->new( $binarySB, wxHORIZONTAL );

    $self->{outDir} = $outDirText;
    $self->{outFile} = $binaryText;

    $outS->Add( $b7,            0, wxALIGN_CENTRE );
    $outS->Add( $outDirText,    1, wxEXPAND | wxGROW | wxALIGN_CENTRE );
    $binaryS->Add( $b8,         0, wxALIGN_CENTRE );
    $binaryS->Add( $binaryText, 1, wxEXPAND | wxGROW | wxALIGN_CENTRE );


## frame widget/control ordering (top to bottom)

    $root->Add( $toolP,   0, wxEXPAND | wxTOP | wxBOTTOM | wxALIGN_CENTRE,5 );
    $root->Add( $list,    1, wxEXPAND | wxTOP | wxBOTTOM, 5 );
    $root->Add( $outS,    0, wxEXPAND | wxALIGN_CENTRE | wxTOP | wxBOTTOM, 5 );
    $root->Add( $binaryS, 0, wxEXPAND | wxALIGN_CENTRE | wxTOP | wxBOTTOM, 5 );
    $root->Add( $incS,    0, wxEXPAND | wxALL, 0 );

## register events
    $self->SetAcceleratorTable(
        Wx::AcceleratorTable->new(
            [ wxACCEL_CTRL, 'O', $b1->GetId + 666, ],
            [ wxACCEL_CTRL, 'A', $b3->GetId + 666, ],
            [ wxACCEL_CTRL, 'I', $b4->GetId + 666, ],
        )
    );
    EVT_MENU( $self, $b1->GetId + 666, \&OnOpenFile );
    EVT_BUTTON( $self, $b1, \&OnOpenFile );
    EVT_BUTTON( $self, $b2, \&OnAddDependency );
    EVT_BUTTON( $self, $b3, \&OnSelectAll );
    EVT_MENU( $self, $b3->GetId + 666, \&OnSelectAll );
    EVT_BUTTON( $self, $b4, \&OnInvertSelection );
    EVT_MENU( $self, $b4->GetId + 666, \&OnInvertSelection);
    EVT_BUTTON( $self, $b5, \&OnAddToInc );
    EVT_BUTTON( $self, $b6, \&OnRemoveFromINC );
    EVT_BUTTON( $self, $b7, \&OnOutDir );
    EVT_BUTTON( $self, $b8, \&OnCreateBinary );
    EVT_LIST_COL_CLICK( $self, $list, \&OnSortList );

    return $self;
}

sub ListDeps {
    my $l = $_[0]->{list};
    $l->Show(0);
    $l->DeleteAllItems();
    my $ix   = 0;
    my $deps = $_[0]->{deps}->{deps};
    for my $k ( keys %{$deps} ) {
        my $id = $l->InsertStringItem( $ix++, $k );
        $l->SetItemData( $id, $id );
        $l->SetItem( $id, 1, $deps->{$k}->{file} );
        if ( exists $deps->{$k}->{used_by} ) {
            my $i = 2; 
            ## in case this file is used_by more than 1 other
            ## add a column (never came up in testing,
            ## think it's a bug in Module::ScanDeps, don't really care now ;)
            for ( @{ $deps->{$k}->{used_by} } ) {
                $l->InsertColumn( $i, "Used by $i" ) if $i == $l->GetColumnCount ;
                $l->SetItem( $id, $i, $_ );
                $i++;
            }
        }
    }
    $l->Show(1);
}

sub KosherINC {
    my $l = shift;
    @INC = ();
    if ( $l->GetItemCount() ) {
        my $i = -1;

        while ( -1 != ( $i = $l->GetNextItem( $i, wxLIST_NEXT_ALL ) ) ) {
            push @INC, $l->GetItemText($i);
        }
    }
}

sub OnSelectAll {
    my $l = $_[0]->{list};

    return unless $l->GetItemCount();

    $l->Show(0);

    for ( 0 .. $l->GetItemCount() - 1 ) {
        $l->SetItemState( $_, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
    }

    $l->Show(1);
}

sub OnOpenFile {
    my( $self ) = @_;
    my $str = Wx::FileSelector(
        'Load a script to turn into a binary',
        "", "", "",
        "Perl Files(*.pl;*.cgi)|*.pl;*.cgi ",
        wxOPEN | wxFILE_MUST_EXIST, 
    );

    if ($str) {
        $self->{deps} = PerlBin->new($str);
        $self->ListDeps();
        $self->{toolSB}->SetLabel($str);
        $self->OnSelectAll();
        $str = basename $str;
        $str =~ s{^(.*?)\.(.*?)\z}{$1$Config{exe_ext}};
        $self->{outFile}->SetValue($str);
    }
}

sub OnAddDependency {
    my( $self ) = @_;
    my $module = Wx::GetTextFromUser( "Enter module name (Foo::Bar)",
        "Input text", "" );
    if ($module) {
        $module =~ s[::][/]g;
        $module .= '.pm';
        $_[0]->{deps}->add_deps( $module );
        $self->{added} = [] unless exists $self->{added};
        push @{ $self->{added} }, $module;
        $self->ListDeps();
    }
}


sub OnInvertSelection {
    my $l = $_[0]->{list};

    $l->Show(0);

    for ( 0 .. $l->GetItemCount() - 1 ) {
        if ( $l->GetItemState( $_, wxLIST_STATE_SELECTED ) ==
            wxLIST_STATE_SELECTED )
        {
            $l->SetItemState( $_, 0, wxLIST_STATE_SELECTED );
        }
        else {
            $l->SetItemState( $_, wxLIST_STATE_SELECTED,
                wxLIST_STATE_SELECTED );
        }
    }

    $l->Show(1);
}


sub OnAddToInc {
    my $dir = Wx::DirSelector( 'Choose a directory to add to @INC', cwd() );
    my $l = $_[0]->{incList};
    if ($dir) {
        my $id = $l->InsertStringItem( $l->GetItemCount(), $dir );
        $l->SetItemData( $id, $id );
        KosherINC($l);
    }
}


sub OnRemoveFromINC {
    my $l = $_[0]->{incList};

    if ( $l->GetItemCount() ) {
        my $i = -1;
        my @items;
        while (
            -1 != (
                $i = $l->GetNextItem(
                    $i, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED
                )
            )
          )
        {
            push @items, $i;
        }
        @items = sort { $b <=> $a } @items;
        $l->DeleteItem($_) for @items;
    }
    KosherINC($l);
}

sub OnOutDir {
    my $dir =
      Wx::DirSelector(
        "Choose a EXISTING directory to put your new binary and lib",
        $_[0]->{outDir}->GetValue );
    $_[0]->{outDir}->SetValue($dir) if $dir;
}

sub OnSortList {
    my ( $self, $e ) = @_;
    my $list = $self->{list};
    $e = $e->GetColumn;    # means sort by that column
    $list->Show(0); # hide the list (don't want nobody clicking 50 times
    if ( exists $self->{"list.$e"} and $self->{"list.$e"} ) {
        $list->SortItems(
            sub {
                return
                  lc $list->GetItem( $list->FindItemData( -1, $_[0] ),
                    $e )->GetText cmp
                  lc $list->GetItem( $list->FindItemData( -1, $_[1] ),
                    $e )->GetText;
            }
        );
        $self->{"list.$e"} = 0;
    }
    else {
        $self->{"list.$e"} = 1;
        $list->SortItems(
            sub {
                return
                  lc $list->GetItem( $list->FindItemData( -1, $_[1] ),
                    $e )->GetText cmp
                  lc $list->GetItem( $list->FindItemData( -1, $_[0] ),
                    $e )->GetText;
            }
        );
    }
    $list->Show(1);
}

sub OnCreateBinary {

    my $script = rel2abs $_[0]->{toolSB}->GetLabel();
    my $outdir = rel2abs $_[0]->{outDir}->GetValue() || basename($script, qw[ .pl .pm .t .cgi .fcgi ]).'_perlbined';

    mkdir $outdir or carp "couldn't create $outdir ($!)";
    chdir $outdir or croak "couldn't chdir to $outdir ($!)";


    my $outfile = catfile $outdir, basename($script, qw[ .pl .pm .t .cgi .fcgi ]);;
    
    $outfile .= $Config{exe_ext};

    $_[0]->{deps}->PutBinary($script,$outfile); # turn $script into $outfile
    $_[0]->{deps}->PutSO($outdir);

    # not using $_[0]->{deps}->PutDeps($outdir); cause of the entire SELECTED BUSINESS
    mkdir 'lib' or carp "couldn't create `lib' in `$outdir' ($!)";
    chdir 'lib' or croak "couldn't chdir to `lib' in `$outdir' ($!) THIS IS BAD!!!";

    my $l = $_[0]->{list};

    if ( $l->GetSelectedItemCount() ) {
        my $i = -1;
        while (
            -1 != (
                $i = $l->GetNextItem(
                    $i, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED
                )
            )
          )
        {
            my $k = $l->GetItem($i,0)->GetText;
            my $v = $l->GetItem($i,1)->GetText;
            my $dirToMake = dirname($k);
            mkpath $dirToMake unless -e $dirToMake;
            copy( $v => $k ) or carp "Couldn't copy '$v' to '$k' : $!";
        }
    }

    $_[0]->messageBox(
        -default => 'Ok',
        -icon => 'info',
        -title => 'Hey...',
        -message => "All done now (if you don't see no errors, all is well:D)"
    );
}

#sub DESTROY { use Data::Dumper; print "\n" x 3, Dumper( \@_ ), "\n" x 3; }

1;