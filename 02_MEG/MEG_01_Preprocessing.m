%% =========================================================================
%  MEG_01_Preprocessing.m
%
%  Part 1 : bad channel detection, filtering, downsampling, ASR, ICA (SOBI)
%  Part 2 : IC rejection (visual inspection), sensor realignment, epoching
%           (last 100 s of each video), reordering of trials by video ID
%
%  Requirements : MATLAB R2022b (Signal Processing Toolbox), FieldTrip (20250402),
%                 EEGLAB (2025.0.0) with clean_rawdata plugin, mne-matlab (reading .fif)
%  Input        : raw MEG (SubXX\*Em*.fif, Coordinate_Em_*.cfg)
%                 video presentation order
%  Output       : save_root\02_Preprocessed\FinalData_SubXX.mat
%                 data_final [4 blocks x channels x time x 10 videos]
% =========================================================================
clear; clc; close all;

%% =========================================================================
%% 0. Settings
%% =========================================================================
% ----- Edit these paths before running -----
data_root   = '/path/to/MEG_data';       % raw MEG (SubXX folders)
survey_root = '/path/to/Survey_data';    % Param_SubXX_<category>.mat

% Toolboxes are not included in this repository; download them and set the paths below.
%   FieldTrip   : https://www.fieldtriptoolbox.org/download/        (tested with 20250402)
%   mne-matlab  : https://github.com/mne-tools/mne-matlab
%   EEGLAB      : https://sccn.ucsd.edu/eeglab/download.php        (tested with 2025.0.0)
%                 the clean_rawdata plugin (ASR) must be installed
fieldtrip_dir = '/path/to/fieldtrip';
mne_dir       = '/path/to/mne-matlab';
eeglab_dir    = '/path/to/eeglab';
% -------------------------------------------

code_dir  = fileparts(mfilename('fullpath'));
save_root = fullfile(code_dir, 'data');  % outputs are saved next to this script

addpath(fullfile(code_dir, 'functions'));
addpath(fieldtrip_dir); ft_defaults;
addpath(genpath(mne_dir));
addpath(eeglab_dir); eeglab nogui;

% Participants
subjects = [1 2 3 4 5 6 7 9 10 13 14 16 17 18 19 20 21 22 23];
sub_dat  = set_sub_dat_ma();      % subject ID, block recording order, bad channels noted during the experiment

if ~exist(fullfile(save_root, '01_ICA'), 'dir'),          mkdir(fullfile(save_root, '01_ICA')); end
if ~exist(fullfile(save_root, '02_Preprocessed'), 'dir'), mkdir(fullfile(save_root, '02_Preprocessed')); end

%% =========================================================================
%% Part 1. Bad channels -> filtering -> downsampling -> ASR -> ICA
%% =========================================================================
for subN = subjects
    param = struct();
    param.subjID          = sub_dat{subN, 1};
    param.blk_order       = sub_dat{subN, 2};
    param.exp_badch_label = sub_dat{subN, 3};
    param.data_root       = data_root;
    param                 = ParameterSetting_ma(param);

    % Bad channel detection (variance-based)
    param = Detect_bad_channels_ma(param);

    % Filtering, downsampling, bad channel removal, ASR, ICA
    [data_asr, comp, param] = run_meg_preprocessing_ica(param);

    ica_file = fullfile(save_root, '01_ICA', [param.subjID '_concatenated_asr_sobi.mat']);
    save(ica_file, 'data_asr', 'comp', 'param', '-v7.3');
    fprintf('ICA result saved: %s\n', ica_file);
    close all;
end

%% =========================================================================
%% Part 2. IC rejection -> sensor realignment -> epoching -> reordering
%% =========================================================================
for subN = subjects
    clear data_asr comp data_clean data_meg_aligned data_epoched data_final
    load(fullfile(save_root, '01_ICA', [sub_dat{subN, 1} '_concatenated_asr_sobi.mat']), 'data_asr', 'comp', 'param');

    %% IC inspection: topoplots, time series
    num_IC_plot = min(150, length(comp.label));
    for comp_range = [1 50; 51 100; 101 length(comp.label);]'
        if comp_range(1) > num_IC_plot, continue; end
        cfg           = [];
        cfg.component = comp_range(1):min(comp_range(2), num_IC_plot);
        cfg.layout    = param.layout_meg;
        cfg.comment   = 'no';
        cfg.marker    = 'off';
        figure; set(gcf, 'Color', 'w', 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        ft_topoplotIC(cfg, comp);
    end

    cfg            = [];
    cfg.viewmode   = 'component';
    cfg.continuous = 'yes';
    cfg.layout     = param.layout_meg;
    cfg.blocksize  = 20;
    cfg.channel    = 1:min(20, length(comp.label));
    ft_databrowser(cfg, comp);
    set(gcf, 'Color', 'w', 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

    %% IC rejection (ocular / cardiac components, user input)
    ICA_meg_reject = input(sprintf('[%s] IC to remove (e.g. [1 2 3]):  ', param.subjID));
    cfg            = [];
    cfg.component  = ICA_meg_reject;
    cfg.updatesens = 'no';
    data_clean     = ft_rejectcomponent(cfg, comp, data_asr);
    close all;

    %% Sensor realignment to the first recorded block (single-sphere head model)
    first_file_idx   = param.blk_order(1);
    first_file_label = param.file_labels{first_file_idx};

    cfg_path         = fullfile(param.data_root, param.subjID, ['Coordinate_Em_' first_file_label '.cfg']);
    head_info        = read_coordinate_cfg2016(cfg_path); % units in meter

    vol   = [];
    vol.r = head_info.head_radius * 100;   % m -> cm
    vol.o = head_info.origin' * 100;

    cfg_realign             = [];
    cfg_realign.inwardshift = 2.5;
    cfg_realign.vol         = vol;
    cfg_realign.template    = param.grad_template;
    cfg_realign.channel     = 'all';
    data_meg_aligned        = ft_megrealign(cfg_realign, data_clean);
    close all;

    %% Epoching: last 100 s of each video (video-end trigger 113, -100 s ~ +0.5 s)
    trigger_value = 113;
    prestim_time  = -100.0;
    poststim_time = 0.5;

    % concatenate trigger information of all blocks (1024 Hz -> 512 Hz)
    all_events         = [];
    cumulative_samples = 0;
    for i = 1:length(param.preprocess.file_order)
        file_idx     = param.preprocess.file_order(i);
        fif_filepath = fullfile(param.file(file_idx).folder, param.file(file_idx).name);

        cfg = [];
        cfg.dataset             = fif_filepath;
        cfg.trialdef.eventtype  = 'Stimulus';
        cfg.trialdef.eventvalue = trigger_value;
        cfg.trialdef.prestim    = prestim_time*(-1);
        cfg.trialdef.poststim   = poststim_time;
        cfg_temp                = ft_definetrial(cfg);

        if isfield(cfg_temp, 'event')
            file_events = cfg_temp.event;
            for j = 1:length(file_events)
                file_events(j).sample = round(file_events(j).sample / 2) + cumulative_samples;
            end
            all_events = [all_events; file_events];
        end

        hdr                = ft_read_header(fif_filepath);
        cumulative_samples = cumulative_samples + round(hdr.nSamples * param.downsample_freq / hdr.Fs);
    end

    trigger_indices = [];
    for i = 1:length(all_events)
        if all_events(i).value == trigger_value
            trigger_indices = [trigger_indices, all_events(i).sample];
        end
    end

    fs               = data_clean.fsample;
    prestim_samples  = round(prestim_time * fs);
    poststim_samples = round(poststim_time * fs);

    trl = zeros(length(trigger_indices), 3);
    for i = 1:length(trigger_indices)
        trl(i, :) = [trigger_indices(i) + prestim_samples, trigger_indices(i) + poststim_samples, prestim_samples];
    end

    cfg          = [];
    cfg.trl      = trl;
    data_epoched = ft_redefinetrial(cfg, data_clean);
    fprintf('%s: %d epochs\n', param.subjID, length(data_epoched.trial));

    %% Reorder trials by video ID (random presentation order -> video 1~10 in each block)
    survey_conditions = {'HAHV', 'HALV', 'LAHV', 'LALV'};
    video_order       = zeros(param.blocknum, param.videonum);
    for b = 1:param.blocknum
        tmp = load(fullfile(survey_root, sprintf('Param_%s_%s', param.subjID, survey_conditions{b})));
        video_order(b, :) = tmp.param.randomVideoOrder;
    end

    % 40 trials: HAHV(1-10), HALV(11-20), LAHV(21-30), LALV(31-40)
    [nCh, nTime] = size(data_epoched.trial{1});
    raw_trials   = zeros(param.blocknum, nCh, nTime, param.videonum);
    for b = 1:param.blocknum
        for v = 1:param.videonum
            raw_trials(b, :, :, v) = data_epoched.trial{(b-1) * param.videonum + v};
        end
    end

    reorder_idx = zeros(param.blocknum, param.videonum);
    for b = 1:param.blocknum
        for j = 1:param.videonum
            reorder_idx(b, video_order(b, j)) = j;
        end
    end

    data_final = zeros(size(raw_trials));
    for b = 1:param.blocknum
        for v = 1:param.videonum
            data_final(b, :, :, v) = raw_trials(b, :, :, reorder_idx(b, v));
        end
    end

    %% Save
    save_file = fullfile(save_root, '02_Preprocessed', sprintf('FinalData_%s.mat', param.subjID));
    save(save_file, 'data_final', 'param', '-v7.3');
    fprintf('Saved: %s\n', save_file);
end
