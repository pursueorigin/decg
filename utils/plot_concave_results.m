clear;
width=600;
height=450;
line_width = 2;
marker_size = 10;
font_size = 20;

load('../data/result_movie_main_cen_concave_5e2_5e2_1e4_20_20_true.mat');
plot([0.0; res_CenSCG(:, 3)], [0.0; res_CenSCG(:, 5)], 'DisplayName', 'SCG', 'LineWidth', line_width); hold on;
plot([0.0; res_CenSFW(:, 3)], [0.0; res_CenSFW(:, 5)], 'DisplayName', 'SFW', 'LineWidth', line_width); hold on;
plot([0.0; res_CenSTORM(:, 3)], [0.0; res_CenSTORM(:, 5)], 'DisplayName', 'STORM', 'LineWidth', line_width); hold on;

legend('show', 'Location', 'southeast');
xlim([0, 1.2e6]);
ylim([5.632, 5.65]);
set(gca, 'FontName', 'Times New Roman');
set (gca, 'FontSize', font_size);
xlabel('#function evaluations');
ylabel('objective value');
grid on;
title('concave over modular, MovieLens1M');

file_name = ['../data/movielens_concave_over_modular.eps'];
saveas(gcf, file_name, 'epsc');
