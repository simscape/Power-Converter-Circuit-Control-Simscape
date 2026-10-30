function openDCDCMOSFETMask(blockPath)
%OPENDCDCMOSFETMASK Open the MOSFET block mask for the active topology.

% Copyright 2025-2026 The MathWorks, Inc.

modelOption = get_param(blockPath, 'modelOption');
switch modelOption
    case 'Buck'
        topo = 'Buck';
    case 'Synchronous Buck'
        topo = 'SynchronousBuck';
    case 'Boost'
        topo = 'Boost';
    case 'Synchronous Boost'
        topo = 'SynchronousBoost';
    case 'Buck-Boost'
        topo = 'BuckBoost';
    case 'Synchronous Buck-Boost'
        topo = 'SynchronousBuckBoost';
    otherwise
        return;
end

mosfetPath = [blockPath, '/NonIsolatedDCDCVariant/', topo, '/MainSwitch/SwitchingMOSFETwithThermal/MOSFET'];
open_system(mosfetPath, 'mask');

end
