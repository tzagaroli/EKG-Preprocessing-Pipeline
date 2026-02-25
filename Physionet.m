function [] = Physionet(config, output_path)
%PHYSIONET Function to read and annotate physionet dataset
    fs = config.signal.sample_frequency;

    % Get path to physionet DB (with sample frequency)
    if fs == 500
        physionet_db_path = fullfile(pwd, config.data.physionet_db, "records500/");
    elseif fs == 100
        physionet_db_path = fullfile(pwd, config.data.physionet_db, "records100/");
    else
        error("Config: sample frequency isn't supported.");
    end
    
    if ~isfolder(physionet_db_path)
        error("IO: Path to Physionet DB isn't correct.")
    end

    physionetOutDir = fullfile(string(output_path), "ptb-xl");
    if ~isfolder(physionetOutDir)
        mkdir(physionetOutDir);
    end

    physionetRecords = getPhysionetRecords(physionet_db_path);
    % Read all records (no processing)
    oldPwd = pwd;
    cleanupObj = onCleanup(@() cd(oldPwd));
    
    cd(physionet_db_path);  % Ensure WFDB '.' search path points here
    
    physionetRecords(12691) = [];
    
    parfor k = 1:numel(physionetRecords)
        rec = char(physionetRecords(k));   % WFDB record name, e.g. '00000\00001_hr'
        try
            [signal, Fs, ~] = rdsamp(rec);  % Read full record
        catch ME
            warning("WFDB:ReadFailed", "Failed to read %s (%s)", rec, ME.message);
            continue
        end
    
        signal_filtered = ecgFilter(signal, Fs);
        [FPT_MultiChannel,~]=Annotate_ECG_Multi(signal_filtered,Fs);
    
        A = CreateOutputArray(signal_filtered, FPT_MultiChannel);
        T = array2table(A, 'VariableNames', ...
            ["I","II","III","AVR","AVL","AVF", ...
            "V1","V2","V3","V4","V5","V6", ...
            "P-wave","P-peak","QRS-complex","R-peak","T-wave","T-peak"] ...
        );
    
        % Save the table
        outFile = fullfile(physionetOutDir, sprintf("%d.csv", k));
    
        % Write CSV
        writetable(T, outFile);
    end
end
