function discardIndices = getDiscard_MATLAB(dots, meshFile, ...
    filterScriptFile, curvatureThreshold, fusionCubeHalfSizeMm)
%GETDISCARD_MATLAB Locate point-cloud samples near concave surface regions.
%   dots is an N-by-3 point cloud in mm. meshFile is an STL isosurface and
%   filterScriptFile is the bundled PyMeshLab APSS filter. PyMeshLab APSS
%   curvature is converted to the sign convention used in the paper, where
%   values below curvatureThreshold are concave. The output contains row
%   indices of dots lying within fusionCubeHalfSizeMm of any concave surface
%   point along each coordinate axis.

meshSet = py.pymeshlab.MeshSet();
meshSet.load_new_mesh(meshFile);
meshSet.load_filter_script(filterScriptFile);
meshSet.apply_filter_script();
mesh = meshSet.current_mesh();

surfaceDots = ndarrayToMatrix(mesh.vertex_matrix());
meshLabMeanCurvature = ndarrayToMatrix(mesh.vertex_scalar_array());

% APSS curvature signs depend on the surface-normal convention. For the
% outward-oriented STL meshes generated in Stage 03, PyMeshLab uses the
% opposite sign to the convention in the paper. Convert the sign explicitly
% so the method remains H < 0 for concave fusion regions.
paperMeanCurvature = -meshLabMeanCurvature;
concaveDots = surfaceDots(paperMeanCurvature < curvatureThreshold, :);

if isempty(concaveDots)
    discardIndices = zeros(0, 1);
    return
end

indexSets = cell(size(concaveDots, 1), 1);
for pointIndex = 1:size(concaveDots, 1)
    [~, indexSets{pointIndex}] = findDotsInRange( ...
        concaveDots(pointIndex, :) - fusionCubeHalfSizeMm, ...
        concaveDots(pointIndex, :) + fusionCubeHalfSizeMm, dots);
end
discardIndices = unique(vertcat(indexSets{:}));
end

function matrix = ndarrayToMatrix(ndarray)
% Convert a one- or two-dimensional NumPy array without a NumPy data copy.
values = cell(ndarray.tolist());
if isempty(values)
    matrix = [];
elseif isa(values{1}, 'py.list')
    rows = cellfun(@(row) cellfun(@double, cell(row)), values, ...
        'UniformOutput', false);
    matrix = vertcat(rows{:});
else
    matrix = cellfun(@double, values(:));
end
end
