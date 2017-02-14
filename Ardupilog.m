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
        logRecords = cell(0,3);
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

            if all(obj.fileName == 0) && all(obj.filePathName == 0)
                return
            end
            
            obj = readLog(obj);
        end

        function obj = readLog(obj)
            % Open a file at [filePathName filesep fileName]
            [obj.fileID, errmsg] = fopen([obj.filePathName, filesep, obj.fileName],'r');

            % Read messages one by one, either creating formats, moving to seen, or appending seen
            num_lines = input(['How many log lines to display? ']);
            for ctr = 1:num_lines
                if feof(obj.fileID) ~= 0
                    fclose(obj.fileID);
                    return
                else
                    obj = obj.readLogLine();
                end
            end

            % num_bytes = input(['How many bytes to display? ']);
            % % n=native, b=Big-end, l=Lit-end, s=Big-end-64-long, a = Lit-end-64-long
            % data = fread(obj.fileID, [1, num_bytes], 'uint8', 0, 'l');
            % disp('The data are:')
            % %dec2hex(data,2)
            % char(data)'
            
            % Close the file
            fclose(obj.fileID);
        end
        
        function obj = readLogLine(obj) % Reads a single log line
            obj.lastLineNum = obj.lastLineNum + 1;

            % Read till \xA3,\x95 is found (dec=163,149)
            obj.findMsgStart();
            
            % Read msg id
            msgType = fread(obj.fileID, 1, 'uint8', 0, 'l');
            
            if (msgType == 128) % message is FMT
                newType = fread(obj.fileID, 1, 'uint8', 0, 'l');
                newLen = fread(obj.fileID, 1, 'uint8', 0, 'l'); % HGM: Will always be 89?

                % Read 4 bytes, put into string, remove the last one if it's a space (dec=32, hex=20)
                newName =  fread(obj.fileID, [1 4], 'uint8', 0, 'l');
                % Remove all trailing spaces
                while strcmp(newName(end), ' ')
                    newName(end) = [];
                end
                
                newFmt =  fread(obj.fileID, [1 16], 'uint8', 0, 'l');
                % Remove all trailing spaces
                while strcmp(newFmt(end), ' ')
                    newFmt(end) = [];
                end

                newLabels =  fread(obj.fileID, [1 64], 'uint8', 0, 'l');
                % Remove all trailing spaces
                while strcmp(newLabels(end), ' ')
                    newLabels(end) = [];
                end

                tbl_ndx = size(obj.logRecords,1)+1;
                obj.logRecords{tbl_ndx,1} = newType;
                obj.logRecords{tbl_ndx,2} = newName;
                obj.logRecords{tbl_ndx,3} = newFmt;
                obj.logRecords{tbl_ndx,4} = newLabels;
                
                msgData=char([newName,newFmt,newLabels]);
            elseif any([obj.logRecords{:,1}]==msgType)
                % Extract data according to table
                msgData = '(being trashed)';
            else
                warning(['Unknown message type: number=', num2str(msgType)]);
                msgData = '(being trashed)';
            end

            disp(['Line ' num2str(obj.lastLineNum,'%08d') ': ' num2str(msgType) ',' num2str(msgData) '.'])
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

        % - What ends a message? Maybe readLogLine can find this?        
        % parseData % lvl 2... formats timestamps, converts units,
        % etc.
        
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

% enum LogMessages {
%     LOG_FORMAT_MSG = 128,
%     LOG_PARAMETER_MSG,
%     LOG_GPS_MSG,
%     LOG_GPS2_MSG,
%     LOG_IMU_MSG,
%     LOG_MESSAGE_MSG,
%     LOG_RCIN_MSG,
%     LOG_RCOUT_MSG,
%     LOG_RSSI_MSG,
%     LOG_IMU2_MSG,
%     LOG_BARO_MSG,
%     LOG_POWR_MSG,
%     LOG_AHR2_MSG,
%     LOG_SIMSTATE_MSG,
%     LOG_CMD_MSG,
%     LOG_RADIO_MSG,
%     LOG_ATRP_MSG,
%     LOG_CAMERA_MSG,
%     LOG_IMU3_MSG,
%     LOG_TERRAIN_MSG,
%     LOG_GPS_UBX1_MSG,
%     LOG_GPS_UBX2_MSG,
%     LOG_GPS2_UBX1_MSG,
%     LOG_GPS2_UBX2_MSG,
%     LOG_ESC1_MSG,
%     LOG_ESC2_MSG,
%     LOG_ESC3_MSG,
%     LOG_ESC4_MSG,
%     LOG_ESC5_MSG,
%     LOG_ESC6_MSG,
%     LOG_ESC7_MSG,
%     LOG_ESC8_MSG,
%     LOG_BAR2_MSG,
%     LOG_ARSP_MSG,
%     LOG_ATTITUDE_MSG,
%     LOG_CURRENT_MSG,
%     LOG_CURRENT2_MSG,
%     LOG_COMPASS_MSG,
%     LOG_COMPASS2_MSG,
%     LOG_COMPASS3_MSG,
%     LOG_MODE_MSG,
%     LOG_GPS_RAW_MSG,
%     LOG_GPS_RAWH_MSG,
%     LOG_GPS_RAWS_MSG,
% 	LOG_GPS_SBF_EVENT_MSG,
%     LOG_ACC1_MSG,
%     LOG_ACC2_MSG,
%     LOG_ACC3_MSG,
%     LOG_GYR1_MSG,
%     LOG_GYR2_MSG,
%     LOG_GYR3_MSG,
%     LOG_POS_MSG,
%     LOG_PIDR_MSG,
%     LOG_PIDP_MSG,
%     LOG_PIDY_MSG,
%     LOG_PIDA_MSG,
%     LOG_PIDS_MSG,
%     LOG_VIBE_MSG,
%     LOG_IMUDT_MSG,
%     LOG_IMUDT2_MSG,
%     LOG_IMUDT3_MSG,
%     LOG_ORGN_MSG,
%     LOG_RPM_MSG,
%     LOG_GPA_MSG,
%     LOG_GPA2_MSG,
%     LOG_RFND_MSG,
%     LOG_BAR3_MSG,
%     LOG_NKF1_MSG,
%     LOG_NKF2_MSG,
%     LOG_NKF3_MSG,
%     LOG_NKF4_MSG,
%     LOG_NKF5_MSG,
%     LOG_NKF6_MSG,
%     LOG_NKF7_MSG,
%     LOG_NKF8_MSG,
%     LOG_NKF9_MSG,
%     LOG_NKF10_MSG,
%     LOG_DF_MAV_STATS,

%     LOG_MSG_SBPHEALTH,
%     LOG_MSG_SBPLLH,
%     LOG_MSG_SBPBASELINE,
%     LOG_MSG_SBPTRACKING1,
%     LOG_MSG_SBPTRACKING2,
%     LOG_MSG_SBPRAW1,
%     LOG_MSG_SBPRAW2,
%     LOG_MSG_SBPRAWx,
%     LOG_TRIGGER_MSG,

%     LOG_GIMBAL1_MSG,
%     LOG_GIMBAL2_MSG,
%     LOG_GIMBAL3_MSG,
%     LOG_RATE_MSG,
%     LOG_RALLY_MSG,
% };
