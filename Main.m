clear
close all


%% Loading required tools

% Used to read a config file
addpath(genpath('third_party/yamlmatlab/yaml'));

% Used to perform delination on ECG
addpath(genpath('third_party/ECGdeli/Filtering'));
addpath(genpath('third_party/ECGdeli/ECG_Processing'));

% Custom functions path
addpath('functions\')


%% Loading config
config = ReadYaml('config.yaml');


%% Export PTB-XL records to CSV based on config.signal.sample_frequency

fprintf('\n=== Exporting PTB-XL records to CSV ===\n');

% From config
fsTarget   = config.signal.sample_frequency;   % e.g. 500
ptbRoot    = config.data.raw_physionet;        % e.g. ".local\ptb-xl"
outRoot    = config.data.output_folder;        % e.g. ".local\output"

% Choose recordsXXX directory based on sampling frequency
recordsDir = sprintf('records%d', fsTarget);   % "records500", "records100", ...
inRootRel  = fullfile(ptbRoot, recordsDir);    % relative to project root

% Output base folder: <output_folder>/ptb-xl-csv/recordsXXX
% (flat: everything directly inside recordsXXX)
outBaseRel = fullfile(outRoot, 'ptb-xl-csv', recordsDir);

% Work with absolute paths for I/O
inRootAbs  = fullfile(pwd, inRootRel);
outBaseAbs = fullfile(pwd, outBaseRel);

fprintf('Input root : %s\n', inRootAbs);
fprintf('Output root: %s\n', outBaseAbs);

if ~exist(inRootAbs, 'dir')
    error('Input directory does not exist: %s', inRootAbs);
end

% Ensure flat output directory exists
if ~exist(outBaseAbs, 'dir')
    mkdir(outBaseAbs);
end

% Find all WFDB header files recursively (requires R2016b+ for "**")
heaFiles = dir(fullfile(inRootAbs, '**', '*.hea'));
fprintf('Found %d header files (.hea) under %s\n', numel(heaFiles), inRootAbs);

numSkipped = 0;
numWritten = 0;

for k = 1:numel(heaFiles)
    heaFolder = heaFiles(k).folder;          % absolute: ...\records500\00000
    heaName   = heaFiles(k).name;            % e.g. "00001_hr.hea"
    [~, recName, ~] = fileparts(heaName);    % "00001_hr"

    %% --- Build relative folder structure under inRootAbs (only for reading) ---
    if startsWith(heaFolder, inRootAbs)
        relFolder = heaFolder(numel(inRootAbs)+1:end);   % strip root prefix
    else
        warning('Folder "%s" is not under root "%s". Using no relative folder.', ...
            heaFolder, inRootAbs);
        relFolder = '';
    end

    % Remove leading file separator if present
    if ~isempty(relFolder) && startsWith(relFolder, filesep)
        relFolder = relFolder(2:end);
    end

    %% --- Output path (FLAT) ---
    % All CSVs go directly into outBaseAbs/recordsXXX, no subfolders.
    outDirAbs = outBaseAbs;
    outFile   = fullfile(outDirAbs, [recName '.csv']);

    % If CSV already exists, skip
    if exist(outFile, 'file')
        numSkipped = numSkipped + 1;
        fprintf('[%5d/%5d] Skipping existing: %s\n', k, numel(heaFiles), outFile);
        continue;
    end

    %% --- Record path for rdsamp (RELATIVE, as WFDB expects) ---
    % inRootRel is like ".local\ptb-xl\records500"
    if isempty(relFolder)
        recPathNoExt = fullfile(inRootRel, recName);
    else
        recPathNoExt = fullfile(inRootRel, relFolder, recName);
    end

    fprintf('[%5d/%5d] Processing: %s -> %s\n', ...
        k, numel(heaFiles), recPathNoExt, outFile);

    % Optional: sanity check that the header file is reachable via this relative path
    if ~exist([recPathNoExt '.hea'], 'file')
        warning('Header file not found for record path (relative): %s', [recPathNoExt '.hea']);
        continue;
    end

    try
        %% Read WFDB record using the RELATIVE record path
        [signal, Fs, ~] = rdsamp(recPathNoExt);

        % Sanity check sampling frequency against config
        if Fs ~= fsTarget
            warning('Record %s has Fs=%g Hz (config expects %g Hz).', ...
                recPathNoExt, Fs, fsTarget);
        end

        %% Build header names like LeadI;LeadII;...
        nLeads = size(signal, 2);

        % Standard 12-lead names if applicable
        standardNames = { ...
            'LeadI', 'LeadII', 'LeadIII', ...
            'LeadaVR', 'LeadaVL', 'LeadaVF', ...
            'LeadV1', 'LeadV2', 'LeadV3', 'LeadV4', 'LeadV5', 'LeadV6'};

        if nLeads <= numel(standardNames)
            varNames = standardNames(1:nLeads);
        else
            % More than 12 leads: pad with generic names
            varNames = standardNames;
            for j = (numel(standardNames)+1):nLeads
                varNames{j} = sprintf('Lead%d', j);
            end
        end

        %% Wrap into table so we can write header + data easily
        T = array2table(signal, 'VariableNames', varNames);

        %% Write CSV with semicolon delimiter
        writetable(T, outFile, 'Delimiter', ';');

        numWritten = numWritten + 1;

    catch ME
        warning('Error processing record %s: %s', recPathNoExt, ME.message);
        continue;
    end
end

fprintf('\nExport complete.\n');
fprintf('Total header files: %d\n', numel(heaFiles));
fprintf('Written CSV files : %d\n', numWritten);
fprintf('Skipped (existing): %d\n', numSkipped);
fprintf('CSV files are in  : %s\n\n', outBaseAbs);
