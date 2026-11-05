function [path, dotsElse, ctWeightElse, fusionFlagElse, dotsInTube, ...
    startExtend] = traceElectrodePath(start, dots, ctWeight, ...
    isFusionPoint, parameters)
%TRACEELECTRODEPATH Reconstruct one DBS electrode-lead centreline.
%   start contains two initial points in mm. dots is an N-by-3 candidate
%   point cloud, ctWeight is CT/5000, and isFusionPoint flags points whose
%   weight is reduced to parameters.fusionWeight. parameters supplies the
%   paper values stepLength, tubeLength, tubeRadius, ctWeightExponent, and
%   fusionWeight, together with explicit implementation stopping settings.
%   path is the reconstructed centreline in mm. The *Else outputs contain
%   candidates not removed after this lead, dotsInTube stores the vision
%   field points at each step, and startExtend is empty unless a connector
%   end is detected.

if size(start, 1) ~= 2 || size(start, 2) ~= 3
    error('start must contain exactly two three-dimensional points.')
end
ctWeight = ctWeight(:);
isFusionPoint = logical(isFusionPoint(:));
if size(dots, 1) ~= numel(ctWeight) || size(dots, 1) ~= numel(isFusionPoint)
    error('dots, ctWeight, and isFusionPoint must have equal row counts.')
end

stepLength = parameters.stepLength;
deleteDelaySteps = max(1, ceil(parameters.deleteHistoryLengthMm / stepLength));
maximumIterations = parameters.maximumIterations;

path = nan(maximumIterations + 1, 3);
path(1:2, :) = start;
pathEnd = 2;
direction = start(2, :) - start(1, :);
connectorDetected = false;
startExtend = [];

dotsInTube = cell(maximumIterations, 1);
tubePointIds = cell(maximumIterations, 1);
currentPointIds = (1:size(dots, 1)).';
[dotsInTube{1}, initialIndices] = findDotsInTube( ...
    parameters.tubeLength, 1.5, dots, path(1, :), direction);
tubePointIds{1} = currentPointIds(initialIndices);
lastTubeIndex = 1;

for stepIndex = 2:maximumIterations
    previousPoint = path(stepIndex - 1, :);
    currentPoint = path(stepIndex, :);
    pathLengthEstimate = stepIndex * stepLength;

    if pathLengthEstimate < parameters.contactRegionLength
        tubeLength = parameters.contactTubeLength;
        tubeRadius = parameters.contactTubeRadius;
    elseif pathLengthEstimate > parameters.connectorSearchStart
        tubeLength = parameters.connectorTubeLength;
        tubeRadius = parameters.connectorTubeRadius;
    else
        tubeLength = parameters.tubeLength;
        tubeRadius = parameters.tubeRadius;
    end

    [dotsInTube{stepIndex}, tubeIndices, radialDistances, maximumAlong] = ...
        findDotsInTube(tubeLength, tubeRadius, dots, currentPoint, ...
        currentPoint - previousPoint);
    tubePointIds{stepIndex} = currentPointIds(tubeIndices);
    lastTubeIndex = stepIndex;
    pointCount = size(dotsInTube{stepIndex}, 1);

    if isempty(maximumAlong) || ...
            pointCount < maximumAlong * parameters.minimumPointsPerMm
        warning('Tracking stopped because the vision field was too sparse.')
        break
    end

    if ~connectorDetected && ...
            pathLengthEstimate >= parameters.connectorSearchStart && ...
            maximumAlong > 0 && ...
            pointCount > maximumAlong * parameters.connectorDensityPerMm
        connectorDetected = true;
    end

    if connectorDetected && maximumAlong < 2
        nextPoint = currentPoint + direction * maximumAlong;
        path(stepIndex + 1, :) = nextPoint;
        pathEnd = stepIndex + 1;
        startExtend = calculateExtensionStart(dots, nextPoint, direction, ...
            stepLength);
        break
    end

    if pathLengthEstimate >= parameters.maxElectrodeLength
        warning('Electrode tracking reached the maximum permitted length.')
        break
    end

    distanceWeight = 1 ./ max(radialDistances, 0.1);
    ctWeightInTube = ctWeight(tubeIndices) .^ parameters.ctWeightExponent;
    fusionWeight = ones(pointCount, 1);
    fusionWeight(isFusionPoint(tubeIndices)) = parameters.fusionWeight;
    combinedWeight = distanceWeight .* ctWeightInTube .* fusionWeight;
    direction = mean((dotsInTube{stepIndex} - currentPoint) .* ...
        combinedWeight, 1);
    if ~all(isfinite(direction)) || norm(direction) == 0
        warning('Tracking stopped because the weighted direction was undefined.')
        break
    end
    direction = direction / norm(direction);
    path(stepIndex + 1, :) = currentPoint + direction * stepLength;
    pathEnd = stepIndex + 1;

    if stepIndex >= deleteDelaySteps + 1
        idsToDelete = tubePointIds{stepIndex - deleteDelaySteps};
        deleteMask = ismember(currentPointIds, idsToDelete);
        dots(deleteMask, :) = [];
        ctWeight(deleteMask) = [];
        isFusionPoint(deleteMask) = [];
        currentPointIds(deleteMask) = [];
    end
end

path = path(1:pathEnd, :);
dotsInTube = dotsInTube(1:lastTubeIndex);
dotsElse = dots;
ctWeightElse = ctWeight;
fusionFlagElse = isFusionPoint;
end

function start = calculateExtensionStart(dots, point, direction, stepLength)
[nearbyPoints, ~, ~, ~] = findDotsInTube(6, 1.5, dots, point, direction);
if isempty(nearbyPoints)
    start = [];
    return
end

centre = mean(nearbyPoints, 1);
[~, ~, ~, backwardDistance] = findDotsInTube( ...
    4, 1.5, dots, centre, -direction);
if isempty(backwardDistance)
    start = [];
    return
end

firstPoint = centre - direction * backwardDistance;
start = [firstPoint; firstPoint + direction * stepLength];
end
