% Run test_logs.m first to build the "logs" and "log_names" variables.

% Test if GPS instances are correctly parsed
log_name = 'marcusbarnet.BIN';
log = logs(ismember(log_names, log_name));
assert(isprop(log, 'GPS'), 'First GPS instance not found.');
assert(isprop(log, 'GPS_1'), 'Second GPS instance not found.');