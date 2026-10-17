%% =========================================================================
%  OnlineSurvey_Analysis.m
%  Online survey analysis (N = 500; 4 videos per participant, 50 raters per video)
%
%  Reproduces the online-survey results of the manuscript:
%    [1] SAM          : per-video mean valence / arousal                    (Fig. 4a)
%                       category mean coordinates
%    [2] PrEmo        : selection rate per video x adjective                (Fig. 4b)
%    [3] Highlight    : selection rate per video x scene option             (Fig. 4c)
%
%  Output
%    - results/SAM_Mean_Online.mat : per-video mean valence / arousal [40 x 2], used by MEG_03_Classification.m
%
%  Requirements
%    - MATLAB R2022b, Statistics and Machine Learning Toolbox (fitlme)
%
%  Input
%    - phenotype/survey_data.tsv of the OpenNeuro dataset (ds007640), one row per respondent
%        Ver          : survey version (1-10); version k contains videos k, k+10, k+20, k+30
%        Bc_SAM_Val   : valence (-4..4) for the category-c video (c = 1 HAHV, 2 HALV, 3 LAHV, 4 LALV)
%        Bc_SAM_Aro   : arousal (1..9)
%        Bc_PrE_1..16 : PrEmo selection (0/1), order as in 'emo' below
%        Bc_High_1..7 : highlight selection (0/1), scenes 1-6 + 'None of these'
% =========================================================================
clear; clc; close all;

%% =========================================================================
%% 0. Paths & constants
%% =========================================================================
bids_dir = '/path/to/ds007640';                % root of the OpenNeuro dataset (edit to your local path)

qname    = {'HAHV','HALV','LAHV','LALV'};      % quadrant = block (1-10/11-20/21-30/31-40)
qvid     = {1:10, 11:20, 21:30, 31:40};
emo      = {'Joy','Hope','Pride','Admiration','Fascination','Desire','Content','Relaxed', ...
            'Sadness','Fear','Shame','Contempt','Anger','Boredom','Disgust','None'};
qcolors  = [ 53 95 117; 187 61 65; 151 183 195; 222 130 138]/255;

%% =========================================================================
%% 0-1. Load survey data and reorganize by video
%% =========================================================================
raw = readtable(fullfile(bids_dir, 'phenotype', 'survey_data.tsv'), 'FileType', 'text', 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
rv  = raw.Properties.VariableNames;

n_resp = height(raw);                         % 500 respondents (50 per version)
V      = nan(n_resp, 40);                     % valence   [respondent x video]
A_raw  = nan(n_resp, 40);                     % arousal   [respondent x video], 1..9
PrE    = cell(1, 4);                          % PrEmo     [respondent x 16] per category
High   = cell(1, 4);                          % highlight [respondent x 7]  per category

for c = 1:4
    vid = (c-1)*10 + raw.Ver;                 % video ID rated in category c
    idx = sub2ind([n_resp 40], (1:n_resp)', vid);
    V(idx)     = raw.(sprintf('B%d_SAM_Val', c));
    A_raw(idx) = raw.(sprintf('B%d_SAM_Aro', c));
    PrE{c}  = raw{:, ~cellfun(@isempty, regexp(rv, sprintf('^B%d_PrE_\\d+$',  c), 'once'))};
    High{c} = raw{:, ~cellfun(@isempty, regexp(rv, sprintf('^B%d_High_\\d+$', c), 'once'))};
end

%% =========================================================================
%% 1. SAM — dimensional mapping
%% =========================================================================
% Valence is already on the -4..4 axis;
% Arousal (1..9) is linearly rescaled to -4..4 (rating - 5).
normA  = @(x) (x-1)/8*8 - 4;
A  = normA(A_raw);                            % [respondent x 40]
SAM_Mean_Online = [mean(V,1,'omitnan')', mean(A,1,'omitnan')'];   % [40 x 2] (V,A)

% saved for MEG_03_Classification.m (Part 3, Fig. 6d)
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
save(fullfile(results_dir, 'SAM_Mean_Online.mat'), 'SAM_Mean_Online');

% --- standard error of the mean per video ---
n_rater = sum(~isnan(V), 1)';                                    % raters per video (= 50)
se_V    = std(V, 0, 1, 'omitnan')' ./ sqrt(n_rater);
se_A    = std(A, 0, 1, 'omitnan')' ./ sqrt(n_rater);

% --- category mean coordinates ---
SAM_group = zeros(4,4);   % [Vmean Vsd Amean Asd] per category
for q = 1:4
    gi = qvid{q};
    SAM_group(q,:) = [mean(SAM_Mean_Online(gi,1)), std(SAM_Mean_Online(gi,1)), ...
                      mean(SAM_Mean_Online(gi,2)), std(SAM_Mean_Online(gi,2))];
end

fprintf('\n[1. SAM]  category mean coordinates (valence, arousal)\n');
for q = 1:4
    fprintf('  %-5s : (%.2f, %.2f)\n', qname{q}, SAM_group(q,1), SAM_group(q,3));
end

% --- Fig. 4a: VA scatter with SEM error bars ---
figure('Name','Fig4a SAM VA map','Position',[80 80 760 620]); hold on;

% Error bars (drawn first, lighter category colors, excluded from legend)
for q = 1:4
    gi = qvid{q};
    light = qcolors(q,:) + (1 - qcolors(q,:)) * 0.45;
    eb = errorbar(SAM_Mean_Online(gi,1), SAM_Mean_Online(gi,2), se_A(gi), se_A(gi), se_V(gi), se_V(gi), ...
        'LineStyle', 'none', 'Color', light, 'LineWidth', 1.1, 'CapSize', 3);
    eb.Annotation.LegendInformation.IconDisplayStyle = 'off';
end

% Mean ratings and video labels
for q = 1:4
    gi = qvid{q};
    plot(SAM_Mean_Online(gi,1), SAM_Mean_Online(gi,2), 'o', 'Color', qcolors(q,:), ...
        'MarkerFaceColor', qcolors(q,:), 'MarkerSize', 8, 'DisplayName', qname{q});
%     for v = gi
%         text(SAM_Mean_Online(v,1), SAM_Mean_Online(v,2), sprintf(' %d',v), ...
%             'FontSize', 9, 'Color', [.5 .5 .5]);
%     end
end

xl = xline(0,'--','Color',[.5 .5 .5]); xl.Annotation.LegendInformation.IconDisplayStyle = 'off';
yl = yline(0,'--','Color',[.5 .5 .5]); yl.Annotation.LegendInformation.IconDisplayStyle = 'off';
xlim([-4 4]); ylim([-4 4]); axis square; box on; grid off;
set(gca, 'XTick', [], 'YTick', [], 'TickLength', [0 0]);
xlabel('Valence'); ylabel('Arousal');
title('2D SAM Mapping of 40 Emotional Videos');
legend('Location','southwest');

%% =========================================================================
%% 2. PrEmo — discrete emotion selection rate
%% =========================================================================
% Selection rate = (# raters selecting the adjective) / 50
PrEmo = zeros(40,16);
for e = 1:4
    for v = 1:10, PrEmo((e-1)*10+v,:) = mean(PrE{e}(raw.Ver == v, :), 1); end
end

% --- dominant emotion per category (top-4) ---
PrEmo_qmean = zeros(4,16);
for q = 1:4, PrEmo_qmean(q,:) = mean(PrEmo(qvid{q},:),1); end

fprintf('\n[2. PrEmo]  dominant emotions per category (top-4 mean selection rate)\n');
for q = 1:4
    [s,o] = sort(PrEmo_qmean(q,:),'descend');
    fprintf('  %-5s : ', qname{q});
    for k = 1:4, fprintf('%s %.2f | ', emo{o(k)}, s(k)); end
    fprintf('\n');
end

% --- Fig. 4b: PrEmo heatmap (40 x 16) ---
figure('Name','Fig4b PrEmo heatmap');
h = heatmap(PrEmo, 'Colormap', parula);
h.XDisplayLabels    = emo;
h.YDisplayLabels    = string(1:40);
h.CellLabelColor    = 'none';
h.ColorbarVisible   = 'on';
h.Title             = 'PrEmo Selection Rate across all Videos';

%% =========================================================================
%% 3. Highlight — emotional peak identification
%% =========================================================================
% Selection rate = (# raters selecting the scene) / 50; 6 scenes + 'none' (col 7)
HL = zeros(40,7);
for e = 1:4
    for v = 1:10, HL((e-1)*10+v,:) = mean(High{e}(raw.Ver == v, :), 1); end
end
scenes = HL(:,1:6);

% category-wise scene trend (mean over the 10 videos of each category)
q_trend = zeros(4,6);
for q = 1:4, q_trend(q,:) = mean(scenes(qvid{q},:),1); end

fprintf('\n[3. Highlight]  category mean selection rate, scenes 1-6\n');
for q = 1:4
    fprintf('  %-5s : %s\n', qname{q}, sprintf('%.3f  ', q_trend(q,:)));
end

% --- Fig. 4c: category-wise highlight selection trend ---
figure('Name','Fig4c Highlight', 'Position', [100 100 600 600]);hold on;
for q = 1:4
    plot(1:6, q_trend(q,:), '-o', 'LineWidth', 2.5, 'Color', qcolors(q,:), 'DisplayName', qname{q});
end

ax            = gca;
ax.TickLength = [0 0];
ax.XMinorTick = 'off';
ax.YMinorTick = 'off';
ax.Box        = 'on';

xlabel('Highlight Scene'); ylabel('Selection Rate');
title('Highlight Selection Rate'); legend('Location','southeast');
set(gca, 'XTick', [], 'YTick', [], 'TickLength', [0 0]);
xlim([1 6]); xticks(1:6);
grid off; hold off;