
use strict;
# package used to get the current working folder
use wsmk_wrkFolder;
my $currentLibfolder;
# get the current working folder and unset the environment variable that has been set in the 
# batch file/ shell script file 
BEGIN {$currentLibfolder = main_getCurrentLibFolder();}
use vars qw/$currentLibfolder/;
use lib $currentLibfolder;

#Standard and nonstandard packages used by the tool 
use strict;                 #for declaration of variables prior to use
use FileHandle;             #for file operations
use File::Copy;             #for copying the file in a local machine  
use LWP::Simple;            #for website header information
use IO::Dir;			    #for directory handling
use Sys::Hostname;          # 
use File::Listing;          #to display a list of files in a directory  
use Time::localtime;        #get system time information

# custom packages developed to be used by the tool	
use wsmk_constants;		    #for user input or error or file constants 
use wsmk_utilityFunctions;  #for common procedures
use wsmk_informationLog;    #used for logging information into Log,Status or Recovery file
use wsmk_userInterface;     #used for user interface definition
use wsmk_auth;	            #used for Authentication and user query module 	
use wsmk_parse;             #used for parsing the conf file and getting the site information	
use wsmk_parse2;		    #used for parsing the conf file and generating the 2D array.

# main subroutine starts here
my $localConfFilePath;
my $boolVersionNumber;
my $blnWISrcRet;
my $logFileReturn;
my $RecoveryMode = "";
my $DEBUG_MODE = FALSE;
eval
{
    my $auqRetVal;
    ($auqRetVal,$localConfFilePath) = auth_main();        # AUQ module functionality    
    if(!($auqRetVal))
    {
	    die CLEANUP_AND_EXIT;
    }    

    if ( ($RecoveryMode ne RECOVERY_MODE_1) && ($RecoveryMode ne RECOVERY_MODE_2) && ($RecoveryMode ne RECOVERY_MODE_3))
    {        
	    &pars_FirstPass($localConfFilePath);    # Parser Module first pass
        &pars_SetRecoveryCode(RECOVERY_MODE_1);    
    }
    
    if (($RecoveryMode ne RECOVERY_MODE_2) && ($RecoveryMode ne RECOVERY_MODE_3))
    {
        # Concatenate all of the configuration files in preparation for the next step where we parse the master file
        use Cwd;
        my $pwd = cwd();
        # get the current working folder
        my $strCurWorkingFolder = &utf_getCurrentWorkingFolder();
        # get session name
        my $strSessionName = &ilog_getSessionName();
        # form the complete working folder
        my $workingFolder = $strCurWorkingFolder . '/' . $strSessionName;
        # change local dir
        my $retwrk_changeLocalDir = wrk_changeLocalDir($workingFolder);
        if (!($retwrk_changeLocalDir))
        {
            $logFileReturn= ilog_setLogInformation('EXT_ERROR',ERR_CWD_COMMAND,'', __LINE__);
            if(!($logFileReturn))
            {	
                $logFileReturn=ilog_print(ERR_INTERNAL_ERROR_CONSOLE.__LINE__,1);
            }

            return 0;
        }

        # my @files        = grep { -f } glob( '*.conf' );
        my @files = File::Find::Rule->file()
            ->name("*apache*")            
            ->in($strCurWorkingFolder);

        my @fhs          = map { open my $fh, '<', $_; $fh } @files;
        my $concatenated = '';
        while (my $fh = shift @fhs) {
            while ( my $line = <$fh> )
            {
                $concatenated .= $line;
            }

            close $fh;
        }

        # go back to orginal dir
        chdir($pwd); 

        my $confAllName = &utf_getCompleteFilePath(FILE_CONF_ALL);
        my $HANDLE_CONF_ALL = new IO::File;
        if(open(HANDLE_CONF_ALL,">> $confAllName") or die 'ERR_FILE_OPEN')
        {
            print HANDLE_CONF_ALL $concatenated;
            close(HANDLE_CONF_ALL); 
        }
        
        &pars_Generate2D(&utf_getCompleteFilePath(FILE_CONF_ALL),&utf_getCompleteFilePath(FILE_RECOVERY)); 
        # Parser Module second pass
        &pars_SetRecoveryCode(RECOVERY_MODE_2);
    }

    &pars_CreateReadinessReport();
    &pars_UploadPublishSettingsAllSites();
    &pars_SetRecoveryCode(RECOVERY_MODE_3);
	utf_setCurrentModuleName(''); 
	&utf_gettimeinfo('1');
    &TerminateTool();
};
if($@)
{
    if ($@ !~ /EXIT_TOOL_NOW/)
    {
        # Abnormal Termination ... 
        print "$@";
    }
}
# end of main subroutine

sub TerminateTool
{
    # Clean up and exit tool
    &utf_DisposeFiles();
    # Restore the include to the original value
    @INC = @lib::ORIG_INC;
    exit(0);
}