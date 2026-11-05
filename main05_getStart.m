% Purpose
%   Determine the two electrode-contact-side trajectory starts and their
%   initial tracking directions from the segmented lead morphology.
%
% Inputs
%   data/03_point_cloud/dots_sub_<case>.mat
%       dots_sub        Lead locations in the upsampled voxel grid.
%   data/03_point_cloud/dots_<case>.mat
%       dots            Lead point coordinates in millimetres.
%   data/01_transform_mat/transform_<case>.mat
%       transform       Voxel-to-world affine transformation.
%
% Outputs
%   data/05_start_points/start_<case>.mat
%       start           Two cells, each containing the first two path points.
%   data/05_start_points/start_<case>.fig and .png
%
% Main processing steps
%   1. Morphologically simplify and skeletonize the segmented lead volume.
%   2. Find the two closest skeleton endpoints on the contact side.
%   3. Estimate centre points in 5 mm and 10 mm neighbourhoods.
%   4. Create the first two trajectory points with a 0.5 mm spacing.
%
% Important parameters
%   initialStepLengthMm     0.5 mm, matching the paper tracking step.
%   caseIds                 Case numbers to process. Edit this value below.

clearvars

%% User setting and paper parameter
caseIds = 1;
initialStepLengthMm = 0.5;

%% Repository-relative folders
scriptFolder = fileparts(mfilename('fullpath'));
repositoryFolder = fileparts(scriptFolder);
functionFolder = fullfile(repositoryFolder, 'function');
dataFolder = fullfile(repositoryFolder, 'data');
pointCloudInputFolder = fullfile(dataFolder, '03_point_cloud');
transformInputFolder = fullfile(dataFolder, '01_transform_mat');
outputFolder = fullfile(dataFolder, '05_start_points');

addpath(functionFolder)
if ~isfolder(outputFolder), mkdir(outputFolder); end

%% Determine trajectory start points
for caseId = caseIds
    dotsSubFile = fullfile(pointCloudInputFolder, ...
        sprintf('dots_sub_%d.mat', caseId));
    dotsFile = fullfile(pointCloudInputFolder, sprintf('dots_%d.mat', caseId));
    transformFile = fullfile(transformInputFolder, ...
        sprintf('transform_%d.mat', caseId));
    if ~isfile(dotsSubFile) || ~isfile(dotsFile) || ~isfile(transformFile)
        error('Missing Stage 01 or Stage 03 output for case %d.', caseId)
    end

    fprintf('Stage 05: determining starts for case %d\n', caseId)
    dotsSubData = load(dotsSubFile, 'dots_sub');
    pointData = load(dotsFile, 'dots');
    transformData = load(transformFile, 'transform');

    [~, endpoints] = getSkeletonEndpoints( ...
        dotsSubData.dots_sub, transformData.transform);
    start = getStart(pointData.dots, endpoints, initialStepLengthMm);
    save(fullfile(outputFolder, sprintf('start_%d.mat', caseId)), ...
        'start', '-mat');

    scatter3DFigure(pointData.dots, 'size', 1.5, 'alpha', 0.1);
    scatter3DAddToFigure(start{1}, 'size', 18, 'color', [0.1 0.3 0.9]);
    scatter3DAddToFigure(start{2}, 'size', 18, 'color', [0.9 0.2 0.1]);
    title(sprintf('Case %d trajectory starts', caseId));
    savefig(fullfile(outputFolder, sprintf('start_%d.fig', caseId)));
    exportgraphics(gcf, fullfile(outputFolder, sprintf('start_%d.png', caseId)));
    close(gcf)
end
