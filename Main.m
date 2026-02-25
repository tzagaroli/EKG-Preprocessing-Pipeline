clear
close all

%% Loading tools

% Used to read a config file
addpath(genpath('third_party/yamlmatlab/yaml'));

% Used to perform delination on ECG
addpath(genpath('third_party/ECGdeli/Filtering'));
addpath(genpath('third_party/ECGdeli/ECG_Processing'));

% Custom functions path
addpath('functions\')

%% Load config
config = ReadYaml('config.yaml');

% Ask the user to select the action
disp("===========================================================================")
disp("                         EKG-Prepocessing-Pipeline                         ")
disp("===========================================================================")
disp("")
disp("Select an action:");
disp("  1) Build PhysioNet dataset");
disp("  2) Build Platine ECG dataset");
disp("  3) Build both datasets");
disp("  0) Exit");

% Read answer
while true
    % Input as string
    choiceStr = input("Your choice: ", 's');
    
    % If string is empty -> Ask again
    if isempty(choiceStr)
        disp("Empty input. Try again.")
        disp(" ")
        continue
    end
    
    % Convert string to double
    choice = str2double(choiceStr);
    
    % If Not a Number -> Ask again
    if isnan(choice)
        disp("Please enter a number.")
        continue
    end
    
    % If outside of range -> Ask again
    if ismember(choice,[0 1 2 3])
        disp(" ")
        break
    else
        disp("Invalid choice. Enter 0, 1, 2 or 3.")
    end
end

% If choice "Exit" -> End the program
if (choice == 0)
    return
end

% Check for valid output path
output_path = fullfile(pwd, config.data.output_folder, getTimestampYYMMDD_HHMM());
if ~isfolder(output_path)
    mkdir(output_path);
end

tic

if (choice == 1)
    Physionet(config, output_path)
elseif(choice == 2)
    EKG_Platine(config, output_path)
else % choice == 3
    Physionet(config, output_path)
    EKG_Platine(config, output_path)
end

elapsedTime = toc;
fprintf("Total execution time: %.2f seconds\n", elapsedTime);
