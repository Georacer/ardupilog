classdef LogMsgGroup < dynamicprops & matlab.mixin.Copyable
    properties (Access = private)
        data_len = 0; % Len of data portion for this message (neglecting 2-byte header + 1-byte ID)
        format = ''; % Format string of data (e.g. QBIHBcLLefffB, QccCfLL, etc.)
        fieldInfo = []; % Array of meta.DynamicProperty items
        fieldNameCell = {}; % Cell-array of field names, to reduce run-time
        bootDatenumUTC = NaN; % The datenum at boot, set by Ardupilog
        alphaPrefix = 'f'; % Character prefix for validating property labels starting from a digit
    end
    properties (Access = public)
        typeNumID = -1; % Numerical ID of message type (e.g. 128=FMT, 129=PARM, 130=GPS, etc.)
        name = ''; % Human readable name of msg group
        LineNo = [];
    end
    properties (Dependent = true)
        TimeS; % Time in seconds since boot.
        DatenumUTC; % MATLAB datenum of UTC Time at boot
    end
    methods
        function obj = LogMsgGroup(type_num, type_name, data_length, format_string, field_names_string)
            if nargin == 0
                % This is an empty constructor, MATLAB requires it to exist
                return
            end
            obj.storeFormat(type_num, type_name, data_length, format_string, field_names_string);
        end
        
        function [] = storeFormat(obj, type_num, type_name, data_length, format_string, field_names_string)
            if isempty(field_names_string)
                obj.fieldNameCell = {};
            else
                obj.fieldNameCell = strsplit(field_names_string,',');
            end
            
            % Verify that format and labels agree
            if length(format_string)~=length(obj.fieldNameCell)
                warning('incompatible data on msg type=%d/%s', type_num, type_name);
                obj = []; % Clear the instance and return %TODO this is kind of messy
                return
            end
            
            % For each of the fields
            for ndx = 1:length(obj.fieldNameCell)
                fieldNameStr = obj.fieldNameCell{ndx};
                if isstrprop(fieldNameStr(1),'digit') % Check if first label is a digit
                    fieldNameStr = strcat(obj.alphaPrefix,fieldNameStr); % Add a alphabetic character as prefix
                end
                % Create a dynamic property with field name, and add to fieldInfo array
                if isempty(obj.fieldInfo)
                    obj.fieldInfo = addprop(obj, fieldNameStr);
                else
                    obj.fieldInfo(end+1) = addprop(obj, fieldNameStr);
                end
                
                % Put field format char (e.g. Q, c, b, h, etc.) into 'Description' field
                obj.fieldInfo(end).Description = format_string(ndx);
            end

            % Save FMT data into private properties (Not actually used anywhere?)
            obj.typeNumID = type_num;
            obj.name = type_name;
            obj.data_len = data_length;
            obj.format = format_string;
            
            % Assert that the provided message length and format agree
            obj.verifyTypeLengths();
        end

        function [] = storeData(obj, data)
        % Store the message data (from the data matrix) into the
        % appropriate fields based on the column ordering.

            % Format and store the msgData appropriately
            columnIndex = 1;
            for field_ndx = 1:length(obj.fieldInfo)
                % Find corresponding field name
                field_name_string = obj.fieldNameCell{field_ndx};
                if isstrprop(field_name_string(1),'digit') % Check if first label is a digit
                    field_name_string = strcat(obj.alphaPrefix,field_name_string); % Add a alphabetic character as prefix
                end
                % select-and-format fieldData
                switch obj.fieldInfo(field_ndx).Description
                  case 'a' % int16_t[32]
                    fieldLen = 2*32;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(uint8(tempArray),'int16'), [], 32));
                  case 'b' % int8_t
                    fieldLen = 1;
                    obj.(field_name_string) = double(typecast(data(:,columnIndex-1 +(1:fieldLen)),'int8'));
                  case 'B' % uint8_t
                    fieldLen = 1;
                    obj.(field_name_string) = double(typecast(data(:,columnIndex-1 +(1:fieldLen)),'uint8'));
                  case 'h' % int16_t
                    fieldLen = 2;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'int16'),[],1));
                  case 'H' % uint16_t
                    fieldLen = 2;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'uint16'),[],1));
                  case 'i' % int32_t
                    fieldLen = 4;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'int32'),[],1));
                  case 'I' % uint32_t
                    fieldLen = 4;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'uint32'),[],1));
                  case 'q' % int64_t
                    fieldLen = 8;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'int64'),[],1));
                  case 'Q' % uint64_t
                    fieldLen = 8;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'uint64'),[],1));
                  case 'f' % float (32 bits)
                    fieldLen = 4;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'single'),[],1));
                  case 'd' % double
                    fieldLen = 8;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'double'),[],1));
                  case 'n' % char[4]
                    fieldLen = 4;
                    obj.(field_name_string) = char(data(:,columnIndex-1 +(1:fieldLen)));
                  case 'N' % char[16]
                    fieldLen = 16;
                    obj.(field_name_string) = char(data(:,columnIndex-1 +(1:fieldLen)));
                  case 'Z' % char[64]
                    fieldLen = 64;
                    obj.(field_name_string) = char(data(:,columnIndex-1 +(1:fieldLen)));
                  case 'c' % int16_t * 100
                    fieldLen = 2;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'int16'),[],1))/100;
                  case 'C' % uint16_t * 100
                    fieldLen = 2;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'uint16'),[],1))/100;
                  case 'e' % int32_t * 100
                    fieldLen = 4;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'int32'),[],1))/100;
                  case 'E' % uint32_t * 100
                    fieldLen = 4;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'uint32'),[],1))/100;
                  case 'L' % int32_t (Latitude/Longitude)
                    fieldLen = 4;
                    tempArray = reshape(data(:,columnIndex-1 +(1:fieldLen))',1,[]);
                    obj.(field_name_string) = double(reshape(typecast(tempArray,'int32'),[],1))/1e7;
                  case 'M' % uint8_t (Flight mode)
                    fieldLen = 1;
                    obj.(field_name_string) = double(typecast(data(:,columnIndex-1 +(1:fieldLen)),'uint8'));
                  otherwise
                    warning(['Unsupported format character: ',obj.fieldInfo(field_ndx).Description,...
                            ' --- Storing data as uint8 array.']);
                end
                
                columnIndex = columnIndex + fieldLen;
            end
        end
        
        function [] = setLineNo(obj, LineNo)
            obj.LineNo = LineNo;
        end
        
        function [] = setBootDatenumUTC(obj, bootDatenumUTC)
            obj.bootDatenumUTC = bootDatenumUTC;
        end
        
        function [] = verifyTypeLengths(obj)
            % First, assert that the length(obj.format) == numel(obj.fieldNameCell)
            if length(obj.format) > numel(obj.fieldNameCell)
                warning([obj.name, ' format string ', obj.format,...
                         ' has more (char) elements than defined fields. ',...
                         'Only using the first ', num2str(numel(obj.fieldNameCell)),...
                         ': ', obj.format(1:numel(obj.fieldNameCell))]);
            end
            if length(obj.format) < numel(obj.fieldNameCell)
                error([obj.name, ' format string: ', obj.format, ' with length ',...
                       num2str(length(obj.format)), ' does not provide (char)',...
                       ' formats for all ', num2str(numel(obj.fieldNameCell)),...
                       ' field names (in fieldNameCell)'])
            end

            % Next, verify that the FMT-specified message length agrees with
            % the sum of the lengths of each (char) format type. (e.g. for 'bbQQ'
            % since 'b'=int8=1byte, 'Q'=uint64=8bytes, the correct length would be
            % 1+1+8+8=18)
            length_sum = 0;
            for varType = obj.format
                length_sum = length_sum + formatLength(varType);
            end
            if (length_sum+3 ~= obj.data_len)
                warning(sprintf('Incompatible declared message type length (%d) and format length (%d) in msg %d/%s',obj.data_len, length_sum+3, obj.typeNumID, obj.name));
            end
        end

        function timeS = get.TimeS(obj)
            if isprop(obj, 'TimeUS')
                timeS = obj.TimeUS/1e6;
            elseif isprop(obj, 'TimeMS')
                timeS = obj.TimeMS/1e3;
            else
                timeS = NaN(size(obj.LineNo));
            end
        end
        
        function datenumUTC = get.DatenumUTC(obj)
            datenumUTC = obj.bootDatenumUTC + obj.TimeS/60/60/24;
        end

        function [slice, remainder] = getSlice(obj, slice_values, slice_type)
        % This returns an indexed portion (a "slice") of a LogMsgGroup
        % Example:
        %    cruise_gps_msgs = GPS.getSlice([t_begin_cruise, t_end_cruise], 'TimeUS')
        %  will return a smaller LogMsgGroup than GPS, only containing data
        %  between TimeUS values greater than t_begin_cruise and less than
        %  t_end_cruise.

            if isprop(obj, slice_type)
                % Find indices corresponding to slice_values, from slice_type
                switch slice_type
                  case 'LineNo'
                    start_ndx = find(obj.LineNo >= slice_values(1),1,'first');
                    end_ndx = find(obj.LineNo <= slice_values(2),1,'last');
                  case 'TimeUS'
                    start_ndx = find(obj.TimeUS >= slice_values(1),1,'first');
                    end_ndx = find(obj.TimeUS <= slice_values(2),1,'last');
                  otherwise
                    error(['Unsupported slice type: ', slice_type]);
                end
                slice_ndx = [start_ndx:1:end_ndx];
            else
                slice_ndx = [];
            end

            % If the slice is not valid, return an empty LogMsgGroup
            % HGM TODO: We need to improve this validity-checking. For instance, what if the slice_ndx is negative? That's not valid
            if isempty(slice_ndx)
                slice = LogMsgGroup.empty();
                return
            end
            % End HGM TODO
            
            % Create the slice as a new LogMsgGroup
            field_names_string = strjoin(obj.fieldNameCell,',');
            slice = LogMsgGroup(obj.typeNumID, obj.name, obj.data_len, obj.format, field_names_string);
            % For each data field, copy the slice of data, identified by slice_ndx
            for field_name = slice.fieldNameCell
                % HGM: The following is valid for 1-dim and 2-dim fields.
                % - Should we extend to n-dim fields?
                % - If yes, is there a standard way to do this?
                % -- one approach: Could build string_statement from ndims() and repeating ',:' ndims()-1 times, then calling with eval(string_statement)
                % -- MATLAB, or the community, might already have this solved
                slice.(field_name{1}) = obj.(field_name{1})(slice_ndx,:);
            end
            % Copy also the LineNo slice and set the bootDatenum
            slice.setLineNo(obj.LineNo(slice_ndx));
            slice.setBootDatenumUTC(obj.bootDatenumUTC);
        end
    end
    methods(Access=protected)
        function cpObj = copyElement(obj)
        % Makes copy() into a "deep copy" method (i.e. when copying
        % a LogMsgGroup, the new copy also has all the data stored
        % in dynamic-property fields (e.g. TimeUS))
            
            % Create a standard copy (to copy non-dynamic properties)
            cpObj = copyElement@matlab.mixin.Copyable(obj);
            
            % Deep-copy the Dynamic Properties
            for ndx = 1:length(obj.fieldInfo)
                % Create a new dynamic property in the copy
                cpObj.fieldInfo(ndx) = addprop(cpObj, obj.fieldInfo(ndx).Name);
                % Copy the data from the original
                cpObj.(obj.fieldInfo(ndx).Name) = obj.(obj.fieldInfo(ndx).Name);
            end
        end

    end
end

function len = formatLength(varType)
% FORMATLENGTH return the size of the input variable type as designated
switch varType
    case 'a' % int16_t[32] (array of 32 int16_t's)
        len = 2*32;
    case 'b' % int8_t
        len = 1;
    case 'B' % uint8_t
        len = 1;
    case 'h' % int16_t
        len = 2;
    case 'H' % uint16_t
        len = 2;
    case 'i' % int32_t
        len = 4;
    case 'I' % uint32_t
        len = 4;
    case 'q' % int64_t
        len = 8;
    case 'Q' % uint64_t
        len = 8;
    case 'f' % float (32 bits)
        len = 4;
    case 'd' % double
        len = 8;
    case 'n' % char[4]
        len = 4;
    case 'N' % char[16]
        len = 16;
    case 'Z' % char[64]
        len = 64;
    case 'c' % int16_t * 100
        len = 2;
    case 'C' % uint16_t * 100
        len = 2;
    case 'e' % int32_t * 100
        len = 4;
    case 'E' % uint32_t * 100
        len = 4;
    case 'L' % int32_t (Latitude/Longitude)
        len = 4;
    case 'M' % uint8_t (Flight mode)
        len = 1;
    otherwise
        error('Unknown variable type designator');
end

end

% Format characters in the format string for binary log messages
%   a   : int16_t[32] (array of 32 int16_t's)
%   b   : int8_t
%   B   : uint8_t
%   h   : int16_t
%   H   : uint16_t
%   i   : int32_t
%   I   : uint32_t
%   f   : float
%   d   : double
%   n   : char[4]
%   N   : char[16]
%   Z   : char[64]
%   c   : int16_t * 100
%   C   : uint16_t * 100
%   e   : int32_t * 100
%   E   : uint32_t * 100
%   L   : int32_t latitude/longitude
%   M   : uint8_t flight mode
%   q   : int64_t
%   Q   : uint64_t