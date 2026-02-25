function pcb_prepare_segments(config, output_path)

    fs = config.signal.sample_frequency;
    segLen = round(fs * 10);

    inDir = fullfile(pwd, config.data.ecg_pcb_values);
    if ~isfolder(inDir)
        error("IO: ecg_pcb_values folder not found: %s", inDir);
    end

    outDir = fullfile(string(output_path), "pcb");
    if ~isfolder(outDir), mkdir(outDir); end

    files = dir(fullfile(inDir, "ECG_*.txt"));
    if isempty(files)
        warning("No ECG_*.txt files found in %s", inDir);
        return;
    end

    % ------------------------------------------------------------
    % Build task list and assign GLOBAL sequential numbering
    % ------------------------------------------------------------
    tasks = struct("fileIdx", {}, "i0", {}, "i1", {}, "globalID", {});
    t = 0;

    for k = 1:numel(files)
        fpath = fullfile(files(k).folder, files(k).name);
        values = readSecondColumnSemicolon_fast(fpath);

        n = numel(values);
        if n == 0, continue; end

        nSeg = ceil(n / segLen);

        for s = 1:nSeg
            i0 = (s-1)*segLen + 1;
            i1 = min(s*segLen, n);

            t = t + 1;

            tasks(t).fileIdx = k;
            tasks(t).i0 = i0;
            tasks(t).i1 = i1;
            tasks(t).globalID = t;   % global numbering
        end
    end

    if isempty(tasks)
        warning("No segments to export.");
        return;
    end

    % ------------------------------------------------------------
    % Parallel processing
    % ------------------------------------------------------------
    parfor ti = 1:numel(tasks)

        k = tasks(ti).fileIdx;
        fpath = fullfile(files(k).folder, files(k).name);

        values = readSecondColumnSemicolon_fast(fpath);
        seg = values(tasks(ti).i0 : tasks(ti).i1);

        outTxt = fullfile(outDir, sprintf("%d.txt", tasks(ti).globalID));

        writeSegmentIndexValue(outTxt, seg);
    end

    fprintf("Segments exported: %d\n", numel(tasks));
    fprintf("Values saved in:  %s\n", outDir);
end


% ============================================================
% Read "index;value" and keep only value column
% ============================================================
function values = readSecondColumnSemicolon_fast(fpath)

    fid = fopen(fpath, "r");
    if fid < 0
        error("Failed to open %s", fpath);
    end
    cleaner = onCleanup(@() fclose(fid));

    C = textscan(fid, "%*f%f", "Delimiter", ";", "CollectOutput", true);
    values = C{1};

    values = values(~isnan(values));
end


% ============================================================
% Write segment as:
% 0;value
% 1;value
% 2;value
% ...
% ============================================================
function writeSegmentIndexValue(outTxt, seg)

    fid = fopen(outTxt, "w");
    if fid < 0
        error("Failed to open %s for writing", outTxt);
    end
    cleaner = onCleanup(@() fclose(fid));

    n = numel(seg);
    for i = 1:n
        fprintf(fid, "%d;%.15g\n", i-1, seg(i));
    end
end
