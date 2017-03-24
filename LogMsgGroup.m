classdef LogMsgGroup < dynamicprops
    properties (Access = private)
        type = -1; % Numerical ID of message type (e.g. 128=FMT, 129=PARM, 130=GPS, etc.)
        data_len = 0; % Len of data portion for this message (neglecting 2-byte header + 1-byte ID)
        format = ''; % Format string of data (e.g. QBIHBcLLefffB, QccCfLL, etc.)
        fieldInfo = []; % Array of meta.DynamicProperty items
        fieldNameCell = {}; % Cell-array of field names, to reduce run-time
    end
    properties (Access = public)
        % TimeRel % array of boot-relative time values
        % Timestamp % array of time values
        LineNo = [];
    end
    
    methods
        function obj = LogMsgGroup(type_num, data_length, format_string, field_names_string)
            if nargin == 0
                % This is an empty constructor, MATLAB requires it to exist
                return
            end
            obj.storeFormat(type_num, data_length, format_string, field_names_string);
        end
        
        function [] = storeFormat(obj, type_num, data_length, format_string, field_names_string)
            obj.fieldNameCell = strsplit(field_names_string,',');
            % For each of the fields
            for ndx = 1:length(obj.fieldNameCell)
                % Create a dynamic property with field name, and add to fieldInfo array
                if isempty(obj.fieldInfo)
                    obj.fieldInfo = addprop(obj, obj.fieldNameCell{ndx});
                else
                    obj.fieldInfo(end+1) = addprop(obj, obj.fieldNameCell{ndx});
                end
                
                % Put field format char (e.g. Q, c, b, h, etc.) into 'Description' field
                obj.fieldInfo(end).Description = format_string(ndx);
            end

            % Save FMT data into private properties (Not actually used anywhere?)
            obj.type = type_num;
            obj.data_len = data_length;
            obj.format = format_string;
        end

        function [] = storeData(obj, data)
            % Format and store the msgData appropriately
            columnIndex = 1;
            for field_ndx = 1:length(obj.fieldInfo)
                % Find corresponding field name
                field_name_string = obj.fieldNameCell{field_ndx};
                % select-and-format fieldData
                switch obj.fieldInfo(field_ndx).Description
                  case 'b' % int8_t
                    fieldLen = 1;
                    obj.(field_name_string) = double(typecast(data(:,columnIndex-1 +(1:fieldLen)),'int8'));
                  case 'B' % uint8_t
                    fieldLen = 1;
                    obj.(field_name_string) = double(typecast(data(:,columnIndex-1 +(1:fieldLen)),'uint8'));
                  case 'h' % int16_t
                    fieldLen = 2;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'int16'),size(tempArray,1),1));
                  case 'H' % uint16_t
                    fieldLen = 2;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'uint16'),size(tempArray,1),1));
                  case 'i' % int32_t
                    fieldLen = 4;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'int32'),size(tempArray,1),1));
                  case 'I' % uint32_t
                    fieldLen = 4;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'uint32'),size(tempArray,1),1));
                  case 'q' % int64_t
                    fieldLen = 8;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'int64'),size(tempArray,1),1));
                  case 'Q' % uint64_t
                    fieldLen = 8;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'uint64'),size(tempArray,1),1));
                  case 'f' % float (32 bits)
                    fieldLen = 4;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'single'),size(tempArray,1),1));
                  case 'd' % double
                    fieldLen = 8;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'double'),size(tempArray,1),1));
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
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'int16'),size(tempArray,1),1))/100;
                  case 'C' % uint16_t * 100
                    fieldLen = 2;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'uint16'),size(tempArray,1),1))/100;
                  case 'e' % int32_t * 100
                    fieldLen = 4;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'int32'),size(tempArray,1),1))/100;
                  case 'E' % uint32_t * 100
                    fieldLen = 4;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'uint32'),size(tempArray,1),1))/100;
                  case 'L' % int32_t (Latitude/Longitude)
                    fieldLen = 4;
                    tempArray = data(:,columnIndex-1 +(1:fieldLen));
                    obj.(field_name_string) = double(reshape(typecast(tempArray(:),'int32'),size(tempArray,1),1))/1e7;
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
    end
end

% Format characters in the format string for binary log messages
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