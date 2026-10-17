%% =========================================================================
%  MEG_03_Classification.m
%  4-class (HAHV / HALV / LAHV / LALV) classification with LDA
%
%  Part 1 : subject-dependent classification
%           - features : relative band power, all channels x 6 bands, 1-s windows
%           - CV at the trial level (1 trial per category per fold)
%           - window-level prediction -> trial-level majority voting
%  Part 2 : group accuracy, confusion matrices, video-specific accuracy
%  Part 3 : correlation between video-specific accuracy and distance of mean SAM
%           ratings from the ideal category coordinate (Fig. 6d)
%  Results are printed to the command window (no figures).
%
%  Requirements : MATLAB R2022b, Statistics and Machine Learning Toolbox (fitcdiscr, confusionmat, corr)
%                 no external toolbox is needed for this script
%  Input  : save_root\03_Features\BandPower_STFT_SubXX.mat (MEG_02_FeatureExtraction.m)
%           SAM_Mean_Online.mat (SAM_Mean_Online [40 x 2], mean valence / arousal of the online survey)
% =========================================================================
clear; clc; close all;

% ----- Edit this path if the online survey results are stored elsewhere -----
code_dir  = fileparts(mfilename('fullpath'));
sam_file  = fullfile(code_dir, '..', '01_OnlineSurvey', 'results', 'SAM_Mean_Online.mat');
% -----------------------------------------------------------------------------

save_root = fullfile(code_dir, 'data');  % outputs of MEG_01 / MEG_02

subjects     = [1 2 3 4 5 6 7 9 10 13 14 16 17 18 19 20 21 22 23];
n_subjects   = length(subjects);
class_names  = {'HAHV', 'HALV', 'LAHV', 'LALV'};
results      = cell(n_subjects, 1);

%% =========================================================================
%% Part 1. Subject-dependent LDA classification
%% =========================================================================
for si = 1:n_subjects
    subjID = sprintf('Sub%02d', subjects(si));
    load(fullfile(save_root, '03_Features', sprintf('BandPower_STFT_%s.mat', subjID)), 'band_power', 'param');

    [blockN, trialN, chN, segN, bandN] = size(band_power);

    % All channels, all frequency bands
    selected_chan_labels  = [param.ch.FL_labels, param.ch.FR_labels, ...
                             param.ch.TL_labels, param.ch.TR_labels, ...
                             param.ch.PL_labels, param.ch.PR_labels, ...
                             param.ch.OL_labels, param.ch.OR_labels, param.ch.Cent_labels];
    selected_chan_indices = find(ismember({param.chanlocs.labels}, selected_chan_labels));

    selected_bands = {'delta', 'theta', 'alpha', 'beta', 'lowgamma', 'highgamma'};
    band_indices   = zeros(1, length(selected_bands));
    for i = 1:length(selected_bands)
        band_indices(i) = find(strcmp(param.band.names, selected_bands{i}));
    end

    %% Feature preparation
    total_valid_samples = blockN * trialN * segN;
    X_combined          = zeros(total_valid_samples, length(band_indices) * length(selected_chan_indices));
    trial_mapping       = zeros(total_valid_samples, 1);
    y                   = zeros(total_valid_samples, 1);

    for smp = 1:total_valid_samples
        blk = floor((smp-1) / (trialN*segN)) + 1;
        tr  = floor(mod(smp-1, trialN*segN) / segN) + 1;
        sg  = mod(smp-1, segN) + 1;

        feat_idx = 0;
        for ch = selected_chan_indices
            for b = band_indices
                feat_idx = feat_idx + 1;
                X_combined(smp, feat_idx) = band_power(blk, tr, ch, sg, b);
            end
        end

        trial_mapping(smp) = (blk-1) * trialN + tr;   % trial ID = video ID (1-40)
        y(smp)             = blk;                     % label = emotional category
    end

    %% Cross-validation
    block_trials = cell(blockN, 1);
    for b = 1:blockN
        block_trials{b} = unique(trial_mapping(y == b));
    end

    num_folds   = 10;
    fold_trials = cell(num_folds, blockN);
    for b = 1:blockN
        shuffled_trials = block_trials{b}(randperm(length(block_trials{b})));
        trials_per_fold = floor(length(shuffled_trials) / num_folds);   % 1
        trial_idx = 1;
        for fold = 1:num_folds
            fold_trials{fold, b} = shuffled_trials(trial_idx:trial_idx + trials_per_fold - 1);
            trial_idx = trial_idx + trials_per_fold;
        end
    end

    fold_accuracies       = zeros(num_folds, 1);
    fold_trial_accuracies = zeros(num_folds, 1);
    all_test_trials       = cell(num_folds, 1);
    all_predictions       = cell(num_folds, 1);
    all_true_labels       = cell(num_folds, 1);
    all_trial_predictions = cell(num_folds, 1);
    all_trial_true_labels = cell(num_folds, 1);
    all_trial_test_ids    = cell(num_folds, 1);

    for fold = 1:num_folds
        test_trials  = vertcat(fold_trials{fold, :});
        train_trials = setdiff(vertcat(block_trials{:}), test_trials);
        all_test_trials{fold} = test_trials;

        train_idx = ismember(trial_mapping, train_trials);
        test_idx  = ismember(trial_mapping, test_trials);

        % LDA
        mdl         = fitcdiscr(X_combined(train_idx, :), y(train_idx), 'DiscrimType', 'linear');
        predictions = predict(mdl, X_combined(test_idx, :));
        y_test      = y(test_idx);

        all_predictions{fold} = predictions;
        all_true_labels{fold} = y_test;
        fold_accuracies(fold) = sum(predictions == y_test) / numel(y_test);   % window level

        % Trial-level majority voting over the 100 windows
        test_trial_mapping = trial_mapping(test_idx);
        unique_test_trials = unique(test_trial_mapping);
        trial_predictions  = zeros(length(unique_test_trials), 1);
        trial_true_labels  = zeros(length(unique_test_trials), 1);
        for t = 1:length(unique_test_trials)
            mask                   = (test_trial_mapping == unique_test_trials(t));
            [unique_preds, ~, idx] = unique(predictions(mask));
            counts                 = accumarray(idx, 1);
            [~, max_idx]           = max(counts);
            trial_predictions(t)   = unique_preds(max_idx);
            trial_true_labels(t)   = y_test(find(mask, 1));
        end

        all_trial_predictions{fold} = trial_predictions;
        all_trial_true_labels{fold} = trial_true_labels;
        all_trial_test_ids{fold}    = unique_test_trials;
        fold_trial_accuracies(fold) = sum(trial_predictions == trial_true_labels) / length(trial_predictions);
    end

    R = struct();
    R.subject_id                            = subjID;
    R.segment_level.mean_accuracy           = mean(fold_accuracies);
    R.segment_level.fold_accuracies         = fold_accuracies;
    R.segment_level.all_predictions         = all_predictions;
    R.segment_level.all_true_labels         = all_true_labels;
    R.segment_level.all_test_trials         = all_test_trials;
    R.trial_level.mean_accuracy             = mean(fold_trial_accuracies);
    R.trial_level.fold_accuracies           = fold_trial_accuracies;
    R.trial_level.all_predictions           = all_trial_predictions;
    R.trial_level.all_true_labels           = all_trial_true_labels;
    R.trial_level.all_test_ids              = all_trial_test_ids;
    results{si} = R;

    fprintf('%s : window-level %.2f%%, trial-level %.2f%%\n', subjID, ...
        100*R.segment_level.mean_accuracy, 100*R.trial_level.mean_accuracy);
end

save(fullfile(save_root, 'Classification_Results.mat'), 'results', 'subjects');

%% =========================================================================
%% Part 2. Group accuracy, confusion matrices, video-specific accuracy
%% =========================================================================
num_vids_total = 40;
chance_level   = 0.25;

trial_acc = cellfun(@(R) R.trial_level.mean_accuracy, results);
seg_acc   = cellfun(@(R) R.segment_level.mean_accuracy, results);
fprintf('\nTrial-level accuracy  : %.2f ± %.2f %%\n', 100*mean(trial_acc), 100*std(trial_acc));
fprintf('Window-level accuracy : %.2f ± %.2f %%\n', 100*mean(seg_acc), 100*std(seg_acc));

% per-video (trial-level) correctness and pooled predictions
all_subjects_vid_acc = NaN(n_subjects, num_vids_total);
trial_pred_all = []; trial_true_all = [];
seg_pred_all   = []; seg_true_all   = [];
for si = 1:n_subjects
    R = results{si};
    for f = 1:numel(R.trial_level.all_predictions)
        ids   = R.trial_level.all_test_ids{f};
        preds = R.trial_level.all_predictions{f};
        trues = R.trial_level.all_true_labels{f};
        all_subjects_vid_acc(si, ids) = double(preds == trues)';
        trial_pred_all = [trial_pred_all; preds];
        trial_true_all = [trial_true_all; trues];
        seg_pred_all   = [seg_pred_all; R.segment_level.all_predictions{f}];
        seg_true_all   = [seg_true_all; R.segment_level.all_true_labels{f}];
    end
end

% confusion matrices (row-normalized, %)
cm_sets = {trial_true_all, trial_pred_all, 'Trial-level confusion matrix (Fig. 6a)'; ...
           seg_true_all,   seg_pred_all,   'Window-level confusion matrix (Fig. 6b)'};
for k = 1:2
    cm            = confusionmat(cm_sets{k, 1}, cm_sets{k, 2});
    cm_normalized = cm ./ sum(cm, 2);

    fprintf('\n%s [%%] (rows: true, columns: predicted)\n', cm_sets{k, 3});
    fprintf('%8s', ''); fprintf('%8s', class_names{:}); fprintf('\n');
    for i = 1:4
        fprintf('%8s', class_names{i}); fprintf('%8.1f', cm_normalized(i, :)*100); fprintf('\n');
    end
end

% video-specific accuracy (mean ± SEM across participants)
group_overall_mean  = mean(all_subjects_vid_acc, 'omitnan');               % 1 x 40
group_sem_video_acc = std(all_subjects_vid_acc, 'omitnan') / sqrt(n_subjects);

fprintf('\nVideo-specific accuracy (Fig. 6c) [%%], mean ± SEM, chance = %.0f%%\n', chance_level*100);
for v = 1:num_vids_total
    fprintf('  Video %02d (%s) : %6.2f ± %5.2f\n', v, class_names{ceil(v/10)}, ...
        100*group_overall_mean(v), 100*group_sem_video_acc(v));
end

%% =========================================================================
%% Part 3. Distance of mean SAM ratings from ideal coordinate vs accuracy
%% =========================================================================
load(sam_file, 'SAM_Mean_Online');   % [40 x 2] (valence, arousal), -4..4

% ideal coordinates: HAHV (4,4), HALV (-4,4), LAHV (4,-4), LALV (-4,-4)
targets = [4 4; -4 4; 4 -4; -4 -4];
euclidean_distances = zeros(num_vids_total, 1);
for i = 1:num_vids_total
    q = ceil(i / 10);
    euclidean_distances(i) = sqrt((SAM_Mean_Online(i,1) - targets(q,1))^2 + (SAM_Mean_Online(i,2) - targets(q,2))^2);
end

% Pearson correlation and 95% CI (Fisher's z transformation)
x = euclidean_distances;
y = group_overall_mean(:);
n = length(x);

[r, p] = corr(x, y, 'Type', 'Pearson');
z      = atanh(r);
se_z   = 1 / sqrt(n - 3);
ci_r   = tanh(z + [-1, 1] * 1.96 * se_z);
fprintf('\nDistance vs accuracy (Fig. 6d): r = %.3f, 95%% CI [%.2f, %.2f], p = %.3f\n', r, ci_r(1), ci_r(2), p);
