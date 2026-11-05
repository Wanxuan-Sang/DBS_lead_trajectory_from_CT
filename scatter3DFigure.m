function scatter3DFigure(dots, varargin)
%SCATTER3DFIGURE Create a figure containing an N-by-3 point cloud.
%   dots is expressed in the active coordinate unit (mm in this project).
%   Optional name-value arguments are size, color, and alpha. The function
%   has no output; it creates a new figure and retains the axes for overlays.

parser = inputParser;
addParameter(parser, 'size', 2)
addParameter(parser, 'color', 0.4 * [1, 1, 1])
addParameter(parser, 'alpha', 0.6)
parse(parser, varargin{:})

figure
scatter3(dots(:, 1), dots(:, 2), dots(:, 3), parser.Results.size, ...
    parser.Results.color, 'filled', ...
    'MarkerEdgeAlpha', parser.Results.alpha, ...
    'MarkerFaceAlpha', parser.Results.alpha)
hold on
xlabel('x (mm)')
ylabel('y (mm)')
zlabel('z (mm)')
axis equal
end
