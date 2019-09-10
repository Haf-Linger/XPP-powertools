############################################
#    GuiTool module                        #
#       part of the XPP PowerTools         #
############################################
# V00.01 - 2019 - initial version 
package GuiTool;

use strict;
use warnings;
use 5.028;

use File::Basename;
use File::Spec::Functions;
use Moose;
use Path::Tiny;
use Tk;
use Tk::BrowseEntry;
use Tk::DialogBox;
use Tk::DropSite;
use Tk::FileSelect;

#=============================================================
#  Attributes
#=============================================================
#the cancel button
has 'cancel' => (
	is => 'rw',
	isa => 'Tk::Widget',
);
has 'fileselect' => (
	is => 'ro',
	isa => 'Int',
	default => 0,
);
has 'inputDrop' => (
	is  => 'rw',
	isa => 'Tk::Widget',
	);
has 'inputEntry' => (
	is => 'rw',
	isa => 'Tk::Widget',
);
#primary file to process
has 'inputFile' => (
	is => 'rw',
	isa      => 'Str|Undef',
	clearer => '_clear_input',
);
#joblabel
has 'joblabel' => (
	is => 'rw',
	isa => 'Str',
	clearer => '_clear_joblabel',
	predicate => 'has_joblabel',
	writer => '_set_joblabel',
);
#message end up in the central message window
has 'messageWindow' => (
	is  => 'rw',
	isa => 'Tk::Widget',
	);
#name of this program
has 'progname' => (
	is => 'ro',
	isa => 'Str',
	builder => '_progName',
	);
#the text for the progress area at the bottom of the main window
has 'progress' => (
	is => 'rw',
	isa => 'Tk::Widget',
);
#the start button
has 'start' => (
	is => 'rw',
	isa => 'Tk::Widget',
);
#version of the program
has 'version' => (
	is => 'ro',
	isa => 'Str',
	default => '1.00',
);

#the main window
has 'window' => (
	is  => 'rw',
	predicate => 'has_window',
	);
#xpp gives you acces to the $X object 
has 'xpp' => (
	is => 'rw',
	isa => 'XppTool',
);

#=============================================================
#  Tk SETUP
#=============================================================
use constant  {
	 TK_BG          => 'white',
	 TK_FG          => 'black',
	 TK_ABG         => 'goldenrod1',
	 TK_BLUE        => 'blue',
	 TK_LGREEN      => 'palegreen',
	 TK_GREEN       => 'green',
	 TK_GREY        => 'grey',
	 TK_RED         => 'red',
	 TK_FNT_BIGGER => "-*-lucida-bold-r-normal-*-24-*",
	 TK_FNT_BIGB   => "-*-lucida-bold-r-normal-*-18-*",
	 TK_FNT_BIG    => "-*-lucida-medium-r-normal-*-14-*",
	 TK_FNT_B      => "-*-lucida-bold-r-normal-*-12-*",
	 TK_FNT        => "-*-lucida-medium-r-normal-*-12-*",
};
#=============================================================
#  Builders
#=============================================================
#-------------------------------------------------------------
sub _progName {
#-------------------------------------------------------------
	my $self = shift;
    my $prog;
    if (defined $PerlApp::VERSION) {
        #running under PerlApp, so get name of program
        $prog = PerlApp::exe();
    } else {
        # Not running PerlAppified, so file should already exist
        $prog = $0;
    }
    $prog = basename($prog);
    $prog =~ s/\..*$//;
    return($prog);
}

#=============================================================
#  Methods
#=============================================================
#-------------------------------------------------------------
sub accept_drop {
#-------------------------------------------------------------
	my $self = shift;
	my $selection = shift;
    my $filename;
	if ($^O eq 'MSWin32') {
		$filename = $self->inputDrop->SelectionGet(-selection => $selection, 'STRING');
	} else {
		$filename = $self->inputDrop->SelectionGet(-selection => $selection, 'FILE_NAME');
	}
    if (defined $filename) {
		$self->updateInputEntry($filename);
    } 
	return();
}
#display message in main window
#-------------------------------------------------------------
sub message {
#-------------------------------------------------------------
	my $self = shift;
	my $message = shift;
	return() unless $self->has_window();
	$self->messageWindow->insert('end', "$message");
    $self->messageWindow->see('end');
    #update display
    $self->window->update();
	return();
}

#cancel button pressed in main window
#-------------------------------------------------------------
sub onCancel {
#-------------------------------------------------------------
    my $self = shift;
    #standard exit routine    
    exit();
}
#start button pressed in main window
#-------------------------------------------------------------
sub onStart {
#-------------------------------------------------------------
    my $self = shift;
	$self->setProgress("Running...");
    $self->start->configure(
            -text=>'Running...',
            -state=>'disabled',
            );	
	main::executeRun();
	return();
}
#set window up to end things
#-------------------------------------------------------------
sub onEnd {
#-------------------------------------------------------------
    my $self = shift;
    #do not try unless there is an active job window
    return() unless $self->has_window();

    $self->start->configure(
            -text=>'Done',
            -command=>\&onCancel,
            -state=>'normal',
            -bg=>$self->TK_ABG,
            -fg=>$self->TK_FG,
            -activebackground=>$self->TK_RED,
            );
	return();
}
#receives a path to an xpp job and returns the corresponding label
#-------------------------------------------------------------
sub setLabel {
#-------------------------------------------------------------
    my $self = shift;
    my ($job) = @_;
    my $error = 0;

    $job =~ s#\\#/#g;
    $error = 1 unless ($job =~ s#^.+/CLS_#CLS: #);#drop start
    $error = 1 unless ($job =~ s#/GRP_# GRP: #);
    $error = 1 unless ($job =~ s#/JOB_# JOB: #);


    if ($error) {
    	$self->_clear_joblabel();
    } else {
    	$self->_set_joblabel($job);
	}
	return();
}
#put a message in the progress area
#-------------------------------------------------------------
sub setProgress {
#-------------------------------------------------------------
	my $self = shift;
	my $message = shift;
    #do not try unless there is an active job window
    return() unless $self->has_window();
	#update progress area
	$self->progress->configure(-text=>$message);
	$self->window->update();	
	return();	
}
#open up the main window
#-------------------------------------------------------------
sub startMain {
#-------------------------------------------------------------
    my $self = shift;
	my $fileSelect = $self->fileselect();
    my $logo = "company.gif";
    $self->window(MainWindow->new());
    if (defined $PerlApp::VERSION) {
        #running under PerlApp, so unbound the file
        $logo = PerlApp::extract_bound_file($logo);
        main::badExit("Logo file was not bound into executable\n\tAlert System Administration") unless ($logo);
    } else {
        # Not running PerlAppified, so file should already exist
        $logo = $logo = "$FindBin::Bin/modules/" . "company.gif"; 
        #$logo = $logo = $ENV{'XYV_EXECS'} . "/procs/config/company.gif"; $FindBin::Bin/Modules
        main::badExit("Logo file <$logo> does not exist\nAlert System Administration") unless (-e "$logo");
    }

    #now draw the windows
    $self->window->configure(-bg=>$self->TK_BG, -fg=>$self->TK_FG, -title=>$self->xpp->progname());

    #frames---------------------------------------------------
    my $top      = $self->window()->Frame(-bg=>$self->TK_BG)->grid(-row=>'0',-column=>0,-columnspan=>'2',-sticky=>'w');
    my $middle   = $self->window()->Frame(-bg=>$self->TK_BG)->grid(-row=>'1',-column=>0,-columnspan=>'2');
    my $bot      = $self->window()->Frame(-bg=>$self->TK_BG)->grid(-row=>'2',-column=>0,-columnspan=>'2');
    my $botbar   = $self->window()->Frame()->grid(-row=>'3',-column=>0,-columnspan=>'2',-sticky=>'we');

    #top frame-------------------------------------------------
     my $image    = $top->Photo(-file=>$logo);
    $top->Label(
            -image=>$image,
            -bg=>$self->TK_BG,
            -fg=>$self->TK_FG,         )->grid(-row=>'0',-column=>0,-rowspan=>'3',-sticky=>'w');
    $top->Label(
            -bg=>$self->TK_BG,
            -fg=>$self->TK_FG,
            -font=>$self->TK_FNT_BIGGER,
            -text=>$self->xpp->progname()      )->grid(-row=>'0',-column=>1,-sticky=>'nw');
    $top->Label(
            -bg=>$self->TK_BG,
            -fg=>$self->TK_FG,
            -font=>$self->TK_FNT_BIGB,
            -text=>"Version: " . $self->version(),
                                       )->grid(-row=>'1',-column=>1,-sticky=>'nw');
    my $jobLabel =$self->joblabel();
    $jobLabel =~ s#GRP#\nGRP#;
    $jobLabel =~ s#JOB#\nJOB#;
    $jobLabel =~ s#DIV#\nDIV#;
    $top->Label(
            -bg=>$self->TK_BG,
            -fg=>$self->TK_FG,
            -font=>$self->TK_FNT_B,
            -justify=>'left',
            -text=>$jobLabel,
                                    )->grid(-row=>'2',-column=>1,-sticky=>'nw');
    #middle frame--------------------------------------------------
    my $row = 0;
	#separator
	$middle->Frame(
			-relief=>'solid',
			-height=>1,
			-background=>TK_FG,
					
								)->grid(-row=>$row, -column=>0, -columnspan=>3, -sticky=>'we');
	#droparea
	$row++;
	if ($fileSelect) {
		$middle->Label(
				-text=>"Import Files : ",
				-font=>TK_FNT_BIG,
				-bg=>TK_BG,
				-fg=>TK_FG, )->grid(-column=>'0', -row=>$row, -sticky=>'w', -pady=>5);
		$self->inputEntry($middle->Entry(
				-textvariable=>$self->inputFile(),
				-width=>'32',
				-font=>TK_FNT_B,
				-bg=>TK_GREY,
				-fg=>TK_FG, ))->grid(-column=>'1', -row=>$row, -sticky=>'w');
		$self->inputEntry->xview('end');
		$middle->Button(
			 -text => "...",
			 -command => sub {$self->tkSelectFile()},
			 -font => TK_FNT,
			 -bg => TK_GREY,
			 -fg => TK_FG,
			 -width => 3,
			 )->grid(-row=>$row, -column=>'2', -sticky=>'w');
		$row++;
		$self->inputDrop($middle->Frame(-bg=>$self->TK_BG));
		$self->inputDrop->grid(-row=>$row,-column=>0, -columnspan=>3, -pady=>5, -sticky=>"eswn" );

		$self->inputDrop->Label(
				-text=>"...drop file to be processed...",
				-font=>TK_FNT_BIG,
				-bg=>TK_GREY,
				-fg=>TK_FG, )->grid(-column=>'0', -row=>1, -sticky=>'we', -ipadx=>55, -ipady=>20);
		$self->inputDrop->DropSite(
						-dropcommand => [ \&GuiTool::accept_drop, $self],
						-droptypes => ($^O eq 'MSWin32' ? 'Win32' : ['KDE', 'XDND', 'Sun'])
						);

 	}
    #messages--------------------------------------
	$row++;
    $self->messageWindow($middle->Scrolled('Text',  -scrollbars=>'se'));
    $self->messageWindow->configure(-width=>'50' , height=>'18', wrap=>'none');
    $self->messageWindow->grid(-row=>$row,-column=>'0',-columnspan=>'3');
    

    #bottom frame-------------------------------------------------
    if ($fileSelect) {
		$self->{'start'} = $bot->Button(
            -text=>"Start",
            -font=>$self->TK_FNT_B,
			-command => sub {$self->onStart()},
            -borderwidth=>'4',
            -bg=>$self->TK_LGREEN,
            -fg=>$self->TK_FG,
            -activebackground=>$self->TK_GREEN,
            -disabledforeground=>$self->TK_BG,
			-state => 'disabled', 
			-width=>'15'		)->pack(-side=>'left',-padx=>'20',-pady=>'8');
	} else {
		$self->{'start'} = $bot->Button(
            -text=>"Start",
            -font=>$self->TK_FNT_B,
			-command => sub {$self->onStart()},
            -borderwidth=>'4',
            -bg=>$self->TK_GREEN,
            -fg=>$self->TK_FG,
            -activebackground=>$self->TK_RED,
            -disabledforeground=>$self->TK_BG,
			-width=>'15'		)->pack(-side=>'left',-padx=>'20',-pady=>'8');
	}
    $self->cancel($bot->Button(
            -text=>"Cancel",
            -font=>$self->TK_FNT_B,
            -command=>sub {$self->onCancel()},
            -borderwidth=>'4',
            -bg=>$self->TK_ABG,
            -fg=>$self->TK_FG,
            -activebackground=>$self->TK_RED,
            -width=>'15',       ))->pack(-padx=>'2',-pady=>'8');

	#bottom bar-------------------------------------------------
    my $frame3 = $botbar->Frame(-borderwidth=>'2')->pack(-side=>'left',-fill=>'x');
    $frame3->Label(-text=>" Action ")->pack(-side=>'left');
    my $frame4 = $botbar->Frame(-relief=>'sunken',-borderwidth=>'2')->pack(-side=>'left',-fill=>'x');
    if ($fileSelect) {
		$self->progress($frame4->Label(-text=>"Select/Drop File...")->pack(-side=>'left'));
	} else {
		$self->progress($frame4->Label(-text=>"Press Start")->pack(-side=>'left'));	
	}
	return();
}
#-------------------------------------------------------------
sub tkMessagebox {
#-------------------------------------------------------------
    my $self = shift;
    my($mesg) = @_;
    #do not try unless there is an active job window
    return() unless $self->has_window();

    #main is default window
    my $dialog = $self->window()->messageBox(
                -title=>$self->xpp->progname(),
				-icon=>'error',
				-message=>$mesg,
				-type=>'OK',
                );
	return();
}
#-------------------------------------------------------------
sub tkSelectFile {
#-------------------------------------------------------------
    my $self = shift;
    #select the input file
    #my $file = $self->{'window'}->getOpenFile();
    my $file = $self->window->getOpenFile();
    #no file selected?
    return() unless $file;
	#update window
	$self->updateInputEntry($file);
	return();
}

#-------------------------------------------------------------
sub update {
#-------------------------------------------------------------
	my $self = shift;
	$self->window->update();
	return();
}

#-------------------------------------------------------------
sub updateInputEntry {
#-------------------------------------------------------------
	my $self = shift;
	my $file = shift;
	return() unless $self->has_window();
	#display in entry box
	$file = canonpath($file);
	$self->inputFile($file);
	$self->inputEntry->configure(-textvariable=>\$file);
	$self->inputEntry->xview('end');
	$self->window->update();
	#change start button
	$self->start->configure(
		-state=>'normal',
        -text=>"Start",
		);
	$self->setProgress("Press Start");
	return();
}

#add some speed
__PACKAGE__->meta->make_immutable;


1;