clear;
width=600;
height=450;
line_width = 2;
marker_size = 10;
font_size = 20;
title_font_size = 19;
text_size = 20;
avg_nnz = 1.655975165562914e+02;

num_functions_SCG_STORM = [
2.4e4, 7.2e4, 5.6458;
1.2e5, 1.44e5, 5.6481;
1.92e5, 1.68e5, 5.6484;
3e5, 2.4e5, 5.6489;
1.02e6, 3.6e5, 5.6491;
];

% rescale
for i = 1 : 2
    num_functions_SCG_STORM(:, i) = num_functions_SCG_STORM(:, i) * avg_nnz;
end

plot(num_functions_SCG_STORM(:, 2), num_functions_SCG_STORM(:, 1), '-*', 'LineWidth', 2);

strValues = strtrim(cellstr(num2str([num_functions_SCG_STORM(:, 3)])));
text(num_functions_SCG_STORM(:, 2), num_functions_SCG_STORM(:, 1), strValues, 'VerticalAlignment', 'bottom', 'FontSize', text_size, 'FontName', 'Times New Roman');

set(gca, 'FontName', 'Times New Roman');
set (gca, 'FontSize', font_size);
xlabel('#function evaluations for SCG++');
ylabel('#function evaluations for SCG');
grid on;
title('concave over modular, MovieLens1M', 'FontSize', title_font_size);

file_name = ['../data/result_num_functions_concave_over_modular.eps'];
saveas(gcf, file_name, 'epsc');