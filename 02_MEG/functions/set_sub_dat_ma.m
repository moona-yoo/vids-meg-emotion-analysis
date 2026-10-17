function sub_dat = set_sub_dat_ma()
% Subject information (23 subjects)
%   Column 1: subject ID (Sub01 ~ Sub23)
%   Column 2: block recording order (1 = HAHV, 2 = HALV, 3 = LAHV, 4 = LALV)
%   Column 3: bad channels noted during the experiment (real-time monitoring)

sub_dat = cell(23, 3);

%% Block Order
tmp_blk  = {[1 3 4 2], [1 4 2 3], [2 1 4 3], [2 3 1 4], [2 3 4 1], ...
            [3 1 2 4], [2 4 3 1], [3 1 4 2], [3 2 4 1], [3 4 1 2], ...
            [3 4 2 1], [4 1 2 3], [4 1 3 2], [4 2 1 3], [4 2 3 1], ...
            [4 3 1 2], [4 3 2 1], [1 2 3 4], [2 1 4 3], [3 2 1 4], ...
            [4 2 3 1], [1 2 4 3], [3 2 4 1] };

%% Bad Channel Info (noted during the experiment)
tmp_bad   = {[], [65 116], [65 68 116], [], [65 116], ...
             [], [65 68 116], [], [65 68 116], [116], ...
             [65 68 116], [65 68 70 81 84 113 116], [], [116], [], ...
             [65 68 116], [116], [65 68 84 113 116], [], [116], ...
             [], [65 116], [] };

tmp_bad   = cellfun(@(x) arrayfun(@(n) ['MEG 3' sprintf('%03d', n)], x, 'UniformOutput', false), ...
            tmp_bad, 'UniformOutput', false);

%% Subject data
for i = 1:23
    sub_dat{i, 1} = sprintf('Sub%02d', i);
    sub_dat{i, 2} = tmp_blk{i};
    sub_dat{i, 3} = tmp_bad{i};
end

end
