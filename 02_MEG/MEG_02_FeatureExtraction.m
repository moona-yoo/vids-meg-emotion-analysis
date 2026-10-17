%% =========================================================================
%  MEG_02_FeatureExtraction.m
%  Spectral feature extraction (relative band power, STFT)
%
%  STFT (1-s Hamming windows) -> mean power in 6 bands -> relative power
%  band_power [4 blocks x 10 videos x channels x 100 windows x 6 bands]
%
%  Requirements : MATLAB R2022b, Signal Processing Toolbox (stft, hamming)
%  Input  : save_root\02_Preprocessed\FinalData_SubXX.mat (MEG_01_Preprocessing.m)
%  Output : save_root\03_Features\BandPower_STFT_SubXX.mat
% =========================================================================
clear; clc; close all;

code_dir  = fileparts(mfilename('fullpath'));
save_root = fullfile(code_dir, 'data');
addpath(fullfile(code_dir, 'functions'));

subjects = [1 2 3 4 5 6 7 9 10 13 14 16 17 18 19 20 21 22 23];

if ~exist(fullfile(save_root, '03_Features'), 'dir'), mkdir(fullfile(save_root, '03_Features')); end

for subN = subjects
    subjID = sprintf('Sub%02d', subN);
    load(fullfile(save_root, '02_Preprocessed', sprintf('FinalData_%s.mat', subjID)), 'data_final', 'param');

    method         = 'stft';
    relative_power = true;

    [blockN, chN, timeN, trialN] = size(data_final);

    band_names = param.band.names;
    num_bands  = length(band_names);
    fs         = param.downsample_freq;

    % Segment setting
    hw        = 0.50;                           % half window (s)
    dt        = 1.00;                           % window step (s)
    L_seg     = 2 * ceil(fs * hw) + 1;          % segment length (samples)
    nSegments = floor(timeN / (dt * fs));       % number of segments (100)

    band_power = zeros(blockN, trialN, chN, nSegments, num_bands);

    for blk = 1:blockN
        fprintf('%s - BLOCK %d/%d\n', subjID, blk, blockN);
        for tr = 1:trialN
            for ch = 1:chN
                x              = squeeze(data_final(blk, ch, :, tr));
                window         = hamming(L_seg);
                overlap_length = L_seg - round(fs*dt);

                % STFT
                [spectr_stft, frequency_domain_stft, time_domain_stft] = stft(x, fs, ...
                    "Window", window, 'OverlapLength', overlap_length, ...
                    'FFTLength', L_seg, 'FrequencyRange', 'onesided');

                spectr_stft = 2 * (abs(spectr_stft) .^ 2) / (L_seg*fs);

                for t = 1:min(nSegments, length(time_domain_stft))
                    band_vals = zeros(1, num_bands);
                    for b = 1:num_bands
                        band_range = param.band.(band_names{b});
                        idx_band   = find(frequency_domain_stft >= band_range(1) & frequency_domain_stft < band_range(2));
                        if ~isempty(idx_band)
                            band_vals(b) = mean(spectr_stft(idx_band, t));
                        end
                    end

                    % relative power: band power / total power over the 6 bands
                    if relative_power
                        total = sum(band_vals);
                        if total > 0
                            band_vals = band_vals / total;
                        end
                    end

                    band_power(blk, tr, ch, t, :) = band_vals;
                end
            end
        end
    end

    save_file = fullfile(save_root, '03_Features', sprintf('BandPower_%s_%s.mat', upper(method), subjID));
    save(save_file, 'band_power', 'param', '-v7.3');
    fprintf('Saved: %s  [%s] (block x video x ch x segment x band)\n', save_file, num2str(size(band_power)));
end
