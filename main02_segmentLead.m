% Purpose
%   Segment high-density DBS lead voxels from the postoperative CT volume.
%
% Inputs
%   data/01_ct_mat/CT_<case>.mat
%       CT              CT numbers in Hounsfield units (HU).
%
% Outputs
%   data/02_segmented_lead/CT_lead_<case>.mat
%       CT_lead         CT volume containing the retained lead components.
%
% Main processing steps
%   1. Apply the 5000 HU metal-segmentation threshold from the paper.
%   2. Label 6-connected components.
%   3. Retain slender components using their bounding-box extent ratio.
%
% Important parameters
%   metalThresholdHu    5000 HU, as reported in the paper.
%   maximumExtent       Maximum voxel-to-bounding-box ratio for a lead.
%   caseIds             Case numbers to process. Edit this value below.

clearvars

%% User setting and paper parameters
caseIds = 1;
metalThresholdHu = 5000;
maximumExtent = 0.004;

%% Repository-relative folders
scriptFolder = fileparts(mfilename('fullpath'));
repositoryFolder = fileparts(scriptFolder);
dataFolder = fullfile(repositoryFolder, 'data');
ctInputFolder = fullfile(dataFolder, '01_ct_mat');
outputFolder = fullfile(dataFolder, '02_segmented_lead');

if ~isfolder(outputFolder), mkdir(outputFolder); end

%% Segment slender high-density components
for caseId = caseIds
    inputFile = fullfile(ctInputFolder, sprintf('CT_%d.mat', caseId));
    if ~isfile(inputFile)
        error('Stage 01 output not found for case %d: %s', caseId, inputFile)
    end

    fprintf('Stage 02: segmenting case %d\n', caseId)
    inputData = load(inputFile, 'CT');
    CT = inputData.CT;

    metalMask = CT >= metalThresholdHu;
    labels = bwlabeln(metalMask, 6);
    componentTable = regionprops3(labels, 'Extent');
    if isempty(componentTable)
        error('No components were found above %g HU for case %d.', ...
            metalThresholdHu, caseId)
    end

    leadLabels = find(componentTable.Extent <= maximumExtent);
    if isempty(leadLabels)
        error(['No slender lead components were retained for case %d. ' ...
            'Check the CT range and maximumExtent.'], caseId)
    end

    leadMask = ismember(labels, leadLabels);
    CT_lead = zeros(size(CT), 'like', CT);
    CT_lead(leadMask) = CT(leadMask);

    save(fullfile(outputFolder, sprintf('CT_lead_%d.mat', caseId)), ...
        'CT_lead', 'metalThresholdHu', 'maximumExtent', '-mat');
end
