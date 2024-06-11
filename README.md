# AbsQuantMRSI
# Absolute Metabolite Quantification for MRSI

## Author: Ovidiu Andronesi, MGH, 6th June 2024 

## A. To run this analysis the following data should be available:
## 1. Metabolic maps from MRSI before absolute quantification - these should be maps produced after using a spectra fitting software such as LCModel or jMRUI
## 2. Water reference maps from MRSI acquired with the same protocol like metabolite MRSI - these should be a map produced after using the same spectra fitting software like for metabolites
## 3. Anatomical MRI: T1 weighted MPRAGE for healthy brains or T2 weighted FLAIR for tumors
## 4. T1, T2 and PD maps obtained with a multiparametric MRI protocol such as EPTI or MRF

## B. Running this script implies:
## 1. Calling the script Allsteps_AbsQuant.sh with the correct parameters options
## 2. An example of how to call the Allsteps_AbsQuant.sh with the correct parameters options can be found in the patiennt specific script Run_AbsQuant_patient.sh
## 3. The script Allsteps_AbsQuant.sh will produce segmentation of MRI and coregister segmentation to MRSI
## 4. The script Allsteps_AbsQuant.sh will call the Matlab script EPTI_correct_orientation.m to extract T1/T2/PD maps from EPTI and coregister to MRSI
## 5. The script Allsteps_AbsQuant.sh will call the Matlab script AbsoluteQuant.m to convert the metablic maps into absolute mM concentration maps
## 6. All the program dependences are specified in InstallProgramPaths.sh
## 7. The paths and folders of the programs and data will have to be adapted based on the user and its conventions for program installation and data storage

## C. Dependent programs that are needed:
## 1. Linux OS
## 2. Matlab
## 3. FSL
## 4. Freesurfer
## 5. The location of all the programs is specified in InstallProgramPaths.sh


## The pipeline flowchart steps: Run_AbsQuant_patient.sh -> Allsteps_AbsQuant.sh -> (FSL & Freesurfer & EPTI_correct_orientation.m & AbsoluteQuant.m)
