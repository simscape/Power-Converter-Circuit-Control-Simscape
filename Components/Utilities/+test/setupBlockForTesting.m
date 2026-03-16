function newBlockPath = setupBlockForTesting(model, currentBlock, referenceBlockPath)
% The function gets all the connections tthen replaces the existing block
% with the reference block and tries to reconnect those connections.
% Please make sure the block is coonected to a port directly and does not
% have a three-way connection.
%
% Copyright 2025 The MathWorks, Inc.

portConnectivity = get_param(strcat(model, "/",currentBlock), "PortConnectivity");

InputConnections = struct([]);
OutputConnections = struct([]);

% Inputs
j=1;
for i = 1:length(portConnectivity)
    if startsWith(portConnectivity(i).Type, 'LConn')
        InputConnections(j).portName = portConnectivity(i).Type;
        InputConnections(j).dstPortHandle = portConnectivity(i).DstPort(1); % Get the handle to the first block.
        j=j+1;
    end
end

% Outputs
j=1;
for i = 1:length(portConnectivity)
    if startsWith(portConnectivity(i).Type, 'RConn')
        OutputConnections(j).portName = portConnectivity(i).Type;
        OutputConnections(j).dstPortHandle = portConnectivity(i).DstPort(1); % Get the handle to the first block.
        j=j+1;
    end
end

% Replace the block and get port handles
temp = split(referenceBlockPath, '/'); library = temp{1};
load_system(library); c = onCleanup(@()bdclose(library));
newBlockPath = replace_block(model, 'Name', currentBlock, referenceBlockPath, 'noprompt');
newBlockPath = newBlockPath{1};
portHandles = get_param(newBlockPath, "PortHandles");
portConnectivity = get_param(newBlockPath, "PortConnectivity");

% Add connections if missing
% Inputs
for i = 1:length(InputConnections)
    if InputConnections(i).dstPortHandle ~= -1 && ~isConnected(InputConnections(i).portName, portConnectivity)
        tokens = regexp(InputConnections(i).portName, '^(.*?)(\d+)$', 'tokens', 'once');
        connSide = tokens{1};
        connIndex = tokens{2};
        add_line(model, portHandles.(connSide)(str2double(connIndex)), InputConnections(i).dstPortHandle)
    end
end

% Outputs
for i = 1:length(OutputConnections)
    if OutputConnections(i).dstPortHandle ~= -1 && ~isConnected(OutputConnections(i).portName, portConnectivity)
        tokens = regexp(OutputConnections(i).portName, '^(.*?)(\d+)$', 'tokens', 'once');
        connSide = tokens{1};
        connIndex = tokens{2};
        add_line(model, portHandles.(connSide)(str2double(connIndex)), OutputConnections(i).dstPortHandle)
    end
end

% Delete un-connected lines
delete_line(find_system(model,'FindAll','on','Type','line','Connected','off'));
end

function TF = isConnected(portType, portConnectivity)
% Check if the inoput port is connected.

portConnectivityType = {portConnectivity.Type};
[present, index] = ismember(portType, portConnectivityType);

if (present)
    if startsWith(portType, "LC") && isempty(portConnectivity(index).DstPort)
        TF =  false;
    elseif startsWith(portType, "LC") && ~isempty(portConnectivity(index).DstPort)
        TF =  true;
    elseif startsWith(portType, "RC") && isempty(portConnectivity(index).DstPort)
        TF =  false;
    elseif startsWith(portType, "RC") && ~isempty(portConnectivity(index).DstPort)
        TF = true;
    end
else
    TF = false;
end
end