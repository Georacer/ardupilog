% Reads ArduPilot's system identification dataflash logs and extracts the SID
% subsections of the fligts into .mat file, discarding all irrelevant data
%
% Usage:
% see sid_pre_config.m file
%
% Amilcar Lucas - IAV GmbH
% License: GPL v3

close all;

% read the configuration from the external, user editable configuration file
if exist('sid_pre_config.m', 'file') ~= 2
   error('sid_pre_config.m file not found');
end
sid_pre_config

% check that the user configured the source dataflash filenames
if exist('bin_log_filenames', 'var') ~= 1
   error('bin_log_filenames variable not defined');
end
if ~iscellstr(bin_log_filenames)
   error('bin_log_filenames variable is not a string cell array');
end

% load the log(s) if not done yet
if exist('bin_logs', 'var') ~= 1
    for file = 1:length(bin_log_filenames)
        bin_logs(file) = Ardupilog(char(bin_log_filenames(file)));
        if exist('bin_log_filter_msgs', 'var') == 1
            if ~iscellstr(bin_log_filter_msgs)
               error('bin_log_filter_msgs variable is not a string cell array');
            end
            bin_logs(file) = bin_logs(file).filterMsgs(bin_log_filter_msgs);
        end
        figure;
        ax = subplot(2, 1, 1);
        ax = bin_logs(file).plot('MODE/ModeNum', 'b.', ax);
        ylabel(bin_logs(file).getLabel('MODE/ModeNum'));
        title(bin_log_filenames(file));
        hold on;
        yyaxis right;
        ax = bin_logs(file).plot('SIDS/Ax', 'r*', ax);
        ylabel(bin_logs(file).getLabel('SIDS/Ax'));
        hold off;
        
        ax = subplot(2, 1, 2);
        ax = bin_logs(file).plot('SIDD/F', 'b.', ax);
        ylabel(bin_logs(file).getLabel('SIDD/F'));
        hold on;
        yyaxis right;
        TimeS = bin_logs(file).SIDS.TimeS;
        subflight = 1:length(bin_logs(file).SIDS.Ax);
        plot(TimeS, subflight, 'r*');
        ylabel('subflight');
        hold off;

        % This aids the users configuring the bin_log_sections.file and
        % bin_log_sections.subflight variables
        disp('   flight  filename');
        disp(['     '  num2str(file) '    ' char(bin_log_filenames(file))]);
        disp('subflight  SID_AXIS');
        disp([(1:length(bin_logs(file).SIDS.Ax))' bin_logs(file).SIDS.Ax])
    end
    clear file ax TimeS subflight
else
     close all;
     disp('Skiped .bin file(s) read. Using cached bin_logs workspace variable instead');
end

% check the user input
if exist('bin_log_sections', 'var') ~= 1
   error('bin_log_sections variable not defined');
end

% check the user input
if ~isfield(bin_log_sections', 'file')
   error('bin_log_sections.file variable not defined');
end

% check the user input
if ~isfield(bin_log_sections', 'subflight')
   error('bin_log_sections.subflight variable not defined');
end

% check the user input
if length(bin_log_sections.file) ~= length(bin_log_sections.subflight)
    error('length of bin_log_sections.file bin_log_sections.subflight missmatch');
end

% check the user input
if length(bin_log_sections.file) > 13
    error('length of bin_log_sections variables must not be higher than max. SID_AXIS value');
end

% slice the system identification flight subsection(s)
if exist('sid', 'var') ~= 1
    for i = 1:length(bin_log_sections.file)
        b = bin_logs(bin_log_sections.file(i)).getSlice( ...
                    [bin_logs(bin_log_sections.file(i)).SIDS.TimeUS(bin_log_sections.subflight(i))/1e6 ...
                     bin_logs(bin_log_sections.file(i)).SIDS.TimeUS(bin_log_sections.subflight(i))/1e6+bin_logs(bin_log_sections.file(i)).SIDS.TR(bin_log_sections.subflight(i))+1], ...
                    'TimeS');
        % preserve some messages that are outside of the slice time interval
        b.FMT = bin_logs(bin_log_sections.file(i)).FMT;
        b.UNIT = bin_logs(bin_log_sections.file(i)).UNIT;
        b.FMTU = bin_logs(bin_log_sections.file(i)).FMTU;
        b.MULT = bin_logs(bin_log_sections.file(i)).MULT;
        b.PARM = bin_logs(bin_log_sections.file(i)).PARM;
        % Update the number of actual included messages
        b.numMsgs = 0;
        for msgName = b.msgsContained
            msgName = char(msgName);
            b.numMsgs = b.numMsgs + length(b.(msgName).LineNo);
        end
        if save_a_mat_file_per_sid_axis
            save(['sid_' num2str(i) '.mat'], 'b');
        end
        sid(i) = b;
    end
    
    % save the result to a file for future use
    filename = 'sid.mat';
    if exist(filename, 'file')
        [filename, path] = uiputfile({'*.mat','Mat file (*.mat)';'*.*','All files (*.*)'}, 'Save File Name', filename);
    end
    if ~isempty(filename)
        save(filename, 'sid');
    end
    
    clear i filter_msgs b msgName filename path
else
     disp('Skiped subfligths slicing. Using cached sid workspace variable instead');
end
