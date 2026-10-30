function selectNonIsolatedDCDCControllerTopology(blockPath)
%SELECTNONISOLATEDDCDCCTRLTOPOLOGY Mask callback for the topology selection.
%
%   The controller mirrors the six topologies offered by the Non-Isolated DC-DC
%   plant block. The topology changes one thing structurally: the duty
%   feedforward law, because the ideal duty is a different function of the input
%   and output voltage for each of the three converter families.
%
%       Buck        D = Vout / Vin
%       Boost       D = 1 - Vin / Vout
%       Buck-Boost  D = Vout / (Vin + Vout)
%
%   Everything else the topology affects is a scalar the mask initialization
%   derives, so it needs no structural switching here. Those scalars are the
%   inductor-current base, the nominal duty, the gate vector width and whether the
%   dead time applies.

% Copyright 2026 The MathWorks, Inc.

topologyChoice = get_param(blockPath, 'modelOption');
feedforwardLoc = [blockPath, '/Duty Feedforward/Feedforward Law'];

% A dialog open runs this callback with the choice already in force, so every write
% compares first. Writing the value a block already holds throws
% Simulink:Libraries:LockViolation on a locked library.
switch topologyChoice
    case {'Buck', 'Synchronous Buck'}
        setControllerVariantActiveChoice(feedforwardLoc, 'Buck');
    case {'Boost', 'Synchronous Boost'}
        setControllerVariantActiveChoice(feedforwardLoc, 'Boost');
    case {'Buck-Boost', 'Synchronous Buck-Boost'}
        setControllerVariantActiveChoice(feedforwardLoc, 'BuckBoost');
    otherwise
        error('nonIsolatedDCDC:unknownTopology', ...
            'Unsupported topology "%s".', topologyChoice);
end

end
