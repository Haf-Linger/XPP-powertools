#!/etc/xyvision/common/perl/bin/perl
# sample job tool
# just a demonstration of how to use the XPP PowerTools modules
our $Version = "1.00";

use strict;
use warnings;
use 5.010;

use Data::Dumper;        
use FindBin;
use File::Basename;
use File::Copy;
#use File::Path qw(mkpath rmtree);
use File::Spec::Functions;
use Getopt::Long;
use Path::Tiny;
use Tk;

#set path to modules
use lib "$FindBin::Bin/Modules";
#load XPP PowerTools
use GuiTool;
use XppTool;

#=============================================================
#  GLOBALS
#=============================================================
my $BG = 0;									#background flag
my $DebugLevel;								#message debug level
my $StartTag;								#start tag of book file
my $EndTag;									#end tag of book file
#=============================================================
#  RegEx PATTERN SETUP
#=============================================================
our $tagP = qr/[^>]+?/;
our $attribValueP = qr/[^"]+?/;		#" added for display only
our $numberP = qr/[\d\.]+/;
our $cssValueP = qr/[^;]+/;

#=============================================================
#  MAIN
#=============================================================
umask 000;
#shift perl messages into log file
$SIG{__WARN__} = sub { message($_[0], 0)};

#can we actually run?
badExit('This machine is not set up to run XPP software') unless (exists $ENV{'XYV_EXECS'});

#prepare for a Tk jobtool
my $M = GuiTool->new(fileselect=>1);
#set up the xpp object - will also read in the config file
my $X = XppTool->new(version=> $Version, hasConfig=>0);
#make config available to the jobtool
$M->xpp($X);


#check and read command line
checkCmdLine();
#and go...well almost
if ($BG) {
	#just run
	preFlight();
	executeRun();	
} else {
	$M->startMain();
	#check things before we can start
	preFlight();
	#inputfile?
	$M->updateInputEntry($M->inputFile()) if ($M->inputFile());
	#start wait: see tkOnStart in GuiTool.pm for the real action
	MainLoop;
}


#=============================================================
# SUBROUTINES
#=============================================================
#-------------------------------------------------------------
sub badExit {
#-------------------------------------------------------------
	my ($mesg) = @_;
	my $SepError = "*" x 50;
    #message
    message("$SepError\nERROR:\n\t$mesg\n\tprogram stops\n$SepError\n", 0);
    #in foreground, open dialogbox
    my $winMesg = "Unexpected End of Program\n\n$mesg\n\nProgram stops\n";
    $M->tkMessagebox($winMesg) unless ($BG);
    #this is the end (on a bad note)
    exit(-1);       
}

#check if command to launch this program can be understood by the program
#-------------------------------------------------------------
sub checkCmdLine {
#-------------------------------------------------------------
	my $file;
	#check1
	GetOptions('debug=i' => \$DebugLevel, 'bg' => \$BG, 'in=s' => \$file) or printUsage();
	my $noa = scalar(@ARGV);
	printUsage() if ($noa != 1);
	#check2
	my $path = shift @ARGV;
	#clean path
	$path = canonpath($path);
	my $job = basename($path);
	if ($job =~ m#JOB_#) {
		#started as jobtool
		$X->job($path);
	}	
	$M->setLabel($X->job());
	badExit("You need to start this tool on an XPP JOB") unless ($M->has_joblabel());
	badExit("Job: " . $X->job() . "does not exist") unless (-d $X->job());
	#set file?
	if ($file) {
		$file = canonpath($file);
		badExit("input file <$file> is not readable") unless (-r $file);
		$M->inputFile($file);
	}	
	return();
}

#compose list of divs
#-------------------------------------------------------------
sub composeDivs {
#-------------------------------------------------------------
	my @divs = @_;
	message(">composing divs {\n", 1);
	foreach my $div (@divs) {
		message(" -$div:\n", 5);
		$X->div($div);
		$X->divCompose();
	}
	message("}\n", 5);
	return();
}
#chunk input file and toxsf chunks in divs
#returns a list of div names
#-------------------------------------------------------------
sub createDivs {
#-------------------------------------------------------------
	my $fileInpath = shift;
	my $fileChunk = "in.xml";
	my @divs;
	message(">reading input file {\n", 1);
	my $fileIn = path($fileInpath);
	my $content = $fileIn->slurp_utf8();
	my $split = '<h1';
	#split this file
	my @chunks = split(/$split/, $content);
	#first chunk is <book> tag
	$StartTag = shift @chunks;
	$StartTag =~ s#\s+$##s;
	$EndTag = $StartTag;
	$EndTag =~ s#<#</#;
	message(" document root tag: $StartTag\n", 7);
	#wrap other chunks, get title, create division
	my $first = 1;
	foreach my $chunk (@chunks) {
		#remove endtag from last chunk
		$chunk =~ s#$EndTag\s*$##s;
		$chunk = $StartTag . $split . $chunk . $EndTag;
		my ($div) = ($chunk =~ m#<h1>(.+?)</h1>#);
		$div =~ s#\s+#_#gs;
		push @divs, $div;
		#set div
		my $divPath = $X->div($div);
		if ($X->divExists()) {
			badExit("$div in use") if ($X->divUse());
			message(" -overwrite: $div\n", 5);
		} else {
			message(" -create: $div\n", 5);
			#create div
			$X->source($X->div("master"));
			$X->target($X->div($div));
			$X->divCopy();
		}
		#set division ticket to cont or 1
		if ($first) {
			$X->divTicket('-p_four 1');
		} else {
			$X->divTicket('-p_four 65535');
		}
		#write out chunk
		my $file = path($divPath, $fileChunk);
		$file->spew_utf8($chunk);
		#toxsf
		$X->source($fileChunk);
		$X->divToxsf();
		#reset first flag
		$first = 0;
	}
	message("}\n", 5);
	return(@divs);
}

#create the DA ticket needed for composing
#-------------------------------------------------------------
sub createDA {
#-------------------------------------------------------------
	my @divs = @_;
	my $cnt = scalar(@divs);
	message(">creating DA ticket {\n", 1);
	message(" $cnt divisions", 7);
	$X->DACreate(@divs);
	message("}\n", 5);
	return();
}

#return $now structure
#-------------------------------------------------------------
sub dateTime {
#-------------------------------------------------------------
    my $timestamp = shift;
	my ($sec,$min,$hour,$day,$monthNr,$year);
    my $now = {};
    
    #get date and time
    if ($timestamp) {
		($sec,$min,$hour,$day,$monthNr,$year) = localtime($timestamp);
	} else {
		($sec,$min,$hour,$day,$monthNr,$year) = localtime(time());	
	}
    my $month=("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$monthNr];
    $monthNr++;
    #now print 'beautified'
    $monthNr = sprintf("%02d",$monthNr);
    $hour = sprintf("%02d",$hour);
    $min = sprintf("%02d",$min);
    $sec = sprintf("%02d",$sec);
    $day = sprintf("%02d",$day);
    $year= 1900 + $year;
    #store the different formats
    $now->{'date'} = "$day-$month-$year";
    $now->{'dateNr'} = "$year-$monthNr-$day";
    $now->{'time'} = "$hour:$min:$sec";
    $now->{'timeStamp'} = "$year$monthNr$day$hour$min$sec";
    #return the 'now' structure
    return($now);       
}

#the main program
#-------------------------------------------------------------
sub executeRun {
#-------------------------------------------------------------
	my $file = $M->inputFile();
	onStart($file);
	my @divs = createDivs($file);
	createDA(@divs);
	composeDivs(@divs);
	exportDivs(@divs);
	onEnd();
	return();
}

#export+transform list of divs and concatenate
#-------------------------------------------------------------
sub exportDivs {
#-------------------------------------------------------------
	my @divs = @_;
	my $fileFromxsf = "fromxsf.xml";
	my $fileTransform = "transform.xml";
	my $fileFinal = "book.xml";
	my $content;
	my $file;
	message(">exporting divs {\n", 1);
	foreach my $div (@divs) {
		message(" -$div\n");
		message("   fromxsf:\n", 5);
		$X->div($div);
		$X->target($fileFromxsf);
		$X->divFromxsf('-Rep -utf8');
		message("   xychange:\n", 5);
		$X->source($X->target());
		$X->target($fileTransform);
		$X->tables('transform');
		$X->divXychange();
		$file = path($X->div(), $fileTransform);
		$content .= $file->slurp_utf8(); 
	}
	message("}\n", 5);
	#write out book file
	$file = path($X->job(), $fileFinal);
	message(">writing book file\n", 1);
	message(" $file\n", 5);
	$file->spew_utf8($StartTag, $content, $EndTag);
	return();
}

#-------------------------------------------------------------
sub message {
#-------------------------------------------------------------
	my $mesg = shift;
	my $level = shift || 5;
	$mesg =~ s#{## if ($DebugLevel < 5);
	if ($level <= $DebugLevel) {
		$mesg =~ s#{## if ($DebugLevel < 5);
		$M->message($mesg);
		$X->log($mesg);
		print $mesg;
	}
	return();
}

#things to do before we start
#-------------------------------------------------------------
sub onStart {
#-------------------------------------------------------------
	my $file = shift;
	my $now = dateTime();
	my $Sep = "-" x 50;
	message("$Sep\n", 1);
	message(" " . $now->{'date'} . " " . $now->{'time'} . "\n", 1);
	message(">inputfile: $file\n", 1);
	return();
}

#things to do when we end
#-------------------------------------------------------------
sub onEnd {
#-------------------------------------------------------------
	$M->setProgress("All Done");
	my $now = dateTime();
	my $Sep = "-" x 50;
	message("$Sep\n", 1);
	message(">All Done\n", 1);
	message(" " . $now->{'date'} . " " . $now->{'time'} . "\n", 1);
	message("$Sep\n", 1);
	$M->onEnd();
	return();
}

#before we start...some tests
#-------------------------------------------------------------
sub preFlight {
#-------------------------------------------------------------
	my $logFile = catfile($X->job(), $M->progname() . ".log");
	$X->logStart($logFile);

    #set debuglevel
    unless (defined $DebugLevel) {
		#set to default value or set to value set in config file 
		$DebugLevel = 5;
		$DebugLevel = $X->config->{'general'}->{'debug'} if (exists $X->config->{'general'}->{'debug'});
    }
	message(">debug level: $DebugLevel\n", 5);
	return();
}

#print correct command line for this tool
#-------------------------------------------------------------
sub printUsage {
#-------------------------------------------------------------
	print "This tool can be used as an interactive Xpp Job tool\n Usage: " . $X->progname() . ".pl [--debug #] [--in full_path_to_inputfile] full_path_to_JOB\n";
	print "Or it can be used as a batch tool\n Usage: " . $X->progname() . ".pl [--debug #] --bg --in full_path_to_inputfile full_path_to_JOB\n";
	exit(-1);
}

