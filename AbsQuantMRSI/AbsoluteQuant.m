
%% Absolute metabolite quantification from MRSI data 
%% this Matlab script is called by the Allsteps_AbsQuant.sh shell script

%% Data used: 
%% 1. metabolite MRSI - metabolic maps obtained by LCModel fitting of water-suppressed MRSI
%% 2. water MRSI - reference water map obtained by LCModel fitting of water-unsuppressed MRSI
%% 3. T1 and T2 water correction based on - a) EPTI multiparametric imaging or b) literature values
%% 4. Brain segmentation - white matter, gray matter, and CSF maps

%% Author: Ovidiu Andronesi, MGH, 6th June 2024  

%% 0. DEFINITIONS, PREPARATIONS
data_dir = getenv('data_dir');
savedir = data_dir;
hasMRF = getenv('MRF'); %% 'Yes' if EPTI data is available; 'No' if literature values are used
CSFthr = str2double(getenv('CSFthresh'));
CSF_tumor = getenv('CSFtumor');
B_0 = getenv('B0field');
conc_sf = str2double(getenv('ConcScalingFactor'));
status_dis = getenv('StatusDisease');
HighResImg = getenv('highResIm');

%load(sprintf('%s/maps/AllMaps.mat',data_dir))
%fprintf('\n CSI resolusion is %s \n', data_dir)
lowres=0;
if lowres==1 %Low res MRSI
    AllMaps.Segmentation.CSF_CSI_map = Segmentation_CSF_CSI_map;
    AllMaps.Segmentation.GM_CSI_map = Segmentation_GM_CSI_map;
    AllMaps.Segmentation.WM_CSI_map = Segmentation_WM_CSI_map;
    f_CSF = AllMaps.Segmentation.CSF_CSI_map;
    f_WM = AllMaps.Segmentation.WM_CSI_map;
    f_GM = AllMaps.Segmentation.GM_CSI_map;
else
    % Super Resolution MRSI
    disp('Loading segmentation  sr Image') 
    f_GM = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/GM_sr.nii.gz'));
    f_WM = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/WM_sr.nii.gz'));
    f_CSF = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/CSF_sr.nii.gz'));
    csf_info = niftiinfo(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/CSF_sr.nii.gz'));
    f_CSF(f_CSF>CSFthr)=1; % corrected CSF 

    if strcmp(CSF_tumor,'Yes')
        T_ROI = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/FLAIR-mask_tumor_sr.nii.gz'));
        f_CSF = f_CSF .* single(1-uint8(T_ROI)); % Subtract from the CSF mask the tumor to avoiud scaling PD values by the tumor.
    end

    fname = fullfile(data_dir,'maps/AbsQuantSR/Anatomy/CSF_sr_corrected');
    niftiwrite(f_CSF,fname,csf_info,'Compressed',true);
end

disp('Load Watermap if existed')
S_water = 1; % if watermap not available just do the T1 and T2 corrections of Metabolites
if lowres ==1
    fpath = sprintf('%s/maps/Denoise/Water_amp_map.nii',data_dir); 
    if exist(fpath,"file")
        disp('Loading water Image') 
        S_water = niftiread(fpath);
    end
	
else %super resolusion    
    last_pos = find(data_dir == '_', 1, 'last'); % to replace metab with water
    fpath = sprintf('%swater/maps/SuperResolution/Water_amp_map_sr.nii.gz',data_dir(1:last_pos)); 
    disp(fpath)
    if exist(fpath,"file")
        disp('Loading water map') 
        S_water = niftiread(fpath) ;
    else
        disp("Water map not available: S_water=1")
    end       
end

%% Calculate Scaling Map for Absolute Quantification (IWR)
%% Repetition and echo times of MRSI 
TE = sum(Par.CSI.TEs)/1E3;
TR = Par.CSI.TR/1E3;

Ctw=55.13*1e3;%concentration of tissue water = 55.13 *1E3 mM;

 if strcmp(hasMRF,'Yes') %EPTI available

    disp('Reading MRF maps') 
    sufx='_mrf'; 

    PD_mrf = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/PD_sr.nii.gz'));     
    T1_mrf = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/T1_sr.nii.gz'));    
    T2_mrf = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/T2_sr.nii.gz'));    
    RMSE_mrf = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/RMSE_sr.nii.gz'));     
    RMSE_mask = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/RMSE_mask_sr.nii.gz')); 
    PD_orig = niftiread(fullfile(data_dir,'../MRF/PD.nii.gz')); 
    RMSE_ventr = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/RMSE_mask_ventricles.nii.gz'));%% Ovidiu
    
    disp('MRF read done')

    median_val = median(PD_orig(RMSE_ventr>0)); %% Scale the PD values by the median value in the ventricles CSF 
    fprintf('\n PD median_val = %d \n', median_val)

 
    PD_mrf_corrected = PD_mrf/median_val;
    PD_mrf_corrected(PD_mrf_corrected>1) = 1;
    niiInfo= niftiinfo(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/PD_sr.nii.gz'));
    fname = fullfile(data_dir,'maps/AbsQuantSR/Anatomy/PD_sr_corrected');
    niftiwrite(PD_mrf_corrected,fname,niiInfo,"Compressed",true)

    R_water = exp(-TE./T2_mrf) .* (1-exp(-TR./T1_mrf)); %Relaxation correction factor for the water signal
    Concen_water = Ctw * PD_mrf_corrected .* R_water; %Water concentration with relaxation correction
    Concen_water0 = Ctw * PD_mrf_corrected; %Water concentration with no relaxation correction
    
  
else
    disp('MRF not available') %EPTI is not available, use literature values (depend on the B0 field)
    sufx='_std';

% if strcmp(B_0,'3T') %literature values depend on the B0 field - the values below are for 3T
% Averaged values from the literature: Wansapura HP et al, JMRI 1999, 9:531-538
         T2_GM = 110;  T2_WM = 80;   T2_CSF = 500; 
         T1_GM = 1331; T1_WM = 832;  T1_CSF = 3817;

% Averaged values from EPTI in 7 healthy volunteers
%        T2_GM = 72;   T2_WM = 64;   T2_CSF = 430;  
%        T1_GM = 1333.5;   T1_WM = 867.42;   T1_CSF = 3622;      

% Water density in brain tissue, literature values in healthy subjects            
        d_GM  = 0.78; d_WM  = 0.65; d_CSF  = 0.97;

		
        R_GM  = exp(-TE./T2_GM)  .* (1-exp(-TR./T1_GM));
        R_WM  = exp(-TE./T2_WM)  .* (1-exp(-TR./T1_WM));
        R_CSF = exp(-TE./T2_CSF) .* (1-exp(-TR./T1_CSF));

    if strcmp(status_dis,'Healthy') %Healthy brain

        Concen_water  = Ctw * ( (f_GM .* R_GM .* d_GM) + (f_WM .* R_WM .* d_WM) + (f_CSF .* R_CSF .* d_CSF) ); 
        Concen_water0 = Ctw * ( (f_GM .* d_GM) + (f_WM .* d_WM) + (f_CSF .* d_CSF) ); %Water concentration without relaxation

    elseif strcmp(status_dis,'Glioma') %Glioma tumor - typical cases
        %C_wat_tum = 42.3*1e3; % concentration of water in tumor with less edema 
        C_wat_tum = 48*1e3; % concentration of water in tumor with more edema

        T1_wat_tum = 832; T2_wat_tum = 80; % T1 and T2 of water in tumor (use values like WM)
        
        
        R_T = exp(-TE./T2_wat_tum)  .* (1-exp(-TR./T1_wat_tum));

        T_ROI = niftiread(fullfile(data_dir,'maps/AbsQuantSR/Anatomy/FLAIR-mask_tumor_sr.nii.gz')); % Tumor ROI
        
        Bmask = niftiread(fullfile(data_dir,'maps/SuperResolution/mask_MEMPRAGE_sr.nii.gz'));

        Bhealthy = uint8(Bmask) - uint8(T_ROI);
        
        Concen_water  = double(Bhealthy) .* ( Ctw * ( (f_GM .* R_GM .* d_GM) + (f_WM .* R_WM .* d_WM) + (f_CSF .* R_CSF .* d_CSF) ) );   %Water map with relaxation correction
        Concen_water  = Concen_water + double(T_ROI) .* ( C_wat_tum .* R_T );
        
        Concen_water0 = double(Bhealthy) .* ( Ctw * ( (f_GM .* d_GM) + (f_WM .* d_WM) + (f_CSF .* d_CSF) ) ); %Water map without relaxation correction
        Concen_water0 = Concen_water0 + double(T_ROI) .* C_wat_tum;

    end

  end

end

% remove Nan and Inf
Concen_water( isnan(Concen_water) | isinf(Concen_water) ) = 0;
Concen_water0( isnan(Concen_water0) | isinf(Concen_water0) ) = 0;
S_water( isnan(S_water) | isinf(S_water) ) = 0;

WaterConc_filename = fullfile(data_dir,'maps/AbsQuantSR',['Water_amp_map_aq' sufx]);
niftiwrite(Concen_water,WaterConc_filename,csf_info,'Compressed',true);

WaterConc0_filename = fullfile(data_dir,'maps/AbsQuantSR',['Water_norelax_amp_map_aq' sufx]);
niftiwrite(Concen_water0,WaterConc0_filename,csf_info,'Compressed',true);

Concen_water = Concen_water ./ S_water;
AbsQuantScalingMap = Concen_water ./ (1-f_CSF); % CSF correction
% remove Nan and Inf
AbsQuantScalingMap( isnan(AbsQuantScalingMap) | isinf(AbsQuantScalingMap) ) = 0;

AbsQuantScale_filename = fullfile(data_dir,'maps/AbsQuantSR',['AbsQuantScale_amp_map_aq' sufx]);
niftiwrite(AbsQuantScalingMap,AbsQuantScale_filename,csf_info,'Compressed',true);

AllMaps.AbsQuant.AbsQuantScalingMap = AbsQuantScalingMap; % Save Scaling map without metabolite correction 

data_dir = savedir; 
save(sprintf('%s/maps/AllMaps.mat',data_dir),'AllMaps','-append')

%% Apply Scaling Map for each metabolite
MetaMlist = getenv('MetaMlistDN'); 
if strcmp(MetaMlist,'all') 
    fprintf('\n Run for all Metabolite\n') 
    %fpath = fullfile(data_dir,'maps/Denoise','*amp_map.nii'); 
    fpath = fullfile(data_dir,'maps/AbsQuantSR','*amp_map_sr.nii'); 
    img_dir = dir(fpath);   
    l = length(img_dir); /AbsQuantSR/Anatomy/
else  /AbsQuantSR/Anatomy/
    fprintf('\n Run for the following metabolite(s)\n') 
    MetaMlist = split(MetaMlist,','); 
    l = length(MetaMlist); 
    disp(MetaMlist) 
end 


for num = 1:l 
    fprintf('\n MetaM %d of %d\n',num,l) 

    if strcmp(MetaMlist,'all') 
        if lowres==1
            MetaM = ['maps/Denoise/', img_dir(num).name]; 
            MetaM_name = extractBefore(img_dir(num).name,"_amp_map_dn.nii"); 
        else
            MetaM = ['maps/SuperResolution/Denoised/', img_dir(num).name]; %These metabolite maps have been quality controlled and filtered based on the CRLB and FWHM values
            MetaM_name = extractBefore(img_dir(num).name,"_amp_map_sr_dn.nii.gz"); 
        end
    else 
        MetaM_name = strtrim(MetaMlist{num}); 
        if lowres==1
            MetaM = ['maps/Denoise/', MetaM_name '_amp_map_dn.nii']; 
        else
            MetaM = ['maps/SuperResolution/Denoised/', MetaM_name '_amp_map_sr_dn.nii.gz'];
        end
    end 
    disp(MetaM)
    meta_filename = fullfile(data_dir, MetaM); 
    S_met = niftiread(meta_filename); 
    S_met(isnan( S_met(:) ) ) = 0; 

    % Relaxation correction for Metabolite in invivo 
    TE = sum(Par.CSI.TEs)/1E3; 
    TR = Par.CSI.TR/1E3; 

    if strcmp(B_0,'3T') % T1 & T2 values of metabolites at 3T according to literature
      switch(MetaM_name)  % Please check the names, name need to match with metaboilite lists 
        case 'Ins' 
            T2s = 161; 
            T1s = 1360; 
        case 'GPC+PCh' 
            T2s = 218; 
            T1s = 1150; 
        case 'NAA+NAAG'
            T2s = 343; 
            T1s = 1390; 
        case 'Cr+PCr' 
            T2s = 166; 
            T1s = 1470; 
        case 'Glu' 
            T2s = 124; 
            T1s = 1270; 
        case 'Gln' 
            T2s = 168; 
            T1s = 1270; 
        case 'GABA' 
            T2s = 75; 
            T1s = 1270; 
        case 'Gly' 
            T2s = 152; 
            T1s = 1270; 
        case 'GSH' 
            T2s = 145; 
            T1s = 1270; 
        otherwise 
            
            %for T2 use the paper of Anke Henning, MRM 2018, 80:452
	    %for T2 use the paper of Małgorzata Marjańska, MRM 2018, 79:1260
            %for T1 use the paper of Moser, NMR Biomed 2001, 14:325
           
            T2s = 124; 
            T1s = 1270;  
     
       end
    end 

    R_met = exp(-TE./T2s) .* (1-exp(-TR./T1s)); %Relaxation correction for metabolites
 
    if strcmp(hasMRF,'Yes')
        Concen_met = conc_sf .* S_met/R_met .* AbsQuantScalingMap .* RMSE_mask ; %Use the RMSE mask here to exclude bad EPTI fitting
    else 
        Concen_met = conc_sf .* S_met/R_met .* AbsQuantScalingMap;
    end

    Concen_met( isnan(Concen_met) | isinf(Concen_met) ) = 0;

    Im_absQuant_filename = fullfile(data_dir,'maps/AbsQuantSR',[MetaM_name '_amp_map_aq' sufx]);
    info_met = niftiinfo(meta_filename);
    niftiwrite(Concen_met, Im_absQuant_filename, info_met,'Compressed',true);

end
disp('###################################################');
disp('#                                                 #');
disp('#    Successs: Absolute Quantification DONE !!    #');
disp('#                                                 #');
disp('###################################################');
