function [dotsInTube, indicesInTube, radialDistances, maximumAlong] = ...
    findDotsInTube(tubeLength, tubeRadius, dots, origin, direction)
%FINDDOTSINTUBE Select points in a forward-facing cylindrical vision field.
%   tubeLength and tubeRadius use the same distance unit as dots (mm in
%   this project). origin and direction are 1-by-3 vectors. The outputs are
%   the selected points, their row indices, radial distances from the tube
%   axis, and the greatest forward projection. maximumAlong is empty when
%   no point is selected.

directionNorm = norm(direction);
if directionNorm == 0
    error('The tube direction must be nonzero.')
end
direction = direction / directionNorm;

[candidateDots, candidateIndices] = findDotsInRange( ...
    origin - tubeLength, origin + tubeLength, dots);
if isempty(candidateDots)
    dotsInTube = zeros(0, 3);
    indicesInTube = zeros(0, 1);
    radialDistances = zeros(0, 1);
    maximumAlong = [];
    return
end

offsets = candidateDots - origin;
alongDistances = offsets * direction.';
radialSquared = sum(offsets .* offsets, 2) - alongDistances .^ 2;
radialSquared = max(radialSquared, 0);
isInTube = alongDistances >= 0 & alongDistances <= tubeLength & ...
    radialSquared <= tubeRadius ^ 2;

dotsInTube = candidateDots(isInTube, :);
indicesInTube = candidateIndices(isInTube);
radialDistances = sqrt(radialSquared(isInTube));
if any(isInTube)
    maximumAlong = max(alongDistances(isInTube));
else
    maximumAlong = [];
end
end
