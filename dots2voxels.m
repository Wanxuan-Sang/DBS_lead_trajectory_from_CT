function [voxels, dotsSubMinimum] = dots2voxels(dotsSub)
%DOTS2VOXELS Convert point subscripts to a compact logical volume.
%   dotsSub is an N-by-3 array of voxel-grid subscripts. voxels is the
%   corresponding logical volume, and dotsSubMinimum is the coordinate
%   offset required to map volume subscripts back to the input grid.

if isempty(dotsSub) || size(dotsSub, 2) ~= 3
    error('dotsSub must be a nonempty N-by-3 array.')
end

dotsSubMinimum = min(dotsSub, [], 1);
voxelSize = ceil(max(dotsSub, [], 1)) - floor(dotsSubMinimum) + 1;
voxels = false(voxelSize);

localSubscripts = round(dotsSub - dotsSubMinimum) + 1;
linearIndices = sub2ind(voxelSize, localSubscripts(:, 1), ...
    localSubscripts(:, 2), localSubscripts(:, 3));
voxels(linearIndices) = true;
end
