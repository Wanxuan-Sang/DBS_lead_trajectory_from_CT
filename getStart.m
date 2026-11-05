function start = getStart(dots, endpoints, stepLengthMm)
%GETSTART Estimate the first two points of each electrode trajectory.
%   dots and endpoints are physical coordinates in mm. The closest endpoint
%   pair is used when three skeleton endpoints exist. Local centres are
%   estimated in 5 mm and 10 mm spherical neighbourhoods. start is a
%   two-element cell array; each cell contains two N-by-3 path points spaced
%   by stepLengthMm. A 0.4 mm axial tube is retained from the original start
%   refinement implementation.

if size(endpoints, 1) < 2 || size(endpoints, 1) > 3
    error('Expected two or three skeleton endpoints.')
end

if size(endpoints, 1) == 2
    contactPoints = endpoints;
else
    endpointPairs = nchoosek(1:size(endpoints, 1), 2);
    pairVectors = endpoints(endpointPairs(:, 1), :) - ...
        endpoints(endpointPairs(:, 2), :);
    [~, closestPairIndex] = min(vecnorm(pairVectors, 2, 2));
    contactPoints = endpoints(endpointPairs(closestPairIndex, :), :);
end

contactPoints = sortrows(contactPoints, 1, 'ascend');
start = cell(2, 1);
for contactIndex = 1:2
    start{contactIndex} = calculateStart( ...
        dots, contactPoints(contactIndex, :), stepLengthMm);
end
end

function startPoints = calculateStart(dots, contactPoint, stepLengthMm)
innerRadiusMm = 5;
outerRadiusMm = 10;
endpointTubeRadiusMm = 0.4;

innerPoints = pointsInSphere(dots, contactPoint, innerRadiusMm);
if isempty(innerPoints)
    error('No point-cloud samples were found within 5 mm of an endpoint.')
end
contactCentre = mean(innerPoints, 1);

outerPoints = pointsInSphere(dots, contactCentre, outerRadiusMm);
if isempty(outerPoints)
    error('No point-cloud samples were found within 10 mm of an endpoint.')
end
direction = mean(outerPoints, 1) - contactCentre;
if norm(direction) == 0
    error('The initial trajectory direction is undefined.')
end
direction = direction / norm(direction);

[~, ~, ~, backwardDistance] = findDotsInTube(outerRadiusMm, ...
    endpointTubeRadiusMm, outerPoints, contactCentre, -direction);
if isempty(backwardDistance)
    backwardDistance = 0;
end

firstPoint = contactCentre - direction * backwardDistance;
startPoints = [firstPoint; firstPoint + direction * stepLengthMm];
end

function selectedPoints = pointsInSphere(dots, centre, radius)
selectedPoints = dots(vecnorm(dots - centre, 2, 2) <= radius, :);
end
