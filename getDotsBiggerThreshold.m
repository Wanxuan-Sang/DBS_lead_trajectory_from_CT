function dotsSub = getDotsBiggerThreshold(data, threshold)
%GETDOTSBIGGERTHRESHOLD Return subscripts whose values exceed a threshold.
%   data is a three-dimensional numeric array and threshold has the same
%   units as data. dotsSub is an N-by-3 array of one-based MATLAB
%   subscripts ordered as [row, column, slice].

[rowSub, columnSub, sliceSub] = ind2sub(size(data), find(data > threshold));
dotsSub = [rowSub, columnSub, sliceSub];
end
