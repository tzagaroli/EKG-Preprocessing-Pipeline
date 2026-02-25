function values = readSecondColumnSemicolon_fast(fpath)
    % Read the second numeric column from a semicolon-separated file.
    % Returns a column vector with NaN values removed.

    fid = fopen(fpath, "r");
    if fid < 0
        error("Failed to open %s", fpath);
    end

    % Ensure the file is closed when the function exits
    cleaner = onCleanup(@() fclose(fid));

    % Skip first column (%*f), read second column (%f)
    C = textscan(fid, "%*f%f", "Delimiter", ";", "CollectOutput", true);

    values = C{1};

    % Remove NaN entries
    values = values(~isnan(values));
end