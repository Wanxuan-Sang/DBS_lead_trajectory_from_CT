% Purpose
%   Identify point-cloud samples in lead-fusion regions by analysing the
%   mean curvature of multiple CT-number isosurfaces.
%
% Inputs
%   data/03_point_cloud/dots_<case>.mat
%       dots            Dense lead point coordinates in millimetres.
%   data/03_isosurface/<case>/isosurface_<case>_<HU>.stl
%   data/01_transform_mat/transform_<case>.mat
%       voxelSpacing    NIfTI voxel dimensions in millimetres.
%   function/APSS_H.mlx
%
% Outputs
%   data/04_fusion_points/dots_discard_<case>.mat
%       dots_discard    Points assigned zero weight during tracking.
%   data/04_fusion_points/dots_discard_<case>.fig and .png
%
% Main processing steps
%   1. Estimate mean curvature on each isosurface with APSS in PyMeshLab.
%   2. Convert PyMeshLab curvature to the paper convention H < 0.
%   3. Take the union of CT-voxel-sized regions around concave points.
%
% Important parameters
%   isosurfaceLevelsHu       5000:1000:15000 HU.
%   paperCurvatureBoundary  0; concave regions satisfy paper H < 0.
%   pyMeshLabNoiseTolerance 0.2; implementation-only APSS tolerance.
%   voxelSpacing            Three-axis NIfTI voxel size in millimetres.
%   caseIds                 Case numbers to process. Edit this value below.

clearvars

%% User setting, paper boundary, and APSS tolerance
caseIds = 1;
isosurfaceLevelsHu = 5000:1000:15000;
paperCurvatureBoundary = 0;
pyMeshLabNoiseTolerance = 0.2;
curvatureThreshold = paperCurvatureBoundary - pyMeshLabNoiseTolerance;

%% Repository-relative folders
scriptFolder = fileparts(mfilename('fullpath'));
repositoryFolder = fileparts(scriptFolder);
functionFolder = fullfile(repositoryFolder, 'function');
dataFolder = fullfile(repositoryFolder, 'data');
pointCloudInputFolder = fullfile(dataFolder, '03_point_cloud');
transformInputFolder = fullfile(dataFolder, '01_transform_mat');
isosurfaceRoot = fullfile(dataFolder, '03_isosurface');
outputFolder = fullfile(dataFolder, '04_fusion_points');
filterScriptFile = fullfile(functionFolder, 'APSS_H.mlx');

addpath(functionFolder)
if ~isfile(filterScriptFile)
    error('APSS filter script not found: %s', filterScriptFile)
end
if ~isfolder(outputFolder), mkdir(outputFolder); end

%% Identify fusion-region points
for caseId = caseIds
    dotsFile = fullfile(pointCloudInputFolder, sprintf('dots_%d.mat', caseId));
    transformFile = fullfile(transformInputFolder, ...
        sprintf('transform_%d.mat', caseId));
    if ~isfile(dotsFile) || ~isfile(transformFile)
        error('Missing Stage 01 or Stage 03 output for case %d.', caseId)
    end

    fprintf('Stage 04: identifying fusion regions for case %d\n', caseId)
    pointData = load(dotsFile, 'dots');
    transformData = load(transformFile);
    dots = pointData.dots;
    voxelSpacing = getVoxelSpacing(transformData);
    fusionCuboidHalfSizeMm = voxelSpacing / 2;
    discardIndexSets = cell(numel(isosurfaceLevelsHu), 1);

    for levelIndex = 1:numel(isosurfaceLevelsHu)
        levelHu = isosurfaceLevelsHu(levelIndex);
        meshFile = fullfile(isosurfaceRoot, num2str(caseId), ...
            sprintf('isosurface_%d_%d.stl', caseId, levelHu));
        if ~isfile(meshFile)
            warning('Skipping missing isosurface: %s', meshFile)
            discardIndexSets{levelIndex} = zeros(0, 1);
            continue
        end

        discardIndexSets{levelIndex} = getDiscard_MATLAB( ...
            dots, meshFile, filterScriptFile, curvatureThreshold, ...
            fusionCuboidHalfSizeMm);
    end

    dotsDiscardIndex = unique(vertcat(discardIndexSets{:}));
    dots_discard = dots(dotsDiscardIndex, :);
    save(fullfile(outputFolder, sprintf('dots_discard_%d.mat', caseId)), ...
        'dots_discard', 'voxelSpacing', 'paperCurvatureBoundary', ...
        'pyMeshLabNoiseTolerance', '-mat');

    scatter3DFigure(dots, 'size', 0.5, 'alpha', 0.15);
    if ~isempty(dots_discard)
        scatter3DAddToFigure(dots_discard, 'size', 1.5, ...
            'color', [0.9, 0.1, 0.1], 'alpha', 0.3);
    end
    title(sprintf('Case %d fusion-region points', caseId));
    savefig(fullfile(outputFolder, sprintf('dots_discard_%d.fig', caseId)));
    exportgraphics(gcf, fullfile(outputFolder, ...
        sprintf('dots_discard_%d.png', caseId)));
    close(gcf)
end

function voxelSpacing = getVoxelSpacing(transformData)
if isfield(transformData, 'voxelSpacing')
    voxelSpacing = double(transformData.voxelSpacing(:).');
elseif isfield(transformData, 'transform')
    linearTransform = transformData.transform.T(1:3, 1:3);
    voxelSpacing = vecnorm(linearTransform, 2, 2).';
else
    error('The transform MAT file contains no voxel-spacing information.')
end
if numel(voxelSpacing) ~= 3 || any(~isfinite(voxelSpacing)) || ...
        any(voxelSpacing <= 0)
    error('voxelSpacing must contain three positive finite values.')
end
end
