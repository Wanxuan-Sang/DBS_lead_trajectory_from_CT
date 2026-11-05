function [skeletonPoints, endpoints] = getSkeletonEndpoints(dotsSub, transform)
%GETSKELETONENDPOINTS Extract lead skeleton points and terminal points.
%   dotsSub is an N-by-3 array in the upsampled voxel grid and transform is
%   the NIfTI voxel-to-world transform. skeletonPoints and endpoints are
%   returned as physical coordinates in mm. Cuboid morphology and branch
%   pruning reproduce the endpoint-detection stage of the original method.

[leadVoxels, dotsSubMinimum] = dots2voxels(dotsSub);

leadVoxels = imdilate(leadVoxels, strel('cuboid', [20, 20, 20]));
leadVoxels = imerode(leadVoxels, strel('cuboid', [10, 10, 10]));

skeletonVolume = bwskel(leadVoxels, 'MinBranchLength', 50);
endpointVolume = false(size(skeletonVolume));
endpointCount = 0;
for pass = 1:3
    if pass > 1
        skeletonVolume = imfill(skeletonVolume, 'holes');
        minimumBranchLength = 50;
        if pass == 3
            minimumBranchLength = 100;
        end
        skeletonVolume = bwskel(skeletonVolume, ...
            'MinBranchLength', minimumBranchLength);
    end

    endpointVolume = bwmorph3(skeletonVolume, 'endpoints');
    endpointCount = nnz(endpointVolume);
    if endpointCount == 2 || endpointCount == 3
        break
    end
    if endpointCount < 2
        error('Skeletonization produced fewer than two endpoints.')
    end
end
if endpointCount > 3
    error('Skeletonization produced more than three endpoints after pruning.')
end

skeletonSub = logicalVolumeSubscripts(skeletonVolume, dotsSubMinimum);
endpointSub = logicalVolumeSubscripts(endpointVolume, dotsSubMinimum);
skeletonPoints = transformPointsForward(transform, skeletonSub - 1);
endpoints = transformPointsForward(transform, endpointSub - 1);
end

function points = logicalVolumeSubscripts(volume, coordinateOffset)
[rowSub, columnSub, sliceSub] = ind2sub(size(volume), find(volume));
points = [rowSub, columnSub, sliceSub] - 1 + coordinateOffset;
end
