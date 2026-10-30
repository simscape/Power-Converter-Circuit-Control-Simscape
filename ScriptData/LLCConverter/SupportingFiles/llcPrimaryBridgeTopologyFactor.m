function topologyFactor = llcPrimaryBridgeTopologyFactor(primaryBridgeOption)
%   This function returns the topology factor of the LLC converter primary
%   inverter. The factor divides the input voltage to give the voltage that the
%   primary inverter applies to the resonant tank: a full bridge applies the
%   whole input voltage, a half bridge applies half of it.
%
%   Input:
%     primaryBridgeOption  Primary inverter, "Full-Bridge" or "Half-Bridge".
%
%   Output:
%     topologyFactor       1 for a full bridge, 2 for a half bridge.
%
%   Example:
%     topologyFactor = llcPrimaryBridgeTopologyFactor("Half-Bridge")

% Copyright 2026 The MathWorks, Inc.

arguments
    primaryBridgeOption (1,1) string ...
        {mustBeMember(primaryBridgeOption, ["Full-Bridge", "Half-Bridge"])}
end

switch primaryBridgeOption
    case "Full-Bridge"
        topologyFactor = 1;
    case "Half-Bridge"
        topologyFactor = 2;
end

end
