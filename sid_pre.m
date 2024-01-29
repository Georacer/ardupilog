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
        if ~issorted(bin_logs(file).MODE.TimeS, 'strictascend')
            disp([char(bin_log_filenames(file)) ' MODE.TimeS is not monotonic!'])
        end
        title(bin_log_filenames(file));
        hold on;
        yyaxis right;
        ax = bin_logs(file).plot('SIDS/Ax', 'r*', ax);
        ylabel(bin_logs(file).getLabel('SIDS/Ax'));
        if ~issorted(bin_logs(file).SIDS.TimeS, 'strictascend')
            disp([char(bin_log_filenames(file)) ' SIDS.TimeS is not monotonic!'])
            xlim([min(bin_logs(file).MODE.TimeS) max(bin_logs(file).MODE.TimeS)]);
        end
        hold off;

        ax = subplot(2, 1, 2);
        ax = bin_logs(file).plot('SIDD/F', 'b.', ax);
        ylabel(bin_logs(file).getLabel('SIDD/F'));
        if ~issorted(bin_logs(file).SIDD.TimeS, 'strictascend')
            disp([char(bin_log_filenames(file)) ' SIDD.TimeS is not monotonic!'])
        end
        hold on;
        yyaxis right;
        TimeS = bin_logs(file).SIDS.TimeS;
        subflight = 1:length(bin_logs(file).SIDS.Ax);
        plot(TimeS, subflight, 'r*');
        ylabel('subflight');
        if ~issorted(bin_logs(file).SIDS.TimeS, 'strictascend')
            disp([char(bin_log_filenames(file)) ' SIDS.TimeS is not monotonic!'])
            xlim([min(bin_logs(file).MODE.TimeS) max(bin_logs(file).MODE.TimeS)]);
        end
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
    id = cell(length(bin_log_sections.file), 1);
    for i = 1:length(bin_log_sections.file)
        log = bin_logs(bin_log_sections.file(i)).getSlice( ...
                    [bin_logs(bin_log_sections.file(i)).SIDS.TimeUS(bin_log_sections.subflight(i))/1e6 ...
                     bin_logs(bin_log_sections.file(i)).SIDS.TimeUS(bin_log_sections.subflight(i))/1e6+bin_logs(bin_log_sections.file(i)).SIDS.TR(bin_log_sections.subflight(i))+1], ...
                    'TimeS');
        % preserve some messages that are outside of the slice time interval
        log.FMT = bin_logs(bin_log_sections.file(i)).FMT;
        log.UNIT = bin_logs(bin_log_sections.file(i)).UNIT;
        log.FMTU = bin_logs(bin_log_sections.file(i)).FMTU;
        log.MULT = bin_logs(bin_log_sections.file(i)).MULT;
        log.PARM = bin_logs(bin_log_sections.file(i)).PARM;
        % Update the number of actual included messages
        log.numMsgs = 0;
        for msg = log.msgsContained
            msgName = char(msg);
            log.numMsgs = log.numMsgs + length(log.(msgName).LineNo);
        end
        
        % https://de.mathworks.com/help/ident/ug/representing-time-and-frequency-domain-data-using-iddata-objects.html
        in_dat = log.SIDD.Targ;
        out_dat = out_data(log, i);
        len = min(length(in_dat), length(out_dat));
        if len ~= length(in_dat)
            disp(['sorry, had to truncate SID in data on ' sid_axis_desc(i)]);
        end
        if len ~= length(out_dat)
            disp(['sorry, had to truncate SID out data on ' sid_axis_desc(i)]);
        end
        delta_T = log.SIDD.Time(2:len)-log.SIDD.Time(1:len-1);
        Ts = mean(delta_T);
        %plot(delta_T);
        idd = iddata(out_dat(1:len), log.SIDD.Targ(1:len), Ts, ...
            'Name', sid_axis_desc(i), ...
            'InputName', input_name(i), ...
            'OutputName', output_name(i), ...
            'InputUnit', input_unit(i), ...
            'OutputUnit', output_unit(i));
            % 'SamplingInstants', log.SIDD.Time(1:len), ...

        if save_a_mat_file_per_sid_axis
            save(['sid_' num2str(i) '.mat'], 'log', 'idd', 'Ts');
        end
        sid(i) = log;
        id{i} = idd;
    end
    
    % save the result to a file for future use
    filename = 'sid.mat';
    if exist(filename, 'file')
        [filename, path] = uiputfile({'*.mat','Mat file (*.mat)';'*.*','All files (*.*)'}, 'Save File Name', filename);
    end
    if filename ~= 0
        save(filename, 'sid', 'id', 'Ts');
    end
    
    clear i filter_msgs log msg msgName filename path in_dat out_dat len idd delta_T
else
     disp('Skiped subfligths slicing. Using cached sid workspace variable instead');
end

function in_dat = in_data(obj, sid_axis)
    switch(sid_axis)
        case 1
            in_dat = obj.SIDD.Targ;
        case 2
            in_dat = obj.SIDD.Targ;
        case 3
            in_dat = obj.SIDD.Targ;
        case 4
            in_dat = obj.SIDD.Targ;
        case 5
            in_dat = obj.SIDD.Targ;
        case 6
            in_dat = obj.SIDD.Targ;
        case 7
            in_dat = obj.SIDD.Targ;
        case 8
            in_dat = obj.SIDD.Targ;
        case 9
            in_dat = obj.SIDD.Targ;
        case 10
            in_dat = obj.SIDD.Targ;
        case 11
            in_dat = obj.SIDD.Targ;
        case 12
            in_dat = obj.SIDD.Targ;
        case 13
            in_dat = obj.SIDD.Targ;
    end
end

function out_dat = out_data(obj, sid_axis)
    switch(sid_axis)
        case 1
            out_dat = obj.ATT.Roll;
        case 2
            out_dat = obj.ATT.Pitch;
        case 3
            out_dat = obj.ATT.Yaw;
        case 4
            out_dat = obj.ATT.Roll;
        case 5
            out_dat = obj.ATT.Pitch;
        case 6
            out_dat = obj.ATT.Yaw;
        case 7
            out_dat = obj.RATE.R;
        case 8
            out_dat = obj.RATE.P;
        case 9
            out_dat = obj.RATE.Y;
        case 10
            out_dat = obj.PIDR.Act;
        case 11
            out_dat = obj.PIDP.Act;
        case 12
            out_dat = obj.PIDY.Act;
        case 13
            out_dat = obj.PIDA.Act;
    end
end

function in_nam = input_name(sid_axis)
    switch(sid_axis)
        case 1
            in_nam = 'SIDD.Targ';
        case 2
            in_nam = 'SIDD.Targ';
        case 3
            in_nam = 'SIDD.Targ';
        case 4
            in_nam = 'SIDD.Targ';
        case 5
            in_nam = 'SIDD.Targ';
        case 6
            in_nam = 'SIDD.Targ';
        case 7
            in_nam = 'SIDD.Targ';
        case 8
            in_nam = 'SIDD.Targ';
        case 9
            in_nam = 'SIDD.Targ';
        case 10
            in_nam = 'SIDD.Targ';
        case 11
            in_nam = 'SIDD.Targ';
        case 12
            in_nam = 'SIDD.Targ';
        case 13
            in_nam = 'SIDD.Targ';
    end
end

function out_nam = output_name(sid_axis)
    switch(sid_axis)
        case 1
            out_nam = 'ATT.Roll';
        case 2
            out_nam = 'ATT.Pitch';
        case 3
            out_nam = 'ATT.Yaw';
        case 4
            out_nam = 'ATT.Roll';
        case 5
            out_nam = 'ATT.Pitch';
        case 6
            out_nam = 'ATT.Yaw';
        case 7
            out_nam = 'RATE.R';
        case 8
            out_nam = 'RATE.P';
        case 9
            out_nam = 'RATE.Y';
        case 10
            out_nam = 'PIDR.Act';
        case 11
            out_nam = 'PIDP.Act';
        case 12
            out_nam = 'PIDY.Act';
        case 13
            out_nam = 'PIDA.Act';
    end
end

function desc = sid_axis_desc(sid_axis)
    switch(sid_axis)
        case 1
            desc = 'Input roll angle';
        case 2
            desc = 'Input pitch angle';
        case 3
            desc = 'Input yaw angle';
        case 4
            desc = 'Recovery (FF=0) roll angle';
        case 5
            desc = 'Recovery (FF=0) pitch angle';
        case 6
            desc = 'Recovery (FF=0) yaw angle';
        case 7
            desc = 'Rate roll';
        case 8
            desc = 'Rate pitch';
        case 9
            desc = 'Rate yaw';
        case 10
            desc = 'Mixer roll';
        case 11
            desc = 'Mixer pitch';
        case 12
            desc = 'Mixer yaw';
        case 13
            desc = 'Mixer thrust';
    end
end

function desc = input_unit(sid_axis)
    switch(sid_axis)
        case {1, 2, 3, 4, 5, 6}
            desc = '°';
        case {7, 8, 9}
            desc = '°/s';
        case {10, 11, 12, 13}
            desc = ' ';
    end
end

function desc = output_unit(sid_axis)
    switch(sid_axis)
        case {1, 2, 3, 4, 5, 6}
            desc = '°';
        case {7, 8, 9}
            desc = '°/s';
        case {10, 11, 12, 13}
            desc = ' ';
    end
end
