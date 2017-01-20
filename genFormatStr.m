function [ formatStr ] = genFormatStr( format )
%GENFORMATSTR Generate a format string for CSV parsing
%   Detailed explanation goes here

% Commented out for speed reasons
% p = inputParser;
% p.addRequired('format',@isstr);
% p.parse(format);
% opts = p.Results;
% format = opts.format;

formatStr = zeros(1,2);
formatStr = 's';

for i=1:length(format)
    
    switch format(i)
        case {'b', 'B', 'h', 'H', 'i', 'I', 'q', 'Q'}
            formatStr = [ formatStr 'f']; % Converting to float because cell2str needs uniform data types to work on
        case {'f', 'c', 'C', 'e', 'E', 'L', 'd'}
            formatStr = [ formatStr 'f'];
        case {'n', 'N', 'Z', 'M'}
            formatStr = [ formatStr 's'];
        otherwise
            error('Uknown format specifier: %s',format(i))
    end

end

end

