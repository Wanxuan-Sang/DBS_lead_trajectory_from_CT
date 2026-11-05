function [dotsInRange, indicesInRange] = findDotsInRange(dotMinimum, ...
    dotMaximum, dots)
%FINDDOTSINRANGE Select points inside an axis-aligned three-dimensional box.
%   dotMinimum and dotMaximum are 1-by-3 bounds in the same units as the
%   N-by-3 array dots. dotsInRange contains the selected points and
%   indicesInRange contains their row indices in dots.

isInRange = all(dots >= dotMinimum, 2) & all(dots <= dotMaximum, 2);
dotsInRange = dots(isInRange, :);
indicesInRange = find(isInRange);
end
