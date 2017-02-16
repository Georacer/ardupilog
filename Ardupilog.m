% HGM:
% - Does endian-ness matter? How to make robust?
% - Consider non-doubles for efficiency/speed/memory
% - What's the difference between the "length" of a message as provided by FMT, vs the sum of the lengths of the field identifiers? (BQNnz, for example)
%
% This is hard-coded:
% - The 128 (FMT) message must have fields "Name", "Type", and "Length" which specify other LogMsgGroups

classdef Ardupilog < dynamicprops
    properties (Access = public)
        fileName % name of .bin file
        filePathName % path to .bin file
        % platform
        % version
        % bootTime
    end
    properties (Access = private)
        fileID = -1;
        lastLineNum = 0;
        fmt_name = 'FMT'; % (Just in case this string is ever re-defined in a log)
    end %properties
    methods
        function obj = Ardupilog(pathAndFileName)
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
            
            % THE MAIN CALL: Begin reading specified log file
            obj = readLog(obj);
        end

        function obj = readLog(obj)
            % Open a file at [filePathName filesep fileName]
            [obj.fileID, errmsg] = fopen([obj.filePathName, filesep, obj.fileName],'r');

            % Read messages one by one, either creating formats, moving to seen, or appending seen
            num_lines = input(['How many log lines to display? ']);
            if isempty(num_lines)
                disp('Processing entire log, could take a while...')
                num_lines = 1e14; % a big number, more lines than any log would have
            end
            for ctr = 1:num_lines
                % If another log line exists, process it
                if ~feof(obj.fileID)
                    % The main call to process a single log line
                    obj = obj.readLogLine();
                else % at end of file
                    disp('Reached end of file.')
                    break
                end

                % Display progress for user (TODO: Turn into waitbar)
                if mod(obj.lastLineNum,5e3)==0
                    obj.lastLineNum
                end
            end

            % Display message on completion
            disp(['Done processing ', num2str(obj.lastLineNum), ' lines, closing file.'])
            
            % Close the file
            if fclose(obj.fileID) == 0;
                obj.fileID = -1;
            else
                warn('File not closed successfully')
            end
        end
        
        function obj = readLogLine(obj) % Reads a single log line
            % Increment the (internal) log line number
            lineNum = obj.lastLineNum + 1;

            % Read till \xA3,\x95 is found (dec=163,149)
            obj.findMsgStart();
            
            % Read msg id
            msgTypeNum = fread(obj.fileID, 1, 'uint8', 0, 'l');

            % If file just ended, discard partial msg and quit
            if feof(obj.fileID)
                return
            end

            % Process message based on id
            if (msgTypeNum == 128) % message is FMT
                % Process FMT message to create a new dynamic property
                msgData = uint8(fread(obj.fileID, [1 86], 'uint8', 0, 'l'));
                
                newType = msgData(1);
                newLen = msgData(2); % Note: this is header+ID+dataLen = 2+1+dataLen.
                
                newName = char(trimTail(msgData([3:6])));
                newFmt = char(trimTail(msgData([7:22])));
                newLabels = char(trimTail(msgData([23:86])));
                % newName = char(readBytesAndTrimTail(obj.fileID, 4));
                % newFmt =  char(readBytesAndTrimTail(obj.fileID, 16));
                % newLabels = char(readBytesAndTrimTail(obj.fileID, 64));

                if length(newLabels) < 64 && feof(obj.fileID)
                    % Did not get a complete FMT message, discard without action
                    return
                end

                % Create dynamic property of Ardupilog with newName
                addprop(obj, newName);
                % Instantiate LogMsgGroup class named newName
                obj.(newName) = LogMsgGroup();
                % Process FMT data
                obj.(newName).storeFormat(newType, newLen, newFmt, newLabels);
                
                if (newType == 128)
                    % Special case: first line is 128 (FMT) which defines 128 (FMT),
                    %    so msgName can't be found in the FMT group yet. Use newName. 
                    msgName = newName;
                    obj.fmt_name = newName;
                else
                    % Usual case: find the msgName in the FMT LogMsgGroup
                    msgType_ndx = find(obj.(obj.fmt_name).Type==msgTypeNum);                    
                    msgName = trimTail(obj.(obj.fmt_name).Name(msgType_ndx,:));
                end
                
            else % message is not FMT
                % Look up msgTypeNum in known FMT.Type to get msgName
                msgType_ndx = find(obj.(obj.fmt_name).Type==msgTypeNum);
                if isempty(msgType_ndx) % if message type unknown
                    warning(['Unknown message type: num=', num2str(msgTypeNum),...
                             ' line=', num2str(lineNum)]);
                    % Do nothing else, the search for next msg header will trash all the bytes
                    return
                end

                % Find msgName from FMT LogMsgGroup
                msgName = trimTail(obj.(obj.fmt_name).Name(msgType_ndx,:));

                % Extract data according to table
                msgLength = obj.(obj.fmt_name).Length(msgType_ndx);
                readLength = msgLength - 3; % since header (2) and ID (1) bytes already read
                msgData = uint8(fread(obj.fileID, [1 readLength], 'uint8', 0, 'l'));

                if length(msgData) < readLength && feof(obj.fileID)
                    % Did not get a complete message. Discard incomplete portion and return
                    return
                end
            end % end special processing of FMT vs non-FMT messages

            % Store msgData correctly in that LogMsgGroup
            obj.(msgName).storeMsg(lineNum, msgData);
            
            % Update lastLineNum to indicate log line processed
            obj.lastLineNum = lineNum;
        end
            
        function obj = findMsgStart(obj)
        % Read bytes from the file till the message-start character is found (dec=163,hex=A3)
            data(1) = fread(obj.fileID, 1, 'uint8', 0, 'l');
            data(2) = fread(obj.fileID, 1, 'uint8', 0, 'l');            
            while (feof(obj.fileID)==0) && (data(1) ~= 163) && (data(2) ~= 149)
                disp(['Warning: Trashing byte from log! hex=', dec2hex(data(1),2),' dec=', data(1),' char=',char(data(1))])
                data(1) = data(2); % move data(2) to 1st pos, data(1) is now replaced
                data(2) = fread(obj.fileID, 1, 'uint8', 0, 'l'); % read new byte into data(2)
            end
        end
    end %methods
end %classdef Ardupilog

function string = trimTail(string);
    % Remove any trailing space (zero-chars)
    while string(end)==0
        string(end) = [];
    end
end