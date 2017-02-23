% HGM:
% - Does endian-ness matter? How to make robust?
% - Consider non-doubles for efficiency/speed/memory
% - What's the difference between the "length" of a message as provided by FMT, vs the sum of the lengths of the field identifiers? (BQNnz, for example)
%
% This is hard-coded:
% - The 128 (FMT) message must have fields "Name", "Type", and "Length" which specify other LogMsgGroups

classdef Ardupilog < dynamicprops & matlab.mixin.Copyable
    properties (Access = public)
        fileName % name of .bin file
        filePathName % path to .bin file
        % platform
        % version
        % bootTime
        numMsgs
    end
    properties (Access = private)
        fileID = -1;
        lastLineNum = 0;
        fmt_name = 'FMT'; % (Just in case this string is ever re-defined in a log)
        header1 = 163; % First ("temporary") header byte
        header2 = 149; % Second header byte
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
                disp(['File not found: ', pathAndFileName])
                return
            end
            
            % THE MAIN CALL: Begin reading specified log file
            readLog(obj);
        end
        
        function [] = countMsgs(obj)
        % Open file, count number of headers = number of messages, close file
            % Open a file at [filePathName filesep fileName]
            [obj.fileID, errmsg] = fopen([obj.filePathName, filesep, obj.fileName],'r');
            if ~isempty(errmsg) || obj.fileID==-1
                error(errmsg);
            end

            readsize = 1024*1024; % Block size to read before performing a count
                        
            indices = []; % Array to count header-messages
            carry = []; % In case a read accidentally splits a header-message
                        
            while feof(obj.fileID)==0
                % Read a block of the file
                batch = [carry fread(obj.fileID,readsize)'];
                if isempty(batch)
                    break
                end
                % If the ending of the block is inside the header
                if batch(end)==obj.header1
                    % Carry the header to the next batch
                    carry = batch(end);
                else
                    carry = [];
                end
                % Append the index-count of the header message
                indices = [indices strfind(batch,[obj.header1 obj.header2])];
            end
            
            % The number of header occurances is the number of messages
            obj.numMsgs = length(indices);
            
            % Close the file
            if fclose(obj.fileID) == 0;
                obj.fileID = -1;
            else
                error('File not closed successfully, find out why before proceeding.')
            end

        end

        function [] = readLog(obj)

            % Count how many message are in the log file (opens, reads, and closes the file)
            obj.countMsgs();
            
            % Open a file at [filePathName filesep fileName]
            [obj.fileID, errmsg] = fopen([obj.filePathName, filesep, obj.fileName],'r');
            if ~isempty(errmsg) || obj.fileID==-1
                error(errmsg);
            end

            % Read messages one by one, either creating formats, moving to seen, or appending seen
            num_lines = input(sprintf(['How many log lines to process? (%d total, press Enter to process all): '],obj.numMsgs));
            if isempty(num_lines)
                num_lines = obj.numMsgs*10; % numMsgs should be accurate, the *10 is "just in case"...
            end
            wb_handle = waitbar(0, 'Initializing...', ...
                         'Name', ['Processing log: ', obj.fileName], ...
                         'CreateCancelBtn', 'setappdata(gcbf, ''cancel'', 1)');
            setappdata(wb_handle,'cancel',0);
            for ctr = 1:num_lines
                % If another log line exists, process itsprint
                if ~feof(obj.fileID)
                    % Check to see if user pressed cancel button
                    if getappdata(wb_handle, 'cancel') == 1
                        disp('Canceled by user')
                        break
                    end
                    % The main call to process a single log line
                    obj.readLogLine();
                else % at end of file
                    disp('Reached end of file.')
                    break
                end

                % Display progress for user
                % if mod(obj.lastLineNum, 1e3) == 0 % every 1e3 messages
                waitbar(ctr/obj.numMsgs, wb_handle, sprintf('%d of %d', obj.lastLineNum, obj.numMsgs));
                % end
            end

            delete(wb_handle);
            % Display message on completion
            disp(['Done processing ', num2str(obj.lastLineNum), ' lines, closing file.'])
            
            % Close the file
            if fclose(obj.fileID) == 0;
                obj.fileID = -1;
            else
                warn('File not closed successfully')
            end
        end
        
        function [] = readLogLine(obj) % Reads a single log line
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
                
                newName = char(trimTail(msgData(3:6)));
                newFmt = char(trimTail(msgData(7:22)));
                newLabels = char(trimTail(msgData(23:86)));
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
                    msgType_ndx = find(obj.(obj.fmt_name).Type==msgTypeNum,1);                    
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
            
        function [] = findMsgStart(obj)
        % Read bytes from the file till the message-start character is found (dec=163,hex=A3)
            b1 = fread(obj.fileID, 1, 'uint8', 0, 'l');
            b2 = fread(obj.fileID, 1, 'uint8', 0, 'l');            
            while (feof(obj.fileID)==0) && (b1 ~= obj.header1) && (b2 ~= obj.header2)
                disp(['Warning: Trashing byte from log! hex=', dec2hex(b1,2),' dec=', b1,' char=',char(b1)])
                b1 = b2; % move 2nd byte to 1st pos, old b1 is trashed
                b2 = fread(obj.fileID, 1, 'uint8', 0, 'l'); % read new byte into b2
            end
        end
    end %methods
end %classdef Ardupilog

function string = trimTail(string)
    % Remove any trailing space (zero-chars)
    while string(end)==0
        string(end) = [];
    end
end