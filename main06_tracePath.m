% Purpose
%   Reconstruct bilateral DBS lead trajectories by repeatedly computing a
%   weighted direction from candidate points in a cylindrical vision field.
%
% Inputs
%   data/05_start_points/start_<case>.mat
%       start           Initial two-point definitions for both trajectories.
%   data/03_point_cloud/dots_<case>.mat
%       dots            Candidate lead points in millimetres.
%   data/03_point_cloud/CT_number_<case>.mat
%       CT_number       CT number associated with each candidate point.
%   data/04_fusion_points/dots_discard_<case>.mat
%       dots_discard    Candidate points in fusion regions.
%
% Outputs
%   data/06_trajectories/trajectory_<case>.mat
%       path_el1/path_el2   Reconstructed electrode-lead trajectories.
%       path1/path2         Complete paths when extension tracking succeeds.
%       trackingParameters  Paper tracking parameters used for the run.
%   data/06_trajectories/trajectory_<case>.fig and .png
%
% Main processing steps
%   1. Normalize CT weights by the 5000 HU segmentation threshold.
%   2. Track each electrode lead from its contact-side start point.
%   3. Assign zero weight to points identified as fusion regions.
%   4. Continue along the extension cable when a connector is detected.
%   5. Save trajectories and a quality-control figure.
%
% Important parameters
%   stepLength              0.5 mm, as reported in the paper.
%   tubeLength              2 * stepLength, as reported in the paper.
%   tubeRadius              0.65 mm (half of the 1.3 mm lead diameter).
%   ctWeightExponent        1, giving the paper weight CT number / 5000.
%   fusionWeight            0 inside fusion regions and 1 elsewhere.
%   caseIds                 Case numbers to process. Edit this value below.
%   trackExtensionCable     Enable only when CT covers the extension cable.

clearvars

%% User setting
caseIds = 1;
trackExtensionCable = false;

%% Tracking parameters reported in the paper
trackingParameters.stepLength = 0.5;
trackingParameters.tubeLength = 2 * trackingParameters.stepLength;
trackingParameters.tubeRadius = 0.65;
trackingParameters.ctWeightExponent = 1;
trackingParameters.fusionWeight = 0;

% Explicit implementation settings used by the original workflow. These
% stopping and connector-detection values are not parameters of the paper's
% direction-weighting equations.
trackingParameters.minimumPointsPerMm = 4;
trackingParameters.maxElectrodeLength = 430;
trackingParameters.contactRegionLength = 10;
trackingParameters.contactTubeLength = 5;
trackingParameters.contactTubeRadius = 1;
trackingParameters.connectorSearchStart = 380;
trackingParameters.connectorTubeLength = 4;
trackingParameters.connectorTubeRadius = 2;
trackingParameters.connectorDensityPerMm = 200;
trackingParameters.maximumIterations = ...
    ceil(450 / trackingParameters.stepLength);
trackingParameters.deleteHistoryLengthMm = 5;

% The extension-cable values are implementation details not specified by
% the paper equations. They are kept visible here and are never set inside
% traceExtendPath.
extensionParameters.stepLength = 1.2;
extensionParameters.tubeLength = 4;
extensionParameters.tubeRadius = 1.2;
extensionParameters.ctWeightExponent = 1;
extensionParameters.minimumPointsPerMm = 10;
extensionParameters.roughEndLength = 430;
extensionParameters.maxPathLength = 450;
extensionParameters.maximumIterations = 2000;
extensionParameters.deleteDelaySteps = 3;

segmentationThresholdHu = 5000;

%% Repository-relative folders
scriptFolder = fileparts(mfilename('fullpath'));
repositoryFolder = fileparts(scriptFolder);
functionFolder = fullfile(repositoryFolder, 'function');
dataFolder = fullfile(repositoryFolder, 'data');
startInputFolder = fullfile(dataFolder, '05_start_points');
pointCloudInputFolder = fullfile(dataFolder, '03_point_cloud');
fusionInputFolder = fullfile(dataFolder, '04_fusion_points');
outputFolder = fullfile(dataFolder, '06_trajectories');

addpath(functionFolder)
if ~isfolder(outputFolder), mkdir(outputFolder); end

%% Reconstruct trajectories
for caseId = caseIds
    startFile = fullfile(startInputFolder, sprintf('start_%d.mat', caseId));
    dotsFile = fullfile(pointCloudInputFolder, sprintf('dots_%d.mat', caseId));
    ctFile = fullfile(pointCloudInputFolder, sprintf('CT_number_%d.mat', caseId));
    discardFile = fullfile(fusionInputFolder, ...
        sprintf('dots_discard_%d.mat', caseId));
    if ~isfile(startFile) || ~isfile(dotsFile) || ...
            ~isfile(ctFile) || ~isfile(discardFile)
        error('Missing Stage 03, Stage 04, or Stage 05 output for case %d.', caseId)
    end

    fprintf('Stage 06: tracing case %d\n', caseId)
    startData = load(startFile, 'start');
    pointData = load(dotsFile, 'dots');
    ctData = load(ctFile, 'CT_number');
    discardData = load(discardFile, 'dots_discard');

    start = startData.start;
    dots = pointData.dots;
    ctWeight = ctData.CT_number / segmentationThresholdHu;
    isFusionPoint = ismember(dots, discardData.dots_discard, 'rows');

    [path_el1, dotsElse, ctElse, fusionElse, ~, startEx1] = ...
        traceElectrodePath(start{1}, dots, ctWeight, isFusionPoint, ...
        trackingParameters);
    [path_el2, dotsElse, ctElse, ~, ~, startEx2] = ...
        traceElectrodePath(start{2}, dotsElse, ctElse, fusionElse, ...
        trackingParameters);

    path1 = path_el1;
    path2 = path_el2;
    if trackExtensionCable && ~isempty(startEx1)
        [pathEx1, ~, ~, ~] = traceExtendPath(startEx1, dotsElse, ctElse, extensionParameters); %#ok<UNRCH>
        path1 = [path_el1; pathEx1];
    end
    if trackExtensionCable && ~isempty(startEx2)
        [pathEx2, ~, ~, ~] = traceExtendPath(startEx2, dotsElse, ctElse, extensionParameters); %#ok<UNRCH>
        path2 = [path_el2; pathEx2];
    end

    length1 = sum(vecnorm(diff(path1), 2, 2));
    length2 = sum(vecnorm(diff(path2), 2, 2));
    outputFile = fullfile(outputFolder, sprintf('trajectory_%d.mat', caseId));
    save(outputFile, 'path_el1', 'path_el2', 'path1', 'path2', ...
        'length1', 'length2', 'trackingParameters', ...
        'extensionParameters', 'trackExtensionCable', '-mat');

    scatter3DFigure(dots, 'size', 0.5, 'alpha', 0.08);
    plotPath(path1, 'line_spec', '-', 'color', [0.85, 0.1, 0.1], ...
        'line_width', 2, 'marker_size', 1);
    plotPath(path2, 'line_spec', '-', 'color', [0.1, 0.2, 0.85], ...
        'line_width', 2, 'marker_size', 1);
    title(sprintf('Case %d: L1 = %.1f mm, L2 = %.1f mm', ...
        caseId, length1, length2));
    savefig(fullfile(outputFolder, sprintf('trajectory_%d.fig', caseId)));
    exportgraphics(gcf, fullfile(outputFolder, ...
        sprintf('trajectory_%d.png', caseId)));
    close(gcf)
end
