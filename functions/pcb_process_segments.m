function pcb_process_segments(config, output_path)
    fs = config.signal.sample_frequency;

    pcbDir = fullfile(string(output_path), "pcb");
    if ~isfolder(pcbDir)
        error("PCB folder not found: %s. Run the segment export step first.", pcbDir);
    end

    % Input segments: numeric filenames 1.txt, 2.txt, ...
    segFiles = dir(fullfile(pcbDir, "*.txt"));
    if isempty(segFiles)
        warning("No segment .txt files found in %s", pcbDir);
        return;
    end

    % Keep only numeric filenames and sort
    stems = erase(string({segFiles.name}), ".txt");
    isNum = ~isnan(str2double(stems));
    segFiles = segFiles(isNum);

    if isempty(segFiles)
        warning("No numerically named segment files found in %s", pcbDir);
        return;
    end

    ids = arrayfun(@(d) str2double(erase(d.name, ".txt")), segFiles);
    [idsSorted, order] = sort(ids);
    segFiles = segFiles(order);

    % ------------------------------------------------------------
    % Parallel processing: read -> process -> write csv -> delete txt
    % ------------------------------------------------------------
    parfor ii = 1:numel(segFiles)

        id = idsSorted(ii);
        inTxt = fullfile(segFiles(ii).folder, segFiles(ii).name);
        outCsv = fullfile(pcbDir, sprintf("%d.csv", id));

        try
            % Read segment values
            seg = readSecondColumnSemicolon_fast(inTxt);

            % Filter
            seg_filtered = ecgFilter(seg, fs);

            % Annotation (duplicate channel)
            sigForAnnot = [seg_filtered, seg_filtered];
            [FPT_MultiChannel, ~] = Annotate_ECG_Multi(sigForAnnot, fs);

            % Build output table
            A = CreateOutputArray(seg, FPT_MultiChannel);
            T = array2table(A, 'VariableNames', ...
                ["V5", ...
                 "P-wave","P-peak","QRS-complex","R-peak","T-wave","T-peak"] ...
            );

            % Write CSV
            writetable(T, outCsv);

            % Delete source segment AFTER successful write
            if isfile(inTxt)
                delete(inTxt);
            end

        catch ME
            % Do not crash the entire parfor, just report
            warning("Failed processing segment %d: %s", id, ME.message);
        end
    end

    fprintf("PCB segments processed -> %s\n", pcbDir);
end
