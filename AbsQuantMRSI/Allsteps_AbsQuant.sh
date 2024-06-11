#!/bin/bash
###########################################################################################
###	    Perform Absolute Quantification of Metabolic Maps using MRSI and EPTI data	    ###
###     Author: Ovidiu Andronesi, MGH, 6th June 2024                                    ###
###########################################################################################

# -1. Preparations
# In case you hit ctrl-c, kill all processes, also background processes. Trap all exit signals and the SIGUSR1 signal.
trap "{ Trapped=1; echo Try to kill: PID: $$, PPID: $PPID; TerminateProgram; echo 'Kill all processes due to user request.'; sleep 3s; kill 0;}" SIGINT SIGUSR1
TerminateProgram(){


	echo "Stop tee."
	# close and restore backup; both stdout and stderr

	exec 1>&6 # duplicate 6 to 1 again
	exec 6>&- # close 6
	exec 2>&7 # duplicate 7 to 2 again
	exec 7>&- # close 7
	sleep 1

	echo -e "\n\nTerminate Program & Backup: "

	cd $calldir

	# Copy the logfile
	echo "Copy logfile to $out_path/UsedSourcecode/logfile.log."
	if [ -d $out_path/UsedSourcecode ]; then
		cp $logfile $out_path/UsedSourcecode
		cp $TMPDIR/ErrorFile.sh $out_path/UsedSourcecode
	fi

	rm -fR $out_path/TempServerDir

	if [[ "$1" == "1" ]]; then		# DebugFlag = 1
		rmtmpdir="n"
	else
		rmtmpdir="y"		
	fi
	echo -e "\n$rmtmpdir"
	if [[ "$rmtmpdir" == "y" ]]; then

		if [ -n "${pid_list[1]}" ]; then
			echo "Wait for all LCModel Processes to terminate gracefully."
			sleep 40		# So that all lcmodel processes can close
		fi

		rm -R -f "$( dirname "${BASH_SOURCE[0]}" )/$TMPDIR"
		if [ -d "$( dirname "${BASH_SOURCE[0]}" )/$TMPDIR" ]; then
			sleep 10
			rm -R -f "$( dirname "${BASH_SOURCE[0]}" )/$TMPDIR"		# Try again if it didnt work
		fi
	fi
	echo "Stop now."
	echo -e "\n\n\n\t\tE N D\n\n\n"

	if [[ "$Trapped" == "0" ]]; then
		exit 0;
	fi
}

# -1.1 Debug flag
DebugFlag=0
Trapped=0


# -1.2 Change to directory of script
calldir=$(pwd)
cd "$( dirname "${BASH_SOURCE[0]}" )"


# -1.3 Create directories
tmp_trunk="tmp"
tmp_num=1
TMPDIR="${tmp_trunk}${tmp_num}"
while [ -d "$TMPDIR" ]; do
	let tmp_num=tmp_num+1
	TMPDIR="${tmp_trunk}${tmp_num}"	
done
export TMPDIR
echo "TMPDIR is: $TMPDIR"
mkdir $TMPDIR
chmod 777 $TMPDIR



# -1.4 Write the script output to a logfile
logfile=${TMPDIR}/logfile.log
hostyy=$(hostname)
echo -e "Run Script on $hostyy with parameters:\n$0 $*\n\n"
echo -e "Run Script on $hostyy with parameters:\n$0 $*" > $logfile


# backup the original filedescriptors, first
# stdout (1) into fd6; stderr (2) into fd7
exec 6<&1							# Copy 1 to 6
exec 7<&2							# Copy 2 to 7
exec > >(tee -a $logfile)			# Copy 1 to tee which writes to logfile
exec 2> >(tee -a $logfile >&2)		# Copy 2 to tee which writes to logfile and redirect to 1 and 2 [???]

echo -e "\n\n0.\t\tS T A R T (PID $$, PPID $PPID)"
sleep 3s;
# 0.

## Step 1.1 ########### DEFINE ARGUMENTS/PARAMETER OPTIONS ####################
export data_dir=unset
export highResIm=unset
export MetaMlistDN=unset
export MRF=unset
export rmseThresh=unset
export CSFthresh=unset
export CSFtumor=unset 
export B0field=unset
export ConcScalingFactor=unset
export StatusDisease=unset
usage()
{
  echo "Usage: Part4_AbsQuant [ -d | --datadir subject directory][--highResIm][--water  watermap folder ][--MRF set to 1 if there is MRF][--rmseThresh RMSE threshold][--CSFthresh RMSE threshold][CSFtumor if Yes ignore CSF in the tumor][--B0field B0 field][--MetaMlistDN MetaMlistDN separated by comma, or all][ConcScalingFactor concentration scaling factor due to differences in water and metabolite LCModel fitting][StatusDisease the disease status of subject Healthy or Glioma, it is used only with the Std method not with MRF"
  exit 2
}


PARSED_ARGUMENTS=$(getopt -a -n Part4_AbsQuant -o d: --long datadir:,MetaMlistDN:,highResIm:,rmseThresh:,\
CSFthresh:,CSFtumor:,B0field:,MRF:,ConcScalingFactor:,StatusDisease: -- "$@")

VALID_ARGUMENTS=$?

if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

echo "Parsed args are= $PARSED_ARGUMENTS"

eval set -- "$PARSED_ARGUMENTS"  

while true; do
  case "$1" in
    -d | --datadir)		export data_dir="$2"; shift 2 ;;
	 --MetaMlistDN)      	export MetaMlistDN="$2"; shift 2 ;;
	 --highResIm)      	export highResIm="$2"; shift 2 ;;
	 --rmseThresh)          export rmseThresh="$2"; shift 2 ;;
	 --CSFthresh)           export CSFthresh="$2"; shift 2 ;;
     --CSFtumor)		export CSFtumor="$2"; shift 2 ;;
	 --B0field)             export B0field="$2"; shift 2 ;;
	 --MRF)     		export MRF="$2"; shift 2 ;;
	 --ConcScalingFactor)   export ConcScalingFactor="$2"; shift 2 ;;
	 --StatusDisease)       export StatusDisease="$2"; shift 2 ;;
         --) shift; break ;; # -- means the end of the arguments; drop this, and break out of the while loop
	*) echo "Unexpected option: $1 is not a vlid argument." # Report an error if invalid options were passed
       usage ;;
  esac
done

echo -e "\n datadir: $data_dir\n"
echo -e "MRF: $MRF\n"
echo -e "MetaMlistDN: $MetaMlistDN\n"
echo -e "RMSE threshold: $rmseThresh\n"
echo -e "CSF threshold: $CSFthresh\n"
echo -e "CSF tumor correction: $CSFtumor\n"
echo -e "B0 field: $B0field\n"
echo -e "HighRes Image: $highResIm.nii.gz\n"
echo -e "Concentration Scaling Factor: $ConcScalingFactor\n"
echo -e "Disease status for std quantification: $StatusDisease\n"

## Step 1. ############ Install Paths  ####################
echo -e "\t1 Install Program,  make directories \n" 

 . ./InstallProgramPaths.sh
part4dir=$(pwd)

if [ ! -d ${data_dir}/maps/SuperResolution/ ]; then
mkdir ${data_dir}/maps/SuperResolution/
fi
mkdir ${data_dir}/../MRF/
mkdir ${data_dir}/maps/AbsQuantSR
mkdir ${data_dir}/maps/AbsQuantSR/Anatomy
export mrf_folder=${data_dir}/../MRF

#############################################################
#Step 1.
#Brain MRI segmentation and resample GM/WM/CSF masks to MRSI
#############################################################
if [ ! -f ${data_dir}/../MRI_anat/Segmentation/${highResIm}_segm_pve_2.nii.gz ]; then
echo -e "\t1 Brain segmentation and resample GM/WM/CSF to SR MRSI \n" 
mkdir  ${data_dir}/../MRI_anat/Segmentation

#Bias field correction
mri_nu_correct.mni --i ${data_dir}/../MRI_anat/${highResIm}.nii.gz --o ${data_dir}/../MRI_anat/${highResIm}_nu.nii.gz --n 2 --ants-n4
#bet2 ${data_dir}/../MRI_anat/${highResIm}_nu.nii.gz ${data_dir}/../MRI_anat/${highResIm}_strip.nii.gz -f 0.5 -g -0.15
bet2 ${data_dir}/../MRI_anat/${highResIm}_nu.nii.gz ${data_dir}/../MRI_anat/${highResIm}_strip.nii.gz -f 0.6 -g 0
bet2 ${data_dir}/../MRI_anat/${highResIm}_strip.nii.gz ${data_dir}/../MRI_anat/${highResIm}_strip.nii.gz -f 0.5 -g 0
fslmaths ${data_dir}/../MRI_anat/${highResIm}_strip.nii.gz -bin ${data_dir}/../MRI_anat/${highResIm}_brain_mask.nii.gz
fast -t 1 -o ${data_dir}/../MRI_anat/Segmentation/${highResIm}_segm.nii.gz -n 3  ${data_dir}/../MRI_anat/${highResIm}_strip.nii.gz
fi

#threshold the segmentation maps
if [ ! -f ${data_dir}/../MRI_anat/Segmentation/WM.nii.gz ]; then
fslmaths ${data_dir}/../MRI_anat/Segmentation/${highResIm}_segm_pve_0.nii.gz -thr 0.99 ${data_dir}/../MRI_anat/Segmentation/CSF.nii.gz
fslmaths ${data_dir}/../MRI_anat/Segmentation/CSF.nii.gz -bin ${data_dir}/../MRI_anat/Segmentation/CSF.nii.gz
fslmaths ${data_dir}/../MRI_anat/Segmentation/${highResIm}_segm_pve_1.nii.gz -thr 0.99 ${data_dir}/../MRI_anat/Segmentation/GM.nii.gz
fslmaths ${data_dir}/../MRI_anat/Segmentation/GM.nii.gz -bin ${data_dir}/../MRI_anat/Segmentation/WM.nii.gz
fslmaths ${data_dir}/../MRI_anat/Segmentation/${highResIm}_segm_pve_2.nii.gz -thr 0.99 ${data_dir}/../MRI_anat/Segmentation/WM.nii.gz
fslmaths ${data_dir}/../MRI_anat/Segmentation/WM.nii.gz -bin ${data_dir}/../MRI_anat/Segmentation/WM.nii.gz

fi

###################################################
#downsample MRI segmentation masks to MRSI size
###################################################

if [ ! -f ${data_dir}/maps/SuperResolution/Anatomy/WM_sr_bin.nii.gz ]; then

if [ ! -f ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr_bin.nii.gz ]; then

mri_binarize --i ${data_dir}/../MRI_anat/${highResIm}_brain_mask.nii.gz --min 1 --max 1 --erode 2 --o ${data_dir}/maps/AbsQuantSR/Anatomy/${highResIm}_brain_mask_erode_sr.nii.gz
mri_convert -rt nearest -it nii -i ${data_dir}/maps/AbsQuantSR/Anatomy/${highResIm}_brain_mask_erode_sr.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/${highResIm}_brain_mask_erode_sr.nii.gz

mri_convert -rt nearest -it nii -i ${data_dir}/../MRI_anat/Segmentation/${highResIm}_segm_pve_0.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr.nii.gz
mri_convert -rt nearest -it nii -i ${data_dir}/../MRI_anat/Segmentation/${highResIm}_segm_pve_1.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr.nii.gz
mri_convert -rt nearest -it nii -i ${data_dir}/../MRI_anat/Segmentation/${highResIm}_segm_pve_2.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr.nii.gz

#normalize the SR segmentation masks
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr.nii.gz -add ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/Segm_norm.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr.nii.gz -add ${data_dir}/maps/AbsQuantSR/Anatomy/Segm_norm.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/Segm_norm.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr.nii.gz -div ${data_dir}/maps/AbsQuantSR/Anatomy/Segm_norm.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr.nii.gz -div ${data_dir}/maps/AbsQuantSR/Anatomy/Segm_norm.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr.nii.gz -div ${data_dir}/maps/AbsQuantSR/Anatomy/Segm_norm.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr.nii.gz 

fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr.nii.gz

mri_convert -rt nearest -it nii -i ${data_dir}/../MRI_anat/Segmentation/CSF.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr_bin.nii.gz
mri_convert -rt nearest -it nii -i ${data_dir}/../MRI_anat/Segmentation/GM.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr_bin.nii.gz
mri_convert -rt nearest -it nii -i ${data_dir}/../MRI_anat/Segmentation/WM.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr_bin.nii.gz

fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr_bin.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr_bin.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr_bin.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr_bin.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr_bin.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr_bin.nii.gz

fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr_bin.nii.gz -bin ${data_dir}/maps/AbsQuantSR/Anatomy/CSF_sr_bin.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr_bin.nii.gz -bin ${data_dir}/maps/AbsQuantSR/Anatomy/GM_sr_bin.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr_bin.nii.gz -bin ${data_dir}/maps/AbsQuantSR/Anatomy/WM_sr_bin.nii.gz

fi

else

cp ${data_dir}/maps/SuperResolution/Anatomy/*_sr.nii ${data_dir}/maps/AbsQuantSR/Anatomy/
cp ${data_dir}/maps/SuperResolution/Anatomy/*_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/
cp ${data_dir}/maps/SuperResolution/Anatomy/*_sr_bin.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/

fi

if [ ! -f ${data_dir}/maps/AbsQuantSR/Anatomy/FLAIR-mask_tumor_sr.nii.gz ]; then
if [ -f ${data_dir}/maps/AbsQuantSR/Anatomy/FLAIR-mask_tumor_sr.nii ]; then
gzip ${data_dir}/maps/AbsQuantSR/Anatomy/FLAIR-mask_tumor_sr.nii
fi
fi 

#############################################################
#Step 2.
#Downsample EPTI to MRSI resolution
#############################################################
if [ $MRF = 'Yes' ]; then
  echo -e " \t2. EPTI exists: prepare T1, T2, PD maps ===>>> \n"

if [ ! -f ${data_dir}/../MRF/RMSE_mask.nii.gz ]; then

  echo -e " \t2.1 Extract T1,T2, PD from the MRF 4D data \n"
  #Extract T1,T2, PD from the EPTI 4D data
  mri_convert -it nii -i ${data_dir}/../MRF/EPTI_GE2SE3Lines_TR2p6_TR0p8_Scan1_B1_Fit_Final.nii -f 0  -ot nii -o ${data_dir}/../MRF/T1.nii.gz
  mri_convert -it nii -i ${data_dir}/../MRF/EPTI_GE2SE3Lines_TR2p6_TR0p8_Scan1_B1_Fit_Final.nii -f 1  -ot nii -o ${data_dir}/../MRF/T2.nii.gz
  mri_convert -it nii -i ${data_dir}/../MRF/EPTI_GE2SE3Lines_TR2p6_TR0p8_Scan1_B1_Fit_Final.nii -f 2  -ot nii -o ${data_dir}/../MRF/T2star.nii.gz
  mri_convert -it nii -i ${data_dir}/../MRF/EPTI_GE2SE3Lines_TR2p6_TR0p8_Scan1_B1_Fit_Final.nii -f 3  -ot nii -o ${data_dir}/../MRF/PD.nii.gz
  mri_convert -it nii -i ${data_dir}/../MRF/EPTI_GE2SE3Lines_TR2p6_TR0p8_Scan1_B1_Fit_Final.nii -f 4  -ot nii -o ${data_dir}/../MRF/RMSE.nii.gz

  echo -e " \t2.2 Correct the orientation of MRF \n"
  ${matlabp} -nosplash -nodesktop -r "mrf_folder = '${mrf_folder}'; TMPDIR = '${TMPDIR}'; addpath(genpath('${freesurferp}'),genpath('${MatlabFunctionsFolder}'))" <${MatlabFunctionsFolder}/EPTI_correct_orientation.m
 
 echo -e " \t2.3 Coregister to ${highResIm} \n "
  $flirtp -ref ${data_dir}/../MRI_anat/${highResIm}.nii.gz -in ${data_dir}/../MRF/T1.nii.gz -cost mutualinfo -omat ${data_dir}/../MRF/EPTI2MP.mat -out ${data_dir}/../MRF/T1.nii.gz
  $flirtp -ref ${data_dir}/../MRI_anat/${highResIm}.nii.gz -in ${data_dir}/../MRF/T2.nii.gz -out ${data_dir}/../MRF/T2.nii.gz -applyxfm -init ${data_dir}/../MRF/EPTI2MP.mat
  $flirtp -ref ${data_dir}/../MRI_anat/${highResIm}.nii.gz -in ${data_dir}/../MRF/PD.nii.gz -out ${data_dir}/../MRF/PD.nii.gz -applyxfm -init ${data_dir}/../MRF/EPTI2MP.mat
  $flirtp -ref ${data_dir}/../MRI_anat/${highResIm}.nii.gz -in ${data_dir}/../MRF/T2star.nii.gz -out ${data_dir}/../MRF/T2star.nii.gz -applyxfm -init ${data_dir}/../MRF/EPTI2MP.mat
  $flirtp -ref ${data_dir}/../MRI_anat/${highResIm}.nii.gz -in ${data_dir}/../MRF/RMSE.nii.gz -out ${data_dir}/../MRF/RMSE.nii.gz -applyxfm -init ${data_dir}/../MRF/EPTI2MP.mat

#Apply the brain mask
 fslmaths ${data_dir}/../MRF/T1.nii.gz     -mul ${data_dir}/../MRI_anat/${highResIm}_brain_mask.nii.gz ${data_dir}/../MRF/T1.nii.gz
 fslmaths ${data_dir}/../MRF/T2.nii.gz     -mul ${data_dir}/../MRI_anat/${highResIm}_brain_mask.nii.gz ${data_dir}/../MRF/T2.nii.gz
 fslmaths ${data_dir}/../MRF/PD.nii.gz     -mul ${data_dir}/../MRI_anat/${highResIm}_brain_mask.nii.gz ${data_dir}/../MRF/PD.nii.gz
 fslmaths ${data_dir}/../MRF/T2star.nii.gz -mul ${data_dir}/../MRI_anat/${highResIm}_brain_mask.nii.gz ${data_dir}/../MRF/T2star.nii.gz
 fslmaths ${data_dir}/../MRF/RMSE.nii.gz   -mul ${data_dir}/../MRI_anat/${highResIm}_brain_mask.nii.gz ${data_dir}/../MRF/RMSE.nii.gz

  echo -e "\t2.4 Threshold RMSE for the upper error and apply to T1,T2,PD \n"
#Upper threshold RMSE for error and create a mask for T1, T2 and PD
 fslmaths ${data_dir}/../MRF/RMSE.nii.gz -uthr ${rmseThresh} ${data_dir}/../MRF/RMSE_mask.nii.gz
 fslmaths ${data_dir}/../MRF/RMSE_mask.nii.gz -bin ${data_dir}/../MRF/RMSE_mask.nii.gz

fi


 ##################################################
 ### Resample EPTI at the MRSI super-resolution ####
 ##################################################

  #Resample MRF to MRSI super-resolution and apply the brain mask
if [ ! -f ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_sr.nii.gz ]; then
  echo -e "\t2.6 Resample EPTI to MRSI super-resolution and apply the brain mask \n"
  mri_convert -rt cubic -it nii -i ${data_dir}/../MRF/T1.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/T1_sr.nii.gz
  mri_convert -rt cubic -it nii -i ${data_dir}/../MRF/T2.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/T2_sr.nii.gz
  mri_convert -rt cubic -it nii -i ${data_dir}/../MRF/PD.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/PD_sr.nii.gz
  mri_convert -rt cubic -it nii -i ${data_dir}/../MRF/RMSE.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_sr.nii.gz
#resample RMSE_mask to MRSI
  mri_convert -rt nearest -it nii -i ${data_dir}/../MRF/RMSE_mask.nii.gz --like ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_sr.nii.gz

 fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_sr.nii.gz -thr 0.999 ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_sr.nii.gz
 fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_sr.nii.gz -bin ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_sr.nii.gz

  echo -e "\t2.7 Skull strip MRF at superres using the mask of skull stripped ${highResIm} \n"
  #skull strip EPTI at superres using the mask of skull stripped FLAIR or MEMPRAGE

  fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/T1_sr.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/T1_sr.nii.gz
  fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/T2_sr.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/T2_sr.nii.gz
  fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/PD_sr.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/PD_sr.nii.gz
  fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_sr.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_sr.nii.gz
  fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_sr.nii.gz -mul ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_sr.nii.gz

fi

#Create a mask only for the CSF of ventricles to estimate the factor for PD normalization
#This can be done also by using Freesurfer segmentation that produces ventricle ROI
if [ ! -f ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_ventricles.nii.gz ]; then
echo -e " \t2.8 Create mask for ventricles for PD normalization \n"

mri_convert -rt nearest -it nii -i ${data_dir}/maps/SuperResolution/mask_${highResIm}_sr.nii.gz --like ${data_dir}/../MRI_anat/${highResIm}.nii.gz -ot nii -o ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz -thr 0.999 ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz -bin ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz
mri_binarize --i ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz --min 1 --max 1 --erode 10 --o ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz -mul ${data_dir}/../MRI_anat/Segmentation/${highResIm}_segm_pve_0.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz -thr 0.999 ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz
fslmaths ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz -bin ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz
fslmaths ${data_dir}/../MRF/RMSE_mask.nii.gz -mul ${data_dir}/maps/AbsQuantSR/Anatomy/mask_ventricles.nii.gz ${data_dir}/maps/AbsQuantSR/Anatomy/RMSE_mask_ventricles.nii.gz

fi

else 
  echo " \t2 EPTI is not available, use standard literature values for T1&T2 and water density \n "
fi


#############################################################
#Step 3.
#Run Absolute Quantification
#############################################################
echo " \t3 Run Absolute Quantification \n"
${matlabc} -nodisplay -r "TMPDIR = '${TMPDIR}'; addpath(genpath('${MatlabFunctionsFolder}'))" -nodisplay < AbsoluteQuant.m

#############################################################
# Step 4. Save logfile and remove tmp folders
#############################################################
cp $part4dir/$logfile ${data_dir}/Logfiles/Part4_logfile_${MRF}MRF.log 
rm -r $part4dir/$TMPDIR

