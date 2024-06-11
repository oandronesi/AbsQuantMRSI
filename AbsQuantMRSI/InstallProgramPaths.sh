##### In this file aliases and paths of all dependent programs are specified so that the script Allsteps_AbsQuant.sh knows all commands.

##### The following programs are necessary:
##### -- OS: Linux					(12.04.3 LTS, current used Kernel: GNU/Linux 3.2.0-48-generic x86_64)
##### -- MATLAB 					(matlab78R2009a)
##### -- FSL 						(FSL package 6.0.5.1, or newer)
##### -- Freesurfer 				(Freesurfer package 7.1.1, or newer)
##### -- tar 						(Any version should work)
##### -- gzip						(Any version should work)
##### -- gunzip						(Any version should work)

## Author: Ovidiu Andronesi, MGH, 6th June 2024 

# aliases

# MATLAB 
export matlabc='/autofs/cluster/matlab/current/bin/matlab'
export matlabp='/autofs/cluster/matlab/9.3/bin/matlab'

# Brain extraction tool (bet) of FSL
export FSLDIR="/usr/pubsw/packages/fsl/current"
export betp="$FSLDIR/bin/bet"
export PATH=$FSLDIR/bin:$PATH
. ${FSLDIR}/etc/fslconf/fsl.sh
export flirtp="/usr/pubsw/packages/fsl/6.0.5.1/bin/flirt"

# Freesurfer 
export FREESURFER_HOME="/usr/local/freesurfer/stable7.1.1"
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export freesurferp=/autofs/vast/freesurfer/centos7_x86_64/7.1.1/matlab


# MATLAB Functions Folder
LocalMatDir=`pwd`
if [ -d $LocalMatDir/Matlab_Functions ]; then
	export MatlabFunctionsFolder="$LocalMatDir/Matlab_Functions"
fi
MatlabStartupCommand="Paths = regexp(path,':','split');rmpathss = ~cellfun('isempty',strfind(Paths,'Matlab_Functions')); if(sum(rmpathss) > 0);"
export MatlabStartupCommand="${MatlabStartupCommand} x = strcat(Paths(rmpathss), {':'});x = [x{:}]; rmpath(x); end; clear Paths rmpathss x; addpath(genpath('${MatlabFunctionsFolder}'))"


