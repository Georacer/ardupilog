LOGS_FOLDER = 'testing';

% Get all the files in the folder
files = dir(LOGS_FOLDER);
num_files = length(files);

% Allocate results
examined_versions = {};
logs = [];
log_names = {};

i=0;
while i<length(files)
    i = i+1;
    cur_file = files(i);
    filename = cur_file.name;
    filepath = fullfile(cur_file.folder, filename);
    
    % Exclude current and parent directory
    if cur_file.isdir
        if strcmp(filename, '.') || strcmp(filename, '..')
            continue
        end
    end
    
    % Parse directories and add files to list
    if cur_file.isdir
        files = [files; dir(filepath)];
    end        
    
    % Parse only logs
    fileparts = split(filename, '.');
    filetype = lower(fileparts{end});
    if ~strcmp(filetype, 'bin')
        continue
    end
    
    % Parse log
    fprintf('------------------------------------------------\n');
    fprintf('Parsing File: %s\n', filepath);
    log_names{end+1} = filename;
    log = Ardupilog(fullfile(cur_file.folder, filename));
    logs = [logs log];
    fprintf('Platform: %s\nVersion: %s\n', log.platform, log.version);
    
    log_metadata = [log.platform ': ' log.version];
    
    if ~ismember(log_metadata, examined_versions)
        examined_versions{end+1} = log_metadata;
    end
end

% Write out results
examined_versions = sort(examined_versions);
results_filepath = fullfile(LOGS_FOLDER, 'test_results.txt');
fd = fopen(results_filepath, 'w');
for i = 1:length(examined_versions)
    fprintf(fd, '%s\n', examined_versions{i});
end
fclose(fd);
