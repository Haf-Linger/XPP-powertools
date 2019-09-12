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
#make xpptool available to the jobtool
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
	GetOptions('debug=i' => \$DebugLevel, 'bg' => \$BG) or printUsage();
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

	onEnd();
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

