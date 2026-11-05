function scatter3DAddToFigure(dots, varargin)
%SCATTER3DADDTOFIGURE Add an N-by-3 point cloud to the current axes.
%   dots is expressed in the active coordinate unit (mm in this project).
%   Optional name-value arguments are size, color, and alpha. The function
%   has no output and does not create a new figure.

parser = inputParser;
addParameter(parser, 'size', 2)
addParameter(parser, 'color', [0.5, 0.5, 0.5])
addParameter(parser, 'alpha', 0.6)
parse(parser, varargin{:})

scatter3(dots(:, 1), dots(:, 2), dots(:, 3), parser.Results.size, ...
    parser.Results.color, 'filled', ...
    'MarkerEdgeAlpha', parser.Results.alpha, ...
    'MarkerFaceAlpha', parser.Results.alpha)
end
