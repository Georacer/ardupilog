% TODO HGM:
% - Implement more clever file opening/closing
% - What endian-ness does Ardupilot use? Implement something smart?
% - Consider non-doubles for efficiency/speed/memory
% - Do we care about preserving the line number of the FMT message
%    for a MessageFormat? (Right now, just neglect it.)

classdef Ardupilog % Does it inherit from anything?
    properties
        % platform
        % version
        % bootTime
        % logTypesNoData = MessageFormat();% An array of message formats without data (yet), instantiated with just the FMT type % 
        % logRecords = MessageFormat('FMT', 'BBnNZ', {'Type','Length','Name','Format','Columns'});% An array of all known message formats with data, instantiated with just the FMT type
        fileName % name of .bin file
        filePathName % path to .bin file
        fileID
        lastLineNum = 0;
    end
    methods
        function obj = Ardupilog(pathAndFileName)
            if nargin == 0
                [filename, filepathname, ~] = uigetfile('*.bin','Select binary (.bin) log-file');
                obj.fileName = filename;
                obj.filePathName = filepathname;
            else
                [filepathname, filename, extension] = fileparts(pathAndFileName);
                obj.filePathName = filepathname;
                obj.fileName = [filename, extension];
            end

            obj = readLog(obj);
        end

        function obj = readLog(obj)
            % Open a file at [filePathName filesep fileName]
            [obj.fileID, errmsg] = fopen([obj.filePathName, filesep, obj.fileName],'r');

            num_bytes = input(['How many bytes to display? ']);
            
            % n=native, b=Big-end, l=Lit-end, s=Big-end-64-long, a = Lit-end-64-long
            data = fread(obj.fileID, [1, num_bytes], 'uint8', 0, 'l');

            % % Read messages one by one, either creating formats, moving to seen, or appending seen
            % while feof(obj.fileID) == 0
            %     obj.readLogLine();
            % end
            disp('The data are:')
            dec2hex(data,2)
            
            % Close the file
            fclose(obj.fileID);
        end
        
        % function readLogLine() % Reads a single log line
        %     lineNum = obj.lastLineNum + 1;
        %     msgType = obj.readFileToComma();
        %     % Look up the format and see if it's known.
        %     if any(strcmp(logRecords_cell{:},msgType))
        %         % If yes, read and add to log.
        %     else
        %         % If no, create new MessageFormat.
        %         msgFmt = obj.readFileToComma();
        %         msgFieldsCell = cell();
        %         for ndx = 1:legnth(msgFmt)
        %             % Read next string, append to msgFieldsCell
        %             fieldName = obj.readFileToComma();
        %             msgFieldsCell{end+1} = fieldName;
        %         end
        %         newMsgFormat = MessageFormat(msgType, msgFmt, msgFieldsCell);
        %         logRecords = [logRecords, newMsgFormat];
        %     end
        % end
        % % - What ends a message? Maybe readLogLine can find this?        
        % % parseData % lvl 2... formats timestamps, converts units,
        % % etc.
        
        % function msgType = readFileToComma()
        %     msgType = '';
        %     nextChar = fread(obj.fileID,1,'char')
        %     while strcmp(nextChar, ',') == 0
        %         if strcmp(nextChar, ' ') == 1
        %             % Discard the (space) char
        %         else
        %             % Keep the (not-a-space) char in the string
        %             msgType = [msgType, nextChar];
        %         end
        %         nextChar = fread(obj.fileID,1,'char');
        %     end
        % end
    end
end