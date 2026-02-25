function [signal] = ecgFilter(signal, Fs)
    %% filtering of the 12-lead ECG
    % Remove baseline wander
    % usage: [filtered_signal,baseline]=ECG_Baseline_Removal(signal,samplerate,window_length,overlap)
    [signal,~] = ECG_Baseline_Removal(signal,Fs,1,0.5);

    % filter noise frequencies
    [signal] = ECG_High_Low_Filter(signal,Fs,1,70);
    signal=Notch_Filter(signal,Fs,50,1);

    % isoline correction
    % usage: [filteredsignal,offset,frequency_matrix,bins_matrix]=Isoline_Correction(signal,varargin)
    [signal,~,~,~]=Isoline_Correction(signal);
end

