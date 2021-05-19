% Plots ArduPilot's system identification results
%
% Usage:
% see sid_plot_config.m file
%
% Amilcar Lucas - IAV GmbH
% License: GPL v3

close all;

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

if sid_axis < 0
   error('sid_axis variable must not be negative');
end

if sid_axis > 13
   error('sid_axis variable must not be bigger than 13');
end

% load the log(s) if not done yet
if exist('sid', 'var') ~= 1
    if sid_axis == 0
        load('sid.mat');
    else
        load(['sid_' num2str(sid_axis) '.mat']);
        sid = b;
        clear b;
    end
else
    disp('Skiped .mat file(s) read. Using cached sid workspace variable instead');
end

if sid_axis == 0
    for i = 1:length(sid)
        plot_sid(sid(i), i, plot_all_3_axis); % plot all
    end
else
    if isscalar(sid)
        plot_sid(sid, sid_axis, plot_all_3_axis); % plot just one
    else
        plot_sid(sid(sid_axis), sid_axis, plot_all_3_axis); % plot just one
    end
end
    
function plot_sid(obj, sid_ax, plot_all_3_axis)
    figure;
    
    % plot the input signal and frequency
    ax = subplot(4,1,1);
    ax = obj.plot('SIDD/Targ', 'b-', ax);
    ylabel(obj.getLabel('SIDD/Targ'));
    title(['SID\_AXIS ' num2str(sid_ax) ' - ' sid_axis_desc(sid_ax)]);
    yyaxis right
    obj.plot('SIDD/F', 'r-', ax);
    ylabel(obj.getLabel('SIDD/F'));
    
    % plot the output signals
    yyaxis left
    ax = subplot(4,1,2);
    if plot_all_3_axis
        obj.plot('SIDD/Gx', 'r-', ax);
        ylabel([obj.getLabel('SIDD/Gx') obj.getLabel('SIDD/Gy') obj.getLabel('SIDD/Gz')]);
        hold on;
        obj.plot('SIDD/Gy', 'g-', ax);
        obj.plot('SIDD/Gz', 'b-', ax);
        hold off;
        legend('Gx', 'Gy', 'Gz');
    else
        plot_att(obj, ax, sid_ax);
    end
    
    ax = subplot(4,1,3);
    if plot_all_3_axis
        obj.plot('SIDD/Ax', 'r-', ax);
        ylabel([obj.getLabel('SIDD/Ax') obj.getLabel('SIDD/Ay') obj.getLabel('SIDD/Az')]);
        hold on;
        obj.plot('SIDD/Ay', 'g-', ax);
        obj.plot('SIDD/Az', 'b-', ax);
        hold off;
        legend('Ax', 'Ay', 'Az');
    else
        plot_rate(obj, ax, sid_ax);
    end
    
    ax = subplot(4,1,4);
    if plot_all_3_axis
        obj.plot('SIDD/Ax', 'r-', ax);
        ylabel([obj.getLabel('SIDD/Ax') obj.getLabel('SIDD/Ay') obj.getLabel('SIDD/Az')]);
        hold on;
        obj.plot('SIDD/Ay', 'g-', ax);
        obj.plot('SIDD/Az', 'b-', ax);
        hold off;
        legend('Ax', 'Ay', 'Az');
    else
%         switch(sid_ax)
%             case {1, 4, 7, 10}
%                 obj.plot('SIDD/Ax', 'b-', ax);
%             case {2, 5, 8, 11}
%                 obj.plot('SIDD/Ay', 'b-', ax);
%             case {3, 6, 9, 12, 13}
%                 obj.plot('SIDD/Az', 'b-', ax);
%         end
        switch(sid_ax)
            case {1, 4, 7, 10}
                plot_pid(obj, ax, 'PIDR');
            case {2, 5, 8, 11}
                plot_pid(obj, ax, 'PIDP');
            case {3, 6, 9, 12}
                plot_pid(obj, ax, 'PIDY');
            case {13}
                obj.plot('SIDD/Az', 'b-', ax);
                ylabel(obj.getLabel('SIDD/Az'));
        end
    end
    xlabel('Time (s)');
end

function desc = sid_axis_desc(axis)
    switch(axis)
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

function ax = plot_att(obj, ax, var)
    switch(var)
        case {1, 4, 7, 10}
            obj.plot('SIDD/Gx', 'r-', ax);
            ylabel(obj.getLabel('SIDD/Gx'));
            hold on;
            yyaxis right
            obj.plot('ATT/DesRoll', 'g-', ax);
            ylabel(obj.getLabel('ATT/DesRoll'));
            obj.plot('ATT/Roll', 'b-', ax);
            ylabel(obj.getLabel('ATT/Roll'));
            hold off;
            legend('Gx', 'DesRoll', 'Roll');
        case {2, 5, 8, 11}
            obj.plot('SIDD/Gy', 'r-', ax);
            ylabel(obj.getLabel('SIDD/Gy'));
            hold on;
            yyaxis right
            obj.plot('ATT/DesPitch', 'g-', ax);
            ylabel(obj.getLabel('ATT/DesPitch'));
            obj.plot('ATT/Pitch', 'b-', ax);
            ylabel(obj.getLabel('ATT/Pitch'));
            hold off;
            legend('Gy', 'DesPitch', 'Pitch');
        case {3, 6, 9, 12}
            obj.plot('SIDD/Gz', 'r-', ax);
            ylabel(obj.getLabel('SIDD/Gz'));
            hold on;
            yyaxis right
            obj.plot('ATT/DesYaw', 'g-', ax);
            ylabel(obj.getLabel('ATT/DesYaw'));
            obj.plot('ATT/Yaw', 'b-', ax);
            ylabel(obj.getLabel('ATT/Yaw'));
            hold off;
            legend('Gz', 'DesYaw', 'Yaw');
        case 13
            obj.plot('SIDD/Gz', 'r-', ax);
            ylabel(obj.getLabel('SIDD/Gz'));
    end
end

function ax = plot_rate(obj, ax, var)
    switch(var)
        case {1, 4, 7, 10}
            obj.plot('SIDD/Gx', 'r-', ax);
            ylabel(obj.getLabel('SIDD/Gx'));
            hold on;
            yyaxis right
            obj.plot('RATE/RDes', 'g-', ax);
            ylabel(obj.getLabel('RATE/RDes'));
            obj.plot('RATE/R', 'b-', ax);
            ylabel(obj.getLabel('RATE/R'));
            hold off;
            legend('Gx', 'RDes', 'R');
        case {2, 5, 8, 11}
            obj.plot('SIDD/Gy', 'r-', ax);
            ylabel(obj.getLabel('SIDD/Gy'));
            hold on;
            yyaxis right
            obj.plot('RATE/PDes', 'g-', ax);
            ylabel(obj.getLabel('RATE/PDes'));
            obj.plot('RATE/P', 'b-', ax);
            ylabel(obj.getLabel('RATE/P'));
            hold off;
            legend('Gy', 'PDes', 'P');
        case {3, 6, 9, 12}
            obj.plot('SIDD/Gz', 'r-', ax);
            ylabel(obj.getLabel('SIDD/Gz'));
            hold on;
            yyaxis right
            obj.plot('RATE/YDes', 'g-', ax);
            ylabel(obj.getLabel('RATE/YDes'));
            obj.plot('RATE/Y', 'b-', ax);
            ylabel(obj.getLabel('RATE/Y'));
            hold off;
            legend('Gz', 'YDes', 'Y');
        case 13
            obj.plot('SIDD/Gz', 'r-', ax);
            ylabel(obj.getLabel('SIDD/Gz'));
    end
end

function ax = plot_pid(obj, ax, var)
    obj.plot([var '/Tar'], 'r-', ax);
    ylabel(obj.getLabel([var '/Tar']));
    hold on;
    obj.plot([var '/Act'], 'g-', ax);
    yyaxis right
    obj.plot([var '/P'], 'b-', ax);
    obj.plot([var '/I'], 'y-', ax);
    obj.plot([var '/D'], 'k-', ax);
    obj.plot([var '/Dmod'], 'r.', ax);
    obj.plot([var '/SRate'], 'g.', ax);
    obj.plot([var '/Limit'], 'b.', ax);
    title(var);
    hold off;
    legend('Tar', 'Act', 'P', 'I', 'D', 'Dmod', 'SRate', 'Limit');
end
