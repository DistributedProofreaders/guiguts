package Tk::TableMatrix::SpreadsheetHideRows;

use Carp;


use Tk;
use Tk::TableMatrix::Spreadsheet;
use Tk::Derived;

use base qw/ Tk::Derived Tk::TableMatrix::Spreadsheet/;

$VERSION = '1.1';


Tk::Widget->Construct("SpreadsheetHideRows");


sub ClassInit{
	my ($class,$mw) = @_;

	$class->SUPER::ClassInit($mw);
	
	

};


sub Populate {
    my ($self, $args) = @_;
    
    $self->ConfigSpecs(
       -selectorCol     => 	[qw/METHOD selectorCol     SelectorCol/,    undef],
       -selectorColWidth=> 	[qw/PASSIVE selectorColWidth     SelectorColWidth/,    2],
       -expandData      => 	[qw/METHOD expandData     ExpandData/,    {}],
   );

    
    $self->SUPER::Populate($args);
    
    $self->tagConfigure('plus', -image =>  $self->Getimage("plus"), -showtext => 0);
    $self->tagConfigure('minus', -image =>  $self->Getimage("minus"), -showtext => 0);
    
    $self->{normalCursor} = $self->cget('-cursor'); # get the default cursor
 
 
}

sub showDetail{

	my $self = shift;
	
	my $row = shift;
	
	my $selectorCol = $self->cget(-selectorCol);
	
	my $index = "$row,$selectorCol"; # make index for the cell to be expanded
	
	my $indRowCols = $self->{indRowCols};
	
	$self->tagCell('minus', $index);
	$indRowCols->{$index} = '-';
	
	# Get the detail data and insert:
	my $expandData = $self->{'_expandData'};
	my $detailData = $expandData->{$row};
	my $detailArray = $detailData->{data};
	
	my $noRows = scalar( @$detailArray);
	
	# InsertRows:
	$self->insertRows($row,$noRows);
	
	# Adjust Spans:
	$self->adjustSpans($row,$noRows);
	
	#insert data
	my $colorigin =  $self->cget(-colorigin);
	my $rowNum = $row+1;
	foreach my $rowData( @$detailArray ){
		#my @rowArray = @$rowData; 
		#grep s/([\{\}])/\\$1/g, @rowArray; # backslash any existing '{' chars, so they don't get interpreted as field chars
		my $insertData = "{".join("}{", @$rowData)."}"; # make insert data look like tcl array, so it
								# gets put in different cells
		$self->set('row', "$rowNum,$colorigin", $insertData);
		$rowNum++;
	}
	
	# Apply Tags, if any:
	my $tag;
	if( defined( $detailData->{tag})){
		$tag = $detailData->{tag};
		my $startRow = $row+1;
		my $noRows = @$detailArray;
		my $stopRow = scalar(@$detailArray) + $startRow - 1;
		my @tagRows = ($startRow..$stopRow);
		$self->tagRow($tag,@tagRows);
	}

	# Apply Spans, if any:
	my $spans;
	if( defined( $detailData->{spans})){
		$spans = $detailData->{spans};
		
		my $spanSize = scalar(@$spans);
		#Error Checking, spans array should be a multiple of 2
		if( ($spanSize % 2) < 1){
		
			my $startRow = $row+1;
			my $noRows = @$detailArray;
			my $stopRow = scalar(@$detailArray) + $startRow - 1;
			foreach my $spanRow($startRow..$stopRow){
				# build an array to feed to spans, change column number for row.col index
				#   (every 2rd item in the array).
				my @spanArray = map $_ % 2 ? $spans->[$_] : "$spanRow,".$spans->[$_], (0..($spanSize-1));
				$self->spans(@spanArray);
			}
			
		}else{
			warn("Spans array for row $row, is not a multiple of 2\n");
		}
			
	}

	
	
	
	# Now Update the internal arrays for the inserted rows ###
	my %expandDataNew;
	foreach my $rowIndex(keys %$expandData){
		if($rowIndex > $row){ # adjust rows greater than the current row
			$expandDataNew{$rowIndex+$noRows} = $expandData->{$rowIndex};
		}
		else{
			$expandDataNew{$rowIndex} = $expandData->{$rowIndex};
		}
	}
	# Copy new to existing:
	%$expandData = %expandDataNew;
	
	
	my %indRowColsNew;
	foreach my $rcindex(keys %$indRowCols){
		
		my ($rowIndex,$colIndex) = split(',',$rcindex);
		if($rowIndex > $row){ # adjust rows greater than the current row
			my $newRow = $rowIndex+$noRows;
			$indRowColsNew{"$newRow,$colIndex"} = $indRowCols->{$rcindex};
		}
		else{
			$indRowColsNew{$rcindex} = $indRowCols->{$rcindex};
		}
	}
	# Copy new to existing:
	%$indRowCols = %indRowColsNew;
	
	# Take care of any lower-level detail data:
	my $subDetail;
	if( defined( $detailData->{expandData})){
		$subDetail = $detailData->{expandData};
		
		foreach my $subRow( keys %$subDetail){
			
			my $realRow = $row+$subRow;
			my $index = "$realRow,$selectorCol";
			$self->tagCell('plus', $index);
			$indRowCols->{$index} = '+'; # update internal array
			
			# put subdetail data to top level, adjusting the relative row
			# numbers to real row numbers:
			#my %adjustedSubDetail;
			#foreach my $subKey(keys %$subDetail){
			#	$adjustedSubDetail{$subKey+$row} = $subDetail->{$subKey};
			#}
			$expandData->{$realRow} = $subDetail->{$subRow}; 
		}

	}

	
	
}

sub hideDetail{

	my $self = shift;
	
	my $row = shift;
	my $expandData = shift;
	my $detailData = $expandData->{$row};

	my $selectorCol = $self->cget(-selectorCol);
	
	my $index = "$row,$selectorCol"; # make index for the cell to be hidden
	
	my $indRowCols = $self->{indRowCols};

	# hide any sublevel data first:
	my $lowerLevelHideRows = 0;
	if( defined( $detailData->{expandData})){ # sublevel data exists
		my $subLevelData = $detailData->{expandData};
		# convert sublevel data to absolute rows
		my $convertedSubData = {};
		foreach my $rowNum(keys %$subLevelData){
			$convertedSubData->{$rowNum+$row} = $subLevelData->{$rowNum};
		}
		#Hide lower level data, if showing
		my $subLevelIndex;
		foreach my $rowNum (sort {$a<=>$b} keys %$convertedSubData){
			$subLevelIndex = "$rowNum,$selectorCol";
			if( $indRowCols->{$subLevelIndex} eq '-'){
				# For lower-level hide-detail calls, we don't use any updates to the
				#   expandData Arg, so we create an anonymous hash ref in this call
				$lowerLevelHideRows += $self->hideDetail($rowNum,{ %$convertedSubData} );
			}
		}
	}
				
	
	$self->tagCell('plus', $index);
	$indRowCols->{$index} = '+';
	
	
	# Get the detail data and hide:
	my $detailArray = $detailData->{data};
	
	my $noRows = scalar( @$detailArray);

	# unapply any spans (This is not auto-handled by the row delete command, so we
	#  have to do it here manually)
	my $spans;
	if( defined( $detailData->{spans})){
		$spans = $detailData->{spans};
		
		my $spanSize = scalar(@$spans);
		#Error Checking, spans array should be a multiple of 2
		if( ($spanSize % 2) < 1){
		
			my $startRow = $row+1;
			my $noRows = @$detailArray;
			my $stopRow = scalar(@$detailArray) + $startRow - 1;
			foreach my $spanRow($startRow..$stopRow){
				# build an array to feed to spans, change column number for row.col index
				#   (every 2rd item in the array).
				my @spanArray = map $_ % 2 ? '0,0' : "$spanRow,".$spans->[$_], (0..($spanSize-1));
				$self->spans(@spanArray);
			}
			
		}else{
			warn("Spans array for row $row, is not a multiple of 2\n");
		}
			
	}


	# Move Any existing spans that are at rows > $row+$noRows to where the should be, now that rows
	#  have been deleted
	$self->adjustSpans($row+$noRows,-$noRows);

	# deleteRows:
	$self->deleteRows($row+1,$noRows);

	my %indRowColsNew;
	foreach my $rcindex(keys %$indRowCols){
		
		my ($rowIndex,$colIndex) = split(',',$rcindex);
		if($rowIndex > $row){ # adjust rows greater than the current row
			my $newRow = $rowIndex-$noRows;
			$indRowColsNew{"$newRow,$colIndex"} = $indRowCols->{$rcindex};
		}
		else{
			$indRowColsNew{$rcindex} = $indRowCols->{$rcindex};
		}
	}
	# Copy new to existing:
	%$indRowCols = %indRowColsNew;	
	
	
	$noRows += $lowerLevelHideRows; # Include the lower level detail rows hidden in the internall array update


	# Now Update the internal arrays for the deleted rows ###
	my %expandDataNew;
	foreach my $rowIndex(keys %$expandData){
		if($rowIndex > ($row+$noRows)){ # adjust rows greater than the current row + detail data
			$expandDataNew{$rowIndex-$noRows} = $expandData->{$rowIndex};
		}
		elsif($rowIndex<= $row){ # rows less than or equal just get copied
			$expandDataNew{$rowIndex} = $expandData->{$rowIndex};
		}
		#else nothing, expand data that is in the detail data that is being hidden doesn't get copied
	}
	# Copy new to existing:
	%$expandData = %expandDataNew;
		
	return $noRows;


}

#----------------------------------------------
# Sub called when -expandData option changes
#
sub expandData{
	my ($self, $expandData) = @_;



	if(! defined($expandData)){ # Handle case where $widget->cget(-expandData) is called

		return $self->{Configure}{-expandData}
				
	}

	$self->clearSelectors;

	my $selectorCol = $self->cget(-selectorCol);
	
	# Create internal copy of expand Data for us to mess with
	my $expandData_int = {};
	%$expandData_int = %$expandData;
	$self->{'_expandData'} = $expandData_int;
	
	# update the indRowCols quick lookup hash:
	$self->updateIndRowCols($expandData, $selectorCol);
	
	$self->setSelectors;

	
}




#----------------------------------------------
# Sub called when -selectorCol option changes
#
sub selectorCol{
	my ($self, $selectorCol) = @_;



	if(! defined($selectorCol)){ # Handle case where $widget->cget(-selectorCol) is called
		#
		# Set default if not defined yet
		my $selCol;
		unless( defined($self->{Configure}{-selectorCol})){
			$selCol = $self->{Configure}{-selectorCol} = 0;
		}
		else{
			$selCol = $self->{Configure}{-selectorCol};
		}
		
		return $selCol;
				
	}

	###### Get Old Selector Col and undo Here ?????###
	$self->clearSelectors;
	
	my $expandData = $self->cget('-expandData');
	
	# update the indRowCols quick lookup hash:
	$self->updateIndRowCols($expandData, $selectorCol);
	
	$self->setSelectors;
	
}

# Method used to clear the selectors defined in the current indRowCols hash
sub setSelectors{
	my $self = shift;
	
	my $indRowCols = $self->{indRowCols};
	
	my @pluses = grep $indRowCols->{$_} eq '+', keys %$indRowCols;
	my @minuses = grep $indRowCols->{$_} eq '-', keys %$indRowCols;
	
	$self->tagCell('plus', @pluses);
	$self->tagCell('minus', @minuses);
	
	my $selectorCol = $self->cget('-selectorCol');
	my $selectorColWidth = $self->cget(-selectorColWidth)  || 2; # set to '2' (the default), incase this called before the defaults have been set
	$self->colWidth($selectorCol, $selectorColWidth);
	
}




# Method used to clear the selectors defined in the current indRowCols hash
sub clearSelectors{
	my $self = shift;
	
	my @indRowCols = keys %{$self->{indRowCols}};
	if( @indRowCols){
		$self->tagCell('', keys %{$self->{indRowCols}});
		
		# Get selectorCol from first entry
		my ($row,$col) = split(',',$indRowCols[0]);
		$self->colWidth($col, 'default');
	}
	
}
		

### Method to update indRowCols, based on the expandData and selectorCol
sub updateIndRowCols{

	my $self = shift;
	
	my($expandData, $selectorCol) = @_;
	
	my $indRowCols = {};
	
	foreach (keys %$expandData){
		$indRowCols->{"$_,$selectorCol"} = '+';
	}
	
	$self->{indRowCols} = $indRowCols;
	return $indRowCols;
	
}
	
# General Motion routine. Calls cellEnter if the pointer has entered another
#  cell.

sub GeneralMotion{

	my $self  = shift;
	my $Ev = $self->XEvent;

	my $rc = $self->index('@' . $Ev->x.",".$Ev->y);

	$self->SUPER::GeneralMotion;
	
	my ($row,$col) = split(',',$rc);

	my @border = $self->border('mark',$Ev->x,$Ev->y);
	if( scalar(@border) == 0 &&  (!($self->{lastrc}) || $rc ne $self->{lastrc})){ # call cellEnter if cell number has changed and we aren't on a border
		$self->{lastrc} = $rc;
		$self->cellEnter($row,$col);
	}
	

		
}

# Method called with the pointer goes over a different cell
#  Sets the cursor to a top-right arrow if over
#  the selectorCol

sub cellEnter{

	my $self  = shift;
	my ($row,$col) = @_;

	#print "Entered '$row,$col'\n";
	
	
	my $rowColResizeDrag = $self->{rowColResizeDrag};  # Flag = 1 if cursor has been changed for a row/col resize
	
	unless($rowColResizeDrag){
	
		my $indRowCols = $self->{indRowCols};
		
		if( defined( $indRowCols->{"$row,$col"})){ 
			#print "Setting ind cursor\n";
			$self->configure(-cursor => 'top_left_arrow');
		}
		else{
			#print "Setting old cursor back '".$self->{normalCursor}."'\n";
			$self->configure(-cursor => $self->{normalCursor});
		}
	}

		
}

		
#############################################################
## Over-ridden beginselect. Epands cell if +/- cell selected
sub BeginSelect{
	my $self  = shift;
	my $rc = shift;
	
	my $indRowCols = $self->{indRowCols}; # get quick lookup hash
	my $state;
	if( defined($indRowCols->{$rc})) {
		$state = $indRowCols->{$rc};
		my ($row,$col) = split(',',$rc);
		if( $state eq '-'){
			$self->hideDetail($row, $self->{'_expandData'});
		}
		else{
			$self->showDetail($row);
		}

		return;
	}
	
	# print "Calling inherited BeginSelect\n";
	$self->SUPER::BeginSelect($rc);
	
}


#------------------- 
#  Method Called to adjust spans starting at  $row by $noRows
#
#   If noRows is greater than 0 then the spans are adjusted up by $noRows
#   If noRows is negative, then spans are adjusted down by $noRows
#
#  This method is needed becase the rowinsert/delete methods of TableMatrix don't
#  automatically adjust the spans 
sub adjustSpans{
	
	my $self = shift;
	my ($row,$noRows) = @_;
	
	my %spans = $self->spans; # Get All Spans
	my %spansFilterd; # filtered for row > $row
	my $minRowFiltered = $row;
	my @filteredIndexes = grep  { my ($r,$c) = split(',',$_); $r >= $minRowFiltered}    keys %spans;
	my %unapplySpans; # temp hash used to unapply spans:
	@unapplySpans{@filteredIndexes} = map '0,0', @filteredIndexes;
	$self->spans(%unapplySpans);  # unapply the spans the filtered spans:
	my %adjustedSpans;
	foreach (@filteredIndexes){
		my ($r,$c) = split(',',$_);
		$adjustedSpans{($r+$noRows).",$c"} = $spans{$_};
	}
	
	# Apply adjusted Spans:
	$self->spans(%adjustedSpans);
	
}

1;

