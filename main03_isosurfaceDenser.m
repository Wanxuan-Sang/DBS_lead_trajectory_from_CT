% Purpose
%   Generate CT-number isosurfaces and upsample the segmented lead volume
%   to obtain a dense point cloud in physical coordinates.
%
% Inputs
%   data/02_segmented_lead/CT_lead_<case>.mat
%       CT_lead         Segmented lead CT volume.
%   data/01_transform_mat/transform_<case>.mat
%       transform       Voxel-to-world affine transformation.
%
% Outputs
%   data/03_isosurface/<case>/isosurface_<case>_<HU>.stl
%   data/03_point_cloud/dots_<case>.mat
%       dots            N-by-3 point coordinates in millimetres.
%   data/03_point_cloud/CT_number_<case>.mat
%       CT_number       CT number associated with each retained point.
%   data/03_point_cloud/dots_sub_<case>.mat
%       dots_sub        Point locations in the upsampled voxel grid.
%   data/03_point_cloud/dots_<case>.fig and .png
%
% Main processing steps
%   1. Generate isosurfaces from 5000 HU to 15000 HU in 1000 HU steps.
%   2. Crop the nonzero lead volume to reduce interpolation cost.
%   3. Upsample by a factor of two using linear interpolation.
%   4. Apply the 5000 HU threshold and transform points to world space.
%
% Important parameters
%   segmentationThresholdHu  5000 HU, as reported in the paper.
%   isosurfaceLevelsHu       5000:1000:15000 HU.
%   upsamplingFactor         2 in all dimensions.
%   caseIds                  Case numbers to process. Edit this value below.

clearvars

%% User setting and paper parameters
caseIds = 1;
segmentationThresholdHu = 5000;
isosurfaceLevelsHu = 5000:1000:15000;
upsamplingFactor = 2;

%% Repository-relative folders
scriptFolder = fileparts(mfilename('fullpath'));
repositoryFolder = fileparts(scriptFolder);
functionFolder = fullfile(repositoryFolder, 'function');
dataFolder = fullfile(repositoryFolder, 'data');
segmentedInputFolder = fullfile(dataFolder, '02_segmented_lead');
transformInputFolder = fullfile(dataFolder, '01_transform_mat');
isosurfaceRoot = fullfile(dataFolder, '03_isosurface');
pointCloudOutputFolder = fullfile(dataFolder, '03_point_cloud');

addpath(functionFolder)
if ~isfolder(isosurfaceRoot), mkdir(isosurfaceRoot); end
if ~isfolder(pointCloudOutputFolder), mkdir(pointCloudOutputFolder); end

%% Generate isosurfaces and dense point clouds
for caseId = caseIds
    segmentedFile = fullfile(segmentedInputFolder, ...
        sprintf('CT_lead_%d.mat', caseId));
    transformFile = fullfile(transformInputFolder, ...
        sprintf('transform_%d.mat', caseId));
    if ~isfile(segmentedFile) || ~isfile(transformFile)
        error('Missing Stage 01 or Stage 02 output for case %d.', caseId)
    end

    fprintf('Stage 03: generating isosurfaces and point cloud for case %d\n', caseId)
    segmentedData = load(segmentedFile, 'CT_lead');
    transformData = load(transformFile, 'transform');
    CT_lead = segmentedData.CT_lead;
    transform = transformData.transform;

    %% Generate CT-number isosurfaces for fusion-region detection
    caseIsosurfaceFolder = fullfile(isosurfaceRoot, num2str(caseId));
    if ~isfolder(caseIsosurfaceFolder), mkdir(caseIsosurfaceFolder); end

    for levelHu = isosurfaceLevelsHu
        surface = isosurface(CT_lead, levelHu);
        if isempty(surface.vertices)
            warning('No %g HU isosurface exists for case %d.', levelHu, caseId)
            continue
        end

        voxelVertices = [surface.vertices(:,2), surface.vertices(:,1), ...
            surface.vertices(:,3)] - 1;
        surface.vertices = transformPointsForward(transform, voxelVertices);
        mesh = triangulation(surface.faces, surface.vertices);
        meshFile = fullfile(caseIsosurfaceFolder, ...
            sprintf('isosurface_%d_%d.stl', caseId, levelHu));
        stlwrite(mesh, meshFile);
    end

    %% Crop and upsample the segmented CT volume
    occupiedSubscripts = getDotsBiggerThreshold(CT_lead, 0);
    if isempty(occupiedSubscripts)
        error('The segmented lead volume is empty for case %d.', caseId)
    end

    subscriptRange = [min(occupiedSubscripts, [], 1); ...
        max(occupiedSubscripts, [], 1)];
    croppedCT = CT_lead( ...
        subscriptRange(1,1):subscriptRange(2,1), ...
        subscriptRange(1,2):subscriptRange(2,2), ...
        subscriptRange(1,3):subscriptRange(2,3));

    [xGrid, yGrid, zGrid] = ndgrid( ...
        subscriptRange(1,1):subscriptRange(2,1), ...
        subscriptRange(1,2):subscriptRange(2,2), ...
        subscriptRange(1,3):subscriptRange(2,3));

    denseStep = 1 / upsamplingFactor;
    [xDense, yDense, zDense] = ndgrid( ...
        subscriptRange(1,1):denseStep:subscriptRange(2,1), ...
        subscriptRange(1,2):denseStep:subscriptRange(2,2), ...
        subscriptRange(1,3):denseStep:subscriptRange(2,3));

    interpolant = griddedInterpolant(xGrid, yGrid, zGrid, double(croppedCT), ...
        'linear', 'none');
    denseCT = interpolant(xDense, yDense, zDense);

    %% Convert retained dense voxels to physical coordinates
    retainedIndices = find(denseCT >= segmentationThresholdHu);
    if isempty(retainedIndices)
        error('No dense points were retained for case %d.', caseId)
    end

    dots_sub = [xDense(retainedIndices), yDense(retainedIndices), ...
        zDense(retainedIndices)];
    dots = transformPointsForward(transform, dots_sub - 1);
    CT_number = denseCT(retainedIndices);

    save(fullfile(pointCloudOutputFolder, sprintf('dots_%d.mat', caseId)), ...
        'dots', '-mat');
    save(fullfile(pointCloudOutputFolder, sprintf('CT_number_%d.mat', caseId)), ...
        'CT_number', '-mat');
    save(fullfile(pointCloudOutputFolder, sprintf('dots_sub_%d.mat', caseId)), ...
        'dots_sub', '-mat');

    scatter3DFigure(dots, 'size', 2, 'alpha', 0.1);
    title(sprintf('Case %d segmented lead point cloud', caseId));
    savefig(fullfile(pointCloudOutputFolder, sprintf('dots_%d.fig', caseId)));
    exportgraphics(gcf, fullfile(pointCloudOutputFolder, ...
        sprintf('dots_%d.png', caseId)));
    close(gcf)
end
