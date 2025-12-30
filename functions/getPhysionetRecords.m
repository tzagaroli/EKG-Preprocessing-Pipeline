function records = getPhysionetRecords(rootPath)
%GETPHYSIONETRECORDS Return WFDB record names (ready for rdsamp)

    arguments
        rootPath (1,1) string
    end

    if ~isfolder(rootPath)
        error("PhysioNet:InvalidPath", "Invalid PhysioNet root path: %s", rootPath);
    end

    % Normalize root path (remove trailing file separators)
    rootPath = strip(rootPath, "right", filesep);

    d = dir(fullfile(rootPath, "**", "*_hr.dat"));
    if isempty(d)
        warning("PhysioNet:NoDatFiles", "No *_hr.dat files found under: %s", rootPath);
        records = strings(0,1);
        return
    end

    datFiles = string(fullfile({d.folder}, {d.name}));
    datFiles = datFiles(:);

    % Build relative paths and remove extension -> WFDB record name
    rel = extractAfter(datFiles, rootPath);
    rel = strip(rel, "left", filesep);   % remove leading "\" or "/"
    records = erase(rel, ".dat");
end
