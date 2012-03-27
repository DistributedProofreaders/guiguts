package Archive::Zip::MemberRead;

#
# Copyright (c) 2002 Sreeji K. Das. All rights reserved.  This program is free
# software; you can redistribute it and/or modify it under the same terms
# as Perl itself.
#
# $Revision: 1.4 $

use strict;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

sub Archive::Zip::Member::readFileHandle
{
	return Archive::Zip::MemberRead->new( shift () );
}

sub new
{
	my ( $class, $zip, $file ) = @_;
	my ( $self, $member );

	if ( $zip && $file )    # zip and filename, or zip and member
	{
		$member = ref($file) ? $file : $zip->memberNamed($file);
	}
	elsif ( $zip && !$file && ref($zip) )    # just member
	{
		$member = $zip;
	}
	else
	{
		die (
'Archive::Zip::MemberRead::new needs a zip and filename, zip and member, or member'
		);
	}

	$self = {};
	bless( $self, $class );
	$self->set_member($member);
	return $self;
}

sub set_member
{
	my ( $self, $member ) = @_;

	$self->{member} = $member;
	$self->set_compression(COMPRESSION_STORED);
	$self->rewind();
}

sub set_compression
{
	my ( $self, $compression ) = @_;
	$self->{member}->desiredCompressionMethod($compression) if $self->{member};
}

sub rewind
{
	my $self = shift;

	$self->_reset_vars();
	$self->{member}->rewindData() if $self->{member};
}

sub _reset_vars
{
	my $self = shift;
	$self->{lines}   = [];
	$self->{partial} = 0;
	$self->{line_no} = 0;
}

sub input_line_number
{
	my $self = shift;
	return $self->{line_no};
}

sub close
{
	my $self = shift;

	$self->_reset_vars();
	$self->{member}->endRead();
}

sub buffer_size
{
	my ( $self, $size ) = @_;

	if ( !$size )
	{
		return $self->{chunkSize} || Archive::Zip::chunkSize();
	}
	else
	{
		$self->{chunkSize} = $size;
	}
}

# $self->{partial} flags whether the last line in the buffer is partial or not.
# A line is treated as partial if it does not ends with \n
sub getline
{
	my $self = shift;
	my ( $temp, $status, $size, $buffer, @lines );

	$status = AZ_OK;
	$size   = $self->buffer_size();
	$temp   = \$status;
	while ( $$temp !~ /\n/ && $status != AZ_STREAM_END )
	{
		( $temp, $status ) = $self->{member}->readChunk($size);
		if ( $status != AZ_OK && $status != AZ_STREAM_END )
		{
			die "ERROR: Error reading chunk from archive - $status\n";
		}

		$buffer .= $$temp;
	}

	@lines = split ( /\n/, $buffer );
	$self->{line_no}++;
	if ( $#lines == -1 )
	{
		return ( $#{ $self->{lines} } == -1 ) 
		  ? undef
		  : shift ( @{ $self->{lines} } );
	}

	$self->{lines}->[ $#{ $self->{lines} } ] .= shift (@lines)
	  if $self->{partial};

	splice( @{ $self->{lines} }, @{ $self->{lines} }, 0, @lines );
	$self->{partial} = !( $buffer =~ /\n$/ );
	return shift ( @{ $self->{lines} } );
}

#
# All these $_ are required to emulate read().
#
sub read
{
	my $self = $_[0];
	my $size = $_[2];
	my ( $temp, $status, $ret );

	( $temp, $status ) = $self->{member}->readChunk($size);
	if ( $status != AZ_OK && $status != AZ_STREAM_END )
	{
		$_[1] = undef;
		$ret = undef;
	}
	else
	{
		$_[1] = $$temp;
		$ret = length($$temp);
	}
	return $ret;
}

1;
