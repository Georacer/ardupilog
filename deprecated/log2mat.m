function [ output_args ] = log2mat( logID )
%LOG2MAT Parse a log file and save it as .mat
%   Detailed explanation goes here

% Remove this
evalin('base','clear');
profile off
profile on

p = inputParser;
p.addRequired('id',@(x) (x>0)&(mod(x,1)==0));
p.parse(logID);
opts = p.Results;
logID = opts.id;

key = sprintf('logs/%03d/*.log',logID);
file = dir(key);

filePath = sprintf('logs/%03d/%s',logID,file.name);

fh = fopen(filePath);

formats = cell(1,5);
% Specify the format line
formats{1,1} = 128;
formats{1,2} = 89;
formats{1,3} = 'FMT';
formats{1,4} = 'BBnNZ';
formats{1,5} = {'Type','Length','Name','Format','Columns'};

msgsSeen = cell(0,1);

[~,reply] = system(['wc -l ',which(filePath)]); % Number of lines in the log file
reply = strsplit(reply,' ');
fileLines = str2num(reply{1});
mh = waitbar(0,'Parsing log');
lineNum = 0;

waitbarPeriod = floor(fileLines/100);

msgs = [];
msgIndices = [];

while true
    
    newline = fgetl(fh);
    if (newline==-1)
        break;
    end    
    
    lineNum = lineNum + 1;
    if mod(lineNum,waitbarPeriod)==0
        waitbar(lineNum/fileLines,mh);
    end
    
    newline = strrep(newline,', ',',');
    
    data = textscan(newline,'%s','Delimiter',',');
    msgType = data{1}{1};
    
    if strcmp(msgType,'FMT')
        % This is a format specifier
        
        if strcmp(data{1}{4},'FMT')
            % This is the FMT specification, already got it
        else
            newrow = cell(1,5);
            id = textscan(data{1}{2},'%d');
            newrow{1} = id{1};
            msgSize = textscan(data{1}{3},'%d');
            newrow{2} = msgSize{1};
            msgName = data{1}{4};
            newrow{3} = msgName;
            msgFormat = data{1}{5};
            newrow{4} = msgFormat;
            newrow{5} = data{1}(6:end);
            formats(end+1,:) = newrow;
            
            [~,instances] = system(sprintf('grep ^%s, %s | wc -l',msgName, which(filePath))); % Number of lines in the log file
            instances = str2double(instances);
            
            if hasStr(msgFormat)
                msgs.(msgName) = cell(instances,length(msgFormat));
%                 eval(sprintf('%s=cell(%d,%d);',msgName,instances,length(msgFormat)) );
            else
                msgs.(msgName) = zeros(instances,length(msgFormat));
                eval(sprintf('%s=zeros(%d,%d);',msgName,instances,length(msgFormat)) );
            end
            
            msgIndices.(msgName)=1;
        end
        
    else
        msgIndexC = strcmp(formats(:,3), msgType);
        msgIndex = find(msgIndexC);
        if msgIndex==0
            error(sprintf('Could not find format for message %s',msgType));
        end        
        format = formats{msgIndex,4};
        formatStr = genFormatStr(format);
        
        msgSize = length(formatStr)-1; % minus the initial msgType
        newrow = cell(1,msgSize);
        for i=2:length(formatStr)
            if (formatStr(i)=='d')
                % field is integer
                temp = textscan(data{1}{i},'%d');
                newrow{i-1} = temp{1};
            elseif (formatStr(i)=='f')
                % field is float
                temp = textscan(data{1}{i},'%f');
                newrow{i-1} = temp{1};
            else
                % field is string
                newrow{i-1} = data{1}{i};
            end
        end
        
        tempInd = msgIndices.(msgType);
        
        if hasStr(format)
            msgs.(msgType)(tempInd,:) = newrow;
%             eval(sprintf('%s(%d,:) = newrow;',msgType, tempInd) );
        else
            newrow = cell2mat(newrow);
            msgs.(msgType)(tempInd,:) = newrow;
%             eval(sprintf('%s(%d,:) = newrow;',msgType, tempInd));
        end
        msgIndices.(msgType) = msgIndices.(msgType)+1;
         
    end

end

fclose(fh);

names = formats(:,3);
for i=1:length(names)
    if  ~strcmp(names{i},'FMT') && msgIndices.(names{i})>1
        msgsSeen(end+1)=names(i);
    end
end

env.msgsSeen = msgsSeen;
env.logID = logID;

assignin('base','formats',formats);
assignin('base','msgs',msgs);
assignin('base','env',env);

[folder, fileName, ~] = fileparts(filePath);

hash = gitHashShort('log2mat');
save(sprintf('%s/%s_%s.mat',folder,fileName,hash), 'env', 'formats', 'msgs');

close(mh);

profile off

end