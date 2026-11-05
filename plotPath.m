function plotPath(path, varargin)
%PLOTPATH Add a three-dimensional trajectory to the current axes.
%   path is an N-by-3 array in mm. Optional name-value arguments are
%   line_spec, color, line_width, and marker_size. This function has no
%   output and does not create a new figure.

parser = inputParser;
addParameter(parser, 'line_spec', '-+')
addParameter(parser, 'color', 0.4 * [1, 1, 1])
addParameter(parser, 'line_width', 1)
addParameter(parser, 'marker_size', 6)
parse(parser, varargin{:})

axis equal
plot3(path(:, 1), path(:, 2), path(:, 3), parser.Results.line_spec, ...
    'Color', parser.Results.color, ...
    'LineWidth', parser.Results.line_width, ...
    'MarkerSize', parser.Results.marker_size)
end
