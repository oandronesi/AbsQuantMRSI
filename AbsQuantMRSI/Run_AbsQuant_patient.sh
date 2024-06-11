#!/bin/bash -f

#######################################################################
## Patient specific script to run Absolute Metabolite Quantification ##
## Author: Ovidiu Andronesi, MGH, 6th June 2024                      ##
#######################################################################

## Author: Ovidiu Andronesi, MGH, 6th June 2024 

export measdata_dir="/autofs/space/somes_002/users/ovidiu/Data/3T/Spiral/MeasuredData"
export procdata_dir="/autofs/space/somes_002/users/ovidiu/Data/3T/Spiral/ProcessedData"
export pipeline_dir="/autofs/space/somes_001/users/ovidiu/Programs/AbsoluteQuantification"

####################################

for subj in \
Patients/Martinos_MGH/Pat01_Prisma_3T_10Jun2024 \
; do

##Absolute quantification EPTI measured T1, T2, PD maps of water
$pipeline_dir/Allsteps_AbsQuant.sh \
--datadir $procdata_dir/$subj/MRSI_ASE_Spiral_TE97_metab \
--MetaMlistDN "NAA+NAAG,GPC+PCh,Cr+PCr,Ins,Glu,Gln,GABA,GSH,2HG,Gly" \
--highResIm MEMPRAGE \
--rmseThresh 30 \
--CSFthresh 0.5 \
--CSFtumor Yes \
--B0field 3T \
--MRF Yes \
--ConcScalingFactor 1 \
--StatusDisease Healthy \

##Absolute quantification using standard literature values for T1 and T2 relaxation times of water
$pipeline_dir/Allsteps_AbsQuant.sh \
--datadir $procdata_dir/$subj/MRSI_ASE_Spiral_TE97_metab \
--MetaMlistDN "NAA+NAAG,GPC+PCh,Cr+PCr,Ins,Glu,Gln,GABA,GSH,2HG,Gly" \
--highResIm MEMPRAGE \
--rmseThresh 30 \
--CSFthresh 0.5 \
--CSFtumor Yes \
--B0field 3T \
--MRF No \
--ConcScalingFactor 1 \
--StatusDisease Healthy

done
