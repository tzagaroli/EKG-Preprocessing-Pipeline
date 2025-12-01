%% Test reading WFDB record from PTB-XL database
fprintf('\n=== Testing WFDB Record Reading ===\n');

% Base PTB-XL folder from config.yaml
ptbRoot = config.data.raw_physionet;   % ".local\ptb-xl"

% Choose which record to read inside PTB-XL
% (adjust these three if you want a different record)
recordDbSubdir = 'records500';        % or 'records100', etc.
patientFolder  = '00000';
recordName     = '00001_hr';          % WFDB record name, no extension

% Build full record path (without .hea/.dat) for rdsamp
recordPath = fullfile(ptbRoot, recordDbSubdir, patientFolder, recordName);

fprintf('Using record path: %s\n', recordPath);

try
    % Read the WFDB record
    [signal, Fs, tm] = rdsamp(recordPath);

    fprintf('Successfully read WFDB record: %s\n', recordPath);
    fprintf('Signal dimensions: %d samples x %d leads\n', size(signal, 1), size(signal, 2));
    fprintf('Sampling frequency (file): %d Hz\n', Fs);
    fprintf('Duration: %.2f seconds\n', size(signal, 1) / Fs);

    % Optional: check against configured sampling frequency
    if isfield(config, 'signal') && isfield(config.signal, 'sample_frequency')
        cfgFs = config.signal.sample_frequency;
        fprintf('Sampling frequency (config): %d Hz\n', cfgFs);
        if ~isempty(cfgFs) && Fs ~= cfgFs
            warning('Sampling frequency in file (%g Hz) differs from config (%g Hz).', Fs, cfgFs);
        end
    end

    % Display first 5 samples of first lead
    fprintf('\nFirst 5 samples of Lead I:\n');
    disp(signal(1:5, 1));

    % Plot the first lead
    figure;
    plot(tm, signal(:, 1));
    xlabel('Time (seconds)');
    ylabel('Amplitude (mV)');
    title(sprintf('ECG Signal - Lead I (%s)', recordName));
    grid on;

catch ME
    fprintf('Error reading WFDB record "%s": %s\n', recordPath, ME.message);
end

fprintf('\n');
