% Reads ArduPilot's system identification dataflash logs and extracts the SID
% subsections of the fligts into .mat file, discarding all irrelevant data
%
% Usage:
% 1. Edit the bin_log_filenames variable on this file and save the file
% 2. run the sid_pre script in matlab
% 3. change the bin_log_filter_msgs and save_a_mat_file_per_sid_axis variables on this file acoording to your needs
% 4. use the output of that script to edit the bin_log_sections variable in this file and save it
% 5. run the sid_pre script in matlab a second time
%
% Amilcar Lucas - IAV GmbH
% License: GPL v3

% Define ArduCopter's system identification flights' dataflash logs
% filenames
% This can be one or more files
bin_log_filenames = { ...
    '2021-05-11 15-00-20.bin', ...
    '2021-05-11 15-16-14.bin', ...
    '2021-05-11 15-32-49.bin', ...
};

% this defines the source of each one of the 13 SID_AXIS subflights
% first  element is the bin_log_file index and the SID subflight of the SID_AXIS 1
% second element is the bin_log_file index and the SID subflight of the SID_AXIS 2
% third  element is the bin_log_file index and the SID subflight of the SID_AXIS 3
% ...
bin_log_sections.file      = [1, 1, 1,  1, 2, 2,  2,  2, 3, 3, 3, 3, 3];
bin_log_sections.subflight = [3, 8, 9, 11, 1, 2, 10, 11, 1, 4, 7, 8, 9];

% a list of messages to preserve
% comment this out if you want to preserve all messages
bin_log_filter_msgs = {'FMT', 'UNIT', 'FMTU', 'MULT', 'PARM', 'MODE', 'SIDD', 'SIDS', 'ATT', 'CTRL', 'RATE', 'PIDR', 'PIDP', 'PIDY', 'PIDA'};

save_a_mat_file_per_sid_axis = 0;