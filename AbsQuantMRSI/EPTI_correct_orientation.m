%% Author: Ovidiu Andronesi, MGH, 6th June 2024 

%function [T1,T2,Ts,PD] = EPTI_correct_orientation(mrf_folder)

mrf_folder = getenv('mrf_folder');

%% in case map names change it can be made more flexible
% eval(sprintf('cd %s', mrf_folder));
% fprintf('path_mrf = %s\n', mrf_folder);
% fname = dir(mrf_folder);
% fname = fname(3).name;
% fprintf('file = %s\n', fname);

T1=MRIread(fullfile(mrf_folder,'T1.nii.gz'),0);
T2=MRIread(fullfile(mrf_folder,'T2.nii.gz'),0);
PD=MRIread(fullfile(mrf_folder,'PD.nii.gz'),0);
T2s=MRIread(fullfile(mrf_folder,'T2star.nii.gz'),0);
RMSE=MRIread(fullfile(mrf_folder,'RMSE.nii.gz'),0);

T1c=flip(flip(permute(T1.vol,[2,1,3]),2),1);
T1.vol=T1c;
T2c=flip(flip(permute(T2.vol,[2,1,3]),2),1);
T2.vol=T2c;
PDc=flip(flip(permute(PD.vol,[2,1,3]),2),1);
PD.vol=PDc;
T2sc=flip(flip(permute(T2s.vol,[2,1,3]),2),1);
T2s.vol=T2sc;
RMSEc=flip(flip(permute(RMSE.vol,[2,1,3]),2),1);
RMSE.vol=RMSEc;

MRIwrite(T1,fullfile(mrf_folder,'T1.nii.gz'),'float');
MRIwrite(T2,fullfile(mrf_folder,'T2.nii.gz'),'float');
MRIwrite(PD,fullfile(mrf_folder,'PD.nii.gz'),'float');
MRIwrite(T2s,fullfile(mrf_folder,'T2star.nii.gz'),'float');
MRIwrite(RMSE,fullfile(mrf_folder,'RMSE.nii.gz'),'float');

%return