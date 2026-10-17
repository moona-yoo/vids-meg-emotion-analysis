function param = ParameterSetting_ma(param)
% ============================================================
% [Function] Load Fixed Experimental Parameters
%   requires param.subjID and param.data_root (folder containing SubXX folders)
% ============================================================

% ---------------------
% Data Path Settings
% ---------------------
param.dir           = dir(fullfile(param.data_root, 'Sub*'));
all_names           = {param.dir.name};
match_idx           = find(strcmp(all_names, param.subjID));
param.subj_folder   = param.dir(match_idx).name;
param.file          = dir(fullfile(param.dir(match_idx).folder, param.subj_folder, '*Em*.fif'));

param.data_path = fullfile(param.data_root, param.subjID);

% ---------------------
% Experiment Parameters
% ---------------------
param.blocknum      = 4;
param.videonum      = 10;

% ---------------------
% Preprocessing Parameters
% ---------------------
param.fs              = 1024;
param.downsample_freq = 512;

% File order and labels (files are listed alphabetically: Calm, Disgust, Fun, Sad)
param.preprocess.file_order  = [3 2 1 4]; % Fun-Disgust-Calm-Sad (= HAHV-HALV-LAHV-LALV)
param.file_labels = {'Fun', 'Disgust', 'Calm', 'Sad'};
param.num_blocks  = length(param.preprocess.file_order);

% Bandpass filter settings
param.bandpass.locutoff     = 1;
param.bandpass.hicutoff     = 95;

% ---------------------
% Channel Settings
% ---------------------
param.ch.names     = {'Frontal', 'Temporal', 'Parietal', 'Occipital', 'Central'};

param.ch.FL_labels = { ...
    'MEG 3013','MEG 3015','MEG 3017','MEG 3018','MEG 3019','MEG 3020','MEG 3022','MEG 3023','MEG 3024', ...
    'MEG 3026','MEG 3027','MEG 3029','MEG 3030','MEG 3032'};

param.ch.FR_labels = { ...
    'MEG 3001','MEG 3002','MEG 3003','MEG 3004','MEG 3005','MEG 3006','MEG 3007','MEG 3008','MEG 3009','MEG 3010', ...
    'MEG 3011','MEG 3012','MEG 3014','MEG 3016'};

param.ch.TL_labels = { ...
    'MEG 3031','MEG 3033','MEG 3034','MEG 3035','MEG 3036','MEG 3037','MEG 3038','MEG 3039','MEG 3040','MEG 3041', ...
    'MEG 3042','MEG 3043','MEG 3044','MEG 3045','MEG 3049','MEG 3050','MEG 3051','MEG 3055','MEG 3056','MEG 3058'};

param.ch.TR_labels = { ...
    'MEG 3100','MEG 3101','MEG 3102','MEG 3103','MEG 3105','MEG 3106','MEG 3109','MEG 3113','MEG 3114','MEG 3115', ...
    'MEG 3116','MEG 3117','MEG 3118','MEG 3119','MEG 3120','MEG 3121','MEG 3122','MEG 3123','MEG 3124','MEG 3125'};

param.ch.PL_labels = { ...
    'MEG 3021','MEG 3025','MEG 3028','MEG 3046','MEG 3047','MEG 3048','MEG 3059','MEG 3061','MEG 3062','MEG 3063', ...
    'MEG 3064','MEG 3078','MEG 3079','MEG 3080','MEG 3092','MEG 3149','MEG 3150','MEG 3151','MEG 3152'};

param.ch.PR_labels = { ...
    'MEG 3093','MEG 3094','MEG 3095','MEG 3096','MEG 3108','MEG 3110','MEG 3111','MEG 3112','MEG 3126','MEG 3127', ...
    'MEG 3128','MEG 3129','MEG 3130','MEG 3131','MEG 3132','MEG 3133','MEG 3134','MEG 3135','MEG 3136'};

param.ch.OL_labels = { ...
    'MEG 3052','MEG 3053','MEG 3054','MEG 3057','MEG 3060','MEG 3065','MEG 3066','MEG 3067','MEG 3068','MEG 3069', ...
    'MEG 3070','MEG 3071','MEG 3072','MEG 3074','MEG 3075','MEG 3076','MEG 3077'};

param.ch.OR_labels = { ...
    'MEG 3073','MEG 3081','MEG 3082','MEG 3083','MEG 3084','MEG 3085','MEG 3086','MEG 3087','MEG 3088','MEG 3089', ...
    'MEG 3090','MEG 3091','MEG 3097','MEG 3098','MEG 3099','MEG 3104','MEG 3107'};

param.ch.Cent_labels = { ...
    'MEG 3141','MEG 3143','MEG 3145','MEG 3146','MEG 3147', 'MEG 3148','MEG 3137','MEG 3138','MEG 3139','MEG 3140', ...
    'MEG 3142','MEG 3144'};

% ---------------------
% Frequency Band Settings
% ---------------------
param.band.names            = {'delta', 'theta', 'alpha', 'beta', 'lowgamma', 'highgamma'};
param.band.delta            = [1 4];
param.band.theta            = [4 8];
param.band.alpha            = [8 13];
param.band.beta             = [15 30];
param.band.lowgamma         = [30 50];
param.band.highgamma        = [50 95];

end
