function controlGroups = totemPoleMaskControlGroups()
%TOTEMPOLEMASKCONTROLGROUPS Named groups of totem-pole plant mask controls.
%   CONTROLGROUPS = totemPoleMaskControlGroups() returns a struct whose fields are cell
%   arrays of mask control names, grouped by the device that owns them. The four
%   selection callbacks show and hide whole groups instead of repeating name lists. They
%   therefore cannot drift out of step with each other.
%
%   Each group is exactly the set of controls that becomes meaningful or meaningless
%   together. A callback that owns a leg can set every group it owns to 'on' or 'off'. No
%   control is left at whatever the previous selection set.

% Copyright 2026 The MathWorks, Inc.

% ---- fast leg ----------------------------------------------------------------
% On-state data of the fast ideal switch. The thermal MOSFET carries its own datasheet
% values on the device block instead, reached through the fast leg buttons.
controlGroups.fastSwitch = {'RdsOnFast', 'RdsOnFast_unit', ...
    'GdsOffFast', 'GdsOffFast_unit', 'VthFast', 'VthFast_unit'};

% The fast ideal switch has an integral protection diode that is enabled, and in a
% totem-pole PFC it conducts the reverse current every half line cycle, so its data is
% electrically real rather than decorative.
controlGroups.fastBodyDiode = {'VfFast', 'VfFast_unit', ...
    'RdFast', 'RdFast_unit', 'GdFast', 'GdFast_unit'};

controlGroups.fastThermal = {'simTempFast', 'simTempFast_unit'};
controlGroups.fastButtons = {'openFastMOSFETMask', 'applyFastMOSFETParam'};

% ---- slow leg ----------------------------------------------------------------
% Split in two because the thyristor reuses the threshold as its gate trigger voltage
% while having no drain-source on-state data of its own.
controlGroups.slowSwitchOnState = {'RdsOnSlow', 'RdsOnSlow_unit', ...
    'GdsOffSlow', 'GdsOffSlow_unit'};
controlGroups.slowThreshold = {'VthSlow', 'VthSlow_unit'};
controlGroups.slowSwitch = [controlGroups.slowSwitchOnState, controlGroups.slowThreshold];

% Junction data of the two slow-leg devices that are a diode: the standalone ideal diode
% and the thyristor. The slow leg is never both at once, so one set of controls serves
% both. The ideal switch's integral diode is deliberately not here - see slowBodyDiode.
controlGroups.slowDiode = {'VfSlow', 'VfSlow_unit', ...
    'RdSlow', 'RdSlow_unit', 'GdSlow', 'GdSlow_unit'};

% The slow ideal switch's own protection diode, mirroring fastBodyDiode. It gets its own
% triple rather than borrowing slowDiode above, because the switch's integral diode and
% the standalone diode device are different components with different datasheet numbers.
% Sharing them would also have dragged the switch's off conductance from the component
% default of 1e-5 S down to the standalone diode's 1e-8 S, stiffening the circuit for a
% behavior change nobody asked for.
controlGroups.slowBodyDiode = {'VfSlowBody', 'VfSlowBody_unit', ...
    'RdSlowBody', 'RdSlowBody_unit', 'GdSlowBody', 'GdSlowBody_unit'};

controlGroups.slowThermal = {'simTempSlow', 'simTempSlow_unit'};
controlGroups.slowHolding = {'IhSlow', 'IhSlow_unit'};
controlGroups.slowMOSFETButtons = {'openSlowMOSFETMask', 'applySlowMOSFETParam'};
controlGroups.slowDiodeButtons  = {'openSlowDiodeMask', 'applySlowDiodeParam'};

% ---- device selection popups -------------------------------------------------
controlGroups.legPopups    = {'fastLegDeviceOption', 'slowLegDeviceOption'};
controlGroups.nestedPopups = {'slowMOSFETDeviceOption', 'slowDiodeDeviceOption'};

end
