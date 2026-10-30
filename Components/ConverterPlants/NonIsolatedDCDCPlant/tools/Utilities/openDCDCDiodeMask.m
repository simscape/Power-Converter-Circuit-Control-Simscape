function openDCDCDiodeMask(blockPath)
%OPENDCDCDIODEMASK Open the Diode block mask for the active topology.

% Copyright 2025-2026 The MathWorks, Inc.

modelOption = get_param(blockPath, 'modelOption');
switch modelOption
    case 'Buck'
        topo = 'Buck';
    case 'Boost'
        topo = 'Boost';
    case 'Buck-Boost'
        topo = 'BuckBoost';
    otherwise
        return;
end

diodePath = [blockPath, '/NonIsolatedDCDCVariant/', topo, '/Diode/TabulatedDiode/Diode'];
open_system(diodePath, 'mask');

end
