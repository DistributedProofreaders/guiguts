$Tk::Thumbnail::VERSION = '1.1';

package Tk::Thumbnail;

use Carp;
use File::Basename;
use Tk::widgets qw/ JPEG LabEntry Pane PNG /;
use base qw/ Tk::Derived Tk::Pane /;
use vars qw/ $err /;
use strict;

Construct Tk::Widget 'Thumbnail';

sub ClassInit {

    my( $class, $mw ) = @_;

    $err = $mw->Photo( -data => $class->err );

    $class->SUPER::ClassInit( $mw );

} # end ClassInit

sub Populate {

    my( $self, $args ) = @_;

    $self->SUPER::Populate( $args );

    $self->ConfigSpecs(
        -background => [['DESCENDANTS', 'SELF'], 'background', 'Background',   undef],
        -command    => ['CALLBACK',              'command',    'Command',  \&button1],
        -iheight    => ['PASSIVE',               'iheight',    'Iheight',         32],
        -images     => ['PASSIVE',               'images',     'Images',       undef],
        -ilabels    => ['PASSIVE',               'ilabels',    'Ilabels',          1],
        -scrollbars => ['PASSIVE',               'scrollbars', 'Scrollbars',  'osow'],
        -iwidth     => ['PASSIVE',               'iwidth',     'Iwidth',          32],
    );

    $self->OnDestroy(
        sub {
            $err->delete;
            $self->free_photos;
        }
    );
      
} # end Populate

sub button1 {

    my( $label, $file, $bad_photo, $w, $h ) = @_;
    return if $bad_photo;

    my $tl = $label->Toplevel;
    $tl->withdraw;
    $tl->title( $file );
    $tl->minsize( 100, 100 );
    my $p = ( UNIVERSAL::isa( $file, 'Tk::Photo' ) ) ? $file : $tl->Photo( -file => $file );
    my $sp = $tl->Scrolled( 'Pane' )->pack( qw/ -fill both -expand 1 / );
    $sp->Label( -image => $p )->pack( qw/ -fill both -expand 1 / );
    $tl->protocol( 'WM_DELETE_WINDOW' => sub {
	$p->delete;
	$tl->destroy;
    } );
    my( $max_width, $max_height ) = ( $tl->vrootwidth - 100, $tl->vrootheight - 100 );
    $w = ( $w > $max_width )  ? $max_width  : $w;
    $h = ( $h > $max_height ) ? $max_height : $h;
    $tl->geometry( "${w}x${h}" );
    $tl->deiconify;

    $tl->bind( '<Button-1>' => [ \&photo_info, $tl, $file, $p, $w, $h ] );

} # end button1

sub photo_info {

    my( $lbl, $tl, $file, $photo, $w, $h ) = @_;

    my $tl_info = $tl->Toplevel;

    my $i = $tl_info->Labelframe( qw/ -text Image / )->pack( qw/ -fill x -expand 1 / );
    foreach my $item ( [ 'Width', $w ], [ 'Height', $h ] ) {
        my $l = $item->[0] . ':';
        my $le = $i->LabEntry(
            -label        => ' ' x ( 13 - length $l ) . $l,
            -labelPack    => [ qw/ -side left -anchor w / ],
            -labelFont    => '9x15bold',
            -relief       => 'flat',
            -textvariable => $item->[1],
            -width        => 35,
        );
        $le->pack(qw/ -fill x -expand 1 /);
    }

    my $f = $tl_info->Labelframe( qw/ -text File / )->pack( qw/ -fill x -expand 1 / );
    $file = $photo->cget( -file );
    my $size = -s $file;
    foreach my $item ( [ 'File', $file ], [ 'Size', $size ] ) {
        my $l = $item->[0] . ':';
        my $le = $f->LabEntry(
            -label        => ' ' x ( 13 - length $l ) . $l,
            -labelPack    => [ qw/ -side left -anchor w / ],
            -labelFont    => '9x15bold',
            -relief       => 'flat',
            -textvariable => $item->[1],
            -width        => 35,
        );
        $le->pack(qw/ -fill x -expand 1 /);
    }

    $tl_info->title( basename( $file ) );

} # end photo_info

sub ConfigChanged {

    # Called at the completion of a configure() command.

    my( $self, $changed_args ) = @_;
    $self->render if grep { /^\-images$/ } keys %$changed_args;

} # end ConfigChanged

sub render {

    # Create a Table of thumbnail images, having a default size of
    # 32x32 pixels.  Once we have a Photo of an image, copy a
    # subsample to a blank Photo and shrink it.  We  maintain a
    # list of our private images so their resources can be released
    # when the Thumbnail is destroyed.

    my( $self ) = @_;

    $self->clear;		# clear Table
    delete $self->{'descendants'};

    my $pxx = $self->cget( -iwidth );  # thumbnail pixel width
    my $pxy = $self->cget( -iheight ); # thumbnail pixel height
    my $lbl = $self->cget( -ilabels ); # display file names IFF true
    my $img = $self->cget( -images );  # reference to list of images
    croak "Tk::Thumbnail: -images not defined." unless defined $img;

    my $count = scalar @$img;
    my $rows = int( sqrt $count );
    $rows++ if $rows * $rows != $count;

  THUMB:
    foreach my $r ( 0 .. $rows - 1 ) {
	foreach my $c ( 0 .. $rows - 1 ) {
	    last THUMB if --$count < 0;

	    my $bad_photo = 0;
	    my $i = @$img[$#$img - $count];
	    my( $photo, $w, $h );
            Tk::catch { $photo = UNIVERSAL::isa($i, 'Tk::Photo') ? $i :
		$self->Photo( -file => $i ) };
	    if ( $@ ) {

		# Re-attempt using -format.

		foreach my $f ( qw/ jpeg png / ) {
		    Tk::catch { $photo = $self->Photo( -file => $i, -format => $f) };   
		    last if $photo;
		}
		unless ( $photo ) {
		    carp "Tk::Thumbnail: cannot make a Photo from '$i'.";
		    $photo = $err;
		    $bad_photo++;
		}
	    }

	    ( $w, $h ) = ( $photo->width, $photo->height );

	    my $subsample = $self->Photo;
	    my $sw = $pxx == -1 ? 1 : ( $w / $pxx );
	    my $sh = $pxy == -1 ? 1 : ( $h / $pxy );

	    if ( $sw >= 1 and $sh >= 1 ) {
                $sw = int( $sw + 0.5 );
                $sh = int( $sh + 0.5 );
		$subsample->copy( $photo, -subsample => ( $sw, $sh ) );
	    } else {
		Tk::catch { $subsample->copy( $photo, -zoom => (1 / $sw, 1 / $sh ) ) };
                carp "Tk::Thumbnail: error with '$i': $@" if $@;
	    }
	    push @{$self->{photos}}, $subsample;

	    my $f = $self->Frame;
	    my $l = $f->Label( -image => $subsample )->grid;
	    
	    $l->bind( '<Button-1>' => [ $self => 'Callback', '-command',
				      $l, $i, $bad_photo, $w, $h ] );
	    my $name = $photo->cget( -file );
	    $name = ( $name ) ? basename( $name ) : basename( $i );
	    $f->Label( -text => $name )->grid if $lbl;

	    $f->grid( -row => $r, -column => $c );
	    push @{$self->{'descendants'}}, $f;
	    
            $photo->delete unless UNIVERSAL::isa( $i, 'Tk::Photo' ) or $photo == $err;

	} # forend columns
    } #forend rows
             
} # end render

sub clear {

    my $self = shift;

    $self->free_photos;		# delete previous images

    foreach my $c ( @{$self->{'descendants'}} ) {
	$c->gridForget;
	$c->destroy;
    }

    $self->update;

} # end clear

sub free_photos {

    # Free all our subsampled Photo images.

    my $self = shift;

    foreach my $photo ( @{$self->{photos}} ) {
        $photo->delete;
    }
    delete $self->{photos};

} # end free_photos

sub err {

    return <<'endof-xpm';
/* XPM */
static char * huh[] = {
"128 128 17 1",
". c #fd8101",
"# c #fd6201",
"a c #fdae01",
"b c #fd8f01",
"c c #fd2501",
"d c #fdfa01",
"e c #fd4401",
"f c #fdbd01",
"g c #fddc01",
"h c #fd0701",
"i c #fd7201",
"j c #fd5301",
"k c #fd9f01",
"l c #fd3501",
"m c #fdeb01",
"n c #fdcc01",
"o c #fd1601",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddf.ieeeej.kgdddddddddddddddddddddddddf.ieeeej.kgdddddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddn#ohhhhhhhhhhhc.mdddddddddddddddddddn#ohhhhhhhhhhhc.mddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddm#hhhheeohhhhhhhhhobddddddddddddddddm#hhhheeohhhhhhhhhobdddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddnchhh.mdddkohhhhhhhhh#ddddddddddddddnchhh.mdddkohhhhhhhhh#ddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddgohhhbddddddmlhhhhhhhhh#ddddddddddddgohhhbddddddmlhhhhhhhhh#dddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddlhhhhmdddddddnhhhhhhhhhhbdddddddddddlhhhhmdddddddnhhhhhhhhhhbddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddd.hhhhhkdddddddd#hhhhhhhhhomddddddddd.hhhhhkdddddddd#hhhhhhhhhomdddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddchhhhhcmdddddddahhhhhhhhhh.dddddddddchhhhhcmdddddddahhhhhhhhhh.dddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddfhhhhhhhkdddddddmhhhhhhhhhhcddddddddfhhhhhhhkdddddddmhhhhhhhhhhcdddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddbhhhhhhhlddddddddchhhhhhhhhhmdddddddbhhhhhhhlddddddddchhhhhhhhhhmddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddd.hhhhhhhhgdddddddehhhhhhhhhhfddddddd.hhhhhhhhgdddddddehhhhhhhhhhfddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddd.hhhhhhhhfdddddddehhhhhhhhhhfddddddd.hhhhhhhhfdddddddehhhhhhhhhhfddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddnhhhhhhhhndddddddehhhhhhhhhhfdddddddnhhhhhhhhndddddddehhhhhhhhhhfddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddlhhhhhhcddddddddehhhhhhhhhhdddddddddlhhhhhhcddddddddehhhhhhhhhhdddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddgchhhhonddddddddchhhhhhhhhldddddddddgchhhhonddddddddchhhhhhhhhldddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddmbeeigdddddddddhhhhhhhhhhbddddddddddmbeeigdddddddddhhhhhhhhhhbdddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddddddddddfhhhhhhhhhomddddddddddddddddddddddddfhhhhhhhhhomdddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddd.hhhhhhhhhbddddddddddddddddddddddddd.hhhhhhhhhbddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddddddddddchhhhhhhh#ddddddddddddddddddddddddddchhhhhhhh#dddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddfhhhhhhhh#ddddddddddddddddddddddddddfhhhhhhhh#ddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddehhhhhhh#dddddddddddddddddddddddddddehhhhhhh#dddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddddddddfhhhhhhhbdddddddddddddddddddddddddddfhhhhhhhbddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddddddddehhhhhcnddddddddddddddddddddddddddddehhhhhcndddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddfhhhhhimddddddddddddddddddddddddddddfhhhhhimddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddehhhcfddddddddddddddddddddddddddddddehhhcfddddddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddddddghhhjmddddddddddddddddddddddddddddddghhhjmdddddddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddddddihh#ddddddddddddddddddddddddddddddddihh#dddddddddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddddddchjdddddddddddddddddddddddddddddddddchjddddddddddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddddddhhgdddddddddddddddddddddddddddddddddhhgddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddnhjdddddddddddddddddddddddddddddddddnhjdddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddfhbdddddddddddddddddddddddddddddddddfhbdddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddfhfdddddddddddddddddddddddddddddddddfhfdddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddfhmdddddddddddddddddddddddddddddddddfhmdddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddg.ddddddddddddddddddddddddddddddddddg.ddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddmffdddddddddddddddddddddddddddddddddmffdddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddnehhhh#mddddddddddddddddddddddddddddnehhhh#mddddddddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddnohhhhhhlmddddddddddddddddddddddddddnohhhhhhlmdddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddmohhhhhhhhedddddddddddddddddddddddddmohhhhhhhhedddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddbhhhhhhhhhhnddddddddddddddddddddddddbhhhhhhhhhhnddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddjhhhhhhhhhhbddddddddddddddddddddddddjhhhhhhhhhhbddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddehhhhhhhhhh.ddddddddddddddddddddddddehhhhhhhhhh.ddddddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddd#hhhhhhhhhhkdddddddddddddddddddddddd#hhhhhhhhhhkddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddkhhhhhhhhhhgddddddddddddddddddddddddkhhhhhhhhhhgddddddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddlhhhhhhhhiddddddddddddddddddddddddddlhhhhhhhhidddddddddddddddddddddddddddddddddddddddddddd",
"ddddddddddddddddddddddddddddddddddddddmlhhhhhh#dddddddddddddddddddddddddddmlhhhhhh#ddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddm.lhhekdddddddddddddddddddddddddddddm.lhhekdddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"};
endof-xpm
    
} # end err
 
1;
__END__

