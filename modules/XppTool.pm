############################################
#    XppTool module                        #
#       part of the XPP PowerTools         #
############################################
# V00.01 - 2019 - initial version 
package XppTool;

use strict;
use warnings;
use 5.028;

use File::Basename;
use File::Copy;
use File::Spec::Functions;
use Moose;
use XML::Simple;

#=============================================================
#  Attributes
#=============================================================
has 'config' => (
	is => 'rw',
	isa => 'HashRef',
	lazy => 1,
	builder => '_readConfig',
);
has 'configfolder' => (
	is  => 'rw',
	isa => 'Str',
	lazy=> 1,
	default => sub { catfile($ENV{'XYV_EXECS'}, 'procs', 'jsc', 'config')}
	);
has 'hasConfig' => (
	is=>'ro',
	isa=>'Int',
	default=>'1'
);
has 'div' => (
	is  => 'rw',
	isa => 'Str',
	predicate => 'has_div',
	);
has 'divname' => (
	is  => 'rw',
	isa => 'Str',
	writer => '_set_divname',
	);
has 'job' => (
	is  => 'rw',
	isa => 'Str',
	);
has 'jobname' => (
	is  => 'rw',
	isa => 'Str',
	lazy=> 1,
	default => sub { my $job = basename($_[0]->job); $job =~ s#JOB_##; return($job);}
	);
#set when logfile is open
has 'logfile' => (
	is=>'rw',
	isa => 'Str',
	predicate => 'has_logfile',
	clearer => '_clear_logfile',
);
#now is a date/time/timestamp structure
has 'now' => (
	is => 'rw',
	isa => 'HashRef',
	writer => '_set_now',
);
#name of this program
has 'progname' => (
	is => 'ro',
	isa => 'Str',
	builder => '_progName',
	);
#source file for xpp command
has 'source' => (
	is  => 'rw',
	isa => 'Str',
	);
#target (result) file for xpp command
has 'target' => (
	is  => 'rw',
	isa => 'Str',
	);
#version of the program
has 'version' => (
	is => 'ro',
	isa => 'Str',
	default => '1.00',
);
#xpp bin folder
has 'xppbin' => (
	is      => 'ro',
	isa     => 'Str',
	default => sub {catfile($ENV{'XYV_EXECS'}, 'bin')},
);

#allow div to be set to full path, relative path or just divname and set divname
around 'div' => sub {
	my $orig = shift;
	my $self = shift;
	#use normal reader method	
	return $self->$orig() unless @_;
	#aha this is a set method
	my $div = shift;
	$div = canonpath($div);
	#check if only divisionname is given or a complete path
	if (basename($div) eq $div) {
		$div = "DIV_$div" unless ($div =~ m#DIV_#);
		$div = catdir($self->job(), $div);	
	}
	#if we have been given a valid div name
	if ($div =~ m#DIV_(.+)$#) {
		$self->_set_divname($1) ;
		#reset the job 
		my $job = dirname($div);
		$self->job($job);
	}
	#and set
	return $self->$orig($div);
};


#=============================================================
#  Builders
#=============================================================
# builds default value for the $self->progname()
#-------------------------------------------------------------
sub _progName {
#-------------------------------------------------------------
	my $self = shift;
    my $prog = basename($0, '.pl', '.exe');
    return($prog);
}
# builds default value for the $self->config()
#-------------------------------------------------------------
sub _readConfig {
#-------------------------------------------------------------
	my $self = shift;
	my $config = {};
	if ($self->hasConfig()) {
		my $file = catfile($self->configfolder(), $self->progname() . "_config.xml");
		$self->error("System not setup for running " . $self->progname() . " tool\nConfig file is missing\n see: $file\n") unless (-r $file);

		$config = eval { XMLin($file, ContentKey => '-content') };

		$self->error("  Config file error: file corrupt\n  see: <$file>\n$@\n") if ($@);
		#print Dumper($config);
	}
    return($config);
}

#=============================================================
#  Methods
#=============================================================
#list all divs in DA ticket that have the specified field set to yes
#-------------------------------------------------------------
sub DAlist {
#-------------------------------------------------------------
	my $self = shift;
	my $field = shift || 'edg';
	my $job = $self->job();
	my @divs;
	$self->error("field <$field> is not a valid DA ticket field") unless grep /^$field$/, qw(comp loep prnt spel pdf edg);
	my $command = "sdedit";
	my $options = "-cd $job da job -job -xml -aout -";
	$self->message("  -reading DA using <$field> field", 5);
	my $daLines = $self->_xppCommandReadAsString($command, $options);
	#get rid of the header - not strictly necessary but still
	$daLines =~ s#^.+?<rule#<rule#s;
	#keep only active records
	my @da = grep m#<${field}_active>yes</${field}_active>#, split m#</rule>#, $daLines;
	#keep only main type divisions
	foreach (@da) {
		push @divs, $1 if (m#<divtype>main</divtype># and m#<divname>(.+?)</divname>#);
	}
	return(@divs);
}

	
#-------------------------------------------------------------
sub divCompose {
#-------------------------------------------------------------
	my $self = shift;
	my $options = shift || $self->config->{'xpp'}->{'compose'} || "";
	my $command = "compose";
	my $div = $self->div() || $self->error("can not run $command, division not set");
    my $status = $self->_xppCommand($command,  "-cd $div $options");
    if ($status) { $self->error("$command failed\n\treturned status <$status>, expected 0"); };	
	return()
}

#-------------------------------------------------------------
sub divCopy {
#-------------------------------------------------------------
	my $self = shift;
	my $command = "copydiv";
	my $divSource = $self->source() || $self->error("can not run $command, source division not set");
	my $divResult = $self->target() || $self->error("can not run $command, target division not set");
    my $status = $self->_xppCommand($command,  "$divSource $divResult");
    if ($status) { $self->error("$command failed\n\treturned status <$status>, expected 0"); };
	return();
}
#-------------------------------------------------------------
sub divExists {
#-------------------------------------------------------------
	my $self = shift;
	my $command = "divExists";
	my $div = $self->div() || $self->error("can not run $command, division not set");
	return(1) if (-d $div);
	return(0);
}
#-------------------------------------------------------------
sub divFromxsf {
#-------------------------------------------------------------
	my $self = shift;
	my $options = shift || $self->config->{'xpp'}->{'fromxsf'} || "";
	my $command = "fromxsf";
	my $div = $self->div() || $self->error("can not run $command, division not set");
	my $file = $self->target() || $self->error("can not run $command, target file not set");
    my $status = $self->_xppCommand($command,  "$file -cd $div $options");
    if ($status == 255) { $self->error("$command failed\n\treturned status <$status>, expected 0"); };
	return();
}

#-------------------------------------------------------------
sub divPdf {
#-------------------------------------------------------------
	my $self = shift;
	my $options = shift || $self->config->{'xpp'}->{'pdf'} || "";
	my $name = shift || "";
	my $command = "psfmtdrv";
	my $div = $self->div() || $self->error("can not run $command, division not set");
	my $file = $self->target() || $self->error("can not run $command, target file not set");
    #read options from print profile file
	if ($options eq "profile") {
		my $profile = $self->config->{'xpp'}->{'printProfile'} || $self->error("printProfile not set in config file, cannot print");
		$options = $self->_xppReadPrinterProfile($profile);
	}
	#add the name of ps/pdf file
	$options .= " -pn $name" if ($name);
	$self->message("  with options: $options", 5);
	#run
	my $status = $self->_xppCommand($command,  "-cd $div $options");
    if ($status) { $self->error("$command failed\n\treturned status <$status>, expected 0"); };
	return();
}

#-------------------------------------------------------------
sub divToxsf {
#-------------------------------------------------------------
	my $self = shift;
	my $options = shift || $self->config->{'xpp'}->{'toxsf'} || "";
	my $command = "toxsf";
	my $div = $self->div() || $self->error("can not run $command, division not set");
	my $file = $self->target() || $self->error("can not run $command, target file not set");
    my $status = $self->_xppCommand($command,  "$file -cd $div $options");
    if ($status == 255) { $self->error("$command failed\n\treturned status <$status>, expected 0"); };
	return();
}

#-------------------------------------------------------------
sub divUse {
#-------------------------------------------------------------
	my $self = shift;
	my $command = "divuse";
	my $div = shift || $self->div() || $self->error("can not run $command, division not set");
	my $status = $self->_xppCommand($command);
	return($status);
}

#do a divxml and place the result in the resultfile
#-------------------------------------------------------------
sub divXml {
#-------------------------------------------------------------
	my $self = shift;
	my $options = shift || $self->config->{'xpp'}->{'divxml'} || "";
	my $div = $self->div() || $self->error("can not run divxml, division not set");
	my $file = $self->target() || $self->error("can not run divxml, target file not set");
	my $command = "divxml";
    my $status = $self->_xppCommand($command,  "-cd $div $options $file");
    
    if ($status > 250) { $self->error("$command failed\n\treturned status <$status>, expected 0"); };
    $self->message("  divxml run with warnings", 5) if ($status);
    $self->message("  result in $file", 7);
	return();
}

#-------------------------------------------------------------
sub error {
#-------------------------------------------------------------
	my $self = shift;
	my $mesg = shift;	
	main::badExit($mesg);
	return();
}

#copy a job + local style files
#if job exists already the style files will get copied
#any local style files in the destination job will get deleted!
#-------------------------------------------------------------
sub jobCopy {
#-------------------------------------------------------------
	my $self = shift;
	my $command = "copydiv";
	my $options = "-job -xsh";
	my $jobSource = $self->source() || $self->error("can not run $command, source job not set");
	my $jobResult = $self->target() || $self->error("can not run $command, target job not set");
 
	my $status = $self->_xppCommand($command,  "$options $jobSource $jobResult");
    if ($status) { $self->error("$command failed\n\treturned status >$status<, expected 0"); };
	
	#old copydiv (pre 9.3.2) does not yet copy any CSS or perl style files
	#opendir(my $dir, $jobSource);
	#my @files = readdir $dir;
	#closedir $dir;
	#foreach my $file (@files) {
	#	next unless ($file =~ m#\.css$# or $file =~ m#\.pl$#);
	#	my $source = catfile($jobSource, $file);
	#	my $result = catfile($jobResult, $file);
	#	copy($source, $result) or $self->error("failed to copy style file:\n$source -> $result\n");
	#	$self->message("  copy $file\n", 7);
	#}
	return();
}
#return all the graphics found in this div
#-------------------------------------------------------------
sub graphicsList {
#-------------------------------------------------------------
	my $self = shift;
	my $div = $self->div() || $self->error("can not run listGraphics, division not set");
	my $command = "listgr";
	my $options = "-f";

    my ($status, @images) = $self->_xppCommandRead($command,  "-cd $div $options");
	$self->error("listgr command failed") if ($status > 1);
	return(@images);
}

#-------------------------------------------------------------
sub handle {
#-------------------------------------------------------------
	my $self = shift;
	my $handle = shift;
	my $command = 'xyh2p';
	my ($tatus, $xppPath) = $self->_xppCommandReadAsString($command, $handle);
	return($xppPath);
}
#-------------------------------------------------------------
sub log {
#-------------------------------------------------------------
	my $self = shift;
	my $mesg = shift;
	#nothing to do if log is not open
	return unless ($self->has_logfile);
	#add mesg to the log file
	my $logFile = $self->logfile();
	open my $fh, '>>:utf8', $logFile ;	
	print $fh $mesg;
	close $fh;
	return();
}

#-------------------------------------------------------------
sub logStart {
#-------------------------------------------------------------
	my $self = shift;
	my $logFile = shift;
	#return if log file is already open
	return if $self->has_logfile;
	#separators for messages
	my $SEP = "=" x 50;                         
	my $Sep = "-" x 50; 
	#open file
	my $fh;
	open $fh, '>:utf8', $logFile or main::badExit("could not open log file\nsee: >$logFile<\n");	
	close $fh;
	#mark log file open
	$self->logfile($logFile);
	#output start message
	$self->setNow();
	my $now = $self->now();
	$self->log("$SEP\n" . $now->{'date'} . " " .  $now->{'time'} . " " . $self->progname() . " V: " . $self->version() . "\n$Sep\n");
	return();
}
#local version of message - does the same as main::message
#-------------------------------------------------------------
sub message {
#-------------------------------------------------------------
	my $self = shift;
	my $message = shift;
	my $level = shift || 5;
	#write message to log and in window
	main::message($message, $level);
	return();
}

#set now dateStamp structure
#-------------------------------------------------------------
sub setNow {
#-------------------------------------------------------------
    my $self = shift;
	my $timestamp = shift || "";
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
    #the 'beautified' version
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
    $now->{'timeStamp'} = "$year$monthNr${day}T$hour$min$sec";
    
    #store the 'now' structure
    $self->_set_now($now);       
	return();
}

#update the job ticket of the current job
#-------------------------------------------------------------
sub updateJobTicket {
#-------------------------------------------------------------
	my $self = shift;
	my $command = "update_jt";
	my $options = shift || $self->error("can not run $command, options not set");
	my $job = $self->job();
	my $status = $self->_xppCommand($command, "-cd $job " . $options);
	if ($status == 1) {$self->error("Update Job Ticket failed\nFatal error");}
	elsif ($status == 2) {$self->error("Update Job Ticket failed\nDate format error");}
	elsif ($status == 3) {$self->error("Update Job Ticket failed\nDate is blank");}
	elsif ($status > 0) {$self->error("Update Job Ticket failed\nerror");}
	return();
}
#do a xychange
#-------------------------------------------------------------
sub xychange {
#-------------------------------------------------------------
	my $self = shift;
	my $options = shift || "";
	my $tables = $self->tables() || "";
	my $div = $self->div() || $self->error("can not run xychange, division not set");
	my $fileIn = $self->source() || $self->error("can not run xychange, source file not set");
	my $fileOut = $self->target() || $self->error("can not run xychange, target file not set");
	my $command = "xychange";

    my $status = $self->_xppCommand($command,  "-cd $div $options $tables $fileIn $fileOut");

    $self->error("Xychange conversion failed\n\treturned status <$status>, expected 0") if ($status > 100);
    if ($status == 99) {
        #need to copy inputfile as if xychange had been running
        $self->message("\tcopied inputfile");
        copy( $fileIn, $fileOut );
    }
    $self->message("  xychange run with warnings", 5) if ($status);
    $self->message("  result in $fileOut", 7);
	return();
}

#=============================================================
#  Private Methods
#=============================================================
#this will execute a xppcommand
#open a pipe and filter the output of the xppcommand
#-------------------------------------------------------------
sub _xppCommand {
#-------------------------------------------------------------
	my $self = shift;
    my ($command, $options) = @_;
    my ($cntPages, $page,  $status);

    #add $XppExecs
    $command = catfile($self->xppbin(), $command);
    #log command
    $self->message("\trunning $command $options\n",9);  
    
    if ($command =~ /(xsf)|(compose)|(psfmt)/  ) {
        $self->message("\tPages: ", 5);
        $cntPages = 1;
    } 
    #start the command as a pipe, allows us to filter the output
    open my $xycom, "$command $options 2>&1 |";
    my $oldfh = select STDOUT; $| = 1; select $oldfh;
    while (<$xycom>) {
        chomp;
        $page = 0;
        #if $self->message comes Error in it, print all the information!
        if (m#Error#i) {
            $self->message("\t$_",1) ;    
        } else {
            #log only selected $self->messages
            $self->message("\t$_", 5) if (/Character Conversion/);              #import
            $self->message("\t$_", 5) if (/Running Xychange/);                  #import
            $self->message("\t$_", 5) if (/Converting to XSF/);                 #import
            $self->message("\n\t$_ ", 5) if (/Re-Processing Frills/);             #compose
            if (/Output set 1 page 1 total pages 1/) {                  #psfmt
                $self->message("\n\tOutput:", 5);
                $cntPages = 1;
                $page = 1;
            }
            if (/Output set \d+ page ([\w\d]+)/) {                      #psfmt
                $self->message("$1 ", 5);
                $page = 1;
            }       
            if (/Start Formatting of page\s+([\w\d]+)/) {               #psfmt
                $self->message("$1 ", 5);
                $page = 1;
            }       
            if (/Processing Page ([\w\d]+)/) {                          #compose
                $self->message("$1 ", 5);
                $page = 1;
            }       
            if (/Convert to XSF Page ([\w\d]+)/) {                      #Toxsf
                $self->message("$1 ", 5);
                $page = 1;
            }       
            if (/End Conversion of Page ([\w\d]+)/) {                   #Fromxsf
                $self->message("$1 ", 5);
                $page = 1;
            }       
            $self->message("$1 entities", 5) if (/There were (\d+) Entities found/);    #Fromxsf
            $self->message("\t$1 using " . basename($2), 5) if (/^(Pass \d+), Transformation table: (.+)/);                      #Xychange
            $self->message("\t$_", 5) if (/PID=/);                              #Divuse
            if (/^Transformed (\d+) bytes/) {
                if ($1 =~ /000$/) {
                    $self->message(".", 5);
                } else {
                    $self->message("\n\t>$1 bytes", 5);
                }
            }
            $self->message("\t$_", 5) if (/ERROR:/ && ! /ERROR: Cannot find page/ && $command !~ /compose/i);   #import
            $self->message("\t$_", 5) if (/Distiller failed: /);                #psfmt
            #not really an error
            if (/No transformation tables specified in job ticket/) {
                $self->message("\t$_", 5);
                $oldfh = select STDOUT; $| = 0; select $oldfh;
                close $xycom;
                return(99);
            }    
            #check if right margin is overflow, insert return if yes
            if ($cntPages && $page) {
                $cntPages++;
                if ($cntPages > 10) {
                    $cntPages = 1;
                    $self->message("\n\t", 5);    
                }   
            }
        } 
        #log all messages
        $self->message("\t$_",9);    
    }
    
    #restore old state
    $oldfh = select STDOUT; $| = 0; select $oldfh;
    close $xycom;
    
    #add missing return if in brief mode
    $self->message("\n", 5) if $cntPages;
    
    #get hold of exit status of command and return it to the caller
    $status = $? >> 8;
    return($status);
}

#this will execute the xppcommand
#return an arrary with all lines returned from xppcommand
#-------------------------------------------------------------
sub _xppCommandRead {
#-------------------------------------------------------------
	my $self = shift;
    my ($command, $options) = @_;
    my ($status,@results);
    #add $XppExecs
    $command = catfile($self->xppbin(), $command);
    #log all messages
    $self->message("\trunning $command $options",8);  
    open my $cmd, '-|:utf8', "$command $options 2>&1 ";
    while (<$cmd>) {
        chomp;
        #log all messages
        $self->message("\t$_\n",9);    
        push @results, $_;
    }
    close $cmd;
    $status = $? >> 8;
    #in case lines are read as 1
    if (scalar(@results) == 1) {
        @results = split /\n/, $results[0]; 
    }
    return($status, @results);
}

#this will execute the xppcommand
#return a string with all lines returned from the xppcommand
#-------------------------------------------------------------
sub _xppCommandReadAsString {
#-------------------------------------------------------------
	my $self = shift;
    my ($command, $options) = @_;
    my ($status, $results);
    #add $XppExecs
    $command = catfile($self->xppbin(), $command);
    #log all messages
    $self->message("\trunning $command $options",8);  
    open my $cmd, '-|:utf8', "$command $options 2>&1";
    while (<$cmd>) {
        chomp;
        #log all messages
        $self->message("\t$_",8);    
        $results .= $_;
    }
    close $cmd;
    $status = $? >> 8;
    return($status, $results);
}

#add some speed
__PACKAGE__->meta->make_immutable;

1;