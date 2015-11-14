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
# tagFiles
#
# This function adds the relevant tags to the photo
################################################################
sub tagFiles {
    my ($srcFolderName, $destFolderName, $photoMappingFile, @addresses) = @_;
    my $i;
    my $addressCount;
    my %addressLine;
    my $jpgSrcPhoto;
    my $tifSrcPhoto;
    my $photo;
    my $destPhoto;
    my $address;
    my $cmd;
    my $mapFile;
    my $exiv2Exe = "exiv2.exe";
    my $tagKeyword = "Iptc.Application2.Keywords";
    my $i;
    my $j;
    my $k;
    my $tag;
    my @genAddresses;
    my $genAddressCount;
    my %genAddressLine;
    my $foundFile;
    my $srcPhoto;

    # open the mapping file
    open($mapFile, '>', "$destFolderName\\$photoMappingFile") or die "Can't open '$destFolderName\\$photoMappingFile' for write: $!"; 

    $addressCount = scalar (@addresses);
    for($i = 0 ; $i < $addressCount ; $i++) {
	%addressLine = @{$addresses[$i]};
	$foundFile = 0;

	#check that the folder exists
        if (!-e $destFolderName) {
	    if(createDestinationFolder( $destFolderName ) == 0) {
	    	exit 2;
	    }
        }

	#check if the sheet number is text (e.g. SS7) and build up the photo name accordingly
	if($addressLine{"sheetNumber"} eq ($addressLine{"sheetNumber"} + 0)) {
	#if(substr($addressLine{"sheetNumber"}, 1) >= 1) {
	    #here for a number
	    $srcPhoto = sprintf("%03d-%02d", $addressLine{"sheetNumber"}, $addressLine{"negativeNumber"});
	}
	else {
	    #here if text
	    $srcPhoto = sprintf("%s-%02d", $addressLine{"sheetNumber"}, $addressLine{"negativeNumber"});
	}


	#find the jpg file if one exists
	$jpgSrcPhoto = sprintf("%s\\%s.jpg", $srcFolderName, $srcPhoto);

	if(-e $jpgSrcPhoto) {
	    #here if the jpg file was found.
	    $foundFile = 1;

	    #create destination photo name and check if we have it already
    	    $destPhoto = generatePhotoName( $destFolderName, "jpg", %addressLine);
	    tagFile($jpgSrcPhoto, $destPhoto, $mapFile, %addressLine);
	}

	#now see if a tif file with the name name exists
	$tifSrcPhoto = sprintf("%s\\%s.tif", $srcFolderName, $srcPhoto);
	#$tifSrcPhoto = sprintf("%s\\%03d-%02d.tif", $srcFolderName, $addressLine{"sheetNumber"}, $addressLine{"negativeNumber"});

	if(-e $tifSrcPhoto) {
	    #here if the tif file was found.
	    $foundFile = 1;

	    #create destination photo name and check if we have it already
    	    $destPhoto = generatePhotoName( $destFolderName, "tif", %addressLine);
	    tagFile($tifSrcPhoto, $destPhoto, $mapFile, %addressLine);
	}

	#make sure at least one version of the photo was found
	if($foundFile == 0) {
	    $photo = sprintf("Could not find photo jpg version '%s' or tif version '%s'\n", $jpgSrcPhoto, $tifSrcPhoto);

	    #log the error in the mapping file
	    print $mapFile "ERROR: $photo";

	    #tell the user too
 	    printError($photo, %addressLine);
	}
    }

    close ($mapFile);
}

################################################################
# tagFile
#
# 
#
################################################################
sub tagFile{
    my ($srcPhoto, $destPhoto, $mapFile, %addressLine) = @_;
    my @genAddresses;
    my $genAddressCount;
    my $j;
    my %genAddressLine;

    #do the copy if the file doesn't current exist
    if(!-e $destPhoto) {
	copy($srcPhoto, $destPhoto) or die "File '$srcPhoto' cannot be copied.";
    }

    print("Tagging '$destPhoto'\n");

    # Iterate through the number of houses in the image
    @genAddresses = generateHouseAddresses(%addressLine);
    $genAddressCount = scalar (@genAddresses);

    for($j = 0 ; $j < $genAddressCount ; $j++) {
	%genAddressLine = @{$genAddresses[$j]};
	#printAddressInfo(%genAddressLine);

	#write the tag to the destFile
	tagPhoto($j, $destPhoto, $mapFile, %genAddressLine);
    }
}

################################################################
# tagPhoto
#
# This function copies the file and then tags the specified file with the address information
#
################################################################
sub tagPhoto{
    my ($firstTime, $destPhoto, $mapFile, %genAddressLine) = @_;
    my $cmd;
    my $tag;
    my $exiv2Exe = "exiv2.exe";
    my $tagKeyword = "Iptc.Application2.Keywords";
    my $address;
    my @tmpDestPhoto;

    #construct tag
    #note that the house number might also contain text
    if($genAddressLine{"houseNumber"} =~ /\D/) {
	#here for text
	#does the sheetNumber contain text?
	if($genAddressLine{"sheetNumber"} =~ /\D/) {
	    #here if yes
    	    $tag = sprintf("AAPS-houseNumber:%s-streetName:%s-sheetNumber:%s-rollNumber:%02d-dateTaken:%s", 
	    	$genAddressLine{"houseNumber"},
	    	$genAddressLine{"streetName"},
	    	$genAddressLine{"sheetNumber"},
	    	$genAddressLine{"negativeNumber"},
	    	$genAddressLine{"dateTaken"} );
	}
	else {
	    	    $tag = sprintf("AAPS-houseNumber:%s-streetName:%s-sheetNumber:%04d-rollNumber:%02d-dateTaken:%s", 
	    	$genAddressLine{"houseNumber"},
	    	$genAddressLine{"streetName"},
	    	$genAddressLine{"sheetNumber"},
	    	$genAddressLine{"negativeNumber"},
	    	$genAddressLine{"dateTaken"} );
	}
    }
    else {
        #here for digits
	#does the sheetNumber contain text?
	if($genAddressLine{"sheetNumber"} =~ /\D/) {
	    #here if yes
    	    $tag = sprintf("AAPS-houseNumber:%04d-streetName:%s-sheetNumber:%s-rollNumber:%02d-dateTaken:%s", 
	    	$genAddressLine{"houseNumber"},
	    	$genAddressLine{"streetName"},
	    	$genAddressLine{"sheetNumber"},
	    	$genAddressLine{"negativeNumber"},
	    	$genAddressLine{"dateTaken"} );
	}
	else {
	    	    $tag = sprintf("AAPS-houseNumber:%04d-streetName:%s-sheetNumber:%04d-rollNumber:%02d-dateTaken:%s", 
	    	$genAddressLine{"houseNumber"},
	    	$genAddressLine{"streetName"},
	    	$genAddressLine{"sheetNumber"},
	    	$genAddressLine{"negativeNumber"},
	    	$genAddressLine{"dateTaken"} );
	}
    }
    
    if($firstTime == 0) {
	$cmd = sprintf("-M\"set $tagKeyword $tag\"");
    }
    else {
	$cmd = sprintf("-M\"add $tagKeyword $tag\"");
    }

    system("$exiv2Exe $cmd \"$destPhoto\"");

    #print the index to the mappingFile so that I have a record of what was tagged
    @tmpDestPhoto = split(/\\/, $destPhoto);
    $address = sprintf("%s:%s -> %s == %s", $genAddressLine{"sheetNumber"}, $genAddressLine{"negativeNumber"}, $tmpDestPhoto[-1], $tag);
    #$address = sprintf("%s:%s -> %s", $genAddressLine{"sheetNumber"}, $genAddressLine{"negativeNumber"}, $tmpDestPhoto[-1]);
    print $mapFile "$address\n"; 
}

################################################################
# generatePhotoName
#
# 
#
################################################################
sub generatePhotoName{
    my ($destFolderName, $ext, %addressLine) = @_;
    my $coreName;
    my $name;
    my $count = 1;
    my $tmpName;
    my $shortHouseNum;
 
    if($addressLine{"numberOfBuildings"} == 1) {
	#here for one house number. However it could be a number or a name (e.g. Island Movie)
	if($addressLine{"houseNumber"} =~ /\D/) {
	    #here for letters
   	    $coreName = sprintf("%s\\%s - %s", $destFolderName, $addressLine{"streetName"}, $addressLine{"houseNumber"});
	}
	else {
	    #here for digits
    	    $coreName = sprintf("%s\\%s - %04d", $destFolderName, $addressLine{"streetName"}, $addressLine{"houseNumber"});
	}
    }
    else {
	#here for an encoded house number
    	$coreName = sprintf("%s\\%s - %s", $destFolderName, $addressLine{"streetName"}, $addressLine{"houseNumber"});
    }


    #check to see if the name is unique
    $tmpName = sprintf("%s.%s", $coreName, $ext);
    while (-e $tmpName) {
	$tmpName = sprintf("%s (%d).%s", $coreName, $count++, $ext);
    }

    return($tmpName);
}

################################################################
# generateHouseAddresses
#
# This function creates an array of address by decoding the
# single line in the address file
# houseNumber formats:
# 1. houseNumber
# 2. houseNumber1-HouseNumber2-HouseNumber3- etc.
# 3. A, B ??
################################################################
sub generateHouseAddresses {
    my (%addressLine) = @_;
    my @houseNumbers;
    my $numHouseNumbers;
    my @genAddressLine;
    my %genAddressLine;
    my @genAddresses;
    my $i;
    my $j;
    my $count = 0;
    my $tmpString;
    my $error;
    my $numDigits;


    #check that the numberOfHouses and the structure of the houseNumber are consistent
    #here if following the '-' format for multiple houseNumbers in one address Line
    @houseNumbers = split(/-/, $addressLine{"houseNumber"});
    $numHouseNumbers = scalar(@houseNumbers);

    #look for the format 'number - number - etc.

    #if($addressLine{"numberOfBuildings"} != $numHouseNumbers) {
	#$error = sprintf("Mismatch found: \n\tnumberOfBuildings = '%d'\n\tnumber of houseNumbers found is '%d'", $addressLine{"numberOfBuildings"}, $numHouseNumbers);
	#printError($error, %addressLine);
    #}
    #else {
	#here if the info matches. Now build up a new address array that holds the expanded set of addresses
        if($numHouseNumbers > 1) {
	    #Are we dealing with digits or letters?
	    if($houseNumbers[0] =~ /\D/) {

	    	#here for letters
		#first find out how many digits are in the first house number. Then check the rest are the same length
		$numDigits = length($houseNumbers[1]);
        	for($j = 1 ; $j < $numHouseNumbers ; $j++ ) {
		if(length($houseNumbers[$j]) != $numDigits) {
		    $error = sprintf("Mismatch found in house number sequence: \n\tHousenumber '%d' does not match the expected length of '%d' digits'", $houseNumbers[$j], $numDigits);
			printError($error, %addressLine);
		    }
		}

		# now create the array of expanded house numbers
	    	$tmpString = substr($houseNumbers[0], 0, length($houseNumbers[0]) - $numDigits); 
	
	    	for($j = 1 ; $j < $numHouseNumbers ; $j++ ) {
	            $houseNumbers[$j] = $tmpString . $houseNumbers[$j];
	    	}
	    }
	    else {

		#here for digits
		#first, find out how many digits are in the 2nd number and onwards. They must all match
		$numDigits = length($houseNumbers[1]);
	        for($j = 1 ; $j < $numHouseNumbers ; $j++ ) {
	            if(length($houseNumbers[$j]) != $numDigits) {
			$error = sprintf("Mismatch found in house number sequence: \n\tHousenumber '%d' does not match the expected length of '%d' digits'", $houseNumbers[$j], $numDigits);
			printError($error, %addressLine);
		    }
		}

		# now create the array of expanded house numbers
	    	$tmpString = substr($houseNumbers[0], 0, length($houseNumbers[0]) - $numDigits);
	
	   	for($j = 1 ; $j < $numHouseNumbers ; $j++ ) {
	            $houseNumbers[$j] = $tmpString . $houseNumbers[$j];
		}
	    }
	}
    
	#Now build up a new address array that holds the expanded set of addresses
	for($i ; $i < $numHouseNumbers ; $i++ ) {
	    @genAddressLine = ("photo", $addressLine{"photo"}, 
			"houseNumber", $houseNumbers[$i], 
			"streetName", $addressLine{"streetName"}, 
			"numberOfBuildings", 1,  
			"sheetNumber", $addressLine{"sheetNumber"}, 
			"negativeNumber", $addressLine{"negativeNumber"}, 
			"photographer", $addressLine{"photographer"}, 
			"dateTaken", $addressLine{"dateTaken"}, 
			"notes", $addressLine{"notes"} );

	    #check the validity of the created line
	    %genAddressLine = @genAddressLine;
	    checkAddressInfo(%genAddressLine);


	    #load the array - I should be able to do this in a simpler way, but I can't figure it out
	    $genAddresses[$count][0] = @genAddressLine[0];
	    $genAddresses[$count][1] = @genAddressLine[1];
	    $genAddresses[$count][2] = @genAddressLine[2];
	    $genAddresses[$count][3] = @genAddressLine[3];
	    $genAddresses[$count][4] = @genAddressLine[4];
	    $genAddresses[$count][5] = @genAddressLine[5];
	    $genAddresses[$count][6] = @genAddressLine[6];
	    $genAddresses[$count][7] = @genAddressLine[7];
	    $genAddresses[$count][8] = @genAddressLine[8];
	    $genAddresses[$count][9] = @genAddressLine[9];
	    $genAddresses[$count][10] = @genAddressLine[10];
	    $genAddresses[$count][11] = @genAddressLine[11];
	    $genAddresses[$count][12] = @genAddressLine[12];
	    $genAddresses[$count][13] = @genAddressLine[13];
	    $genAddresses[$count][14] = @genAddressLine[14];
	    $genAddresses[$count][15] = @genAddressLine[15];
	    $genAddresses[$count][16] = @genAddressLine[16];
	    $genAddresses[$count++][17] = @genAddressLine[17];
	}
    #}

    return(@genAddresses);
}


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
	    #if($tmp[1] eq "NA") { next; }

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
    #for($i = 0 ; $i < $addressCount ; $i++) {
	#%addressLine = @{$addresses[$i]};
	#printAddressInfo(%addressLine);
    #}

    return(@addresses);

}


################################################################
# checkAddressInfo
#    Checks that the address info is consistent
#
################################################################
sub checkAddressInfo {
    my (%addressLine) = @_;\
    my @tmp;

    #some sheetNumbers have "SS" in the front of the number. Strip this out for the sake of the check
    $addressLine{"sheetNumber"} =~ s/S//g;

    if($addressLine{"houseNumber"} < 0 || $addressLine{"houseNumber"} > 9999) {
	printError("ERROR - houseNumber invalid\n", %addressLine);
    }
    elsif($addressLine{"sheetNumber"} < 1 || $addressLine{"sheetNumber"} > 999) {
	printError("ERROR - sheetNumber invalid\n", %addressLine);
    }
    elsif($addressLine{"negativeNumber"} < 1 || $addressLine{"negativeNumber"} > 36) {
	printError("ERROR - negativeNumber invalid\n", %addressLine);
    }
    elsif($addressLine{"numberOfBuildings"} < 1 || $addressLine{"numberOfBuildings"} > 99) {
	printError("ERROR - numberOfBuildings invalid\n", %addressLine);
    }
    else {
	# check that the date is in the correct format
	@tmp = split(/-/, $addressLine{"dateTaken"});
	if($tmp[0] < 1 || $tmp[0] > 12 || $tmp[1] < 1 || $tmp[1] > 31 || $tmp[2] < 1 || $tmp[2] > 2014) {
	    printError("ERROR - dateTaken invalid\n", %addressLine);
	}
    }
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
        my (%addressLine) = @_;

	#print the contents of the addressInfo
	print("$addressLine{\"photo\"}"); 
	print(" ; $addressLine{\"houseNumber\"}"); 
	print(" ; $addressLine{\"streetName\"}"); 
	print(" ; $addressLine{\"numberOfBuildings\"}");   
	print(" ; $addressLine{\"sheetNumber\"}");  
	print(" ; $addressLine{\"negativeNumber\"}");  
	print(" ; $addressLine{\"photographer\"}"); 
	print(" ; $addressLine{\"dateTaken\"}"); 
	print(" ; $addressLine{\"notes\"}"); 

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

 


