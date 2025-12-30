function ts = getTimestampYYMMDD_HHMM()
%GETTIMESTAMPYYMMDD_HHMM Return current timestamp as "YYMMDD_HHMM"

    ts = datetime("now", "Format", "yyMMdd_HHmm");
    ts = string(ts);
end
