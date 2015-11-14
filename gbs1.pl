#! \strawberry\perl\bin\perl
    eval 'exec perl $0 ${1+"$@"}'
	if 0;

use strict refs;
use strict vars;
use strict subs;
use File::Basename;
use File::Copy;
use lib 'D:\Aberscan\PerlApplications\PerlLibrary';
require "library.pl";

my $addressFile;

# Global Variables - initialized in parseCorecommandLine
my %cmdLine;

########################################################################
# This script tags photos with the info contained in the csv file
########################################################################

MAIN: {
    my @addresses;
    my $addressFileName;
    my $srcFolderName;
    my $destFolderName;
    my %addressLine;
    my $i = 0;
    my $addressCount = 0;
    my $photoMappingFile;
    

    my %switches = qw (
        -tagFileName optional
	-srcFolder required
	-destFolder optional
	-photoMappingFile optional
    );

    %cmdLine = parseCommandLine( %switches );

    # For now, map the cmdLine back to variables. I should replace all the unique global variables, but
    # I can't be bothered at the moment
    $addressFileName = $cmdLine{ "tagFileName"};
    $srcFolderName = $cmdLine{ "srcFolder"};
    $destFolderName = $cmdLine{ "destFolder"};

    #if destFolderName was not specified on the cmd line, then make it the same as the srcFolder
    if($destFolderName == "") {
        $destFolderName = "$srcFolderName\\tagged";
    }
    else {
        $destFolderName = "$destFolderName\\tagged";
    }

    $photoMappingFile = $cmdLine{ "photoMappingFile"};

    #first make sure I'm not trying to load an xls tagFile.All hell breaks loose if I do
    #if($addressFileName !=~ /csv$/) {
	#print("ERROR: tagFileName must be a csv file\n");
	#exit 4
    #}

    @addresses = readAddressFile ($addressFileName);

    $addressCount = scalar (@addresses);

    print("Found $addressCount compound addresses:\n");


} # MAIN


################################################################
# readAddressFileName
#
# This function reads the address from the input file and
# returns a two dimensional array containing the info
################################################################
sub readAddressFile {
    my ($addressFileName) = @_;
    my $line;
    my @addresses;
    my @addressLine;
    my @tmp;
    my $count = 0;
    my $i;
    my $addressCount;
    my %addressLine;
    my $mapFile;
open($mapFile, '>', "gbs.txt") or die "Can't open 'gbs.txt' for write: $!"; 

    # open up the mapping file in the output folder
    open(IN, "$addressFileName") or die "Can't open '$addressFileName' for read: $!";

    # ignore the first two lines
    $line = <IN>;
    $line = <IN>;
    while ($line = <IN>) {
	#print("AAA - line = '$line'\n");
	@tmp = split(/, */,$line);

	# check to see if the line was empty
	if($tmp[1] ne "") {
	    # first, reformat the date
	    $tmp[7] =~ s/\//-/g;

	    #if the 'numBuildings' is empty, default to 1
	    if($tmp[3] eq "") { $tmp[3] = 1; }

	    #if the houseNumber is "NA", then skip
	    if($tmp[1] eq "NA") { next; }

	    @addressLine = ("photo", $tmp[0], 
			"houseNumber", trim($tmp[1]),   #trim leading and trailing whitespace
			"streetName", trim($tmp[2]), 	#trim leading and trailing whitespace
			"numberOfBuildings",$tmp[3],  
			"sheetNumber", $tmp[4], 
			"negativeNumber", $tmp[5], 
			"photographer", $tmp[6], 
			"dateTaken", $tmp[7], 
			"notes", $tmp[8] );


	    #load the array - I should be able to do this in a simpler way, but I can't figure it out
	    $addresses[$count][0] = @addressLine[0];
	    $addresses[$count][1] = @addressLine[1];
	    $addresses[$count][2] = @addressLine[2];
	    $addresses[$count][3] = @addressLine[3];
	    $addresses[$count][4] = @addressLine[4];
	    $addresses[$count][5] = @addressLine[5];
	    $addresses[$count][6] = @addressLine[6];
	    $addresses[$count][7] = @addressLine[7];
	    $addresses[$count][8] = @addressLine[8];
	    $addresses[$count][9] = @addressLine[9];
	    $addresses[$count][10] = @addressLine[10];
	    $addresses[$count][11] = @addressLine[11];
	    $addresses[$count][12] = @addressLine[12];
	    $addresses[$count][13] = @addressLine[13];
	    $addresses[$count][14] = @addressLine[14];
	    $addresses[$count][15] = @addressLine[15];
	    $addresses[$count][16] = @addressLine[16];
	    $addresses[$count++][17] = @addressLine[17];
	}
    }
    close( IN );

    #print out the addresses
    $addressCount = scalar (@addresses);
    print("Raw (unpacked) addresses are: '$addressCount'\n");

    #for($i = 0 ; $i < $addressCount ; $i++) {
	#%addressLine = @{$addresses[$i]};
	#printAddressInfo(%addressLine);
    #}

    @addresses = mergeAddresses(@addresses);
    #print out the compound addresses
    print("Compound addresses are:\n");
    $addressCount = scalar (@addresses);
    for($i = 0 ; $i < $addressCount ; $i++) {
	%addressLine = @{$addresses[$i]};
	printAddressInfo($mapFile, %addressLine);
    }
close ($mapFile);

    return(@addresses);

}


################################################################
# mergeAddresses
#
# This function merges the single list format in the csv into
# the merged house number scheme (e.g. Adams St 2012-14) that I
# was expecting the csv to be
################################################################
sub mergeAddresses {
    my (@addresses) = @_;
    my @compAddresses;
    my %addressLine;
    my %futureAddressLine;
    my $addressCount;
    my $i;
    my $j;
    my $count = 0;
    my $houseNumber = "";
    my $lastChar;

    #go through the list of addresses and see if any have #building > 1
    $addressCount = scalar (@addresses);
    for($i = 0 ; $i < $addressCount ; $i++) {
	%addressLine = @{$addresses[$i]};
#printAddressInfo(%addressLine);
	#now if the current addressLine is the start of a multi-address house, then generate the compound house number
	if($addressLine{"numberOfBuildings"} > 1) {
	    #print("CCC - here for multiple buildings\n");
	    #printAddressInfo(%addressLine);

	    #here if multiple buildings. Look forward into future addresses in order to build up the single compound house number
	    #first check to see if the house number contains text
	    if($addressLine{"houseNumber"} =~ /\D/) {
		#here if yes
	    	$houseNumber = $addressLine{"houseNumber"};
	    }
	    else {
	    	$houseNumber = sprintf("%04d", $addressLine{"houseNumber"});
	    }

	    for($j = 1 ; $j < $addressLine{"numberOfBuildings"} ; $j++) {
		%futureAddressLine = @{$addresses[$i + $j]};
		#print("AAA - FutureAddressLine\n");
		#printAddressInfo(%futureAddressLine);

		#if the last char is a digit, then we append the last two digits of the newHouseNumber (e.g. 2014 -> 14).
		#if the last char is alpha, then we append just the last char (e.g. 2014B -> B)
		$lastChar = substr($futureAddressLine{"houseNumber"}, -1);
		if($lastChar =~ m/[0-9]/ ) {
		    #here for digit
		    $houseNumber = $houseNumber . "-" . substr($futureAddressLine{"houseNumber"}, -2);
		}
		else {
		    $houseNumber = $houseNumber . "-" . $lastChar;
		}
		#print("BBB - lastChar = '$lastChar', houseNumber = '$houseNumber'\n");
	    }

	    #set the new house number (should be @addressLine[3]) and skip some addresses
	    $addressLine{"houseNumber"} = $houseNumber;
	    $i = $i + $addressLine{"numberOfBuildings"} - 1;

	}

	#copy the old addressLine into the new array
	$compAddresses[$count][0] = "photo";
	$compAddresses[$count][1] = $addressLine{"photo"};
	$compAddresses[$count][2] = "houseNumber";
	$compAddresses[$count][3] = $addressLine{"houseNumber"};
	$compAddresses[$count][4] = "streetName";
	$compAddresses[$count][5] = $addressLine{"streetName"};
	$compAddresses[$count][6] = "numberOfBuildings";
	$compAddresses[$count][7] = $addressLine{"numberOfBuildings"};
	$compAddresses[$count][8] = "sheetNumber";
	$compAddresses[$count][9] = $addressLine{"sheetNumber"};
	$compAddresses[$count][10] = "negativeNumber";
	$compAddresses[$count][11] = $addressLine{"negativeNumber"};
	$compAddresses[$count][12] = "photographer";
	$compAddresses[$count][13] = $addressLine{"photographer"};
	$compAddresses[$count][14] = "dateTaken";
	$compAddresses[$count][15] = $addressLine{"dateTaken"};
	$compAddresses[$count][16] = "notes";
	$compAddresses[$count][17] = $addressLine{"notes"};


	$count++;
    }

    return(@compAddresses);
}


################################################################
# printAddressInfo
#   Dumps addressInfo to the screen for debug
#
################################################################
sub printAddressInfo {
        my ($mapFile, %addressLine) = @_;

	#print the contents of the addressInfo
	print $mapFile "$addressLine{\"photo\"}"; 
	print $mapFile " ; $addressLine{\"houseNumber\"}"; 
	print $mapFile " ; $addressLine{\"streetName\"}"; 
	print $mapFile " ; $addressLine{\"numberOfBuildings\"}";   
	print $mapFile " ; $addressLine{\"sheetNumber\"}";  
	print $mapFile " ; $addressLine{\"negativeNumber\"}";  
	print $mapFile " ; $addressLine{\"photographer\"}"; 
	print $mapFile " ; $addressLine{\"dateTaken\"}"; 
	print $mapFile " ; $addressLine{\"notes\"}"; 
	print $mapFile "\n";

}

################################################################
# printError
#   
#
################################################################
sub printError {
    my ($error, %addressLine) = @_;

    print("ERROR======================================================================\n");
    print("$error\n");
    printAddressInfo(%addressLine);
    print("ERROR======================================================================\n");  
} 

 


