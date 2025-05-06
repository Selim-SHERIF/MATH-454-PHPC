% plot_results.m
% -----------------------------------
% Reads results.csv and plots average time per iteration
% vs. threads per block (log x-axis), with one curve per matrix.

% Load data
T = readtable('results.csv');

% Get list of unique matrices
matrixNames = unique(T.matrix);

% Create figure
figure; hold on;

% Choose a colormap
colors = lines(numel(matrixNames));

% Plot each matrix
for i = 1:numel(matrixNames)
    % Select rows for this matrix
    mask = strcmp(T.matrix, matrixNames{i});
    tpb = T.threadsPerBlock(mask);
    avg = T.avg_time_s(mask);
    
    % Sort by threadsPerBlock
    [tpb, idx] = sort(tpb);
    avg = avg(idx);
    
    % Plot
    plot(tpb, avg, '-o', 'Color', colors(i,:), ...
         'LineWidth', 1.5, 'MarkerSize', 6, ...
         'DisplayName', matrixNames{i});
end

% Formatting
xlabel('Threads per block','FontSize',12);
ylabel('Average time per iteration (s)','FontSize',12);
title('CG Solver Performance vs. Threads/Block','FontSize',14);
legend('Location','best','Interpreter','none');
grid on;
set(gca,'FontSize',11);

% Set x-axis to logarithmic scale
set(gca, 'XScale', 'log');

hold off;
