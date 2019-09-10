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
my $DebugLevel = 9;							#message debug level
my $SEP = "=" x 50;                         #big separator for messages
my $Sep = "-" x 50;                         #small separator for messages
my $SepError = "*" x 50;                    #sep for error messages
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

	#start wait: see tkOnStart for the real action
	MainLoop;
}


#=============================================================
# SUBROUTINES
#=============================================================
#-------------------------------------------------------------
sub badExit {
#-------------------------------------------------------------
	my ($mesg) = @_;
    #message
    message("$SepError\nERROR:\n\t$mesg\n\tprogram stops\n$SepError\n", 0);
    
    #in foreground, open dialogbox
    my $winMesg = "Unexpected End of Program\n\n$mesg\n\nProgram stops\n";
    $M->tkMessagebox($winMesg) unless ($BG);
    
    #stop the log (if any) 
    $M->logEnd("$SEP\n${winMesg}$SEP");
    
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

#-------------------------------------------------------------
sub createDivs {
#-------------------------------------------------------------
	my $filepath = shift;
	my @divs;
	message(">reading input file\n", 5);
	my $file = path($filepath);
	my $content = $file->slurp_utf8();
	my $split = '<h1';
	#split this file
	my @chunks = split(/$split/, $content);
	#first chunk is <book> tag
	my $startTag = shift @chunks;
	chomp $startTag;
	my $endTag = $startTag;
	$endTag =~ s#<#</#;
	message(" document root tag: $startTag\n", 7);
	#wrap other chunks, get title, create division
	foreach my $chunk (@chunks) {
		$chunk = $startTag . $split . $chunk . $endTag;
		my ($div) = ($chunk =~ m#<h1>(.+?)</h1>#);
		$div =~ s#\s+#_#gs;
		message("-division: $div\n", 5);
		push @divs, $div;
		#create div
		$X->source($X->div("master"));
		$X->target($X->div($div));
		$X->divCopy();
		#write out chunk
		
	}
	

	return(@divs);
}
#
#-------------------------------------------------------------
sub createDA {
#-------------------------------------------------------------
	my $daFile = "da.xml";
	my @divs;
	#remove existing da ticket
	my $daticket = catfile($X->job(), '_da_job.sde');
	unlink $daticket if (-e $daticket);
	open my $da, ">", catfile($X->job(),$daFile) or badExit("could not open temp file: $daFile");
	message(">creating DA ticket");
	say $da '<?xml version="1.0"?>';
	say $da '<file  type="da">';
	say $da '<table>';
	say $da '<_std_comment>created by jobtool: creaDA</_std_comment>';
	foreach my $div (@divs) {
		$div =~ s#DIV_##;
		say $da '<rule>';
		say $da "<divname>$div</divname>";
		say $da '<divtype>main</divtype>';
		say $da '<citi_active>yes</citi_active>';
		say $da '<comp_active>yes</comp_active>';
		say $da '<prnt_active>yes</prnt_active>';
		say $da '<pdf_active>yes</pdf_active>';
		say $da '<edg_active>no</edg_active>';
		say $da '</rule>';
		message("  $div");
	}	
	say $da '</table></file>';
	close $da;
	$X->DAcreate($daFile);
}
#give back $now structure
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
    
    #store the different forms
    $now->{'date'} = "$day-$month-$year";
    $now->{'dateNr'} = "$year-$monthNr-$day";
    $now->{'time'} = "$hour:$min:$sec";
    $now->{'timeStamp'} = "$year$monthNr$day$hour$min$sec";
    
    #return the 'now' structure
    return($now);       
}

#-------------------------------------------------------------
sub executeRun {
#-------------------------------------------------------------
	my $file = $M->inputFile();
	my @divs;
	onStart($file);
	@divs = createDivs($file);

	onEnd();
	return();
}
#-------------------------------------------------------------
sub message {
#-------------------------------------------------------------
	my $mesg = shift;
	my $level = shift || 5;
	if ($level <= $DebugLevel) {
		$M->message($mesg);
		$X->log($mesg);
		print $mesg;
	}
	return();
}

#-------------------------------------------------------------
sub onStart {
#-------------------------------------------------------------
	my $file = shift;
	my $now = dateTime();
	message("$Sep\n", 1);
	message(" " . $now->{'date'} . " " . $now->{'time'} . "\n", 1);
	message(">inputfile: $file\n", 1);
	return();
}


#-------------------------------------------------------------
sub onEnd {
#-------------------------------------------------------------
	$M->setProgress("All Done");
	my $now = dateTime();
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
    unless ($DebugLevel) {
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

