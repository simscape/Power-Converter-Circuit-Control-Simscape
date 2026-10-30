function [controllerTable, boostPFCController] = designBoostPFCController(boostPFCDesign, options)
%DESIGNBOOSTPFCCONTROLLER Tune the boost PFC controller.
%
%   [controllerTable, boostPFCController] = designBoostPFCController(boostPFCDesign,
%   Name=Value) places both loops of the average-current-mode PFC controller against the
%   sized power stage. It returns the structure the "Boost PFC Controller" block mask reads.
%   An outer voltage loop on the DC bus commands power. That command becomes a
%   resistive-emulation current reference iref = P*|vac|, and an inner loop on the inductor
%   current turns it into duty. Both gains are closed-form matches to the integrator plant
%   each loop sees.
%
%   Inputs:
%     boostPFCDesign  Design structure from designBoostPFCConverter.
%
%   Name-value options:
%     PhaseMargin                Phase margin asked of both loops (deg). Default 60.
%     CurrentCrossoverRatio      Current-loop crossover, as the switching frequency over
%                                this ratio. Default 20.
%     VoltageCrossoverFrequency  Voltage-loop crossover frequency (Hz). Default 3.
%     IrefPeakMaxPu              Peak current-reference limit protecting the boost switch
%                                (pu). Default 1.3.
%     LoadFraction               Power command, as a fraction of rated. Default 1.
%     ModulatorGuardTime         Guaranteed off window at each end of the carrier period
%                                (s), returned as the two duty limits. Default 100e-9.
%     PwmStepsPerPeriod          Modulator carrier steps per switching period, setting the
%                                duty resolution. Default 200.
%     GateVoltageOn              Gate drive on level (V). Default 15.
%     GateVoltageOff             Gate drive off level (V). Default 0.
%     DisplayTableFlag           Display the controller table. Default false.
%
%   Outputs:
%     controllerTable     Table of the gains, the sample times and the achieved placement.
%     boostPFCController  Structure the controller block mask reads, in per-unit on two
%                         base sets.
%
%   See also designInterleavedBoostPFCController, designTotemPoleBoostPFCController.

% Copyright 2026 The MathWorks, Inc.

arguments
    boostPFCDesign struct
    options.PhaseMargin (1,1) double {mustBePositive} = 60
    options.CurrentCrossoverRatio (1,1) double {mustBePositive} = 20
    options.VoltageCrossoverFrequency (1,1) double {mustBePositive} = 3
    options.IrefPeakMaxPu (1,1) double {mustBeGreaterThanOrEqual(options.IrefPeakMaxPu,1)} = 1.3
    options.LoadFraction (1,1) double {mustBePositive} = 1
    % mustBePositive, not mustBeNonnegative: zero is the failure mode noted at dutyMin.
    options.ModulatorGuardTime (1,1) double {mustBePositive} = 100e-9
    options.PwmStepsPerPeriod (1,1) double {mustBePositive} = 200
    options.GateVoltageOn (1,1) double = 15
    options.GateVoltageOff (1,1) double = 0
    options.DisplayTableFlag (1,1) logical = false
end

% scalarValue accepts either simscape.Value or a plain double.
VOut   = scalarValue(boostPFCDesign.outputVoltage);
Pbase  = scalarValue(boostPFCDesign.ratedPower);
VacRMS = scalarValue(boostPFCDesign.nomInputVoltage);
Fsw    = scalarValue(boostPFCDesign.switchingFrequency);
LBoost = scalarValue(boostPFCDesign.boostInductance);
CBoost = scalarValue(boostPFCDesign.outputCapacitance);

% Two base sets, because a PFC has an AC and a DC port. On these
% iref_pu = P_pu*|vac|_puAC with |vac|_puAC peaking at 1, so the peak of iref_pu is the
% power command itself - which is what makes iRefPeakMaxPu meaningful as a device limit.
% Pbase is rated power, not the momentary load: tying a base to the load would make the
% per-unit peak-current limit track the load instead of protecting the device.
VbaseDC = VOut;
VbaseAC = sqrt(2) * VacRMS;
IbaseAC = 2 * Pbase / VbaseAC;

% Loop placement.
%   current loop  iL/d  =  VOut/(s*L)        -> Kp = wc*L*sin(PM)/VOut
%   voltage loop  v/p   =  1/(s*Co*VOut)     -> Kp = wc*Co*VOut*sin(PM)
% PI zero at wc/tan(PM), so Ki = Kp*wc/tan(PM). The sin(PM) factor cancels the PI's own
% magnitude boost so the crossover lands where it was asked for.
%
% Both plants are integrators, so one PI places each loop exactly. The voltage plant
% is the bus capacitor charged by power, so the outer loop commands power, which is
% the variable the loop is linear in.
%
% The voltage loop is held at 3 Hz: any 100 Hz bus ripple reaching the current reference comes
% back as third-harmonic input distortion. Load-step recovery takes about 1 s.
% The current loop at Fsw/20 tracks the rectified sine but ignores switching ripple.
PhaseMargin = options.PhaseMargin;
FcCurrent = Fsw / options.CurrentCrossoverRatio;
FcVoltage = options.VoltageCrossoverFrequency;

wcCurrent = 2*pi*FcCurrent;
wcVoltage = 2*pi*FcVoltage;

% Placed in physical units first, then converted on the base set of the side each loop works
% on: the voltage gain maps bus volts to watts (VbaseDC/Pbase), the current gain maps line
% amps to duty (IbaseAC). Crossovers and phase margins are unchanged by the conversion.
KpVoltagePhysical = wcVoltage * CBoost * VOut * sind(PhaseMargin);          % W/V
KiVoltagePhysical = KpVoltagePhysical * wcVoltage / tand(PhaseMargin);      % W/(V*s)
KpCurrentPhysical = wcCurrent * LBoost * sind(PhaseMargin) / VOut;          % 1/A
KiCurrentPhysical = KpCurrentPhysical * wcCurrent / tand(PhaseMargin);      % 1/(A*s)

% The structure the block mask reads. Field names match the mask parameter names.
boostPFCController.KpVoltage = KpVoltagePhysical * VbaseDC / Pbase;
boostPFCController.KiVoltage = KiVoltagePhysical * VbaseDC / Pbase;
boostPFCController.TsVoltage = 1/(2*Fsw);   % the current loop is 5x faster

boostPFCController.KpCurrent = KpCurrentPhysical * IbaseAC;
boostPFCController.KiCurrent = KiCurrentPhysical * IbaseAC;
boostPFCController.TsCurrent = 1/(10*Fsw);

% Peak current-reference limit. The hard clamp is not redundant: VbaseAC is the nominal line
% peak, so on a swell |vac|_puAC exceeds 1 and the reference peak would exceed the command.
boostPFCController.iRefPeakMaxPu = options.IrefPeakMaxPu;

% Power command in pu of rated. No separate power-trim limit: the command must lie in
% [0, iRefPeakMaxPu], so the voltage PI's limits are derived rather than offered as a third
% pair the dialog could contradict.
boostPFCController.PrefPu = options.LoadFraction;

% Modulator guard interval, as the two duty limits the modulator mask reads. Not a dead time:
% a boost leg has one controlled switch and a diode, so there is no shoot-through path. It
% gives a guaranteed off window at both ends of the carrier period, which keeps the gate edge
% off the duty latch's sampling instant and gives the boost diode a conduction interval.
guardDutyFraction = options.ModulatorGuardTime * Fsw;
boostPFCController.dutyMin = guardDutyFraction;
boostPFCController.dutyMax = 1 - guardDutyFraction;

% Fixed-step modulator carrier only; the variable-step carrier declares no rate. The step size
% sets the duty resolution: 1/PwmStepsPerPeriod, 0.5% at the default 200.
boostPFCController.TsPwm = 1/(options.PwmStepsPerPeriod * Fsw);

boostPFCController.gateVoltageOn  = options.GateVoltageOn;
boostPFCController.gateVoltageOff = options.GateVoltageOff;

% Placement metadata, so the achieved design is inspectable.
boostPFCController.phaseMargin = PhaseMargin;
boostPFCController.FcVoltage   = FcVoltage;
boostPFCController.FcCurrent   = FcCurrent;

% The label and unit columns are char, so the display does not put quotes around every row.
controllerTable = table( ...
    char(["Voltage-loop crossover frequency (FcVoltage)"
     "Voltage-loop proportional gain (KpVoltage)"
     "Voltage-loop integral gain (KiVoltage)"
     "Voltage-loop sample time (TsVoltage)"
     "Current-loop crossover frequency (FcCurrent)"
     "Current-loop proportional gain (KpCurrent)"
     "Current-loop integral gain (KiCurrent)"
     "Current-loop sample time (TsCurrent)"
     "Phase margin, both loops (phaseMargin)"
     "Peak current-reference limit (iRefPeakMaxPu)"
     "Power command (PrefPu)"
     "Modulator minimum duty (dutyMin)"
     "Modulator maximum duty (dutyMax)"
     "Fixed-step modulator sample time (TsPwm)"]), ...
    [FcVoltage
     boostPFCController.KpVoltage
     boostPFCController.KiVoltage
     boostPFCController.TsVoltage
     FcCurrent
     boostPFCController.KpCurrent
     boostPFCController.KiCurrent
     boostPFCController.TsCurrent
     PhaseMargin
     boostPFCController.iRefPeakMaxPu
     boostPFCController.PrefPu
     boostPFCController.dutyMin
     boostPFCController.dutyMax
     boostPFCController.TsPwm], ...
    char(["Hz"; "pu"; "pu/s"; "s"; "Hz"; "pu"; "pu/s"; "s"; "deg"; "pu"; "pu"; "pu"; "pu"; "s"]), ...
    'VariableNames', ["Parameter", "Value", "Unit"]);

if options.DisplayTableFlag
    disp(table(controllerTable, 'VariableNames', "Boost PFC Controller Parameters"));
end
end

% ======================================================================
function numericValue = scalarValue(quantity)
% Read a scalar out of either a simscape.Value or a plain double.
if isa(quantity, 'simscape.Value')
    numericValue = quantity.value;
else
    numericValue = quantity;
end
end
