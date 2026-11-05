function [path, dotsElse, ctWeightElse, dotsInTube] = traceExtendPath( ...
    start, dots, ctWeight, parameters)
%TRACEEXTENDPATH Continue a reconstructed path along the extension cable.
%   start contains two initial points in mm. dots is an N-by-3 candidate
%   point cloud and ctWeight is CT/5000. parameters contains the explicitly
%   labelled implementation settings for extension tracking. path is the
%   extension centreline in mm, the *Else outputs contain unused candidates,
%   and dotsInTube stores the vision-field samples at each step.

if size(start, 1) ~= 2 || size(start, 2) ~= 3
    error('start must contain exactly two three-dimensional points.')
end
ctWeight = ctWeight(:);
if size(dots, 1) ~= numel(ctWeight)
    error('dots and ctWeight must have equal row counts.')
end

maximumIterations = parameters.maximumIterations;
path = nan(maximumIterations + 1, 3);
path(1:2, :) = start;
pathEnd = 2;
dotsInTube = cell(maximumIterations, 1);
tubePointIds = cell(maximumIterations, 1);
currentPointIds = (1:size(dots, 1)).';

[dotsInTube{1}, initialIndices] = findDotsInTube( ...
    parameters.tubeLength, 1.5, dots, path(1, :), path(2, :) - path(1, :));
tubePointIds{1} = currentPointIds(initialIndices);
lastTubeIndex = 1;

for stepIndex = 2:maximumIterations
    previousPoint = path(stepIndex - 1, :);
    currentPoint = path(stepIndex, :);
    pathLengthEstimate = stepIndex * parameters.stepLength;

    [dotsInTube{stepIndex}, tubeIndices, radialDistances, maximumAlong] = ...
        findDotsInTube(parameters.tubeLength, parameters.tubeRadius, dots, ...
        currentPoint, currentPoint - previousPoint);
    tubePointIds{stepIndex} = currentPointIds(tubeIndices);
    lastTubeIndex = stepIndex;
    pointCount = size(dotsInTube{stepIndex}, 1);

    if isempty(maximumAlong) || ...
            pointCount < maximumAlong * parameters.minimumPointsPerMm
        if pathLengthEstimate >= parameters.roughEndLength
            pathEnd = max(2, stepIndex - 1);
            dotsInTube{stepIndex} = [];
        else
            warning('Extension tracking stopped because the vision field was too sparse.')
        end
        break
    end

    if pathLengthEstimate >= parameters.maxPathLength
        warning('Extension tracking reached the maximum permitted length.')
        break
    end

    distanceWeight = 1 ./ max(radialDistances, 0.1);
    ctWeightInTube = ctWeight(tubeIndices) .^ parameters.ctWeightExponent;
    direction = mean((dotsInTube{stepIndex} - currentPoint) .* ...
        distanceWeight .* ctWeightInTube, 1);
    if ~all(isfinite(direction)) || norm(direction) == 0
        warning('Extension tracking stopped because the weighted direction was undefined.')
        break
    end
    direction = direction / norm(direction);
    path(stepIndex + 1, :) = currentPoint + ...
        direction * parameters.stepLength;
    pathEnd = stepIndex + 1;

    if stepIndex >= parameters.deleteDelaySteps + 1
        idsToDelete = tubePointIds{stepIndex - parameters.deleteDelaySteps};
        deleteMask = ismember(currentPointIds, idsToDelete);
        dots(deleteMask, :) = [];
        ctWeight(deleteMask) = [];
        currentPointIds(deleteMask) = [];
    end
end

path = path(1:pathEnd, :);
dotsInTube = dotsInTube(1:lastTubeIndex);
dotsElse = dots;
ctWeightElse = ctWeight;
end
