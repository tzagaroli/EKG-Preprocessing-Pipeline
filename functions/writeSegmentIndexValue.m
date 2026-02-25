function writeSegmentIndexValue(outTxt, seg)
    % Write index–value pairs to a semicolon-separated text file.
    % The index starts at 0 and each line has the format: index;value

    fid = fopen(outTxt, "w");
    if fid < 0
        error("Failed to open %s for writing", outTxt);
    end

    % Ensure the file is closed when the function exits
    cleaner = onCleanup(@() fclose(fid));

    n = numel(seg);
    for i = 1:n
        % Write zero-based index and corresponding value
        fprintf(fid, "%d;%.15g\n", i-1, seg(i));
    end
end