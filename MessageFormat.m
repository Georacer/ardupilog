classdef MessageFormat < dynamicprops
    properties
        % timeRel % array of boot-relative time values
        % timestamp % array of time values
        % lineNo % line number in the .bin logfile
        type % Numerical ID of message type (e.g. 128=FMT, 129=PARM, 130=GPS, etc.)
        data_len % Length of data portion for this type messages (neglecting 2-byte header + 1-byte ID)
        format % Format string of data (e.g. QBIHBcLLefffB, QccCfLL, etc.)
        fieldnames_cell % Cell array of (ordered) field names. HGM TODO: Can't this be derived from the fieldProperties array?
        fieldProperties; % Will be array of meta.DynamicProperty items
    end
    methods
        function obj = MessageFormat(type_num, data_length, format_string, field_names_string)
            if nargin == 0
                obj.type = -1;
                obj.data_len = 0;
                obj.format = '';
            else
                obj = obj.storeFormat(type_num, data_length, format_string, field_names_string);
            end
        end
        
        function obj = storeFormat(obj, type_num, data_length, format_string, field_names_string)
            obj.type = type_num;
            obj.data_len = data_length;
            obj.format = format_string;
            obj.fieldnames_cell = strsplit(field_names_string,',');
            for ndx = 1:length(obj.fieldnames_cell)
                % HGM TODO: save delme as item in obj.fieldProperties array
                delme = addprop(obj, obj.fieldnames_cell{ndx});
                % HGM END TODO
            end
        end

        function obj = storeMsg(obj, msgData)
            for field_ndx = 1:length(obj.format)
                % select-and-format fieldData
                switch obj.format(field_ndx)
                  case 'b' % int8_t
                    fieldLen = 1;
                    fieldData = double(typecast(msgData(1:fieldLen),'int8'));
                  case 'B' % uint8_t
                    fieldLen = 1;
                    fieldData = double(typecast(msgData(1:fieldLen),'uint8'));
                  case 'h' % int16_t
                    fieldLen = 2;
                    fieldData = double(typecast(msgData(1:fieldLen),'int16'));
                  case 'H' % uint16_t
                    fieldLen = 2;
                    fieldData = double(typecast(msgData(1:fieldLen),'uint16'));
                  case 'i' % int32_t
                    fieldLen = 4;
                    fieldData = double(typecast(msgData(1:fieldLen),'int32'));
                  case 'I' % uint32_t
                    fieldLen = 4;
                    fieldData = double(typecast(msgData(1:fieldLen),'uint32'));
                  case 'q' % int64_t
                    fieldLen = 8;
                    fieldData = double(typecast(msgData(1:fieldLen),'int64'));
                  case 'Q' % uint64_t
                    fieldLen = 8;
                    fieldData = double(typecast(msgData(1:fieldLen),'uint64'));
                  case 'f' % float (32 bits)
                    fieldLen = 4;
                    fieldData = double(typecast(msgData(1:fieldLen),'single'));
                  case 'd' % double
                    fieldLen = 8;
                    fieldData = double(typecast(msgData(1:fieldLen),'double'));                  
                  case 'n' % char[4]
                    fieldLen = 4;
                    fieldData = char(msgData(1:fieldLen));
                  case 'N' % char[16]
                    fieldLen = 16;
                    fieldData = char(msgData(1:fieldLen));
                  case 'Z' % char[64]
                    fieldLen = 64;
                    fieldData = char(msgData(1:fieldLen));
                  case 'c' % int16_t * 100
                    fieldLen = 2;
                    fieldData = double(typecast(msgData(1:fieldLen),'int16'))/100;
                  case 'C' % uint16_t * 100
                    fieldLen = 2;
                    fieldData = double(typecast(msgData(1:fieldLen),'uint16'))/100;
                  case 'e' % int32_t * 100
                    fieldLen = 4;
                    fieldData = double(typecast(msgData(1:fieldLen),'int32'))/100;
                  case 'C' % uint32_t * 100
                    fieldLen = 4;
                    fieldData = double(typecast(msgData(1:fieldLen),'uint32'))/100;
                  case 'L' % int32_t (Latitude/Longitude)
                    fieldLen = 4;
                    fieldData = double(typecast(msgData(1:fieldLen),'int32'))/1e7;
                  case 'M' % uint8_t (Flight mode)
                    fieldLen = 1;
                    fieldData = double(typecast(msgData(1:fieldLen),'uint8'));
                  otherwise
                    warning('Unsupported format character: ',obj.format(field_ndx),...
                            ' --- Storing data as uint8 array.');
                end
                
                % % HGM: Should we strip the zeros off the end of char-arrays (strings)?
                % %  Pro: saves space, generally our strings are trimmed
                % %  Con: can't put strings of unequal length in a char-matrix, would need a cell-array
                % if any(strcmp({'n','N','Z'}, obj.format(field_ndx)))
                %     while fieldData(end)==0
                %         fieldData(end) = [];
                %     end
                %     % store fieldData into correct field as cell array                    
                %     obj.(obj.fieldnames_cell{field_ndx}) = {obj.(obj.fieldnames_cell{field_ndx});
                %                                             fieldData};
                % else
                %     % store fieldData into correct field as matrix
                %     obj.(obj.fieldnames_cell{field_ndx}) = [obj.(obj.fieldnames_cell{field_ndx});
                %                                             fieldData];
                % end
                
                % store fieldData into correct field
                obj.(obj.fieldnames_cell{field_ndx}) = [obj.(obj.fieldnames_cell{field_ndx});
                                                        fieldData];
                
                % remove fieldData from (remaining) msgData
                msgData(1:fieldLen) = [];
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