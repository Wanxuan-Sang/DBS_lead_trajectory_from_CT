% reads CT data in .nii or .nii.gz format and saves it as .mat files, including CT values and transformation matrices.

%%
% Define global variables for project folders
global project_folder data_folder code_folder
project_folder = ""; % Set the base project folder path
data_folder = project_folder + "\data"; % Set the data folder path
code_folder = project_folder + "\code"; % Set the code folder path

% Change the current directory to the code folder
cd(code_folder);
% Add the code and data folders to the MATLAB path
addpath(genpath(code_folder), genpath(data_folder));
% Display the data folder path
disp(data_folder)

% Define the folder paths for the CT nii data and the save folder for mat files
file_folder = ""; % Set the path to the CT nii data
save_folder = [data_folder + "\1--CT--mat\"; % Set the path to save CT mat data
               data_folder + "\1--transform--mat\"];
% Create the save folders if they do not exist
arrayfun(@mkdir, save_folder);

%%
for num = 1:3
    % Construct the file name
    file_name = "CT_" + num + ".nii.gz";
    file = file_folder + file_name;

    % ----- Read nii file and save as mat -----
    % Get the information about the nii file
    info = niftiinfo(file);
    % Read the CT data and apply scaling and offset
    CT = single(niftiread(file)) * info.MultiplicativeScaling + info.AdditiveOffset; % Obtain CT values
    transform = info.Transform; % Get the transformation matrix
    
    % Save the CT data as a .mat file
    save(save_folder(1) + "CT_" + num + ".mat", "CT", '-mat'); % e.g. "CT_1.mat"
    % Save the transformation matrix as a .mat file
    save(save_folder(2) + "transform_" + num + ".mat", "transform", '-mat'); % e.g. "transform_1.mat"
end