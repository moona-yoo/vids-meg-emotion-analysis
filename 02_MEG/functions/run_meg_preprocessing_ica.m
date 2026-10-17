function [data_asr, comp, param] = run_meg_preprocessing_ica(param)
% ========================================================================
% Per block : load -> 1-95 Hz band-pass + 60 Hz notch -> downsample (512 Hz)
%             -> bad channel removal (experiment list + variance-based)
% Then      : concatenate 4 blocks -> ASR -> ICA (SOBI)
% ========================================================================

all_data_after_badch = {};
all_file_labels      = {};

for i = 1:length(param.preprocess.file_order)
    %% Step 1: Load Raw MEG data
    file_idx        = param.preprocess.file_order(i);
    emotion_file    = param.file(file_idx).name;
    file_label      = param.file_labels{i};
    fif_filepath    = fullfile(param.file(file_idx).folder, emotion_file);
    fprintf('[%d/%d] Loading: %s\n', i, length(param.preprocess.file_order), emotion_file);

    cfg             = [];
    cfg.channel     = {'MEG *'};
    cfg.dataset     = fif_filepath;
    cfg.bpfilter    = 'yes';
    cfg.bpfreq      = [0.1 500];
    data_meg        = ft_preprocessing(cfg);

    data_meg.grad.coordsys     = 'ctf'; % CTF MEG coordinate system name
    data_meg.hdr.grad.coordsys = 'ctf';
    data_meg.grad              = ft_convert_units(data_meg.grad,'cm');

    %% Step 2: band pass & line noise filtering
    cfg           = [];
    cfg.bpfilter  = 'yes';
    cfg.bpfreq    = [1 95];

    cfg.bsfilter  = 'yes';
    cfg.bsfreq    = [59.5 60.5];   % 60Hz ± 0.5Hz
    data_filtered = ft_preprocessing(cfg, data_meg);

    %% Step 3: Downsampling (1024Hz > 512Hz)
    cfg = [];
    cfg.resamplefs   = param.downsample_freq;
    cfg.detrend      = 'no';
    data_downsampled = ft_resampledata(cfg, data_filtered);

    %% Step 4: Bad Channel Removal
    if isfield(param, 'exp_badch_label') && ~isempty(param.exp_badch_label)
        exp_bad_channels = intersect(data_downsampled.label, param.exp_badch_label(:));
    else
        exp_bad_channels = {};
    end

    % 1) bad channels noted during the experiment
    exp_badch_idx = [];
    if ~isempty(exp_bad_channels) && isfield(param, 'channel_info')
        [~, exp_badch_idx] = ismember(exp_bad_channels, param.channel_info.Label);
        exp_badch_idx = exp_badch_idx(exp_badch_idx > 0);
        fprintf('exp_bad_channels index: %s\n', mat2str(exp_badch_idx));
    end

    % 2) variance-based bad channels
    variance_badch_idx = [];
    if isfield(param, 'variance_badch_idx') && ~isempty(param.variance_badch_idx)
        variance_badch_idx = param.variance_badch_idx(:)';
        fprintf('variance_bad_channels index: %s\n', mat2str(variance_badch_idx));
    end

    param.total_badch_idx = unique([exp_badch_idx(:); variance_badch_idx(:)]);
    fprintf('param.total_badch_idx: %s\n', mat2str(param.total_badch_idx));

    bad_channels = data_downsampled.label(param.total_badch_idx);

    if isempty(bad_channels)
        disp('No bad channels entered. Skipping channel removal.');
        data_after_badch = data_downsampled;
    else
        good_channels = setdiff(data_downsampled.label, bad_channels);

        cfg = [];
        cfg.channel      = good_channels;
        data_after_badch = ft_selectdata(cfg, data_downsampled);

        % update grad (remove sensor information of bad channels)
        [~, good_ch_idx] = ismember(data_after_badch.label, data_downsampled.label);
        if isfield(data_after_badch, 'grad')
            data_after_badch.grad.chanpos = data_after_badch.grad.chanpos(good_ch_idx, :);
            data_after_badch.grad.chanori = data_after_badch.grad.chanori(good_ch_idx, :);
            data_after_badch.grad.label   = data_after_badch.grad.label(good_ch_idx);
            if isfield(data_after_badch.grad, 'tra')
                data_after_badch.grad.tra = data_after_badch.grad.tra(good_ch_idx, :);
            end
        end

        fprintf('Removed bad channels: %s\n', strjoin(bad_channels, ', '));
    end

    %% Step 5: Make HPC Template (first recorded block)
    if i == param.blk_order(1)
        tmp_data_meg.grad   = ft_convert_units(data_after_badch.grad,'cm');
        param.grad_template = tmp_data_meg.grad;
        fprintf('grad_template set from first block (file_idx: %d)\n', file_idx);
    end

    %% Step 6: Make Sensor Layout
    cfg              = [];
    cfg.rotate       = 90;
    cfg.channel      = data_after_badch.label;
    param.layout_meg = ft_prepare_layout(cfg, data_after_badch);

    all_data_after_badch{i} = data_after_badch;
    all_file_labels{i}      = file_label;

    fprintf('[%d/%d] Preprocessing completed for: %s\n', i, length(param.preprocess.file_order), emotion_file);
end

%% Step 7: Concatenate all preprocessed data
fprintf('Concatenating all preprocessed data...\n');

data_concatenated = all_data_after_badch{1};

concatenated_data = [];
total_time_points = 0;
for j = 1:length(all_data_after_badch)
    current_data      = all_data_after_badch{j}.trial{1};
    concatenated_data = [concatenated_data, current_data];
    total_time_points = total_time_points + size(current_data, 2);
    fprintf('File %d (%s): %d time points\n', j, all_file_labels{j}, size(current_data, 2));
end

data_concatenated.trial{1} = concatenated_data;
data_concatenated.time{1}  = (0:(total_time_points-1)) / data_concatenated.fsample;

fprintf('Data concatenation completed. Total time points: %d\n', total_time_points);

%% Step 8: ASR (Artifact Subspace Reconstruction) on concatenated data
fprintf('Performing ASR on concatenated data...\n');

% FieldTrip -> EEGLAB structure
n_chans  = size(data_concatenated.trial{1}, 1);
n_pnts   = size(data_concatenated.trial{1}, 2);
fs       = data_concatenated.fsample;
chanlocs(n_chans) = struct('labels', '', 'X', [], 'Y', [], 'Z', []);

for ch = 1:n_chans
    chanlocs(ch).labels = data_concatenated.label{ch};
    chanlocs(ch).X      = data_concatenated.grad.chanpos(ch,1);
    chanlocs(ch).Y      = data_concatenated.grad.chanpos(ch,2);
    chanlocs(ch).Z      = data_concatenated.grad.chanpos(ch,3);
end

param.chanlocs = chanlocs;

MEG          = eeg_emptyset;
MEG.data     = data_concatenated.trial{1};
MEG.nbchan   = n_chans;
MEG.pnts     = n_pnts;
MEG.trials   = 1;
MEG.srate    = fs;
MEG.times    = linspace(0, (n_pnts-1)/fs, n_pnts);
MEG.chanlocs = chanlocs;
MEG.setname  = 'FieldTrip_to_EEGLAB_Concatenated';

% ASR (clean_artifacts, burst correction only)
MEG_clean    = clean_artifacts(MEG, ...
                'Highpass', 'off', 'FlatlineCriterion', 'off', 'ChannelCriterion', 'off', ...
                'LineNoiseCriterion', 'off', 'BurstCriterion', 5, 'WindowCriterion', 'off');

% ASR result -> FieldTrip structure (ICA input)
data_asr          = data_concatenated;
data_asr.trial{1} = MEG_clean.data;

%% Step 9: ICA (SOBI) on concatenated ASR data
fprintf('Running ICA (SOBI) on concatenated ASR data...\n');
cfg                     = [];
cfg.method              = 'sobi';
cfg.updatesens          = 'no';
Num_Sources             = 100;
Num_CorrMat             = 100;
cfg.sobi.n_sources      = Num_Sources;
cfg.sobi.p_correlations = Num_CorrMat;

comp = ft_componentanalysis(cfg, data_asr);

fprintf('Preprocessing completed for all files.\n');

end
