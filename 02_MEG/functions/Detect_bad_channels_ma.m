function param = Detect_bad_channels_ma(param)
% ========================================================================
% Variance-based bad channel detection (FieldTrip)
%   1-95 Hz band-pass + 60 Hz notch -> per-block channel variance (log10)
%   -> channels exceeding the threshold in any block are marked as bad
% ========================================================================

fprintf('\n=== Start Detecting Bad Channels ===\n');

%% ============================================================
% [Step 1] Basic Processing
% ============================================================
MEG_preprocessed = cell(1, param.num_blocks);

% Bandpass filtering + 60 Hz notch + Save channel info
for idx = 1:param.num_blocks
    fprintf('Block %d/%d On Progress ...\n', idx, param.num_blocks);

    i     = param.preprocess.file_order(idx);
    fname = fullfile(param.file(i).folder, param.file(i).name);

    % --- Load Raw MEG Data  ---
    cfg = [];
    cfg.channel = {'MEG *'};
    cfg.dataset = fname;
    data_meg    = ft_preprocessing(cfg);

    data_meg.grad.coordsys     = 'ctf';
    data_meg.hdr.grad.coordsys = 'ctf';
    data_meg.grad              = ft_convert_units(data_meg.grad,'mm');

    % --- Bandpass Filtering (1-95 Hz) using FieldTrip ---
    cfg = [];
    cfg.bpfilter  = 'yes';
    cfg.bpfreq    = [param.bandpass.locutoff param.bandpass.hicutoff]; % [1 95]
    data_filtered = ft_preprocessing(cfg, data_meg);

    % --- 60 Hz Noise Filtering using FieldTrip ---
    cfg = [];
    cfg.bsfilter  = 'yes';
    cfg.bsfreq    = [59.5 60.5];   % 60Hz ± 0.5Hz
    data_filtered = ft_preprocessing(cfg, data_filtered);

    % --- Set Channel Info & Indices ---
    channel_labels     = data_filtered.label;           % cell array of channel names
    channel_indices    = (1:length(channel_labels))';   % column vector
    channel_info       = table(channel_indices, channel_labels, 'VariableNames', {'Index', 'Label'});
    param.channel_info = channel_info;

    MEG_preprocessed{idx} = data_filtered.trial{1}; % [nChannels x nTimePoints]
end

%% ============================================================
% [Step 2] Variance-Based Bad Channel Detection
% ============================================================
all_outlier_idx = [];

for idx = 1:param.num_blocks
    tmp_MEG = MEG_preprocessed{idx};
    tmp_var(:,idx)  = std(tmp_MEG, [], 2).^2;
    log_var(:, idx) = log10(tmp_var(:,idx));
end

% Variance threshold (log10 of variance, T^2)
variance_threshold = -23.5;

% Histogram of channel variance per block
edges  = linspace(-27, -20, 41);
colors = [ 0.2, 0.4, 0.8; 0.8, 0.2, 0.4; 0.2, 0.8, 0.4; 0.8, 0.6, 0.2 ];

figure('Position', [100 200 1170 660])
for idx = 1:param.num_blocks
    subplot(2, 2, idx);
    histogram(log_var(:,idx), edges, 'FaceColor', colors(idx,:), ...
              'EdgeColor', 'white', 'FaceAlpha', 0.7, 'LineWidth', 0.5);
    hold on;
    xline(variance_threshold, '--', 'Color', [0.8 0.2 0.2], 'LineWidth', 2);

    % Detect Bad Channels
    outlier_idx     = find(log_var(:,idx) > variance_threshold);
    all_outlier_idx = [all_outlier_idx; outlier_idx(:)];
    outlier_vals    = log_var(outlier_idx, idx);

    fprintf('  [Block %d] Detected <%d> Bad Channels \n', idx, length(outlier_idx));
    for i = 1:length(outlier_idx)
        fprintf('    - %s (Idx: %d) - log(Variance) = %.2f\n', ...
                 channel_labels{outlier_idx(i)}, outlier_idx(i), outlier_vals(i));
    end

    title(sprintf('Block %d ( %d Bad Channels )', idx, length(outlier_idx)), 'FontSize', 10.5);
    xlabel('log_{10}(Ch Variance)', 'FontSize', 8);
    ylabel('Num of Channels', 'FontSize', 8);
    ylim([0 65]); xlim([-27 -22]);
end
sgtitle(sprintf('Ch Variance Histogram for Each Block (%s)', param.subjID), 'FontSize', 13, 'FontWeight', 'bold');

% Bad channel index (union over blocks)
total_outlier_idx        = unique(all_outlier_idx);
bad_labels_idx           = total_outlier_idx(:);
bad_labels               = channel_info.Label(bad_labels_idx);
param.variance_badch     = bad_labels;
param.variance_badch_idx = bad_labels_idx;

disp('=== Bad Channel Detection Done ===')

end
