% Plots ArduPilot's system identification results
%
% Usage:
% see sid_plot_config.m file
%
% Amilcar Lucas - IAV GmbH
% License: GPL v3

close all;
%set(0, 'defaultFigureUnits', 'centimeters', 'defaultFigurePosition', [0 0 27 24]);

% read the configuration from the external, user editable configuration file
if exist('sid_plot_config.m', 'file') ~= 2
   error('sid_plot_config.m file not found');
end
sid_plot_config

% check the user input
if exist('plot_all_3_axis', 'var') ~= 1
   error('plot_all_3_axis variable not defined');
end

% check the user input
if exist('sid_axis', 'var') ~= 1
   error('sid_axis variable not defined');
end

if isscalar(sid_axis)
    if sid_axis < 0
        error('sid_axis variable must not be negative');
    end

    if sid_axis > 13
        error('sid_axis variable must not be bigger than 13');
    end
else
    if find(sid_axis < 0)
        error('sid_axis variable must not be negative');
    end

    if find(sid_axis > 13)
        error('sid_axis variable must not be bigger than 13');
    end
end

% load the log(s) if not done yet
if exist('sid', 'var') ~= 1
    if isscalar(sid_axis)
        if sid_axis == 0
            load('sid.mat');
        else
            load(['sid_' num2str(sid_axis) '.mat']);
            sid = b;
            clear b;
        end
    else
        for i = sid_axis
            load(['sid_' num2str(i) '.mat']);
            sid(i) = b;
        end
        clear b i;
    end
else
    disp('Skiped .mat file(s) read. Using cached sid workspace variable instead');
end

run_analisys(sid, 7, Ts, 'RLL')
return

if isscalar(sid_axis)
    if sid_axis == 0
        for i = 1:length(sid)
            % create a transfer function model
            tf{i} = tfest(id{i}, 3, 3);
            
            % create a Hammerstein-Wiener model
            hw{i} = nlhw(id{i}, [2 3 1]);

            % compare the validation data of the TF-Model and the HM-Model
            figure();
            compare(id{i}, tf{i}, hw{i})
        end
    else
        if isscalar(id)
            % create a transfer function model
            tf = tfest(id, 3, 3);
            
            % create a Hammerstein-Wiener model
            hw = nlhw(id, [2 3 1]);

            % compare the validation data of the TF-Model and the HM-Model
            figure();
            compare(id, tf, hw)
        else
            % create a transfer function model
            tf{sid_axis} = tfest(id{sid_axis}, 3, 3);
            
            % create a Hammerstein-Wiener model
            hw{sid_axis} = nlhw(id{sid_axis}, [2 3 1]);

            % compare the validation data of the TF-Model and the HM-Model
            figure();
            compare(id{sid_axis}, tf{sid_axis}, hw{sid_axis})
        end
    end
else
    for i = sid_axis
            % create a transfer function model
            tf{i} = tfest(id{i}, 3, 3);
            
            % create a Hammerstein-Wiener model
            hw{i} = nlhw(id{i}, [2 3 1]);

            % compare the validation data of the TF-Model and the HM-Model
            figure();
            compare(id{i}, tf{i}, hw{i})
    end
end

function run_analisys(sid, sid_axis, Ts, axis_str)
    switch(sid_axis)
        case {1, 4, 10}
        case {2, 5, 8, 11}
        case {3, 6, 9, 12}
        case {13}
        case {7}
            params = cellstr(sid(1, 7).PARM.Name);
            idd = iddata(sid(sid_axis).PIDR.Tar, sid(sid_axis).SIDD.Targ, Ts, ...
            'Name', [ axis_str ' RATE ctrl. FLTT SYS ID'], ...
            'InputName', 'SIDD.Targ', ...
            'OutputName', 'PIDR.Tar', ...
            'InputUnit', 'deg/s', ...
            'OutputUnit', 'deg/s');
            tf_fltt = tfest(idd, 2, 0);
            compare(idd, tf_fltt)
            Kp = sid(1, 7).PARM.Value(find(strcmp(params, 'ATC_RAT_RLL_P')));
            Ki = sid(1, 7).PARM.Value(find(strcmp(params, 'ATC_RAT_RLL_I')));
            Kd = sid(1, 7).PARM.Value(find(strcmp(params, 'ATC_RAT_RLL_D')));
            Tf_1 = sid(1, 7).PARM.Value(find(strcmp(params, 'ATC_RAT_RLL_FLTD')));
            sys = pid(Kp, Ki, Kd, 1/Tf_1, Ts);
            figure
            ax = subplot(2, 1, 1)
            sid(7).plot('RATE/ROut', 'g.', ax);            
            subplot(2, 1, 2)
            lsim(sys, sid(sid_axis).PIDR.Err, []);
    end
end
