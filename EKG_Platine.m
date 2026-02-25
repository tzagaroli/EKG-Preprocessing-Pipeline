function [] = EKG_Platine(config, output_path)
%EKG_PLATINE Function to read and annotate pcb dataset

    pcb_prepare_segments(config, output_path);
    pcb_process_segments(config, output_path);
end