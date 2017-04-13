classdef Ardupilog < dynamicprops & matlab.mixin.Copyable
    properties (Access = public)
        fileName % name of .bin file
        filePathName % path to .bin file
        platform % ArduPlane, ArduCopter etc
        version % Firmware version
        commit % Specific git commit
        totalLogMsgs = 0;
        % bootTime
        msgFilter = []; % Storage for the msgIds/msgNames desired for parsing
        numMsgs = 0;
    end
    properties (Access = private)
        fileID = -1;
        header = [163 149]; % Message header as defined in ArduPilot
        log_data = char(0); % The .bin file data as a row-matrix of chars (uint8's)
        fmt_cell = cell(0); % a local copy of the FMT info, to reduce run-time
        fmt_type_mat = []; % equivalent to cell2mat(obj.fmt_cell(:,1)), to reduce run-time
        FMTID = 128;
        FMTLen = 89;
        valid_msgheader_cell = cell(0); % A cell array for reconstructing LineNo (line-number) for all entries
    end %properties
    
    methods
        function obj = Ardupilog(pathAndFileName,msgFilter)
        % The constructor determines if the user wants to:
        % 1) create an Ardupilog from a .bin file (DataFlash log)
        % 2) create an Ardupilog from a .tlog file (MavLink log)
        % 3) create an Ardupilog from a "bare struct" format
        % 4) ... (maybe something else, in the future?)
            
            % At present, the only thing supported is a DataFlash log (.bin), so
            % identify which .bin file the user wants
            if nargin == 0
                % If constructor is empty, prompt user for log file
                [filename, filepathname, ~] = uigetfile('*.bin','Select binary (.bin) log-file');
                obj.fileName = filename;
                obj.filePathName = filepathname;
            else
                % Use user-specified log file
                [filepathname, filename, extension] = fileparts(which(pathAndFileName));
                obj.filePathName = filepathname;
                obj.fileName = [filename, extension];
            end
            % If user pressed "cancel" then return without trying to process
            if all(obj.fileName == 0) && all(obj.filePathName == 0)
                return
            end
            
            % If the user specified message filters, check that they're a valid form
            % and load into obj.msgFilter
            if nargin>=2 % msgFilter argument given
                if ~isempty(msgFilter)
                    if iscellstr(msgFilter) % msgFilter is cell of strings (msgNames)
                        obj.msgFilter = msgFilter;
                    elseif isnumeric(msgFilter) % msgFilter is numeric array (msgIDs)
                        obj.msgFilter = msgFilter;
                    else
                        error('msgFilter input argument invalid. Cell of strings or array accepted');
                    end
                end
            end

            % THE MAIN CALL: Begin reading specified DataFlash log file
            readDataFlashLog(obj);
            
            % Extract firmware version from MSG fields
            if isprop(obj,'MSG')
                for type = {'ArduPlane','ArduCopter','ArduRover','ArduSub'}
                    info_row = strmatch(type{:},obj.MSG.Message);
                    if ~isempty(info_row)
                        obj.platform = type{:};
                        fields_cell = strsplit(obj.MSG.Message(info_row,:));
                        obj.version = fields_cell{1,2};
                        commit = trimTail(fields_cell{1,3});
                        obj.commit = commit(2:(end-1));
                    end
                end
            end
            
            % Clear out the (temporary) properties
            obj.log_data = char(0);
            obj.fmt_cell = cell(0);
            obj.fmt_type_mat = [];
            obj.valid_msgheader_cell = cell(0);
        end
        
        function delete(obj)
            % Probably won't ever be open, but close the file just in case
            if ~isempty(fopen('all')) && any(fopen('all')==obj.fileID)
                fclose(obj.fileID);
            end
        end
        
        function [] = readDataFlashLog(obj)
        % Open file, read all data, close file,
        % Find message headers, find FMT messages, create LogMsgGroup for each FMT msg,
        % Count number of headers = number of messages, process data

            %% Step 1: Open a file, read it into memory, and close it.
            % Open a file at [filePathName filesep fileName]
            [obj.fileID, errmsg] = fopen([obj.filePathName, filesep, obj.fileName], 'r');
            if ~isempty(errmsg) || obj.fileID==-1
                error(errmsg);
            end

            % Define the read-size (inf=read whole file) and read the logfile
            readsize = inf; % Block size to read before performing a count
            obj.log_data = fread(obj.fileID, [1, readsize], '*uchar'); % Read the datafile entirely

            % Close the file
            if fclose(obj.fileID) == 0;
                obj.fileID = -1;
            else
                warn('File not closed successfully')
            end
            
            %% Step 2: Find all FMT messages
            % Discover the locations of every message header
            % (most are valid messages, a few are just data which accidentally
            %  happen to be the header-byte sequence)
            allHeaderCandidates = strfind(obj.log_data, obj.header);
            
            % Try to find the length of the FMT message
            % (from the FMT message definining itself. If unsuccessful, use the 
            %  hard-coded default, obj.FMTLen, which is probably correct anyways)
            for index = allHeaderCandidates
                % Check if this is the FMT message which defines the FMT message specifics
                if obj.log_data(index+2)==obj.FMTID && obj.log_data(index+3)==obj.FMTID
                    obj.FMTLen = double(obj.log_data(index+4));
                    break; % Quit looping as soon as the FMT length is found
                elseif index == allHeaderCandidates(end) % if this is the last headerCandidate
                    warning(['Could not find the FMT message to extract its length. '...
                             'Leaving as the default value: ', num2str(obj.FMTLen)]);
                end
            end
            
            % Get all the FMT messages in a byte-by-byte matrix of size FMTmsgLen x N
            data = obj.isolateMsgData(obj.FMTID,obj.FMTLen,allHeaderCandidates);

            % For each FMT message, create a new LogMsgGroup
            % (as well as some temporary speedup properties: fmt_cell and fmt_type_mat)
            for i=1:size(data,2)
                % Process FMT message to create a new dynamic property
                msgData = data(:,i)';
                
                % HGM: Can we un-hard-code the following? I'm not sure...
                newType = double(msgData(1));
                newLen = double(msgData(2));                
                newName = char(trimTail(msgData(3:6)));
                newFmt = char(trimTail(msgData(7:22)));
                newLabels = char(trimTail(msgData(23:86)));
                
                % Create dynamic property of Ardupilog with newName
                addprop(obj, newName);
                % Instantiate LogMsgGroup class named newName, process FMT data
                obj.(newName) = LogMsgGroup(newType, newName, newLen, newFmt, newLabels);
                
                % Add to obj.fmt_cell and obj.fmt_type_mat (for increased speed)
                obj.fmt_cell = [obj.fmt_cell; {newType, newName, newLen}];
                obj.fmt_type_mat = [obj.fmt_type_mat; newType];
            end
            
            % TODO: If FMT is not filtered out...
            % Store all the FMT message data into the newly-created FMT LogMsgGroup
            fmt_ndx = find(obj.fmt_type_mat == 128);
            FMTName = obj.fmt_cell{fmt_ndx, 2};
            % Store msgData correctly in that LogMsgGroup
            obj.(FMTName).storeData(data');
            % Add to number of msgs in Ardupilog
            obj.numMsgs = obj.numMsgs + size(data, 2);
            % END TODO
            
            % Check for validity of the input msgFilter
            if ~isempty(obj.msgFilter)
                if iscellstr(obj.msgFilter) %obj.msgFilter is a cell-array of strings
                    invalid = find(ismember(obj.msgFilter,obj.fmt_cell(:,2))==0);
                    for i=1:length(invalid)
                        warning('Invalid element in provided message filter: %s',obj.msgFilter{invalid(i)});
                    end
                else %msgFilter is an array of msgId's
                    invalid = find(ismember(obj.msgFilter,cell2mat(obj.fmt_cell(:,1)))==0);
                    for i=1:length(invalid)
                        warning('Invalid element in provided message filter: %d',obj.msgFilter(invalid(i)));
                    end                    
                end
            end
            
            % Iterate over all the discovered msgs
            for i=1:length(obj.fmt_cell)
                msgId = obj.fmt_cell{i,1};
                msgName = obj.fmt_cell{i,2};
                if msgId==obj.FMTID % Skip re-searching for FMT messages
                    continue;
                end

                msgLen = obj.fmt_cell{i,3};
                data = obj.isolateMsgData(msgId,msgLen,allHeaderCandidates);

                % Check against the message filters
                if ~isempty(obj.msgFilter) 
                    if iscellstr(obj.msgFilter)
                        if ~ismember(msgName,obj.msgFilter)
                            continue;
                        end
                    elseif isnumeric(obj.msgFilter)
                        if ~ismember(msgId,obj.msgFilter);
                            continue;
                        end
                    else
                        error('Unexpected comparison result');
                    end
                end
                
                % If message not filtered, store it
                obj.(msgName).storeData(data');
                % Add to number of msgs in Ardupilog
                obj.numMsgs = obj.numMsgs + size(data, 2);
            end
            
            % Construct the LineNo for the whole log
            LineNo_ndx_vec = sort(vertcat(obj.valid_msgheader_cell{:,2}));
            LineNo_vec = [1:length(LineNo_ndx_vec)]';
            % Record the total number of log messages
            obj.totalLogMsgs = LineNo_vec(end);
            % For each LogMsgGroup which wasn't filtered
            for i = 1:size(obj.valid_msgheader_cell,1)
                % Find msgName from msgId in 1st column
                msgId = obj.valid_msgheader_cell{i,1};
                row_in_fmt_cell = vertcat(obj.fmt_cell{:,1})==msgId;
                msgName = obj.fmt_cell{row_in_fmt_cell,2};

                % Pick out the correct line numbers
                msg_LineNo = LineNo_vec(ismember(LineNo_ndx_vec, obj.valid_msgheader_cell{i,2}));
                
                % Write to the LogMsgGroup
                obj.(msgName).setLineNo(msg_LineNo);
            end

            % Display message on completion
            disp('Done processing.');
        end
        
        function headerIndices = discoverValidMsgHeaders(obj,msgId,msgLen,headerIndices)
            % Parses the whole log file and find the indices of all the msgs
            % Cross-references with the length of each message
                
            %debug = true;
            debug = false;

            if debug; fprintf('Searching for msgs with id=%d\n',msgId); end
            
            % Throw out any headers which don't leave room for a susbequent
            % msgId byte
            logSize = length(obj.log_data);
            invalidMask = (headerIndices+2)>logSize;
            headerIndices(invalidMask) = [];
            
            % Filter for the header indices which correspond to the
            % requested msgId
            validMask = obj.log_data(headerIndices+2)==msgId;
            headerIndices(~validMask) = [];

            % Check if the message can fit in the log
            overflow = find(headerIndices+msgLen-1>logSize,1,'first'); 
            if ~isempty(overflow)
                headerIndices(overflow:end) = [];
            end
            
            % Verify that after each msg, another one exists. Otherwise,
            % something is wrong
            % First disregard messages which are at the end of the log
            b1_next_overflow = find((headerIndices+msgLen)>logSize); % Find where there can be no next b1
            b2_next_overflow = find((headerIndices+msgLen+1)>logSize); % Find where there can be no next b2
            % Then search for the next header for the rest of the messages
            b1_next = obj.log_data(headerIndices(setdiff(1:length(headerIndices),b1_next_overflow)) + msgLen);
            b2_next = obj.log_data(headerIndices(setdiff(1:length(headerIndices),b2_next_overflow)) + msgLen + 1);
            b1_next_invalid = find(b1_next~=obj.header(1));
            b2_next_invalid = find(b2_next~=obj.header(2));
            % Remove invalid message indices
            invalid = unique([b1_next_invalid b2_next_invalid]);
            headerIndices(invalid) = [];
        end
            
        function data = isolateMsgData(obj,msgId,msgLen,allHeaderCandidates)
        % Return an msgLen x N array of valid msg data corresponding to msgId

            % Remove invalid header candidates
            msgIndices = obj.discoverValidMsgHeaders(msgId,msgLen,allHeaderCandidates);
            % Save valid headers for reconstructing the log LineNo
            obj.valid_msgheader_cell{end+1, 1} = msgId;
            obj.valid_msgheader_cell{end, 2} = msgIndices';
            
            % Generate the N x msgLen array which corresponds to the indices where FMT information exists
            indexArray = ones(length(msgIndices),1)*(3:(msgLen-1)) + msgIndices'*ones(1,msgLen-3);
            % Vectorize it into an 1 x N*msgLen vector
            indexVector = reshape(indexArray',[1 length(msgIndices)*(msgLen-3)]);
            % Get the FMT data as a vector
            dataVector = obj.log_data(indexVector);
            % and reshape it into a msgLen x N array - CAUTION: reshaping vector
            % to array builds the array column-wise!!!
            data = reshape(dataVector,[(msgLen-3) length(msgIndices)] );
        end
        
    end %methods
end %classdef Ardupilog

function string = trimTail(string)
% Remove any trailing space (zero-chars)
    while string(end)==0
        string(end) = [];
    end
end