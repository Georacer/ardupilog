% Plots ArduPilot's system identification results
%
% Usage:
% 1. Use the sid_pre script to prepare the data
% 2. Edit the sid_axis and plot_all_3_axis variables on this file and save the file
% 3. run the sid_plot script in matlab
%
% Amilcar Lucas - IAV GmbH
% License: GPL v3

% 0 for all SID_AXIS available
% 1 for just SID_AXIS == 1
% 2 for just SID_AXIS == 2
% ...
% 13 for just SID_AXIS == 13
%
% or
%
% use an array of the axis you want to use
%
sid_axis = 0;

% plot all 3 gyro axis together, or just the relevant axis
plot_all_3_axis = 0;
