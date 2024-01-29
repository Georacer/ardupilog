% Plots ArduPilot's system identification results
%
% Usage:
% see sid_plot_config.m file
%
% Amilcar Lucas - IAV GmbH
% License: GPL v3

close all;
set(0, 'defaultFigureUnits', 'centimeters', 'defaultFigurePosition', [0 0 27 24]);

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

if isscalar(sid_axis)
    if sid_axis == 0
        for i = 1:length(sid)
            %plot_sid(sid(i), i, plot_all_3_axis); % plot all
            %plot_input_candidates(sid(i), i); % plot all
            plot_output_candidates(sid(i), i); % plot all
        end
    else
        if isscalar(sid)
            plot_sid(sid, sid_axis, plot_all_3_axis); % plot just one
        else
            plot_sid(sid(sid_axis), sid_axis, plot_all_3_axis); % plot just one
        end
    end
else
    for i = sid_axis
        plot_sid(sid(i), i, plot_all_3_axis); % plot all
    end
end
    
function plot_input_candidates(obj, sid_ax)
    figure;
    
    % plot the input signal
    ax = subplot(4,1,1);
    ax = obj.plot('SIDD/Targ', 'b-', ax);
    ylabel(obj.getLabel('SIDD/Targ'));
    title(['input candidates SID\_AXIS ' num2str(sid_ax) ' - ' sid_axis_desc(sid_ax)]);

    ax = subplot(4,1,2);
    switch(sid_ax)
        case {1, 4, 7, 10}
            obj.plot('ATT/DesRoll', 'g-', ax);
            ylabel(obj.getLabel('ATT/DesRoll'));
        case {2, 5, 8, 11}
            obj.plot('ATT/DesPitch', 'g-', ax);
            ylabel(obj.getLabel('ATT/DesPitch'));
        case {3, 6, 9, 12}
            obj.plot('ATT/DesYaw', 'g-', ax);
            ylabel(obj.getLabel('ATT/DesYaw'));
        case {13}
    end

    ax = subplot(4,1,3);
    switch(sid_ax)
        case {1, 4, 7, 10}
            obj.plot('RATE/RDes', 'b-', ax);
            ylabel(obj.getLabel('RATE/RDes'));
        case {2, 5, 8, 11}
            obj.plot('RATE/PDes', 'b-', ax);
            ylabel(obj.getLabel('RATE/PDes'));
        case {3, 6, 9, 12}
            obj.plot('RATE/YDes', 'b-', ax);
            ylabel(obj.getLabel('RATE/YDes'));
        case {13}
    end

    ax = subplot(4,1,4);
    switch(sid_ax)
        case {1, 4, 7, 10}
            obj.plot('PIDR/Tar', 'r-', ax);
            ylabel(obj.getLabel('PIDR/Tar'));
        case {2, 5, 8, 11}
            obj.plot('PIDP/Tar', 'r-', ax);
            ylabel(obj.getLabel('PIDP/Tar'));
        case {3, 6, 9, 12}
            obj.plot('PIDY/Tar', 'r-', ax);
            ylabel(obj.getLabel('PIDY/Tar'));
        case {13}
    end
    
end

function plot_output_candidates(obj, sid_ax)
    figure;
    
    % plot the input signal
    ax = subplot(4,1,1);
    ax = obj.plot('SIDD/Targ', 'b-', ax);
    ylabel(obj.getLabel('SIDD/Targ'));
    title(['output candidates SID\_AXIS ' num2str(sid_ax) ' - ' sid_axis_desc(sid_ax)]);

    ax = subplot(4,1,2);
    switch(sid_ax)
        case {1, 4, 7, 10}
            obj.plot('ATT/Roll', 'g-', ax);
            ylabel(obj.getLabel('ATT/Roll'));
        case {2, 5, 8, 11}
            obj.plot('ATT/Pitch', 'g-', ax);
            ylabel(obj.getLabel('ATT/Pitch'));
        case {3, 6, 9, 12}
            obj.plot('ATT/Yaw', 'g-', ax);
            ylabel(obj.getLabel('ATT/Yaw'));
        case {13}
    end

    ax = subplot(4,1,3);
    switch(sid_ax)
        case {1, 4, 7, 10}
            obj.plot('RATE/R', 'b-', ax);
            ylabel(obj.getLabel('RATE/R'));
        case {2, 5, 8, 11}
            obj.plot('RATE/P', 'b-', ax);
            ylabel(obj.getLabel('RATE/P'));
        case {3, 6, 9, 12}
            obj.plot('RATE/Y', 'b-', ax);
            ylabel(obj.getLabel('RATE/Y'));
        case {13}
    end

    ax = subplot(4,1,4);
    switch(sid_ax)
        case {1, 4, 7, 10}
            obj.plot('PIDR/Act', 'r-', ax);
            ylabel(obj.getLabel('PIDR/Act'));
        case {2, 5, 8, 11}
            obj.plot('PIDP/Act', 'r-', ax);
            ylabel(obj.getLabel('PIDP/Act'));
        case {3, 6, 9, 12}
            obj.plot('PIDY/Act', 'r-', ax);
            ylabel(obj.getLabel('PIDY/Act'));
        case {13}
    end
    
end

function plot_sid(obj, sid_ax, plot_all_3_axis)
    delta_T = obj.ATT.TimeS(2:length(obj.ATT.TimeS))-obj.ATT.TimeS(1:length(obj.ATT.TimeS)-1);
    Ts = mean(delta_T)

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
    
    compare_rate_att(obj, sid_ax);
    compare_rate_pid(obj, sid_ax);
end

function compare_rate_att(obj, sid_ax)
    figure;
    ax = subplot(3,1,1);
    obj.plot('RATE/RDes', 'b-', ax);
    ylabel(obj.getLabel('RATE/RDes'));
    title(['SID\_AXIS ' num2str(sid_ax) ' - ' sid_axis_desc(sid_ax)]);
    hold on;
    yyaxis right;
    obj.plot('ATT/DesRoll', 'g-', ax);
    ylabel(obj.getLabel('ATT/DesRoll'));
    hold off;
    legend('RATE/RDes','ATT/DesRoll');
    
    ax = subplot(3,1,2);
    obj.plot('RATE/PDes', 'b-', ax);
    ylabel(obj.getLabel('RATE/PDes'));
    hold on;
    yyaxis right;
    obj.plot('ATT/DesPitch', 'g-', ax);
    ylabel(obj.getLabel('ATT/DesPitch'));
    hold off;
    legend('RATE/PDes','ATT/DesPitch');

    ax = subplot(3,1,3);
    obj.plot('RATE/YDes', 'b-', ax);
    ylabel(obj.getLabel('RATE/YDes'));
    hold on;
    yyaxis right;
    obj.plot('ATT/DesYaw', 'g-', ax);
    ylabel(obj.getLabel('ATT/DesYaw'));
    hold off;
    legend('RATE/YDes','ATT/DesYaw');
    xlabel('Time (s)');

    figure;
    ax = subplot(3,1,1);
    obj.plot('RATE/R', 'b-', ax);
    title(['SID\_AXIS ' num2str(sid_ax) ' - ' sid_axis_desc(sid_ax)]);
    ylabel(obj.getLabel('RATE/R'));
    hold on;
    yyaxis right;
    obj.plot('ATT/Roll', 'g-', ax);
    ylabel(obj.getLabel('ATT/Roll'));
    hold off;
    legend('RATE/R','ATT/Roll');
    
    ax = subplot(3,1,2);
    obj.plot('RATE/P', 'b-', ax);
    ylabel(obj.getLabel('RATE/P'));
    hold on;
    yyaxis right;
    obj.plot('ATT/Pitch', 'g-', ax);
    ylabel(obj.getLabel('ATT/Pitch'));
    hold off;
    legend('RATE/P','ATT/Pitch');

    ax = subplot(3,1,3);
    obj.plot('RATE/Y', 'b-', ax);
    ylabel(obj.getLabel('RATE/Y'));
    hold on;
    yyaxis right;
    obj.plot('ATT/Yaw', 'g-', ax);
    ylabel(obj.getLabel('ATT/Yaw'));
    hold off;
    legend('RATE/Y','ATT/Yaw');
    xlabel('Time (s)');
end

function compare_rate_pid(obj, sid_ax)
    figure;
    ax = subplot(3,1,1);
    obj.plot('RATE/RDes', 'b-', ax);
    ylabel(obj.getLabel('RATE/RDes'));
    title(['SID\_AXIS ' num2str(sid_ax) ' - ' sid_axis_desc(sid_ax)]);
    hold on;
    yyaxis right;
    obj.plot('PIDR/Tar', 'g-', ax);
    ylabel(obj.getLabel('PIDR/Tar'));
    hold off;
    legend('RATE/RDes','PIDR/Tar');
    
    ax = subplot(3,1,2);
    obj.plot('RATE/PDes', 'b-', ax);
    ylabel(obj.getLabel('RATE/PDes'));
    hold on;
    yyaxis right;
    obj.plot('PIDP/Tar', 'g-', ax);
    ylabel(obj.getLabel('PIDP/Tar'));
    hold off;
    legend('RATE/PDes','PIDP/Tar');

    ax = subplot(3,1,3);
    obj.plot('RATE/YDes', 'b-', ax);
    ylabel(obj.getLabel('RATE/YDes'));
    hold on;
    yyaxis right;
    obj.plot('PIDY/Tar', 'g-', ax);
    ylabel(obj.getLabel('PIDY/Tar'));
    hold off;
    legend('RATE/YDes','PIDY/Tar');
    xlabel('Time (s)');

    figure;
    ax = subplot(3,1,1);
    obj.plot('RATE/R', 'b-', ax);
    title(['SID\_AXIS ' num2str(sid_ax) ' - ' sid_axis_desc(sid_ax)]);
    ylabel(obj.getLabel('RATE/R'));
    hold on;
    yyaxis right;
    obj.plot('PIDR/Act', 'g-', ax);
    ylabel(obj.getLabel('PIDR/Act'));
    hold off;
    legend('RATE/R','PIDR/Act');
    
    ax = subplot(3,1,2);
    obj.plot('RATE/P', 'b-', ax);
    ylabel(obj.getLabel('RATE/P'));
    hold on;
    yyaxis right;
    obj.plot('PIDP/Act', 'g-', ax);
    ylabel(obj.getLabel('PIDP/Act'));
    hold off;
    legend('RATE/P','PIDP/Act');

    ax = subplot(3,1,3);
    obj.plot('RATE/Y', 'b-', ax);
    ylabel(obj.getLabel('RATE/Y'));
    hold on;
    yyaxis right;
    obj.plot('PIDY/Act', 'g-', ax);
    ylabel(obj.getLabel('PIDY/Act'));
    hold off;
    legend('RATE/Y','PIDY/Act');
    xlabel('Time (s)');

    figure;
    ax = subplot(3,1,1);
    obj.plot('RATE/ROut', 'b-', ax);
    title(['SID\_AXIS ' num2str(sid_ax) ' - ' sid_axis_desc(sid_ax)]);
    ylabel(obj.getLabel('RATE/ROut'));
    hold on;
    yyaxis right;
    %obj.plot('PIDR/Tar', 'g-', ax);
    plot(ax, obj.PIDR.TimeS, obj.PIDR.P+obj.PIDR.I+obj.PIDR.D);
    ylabel(obj.getLabel('PIDR/P'));
    obj.plot('PIDR/Dmod', 'r.', ax);
    obj.plot('PIDR/SRate', 'g.', ax);
    obj.plot('PIDR/Limit', 'b.', ax);
    hold off;
    legend('RATE/ROut','PIDR/P+I+D', 'Dmod', 'SRate', 'Limit');
    
    ax = subplot(3,1,2);
    obj.plot('RATE/POut', 'b-', ax);
    ylabel(obj.getLabel('RATE/POut'));
    hold on;
    yyaxis right;
    %obj.plot('PIDP/Tar', 'g-', ax);
    plot(ax, obj.PIDP.TimeS, obj.PIDP.P+obj.PIDP.I+obj.PIDP.D);
    ylabel(obj.getLabel('PIDP/P'));
    hold off;
    legend('RATE/POut','PIDP/P+I+D');

    ax = subplot(3,1,3);
    obj.plot('RATE/YOut', 'b-', ax);
    ylabel(obj.getLabel('RATE/YOut'));
    hold on;
    yyaxis right;
    %obj.plot('PIDY/Tar', 'g-', ax);
    plot(ax, obj.PIDY.TimeS, obj.PIDY.P+obj.PIDY.I+obj.PIDY.D);
    ylabel(obj.getLabel('PIDY/P'));
    hold off;
    legend('RATE/YOut','PIDY/P+I+D');
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
