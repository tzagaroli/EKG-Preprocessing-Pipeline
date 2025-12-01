%% Function to get all txt files from raw_pcb directory
function files = getRawPcbValuesFiles(config)
    % Get the raw_pcb path from config
    rawPcbValuesPath = config.data.raw_pcb_values;

    % Get all .txt files in the directory
    files = dir(fullfile(rawPcbValuesPath, '*.txt'));

    % Filter out directories (keep only files)
    files = files(~[files.isdir]);

    if isempty(files)
        warning('No .txt files found in %s', rawPcbPath);
    end
end
