classdef Ardupilog < dynamicprops & matlab.mixin.Copyable
    properties (Access = public)
        fileName % name of .bin file
        filePathName % path to .bin file
        platform % ArduPlane, ArduCopter etc
        version % Firmware version
        commit % Specific git commit
        bootTimeUTC % String displaying time of boot in UTC
        totalLogMsgs = 0;
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
        bootDatenumUTC = NaN; % The MATLAB datenum (days since Jan 00, 0000) at APM microcontroller boot (TimeUS = 0)

    end %properties
    
    methods
        function obj = Ardupilog(varargin)
        % TODO: Write a (usage) help message here. User sees this
        % when typing "help Ardupilog" at the matlab prompt.
            
            % Setup argument parser
            p = inputParser;
            addOptional(p,'path',[],@(x) isstr(x)||isempty(x) );
            addOptional(p,'msgFilter',[],@(x) isnumeric(x)||iscellstr(x) );
            parse(p,varargin{:});

            % Decide on initialization method
            if strcmp(p.Results.path,'~') % We just want to create a bare Ardupilog object
                return;
            end
            
            if isempty(p.Results.path)
                % If constructor is empty, prompt user for log file
                [filename, filepathname, ~] = uigetfile('*.bin','Select binary (.bin) log-file');
                obj.fileName = filename;
                obj.filePathName = filepathname;
            else
                % Use user-specified log file
                %[filepathname, filename, extension] = fileparts(which(p.Results.path));
                [filepathname, filename, extension] = fileparts(p.Results.path);
                obj.filePathName = filepathname;
                obj.fileName = [filename, extension];
            end

            obj.msgFilter = p.Results.msgFilter; % Store the message filter

            % If user pressed "cancel" then return without trying to process
            if all(obj.fileName == 0) && all(obj.filePathName == 0)
                return
            end
            
            % THE MAIN CALL: Begin reading specified log file
            readLog(obj);
            
            % Extract firmware version from MSG fields
            obj.findInfo();
            
            % Attempt to find the UTC time of boot (at boot, TimeUS = 0)
            obj.findBootTimeUTC();
            
            % Set the bootDatenumUTC for all LogMsgGroups
            % HGM: This can probably be done better after some code reorganization,
            %  but for now it works well enough. After refactoring is settled, we
            %  might set the bootDatenumUTC when we set the LineNo, or when we store
            %  the TimeUS data, whatever makes sense based on how we decide to handle
            %  message filtering.
            if ~isnan(obj.bootDatenumUTC)
                for prop = properties(obj)'
                    if isa(obj.(prop{1}), 'LogMsgGroup')
                        obj.(prop{1}).setBootDatenumUTC(obj.bootDatenumUTC);
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
        
        function [] = readLog(obj)
        % Open file, read all data, close file,
        % Find message headers, find FMT messages, create LogMsgGroup for each FMT msg,
        % Count number of headers = number of messages, process data

            % Open a file at [filePathName filesep fileName]
            [obj.fileID, errmsg] = fopen([obj.filePathName, filesep, obj.fileName], 'r');
            if ~isempty(errmsg) || obj.fileID==-1
                error(errmsg);
            end

            % Define the read-size (inf=read whole file) and read the logfile
            readsize = inf; % Block size to read before performing a count
            obj.log_data = fread(obj.fileID, [1, readsize], '*uchar'); % Read the datafile entirely

            % Close the file
            if fclose(obj.fileID) == 0
                obj.fileID = -1;
            else
                warn('File not closed successfully')
            end
            
            % Discover the locations of all the messages
            allHeaderCandidates = obj.discoverHeaders([]);
            
            % Find the FMT message legnth
            obj.findFMTLength(allHeaderCandidates);
            
            % Read the FMT messages
            data = obj.isolateMsgData(obj.FMTID,obj.FMTLen,allHeaderCandidates);
            obj.createLogMsgGroups(data');
            
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
            end
            
            % Construct the LineNo for the whole log
            LineNo_ndx_vec = sort(vertcat(obj.valid_msgheader_cell{:,2}));
            LineNo_vec = [1:length(LineNo_ndx_vec)]';
            % Record the total number of log messages
            obj.totalLogMsgs = LineNo_vec(end);
            % Iterate over all the messages
            for i = 1:size(obj.valid_msgheader_cell,1)
                % Find msgName from msgId in 1st column
                msgId = obj.valid_msgheader_cell{i,1};
                row_in_fmt_cell = vertcat(obj.fmt_cell{:,1})==msgId;
                msgName = obj.fmt_cell{row_in_fmt_cell,2};
                
                % Check if this message was meant to be filtered
                if iscellstr(obj.msgFilter)
                    if ~isempty(obj.msgFilter) && ~ismember(msgName,obj.msgFilter)
                        continue;
                    end
                elseif isnumeric(obj.msgFilter)
                    if ~isempty(obj.msgFilter) && ~ismember(msgId,obj.msgFilter)
                        continue;
                    end
                else
                    error('msgFilter type should have passed validation by now and I shouldnt be here');
                end

                % Pick out the correct line numbers
                msg_LineNo = LineNo_vec(ismember(LineNo_ndx_vec, obj.valid_msgheader_cell{i,2}));
                
                % Write to the LogMsgGroup
                obj.(msgName).setLineNo(msg_LineNo);
            end
            
            % Update the number of actual included messages
            propNames = properties(obj);
            for i = 1:length(propNames)
                propName = propNames{i};
                if isa(obj.(propName),'LogMsgGroup')
                    obj.numMsgs = obj.numMsgs + length(obj.(propName).LineNo);
                end
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
            
        function headerIndices = discoverHeaders(obj,msgId)
            % Find all candidate headers within the log data
            % Not all Indices may correspond to actual messages
            if nargin<2
                msgId = [];
            end
            headerIndices = strfind(obj.log_data, [obj.header msgId]);
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
        
        function [] = createLogMsgGroups(obj,data)
            for i=1:size(data,1)
                % Process FMT message to create a new dynamic property
                msgData = data(i,:);
                
                newType = double(msgData(1));
                newLen = double(msgData(2)); % Note: this is header+ID+dataLen = length(header)+1+dataLen.
                
                newName = char(trimTail(msgData(3:6)));
                newFmt = char(trimTail(msgData(7:22)));
                newLabels = char(trimTail(msgData(23:86)));
                
                % Instantiate LogMsgGroup class named newName, process FMT data
                new_msg_group = LogMsgGroup(newType, newName, newLen, newFmt, newLabels);
                if isempty(new_msg_group)
                    warning('Msg group %d/%s could not be created', newType, newName);
                else
                    addprop(obj, newName);
                    obj.(newName) = new_msg_group;
                end
               
                % Add to obj.fmt_cell and obj.fmt_type_mat (for increased speed)
                obj.fmt_cell = [obj.fmt_cell; {newType, newName, newLen}];
                obj.fmt_type_mat = [obj.fmt_type_mat; newType];
                
            end
            % msgName needs to be FMT
            fmt_ndx = find(obj.fmt_type_mat == 128);
            FMTName = obj.fmt_cell{fmt_ndx, 2};
            % Store msgData correctly in that LogMsgGroup
            obj.(FMTName).storeData(data);
        end
        
        function [] = findInfo(obj)
            % Extract vehicle firmware info
                        
            if isprop(obj,'MSG')
                for type = {'ArduPlane','ArduCopter','ArduRover','ArduSub'}
                    info_row = strmatch(type{:},obj.MSG.Message);
                    if ~isempty(info_row)
                        obj.platform = type{:};
                        fields_cell = strsplit(obj.MSG.Message(info_row(1),:));
                        obj.version = fields_cell{1,2};
                        commit = trimTail(fields_cell{1,3});
                        obj.commit = commit(2:(end-1));
                    end
                end
            end
        end
        
        function [] = findBootTimeUTC(obj)
        % From the GPS time, stored in GWk and GMS, calculate what UTC
        % (Coordinated Universal time) was when the Ardupilot microcontroller
        % booted. (TimeUS = AP_HAL::millis() = 0)
            
        % HGM: It's possible the accuracy of this can be improved. I'll put the
        % details of my idea here in the comments, and we can move to a GitHub
        % issue or whatever as appropriate.
        %
        % When a GPS receives data, containing absolute time info (logged in GWk and
        % GMS) it is timestamped by Ardupilot in microseconds-since-boot.  The
        % problem is, that timestamp is stored in the GPA log message, while the
        % GWk/GMS is stored in the GPS log message. The delay between logging the two
        % (GPS and GPA messages) is probably small, but I don't know if there's any
        % way to determine what came from the single original data receipt.
        %
        % We could ask this be changed in Ardupilot, or we might implement
        % something to figure it out from the log... for now, I'm neglecting it,
        % and assuming the GPS message was RECEIVED at it's TimeUS. (Note: the
        % truth is it was LOGGED at this time, not received)
            
        % HGM HACK: 3DR SOLO might have TimeMS instead of TimeUS...
        if isprop(obj.GPS, 'TimeUS')
            timestr = 'TimeUS';
            timeconvert = 1;
        elseif isprop(obj.GPS, 'TimeMS')
            timestr = 'TimeMS';
            timeconvert = 1e3;
        else
            error('Unsupported time in obj.GPS')
        end

        if isprop(obj.GPS, 'GWk')
            wkstr = 'GWk';
        elseif isprop(obj.GPS, 'Week')
            wkstr = 'Week';
        else
            error('Unsupported week-type in obj.GPS')
        end

        if isprop(obj.GPS, 'GMS')
            gpssecstr = 'GMS';
        elseif isprop(obj.GPS, 'T')
            gpssecstr = 'T';
        else
            error('Unsupported GPS-seconds-type in obj.GPS')
        end

            if isprop(obj, 'GPS') && ~isempty(obj.GPS.(timestr))
                % Get the time data from the log
                temp = obj.GPS.(timestr);
                recv_timeUS = temp(1)*timeconvert;
                temp = obj.GPS.(wkstr);
                recv_GWk = temp(1);
                temp = obj.GPS.(gpssecstr);
                recv_GMS = temp(1);
                % Calculate the gps-time datenum
                %  Ref: http://www.oc.nps.edu/oc2902w/gps/timsys.html
                %  Ref: https://confluence.qps.nl/display/KBE/UTC+to+GPS+Time+Correction
                gps_zero_datenum = datenum('1980-01-06 00:00:00.000','yyyy-mm-dd HH:MM:SS.FFF');
                days_since_gps_zero = recv_GWk*7 + recv_GMS/1e3/60/60/24;
                recv_gps_datenum = gps_zero_datenum + days_since_gps_zero;
                % Adjust for leap seconds (disagreement between GPS and UTC)
                leap_second_table = datenum(...
                    ['Jul 01 1981'
                     'Jul 01 1982'
                     'Jul 01 1983'
                     'Jul 01 1985'
                     'Jan 01 1988'
                     'Jan 01 1990'
                     'Jan 01 1991'
                     'Jul 01 1992'
                     'Jul 01 1993'
                     'Jul 01 1994'
                     'Jan 01 1996'
                     'Jul 01 1997'
                     'Jan 01 1999'
                     'Jan 01 2006'
                     'Jan 01 2009'
                     'Jul 01 2012'
                     'Jul 01 2015'], 'mmm dd yyyy');
                leapseconds = sum(recv_gps_datenum > leap_second_table);
                recv_utc_datenum = recv_gps_datenum - leapseconds/60/60/24;
                % Record adjusted time to the log's property
                obj.bootDatenumUTC = recv_utc_datenum - recv_timeUS/1e6/60/60/24;

                % Put a human-readable version in the public properties
                obj.bootTimeUTC = datestr(obj.bootDatenumUTC, 'yyyy-mm-dd HH:MM:SS');
                %obj.bootTimeUTC = datestr(obj.bootDatenumUTC, 'yyyy-mm-dd HH:MM:SS.FFF');
            end                
        end
        
        function [] = findFMTLength(obj,allHeaderCandidates)
            for index = allHeaderCandidates
            % Try to find the length of the format message
                msgId = obj.log_data(index+2); % Get the next expected msgId
                if obj.log_data(index+3)==obj.FMTID % Check if this is the definition of the FMT message
                    if msgId == obj.FMTID % Check if it matches the FMT message
                        obj.FMTLen = double(obj.log_data(index+4));
                        return; % Return as soon as the FMT length is found
                    end
                end
            end
            warning('Could not find the FMT message to extract its length. Leaving the default %d',obj.FMTLen);
            return;
        end
        
        function dump = getStruct(obj)
           % Create a simple struct containing the information of the log
           % without needing to include the Ardupilog class description
           dump = struct();
           props = properties(obj)';
           % Copy all properties which are not LogMsgGroups
           for i = 1:length(props)
               propName = props{i};
               if ~isa(obj.(propName),'LogMsgGroup') % This is not a LogMsgGroup
                   dump.(propName) = obj.(propName);
               else % This is a LogMsgGroup
                   subProps = properties(obj.(propName));
                   for j = 1:length(subProps)
                       subPropName = subProps{j};
                       dump.(propName).(subPropName) = obj.(propName).(subPropName);
                   end
               end
           end
        end

        function slice = getSlice(obj, slice_values, slice_type)
        % This returns an indexed portion (a "slice") of an Ardupilog
        % Example:
        %    log_during_cruise = Log.getSlice([t_begin_cruise, t_end_cruise], 'TimeUS')
        %  will return a smaller Ardupilog, only containing log data between
        %  TimeUS values greater than t_begin_cruise and less than t_end_cruise.

            % Copy all the properties, zero the number of messages
            slice = copy(obj);
            slice.numMsgs = 0;
            
            % Loop through the LogMsgGroups, slicing each one
            logProps = properties(obj);
            for i = 1:length(logProps)
                propertyName = logProps{i}; % Get the name of the property under examination
                % We are interested only in LogMsgGroup objects, skip the rest of the properties
                if ~isa(obj.(propertyName),'LogMsgGroup') 
                    continue;
                end
                
                % Slice the LogMsgGroup
                lmg_slice = slice.(propertyName).getSlice(slice_values, slice_type);
                % If the slice is not empty, add it to the Ardupilog slice
                if isempty(lmg_slice)
                    delete(slice.(propertyName))
                else
                    slice.(propertyName) = lmg_slice;
                    slice.numMsgs = slice.numMsgs + size(slice.(propertyName).LineNo, 1);
                end
            end
        end
        
        function newlog = deleteEmptyMsgs(obj)
        % Delete any logMsgGroups which are empty
        % Implemented by creating a new object and copying non-empty msgs
        % because once created, properties cannot be deleted
        newlog = Ardupilog('~'); % Create a new emtpy log
        
        propertyNames = properties(obj);
        for i = 1:length(propertyNames)
            propertyName = propertyNames{i};
            if ~isa(obj.(propertyName),'LogMsgGroup'); % Copy anything else except LogMsgGroups
                newlog.(propertyName) = obj.(propertyName);
            else % Check if the LogMsgGroup is emtpy
                if isempty(obj.(propertyName).LineNo) % Choosing a field which will always exist
                    % Do nothing
                else
                    addprop(newlog, propertyName);
                    newlog.(propertyName) = obj.(propertyName);
                end
            end
        end
        end
        
        function newlog = filterMsgs(obj,msgFilter)
        % Filter message groups in existing Ardupilog
        
        % Get the logMsgGroups names and ids
        msgNames = {};
        msgIds = [];
        propNames = properties(obj);
        for i=1:length(propNames)
            propName = propNames{i};
            if isa(obj.(propName),'LogMsgGroup')
                msgNames{end+1} = propName;
                msgIds(end+1) = obj.(propName).typeNumID;
            end
        end
        
        % Check for validity of the input msgFilter
        if ~isempty(msgFilter)
            if iscellstr(msgFilter) %obj.msgFilter is a cell-array of strings
                invalid = find(ismember(msgFilter,msgNames)==0);
                for i=1:length(invalid)
                    warning('Invalid element in provided message filter: %s',msgFilter{invalid(i)});
                end
            else %msgFilter is an array of msgId's
                invalid = find(ismember(msgFilter,msgIds)==0);
                for i=1:length(invalid)
                    warning('Invalid element in provided message filter: %d',msgFilter(invalid(i)));
                end
            end
        end
        
        newlog = copy(obj); % Create the new log object
        newlog.msgFilter = msgFilter;
        % Set the LineNos of any messages due for deletion to empty
        propertyNames = properties(newlog);
        for i = 1:length(propertyNames)
            propertyName = propertyNames{i};
            if isa(newlog.(propertyName),'LogMsgGroup'); % For each message group
                msgId = newlog.(propertyName).typeNumID;
                if iscellstr(newlog.msgFilter)
                    if ~ismember(propertyName,newlog.msgFilter)
                        newlog.(propertyName).LineNo = []; % Mark the message group for deletion
                    end
                elseif isnumeric(newlog.msgFilter)
                    if ~ismember(msgId,newlog.msgFilter)
                        newlog.(propertyName).LineNo = []; % Mark the message group for deletion
                    end
                else
                    error('msgFilter type should have passed validation by now and I shouldnt be here');
                end
            end
        end
        
        newlog = newlog.deleteEmptyMsgs();  
        
        % Update the number of actual included messages
        newlog.numMsgs = 0;
        propNames = properties(newlog);
        for i = 1:length(propNames)
            propName = propNames{i};
            if isa(newlog.(propName),'LogMsgGroup')
                newlog.numMsgs = newlog.numMsgs + length(newlog.(propName).LineNo);
            end
        end
        
        end
        
    end
    
    methods(Access=protected)
        
        function newObj = copyElement(obj)
        % Copy function - replacement for matlab.mixin.Copyable.copy() to create object copies
        % Found from somewhere in the internet
            try
                % R2010b or newer - directly in memory (faster)
                objByteArray = getByteStreamFromArray(obj);
                newObj = getArrayFromByteStream(objByteArray);
            catch
                % R2010a or earlier - serialize via temp file (slower)
                fname = [tempname '.mat'];
                save(fname, 'obj');
                newObj = load(fname);
                newObj = newObj.obj;
                delete(fname);
            end
        end
        
    end %methods
end %classdef Ardupilog

function string = trimTail(string)
% Remove any trailing space (zero-chars)
    % Test if string is all zeroes
    if ~any(string)
        string = [];
        return;
    end
    while string(end)==0
        string(end) = [];
    end
end