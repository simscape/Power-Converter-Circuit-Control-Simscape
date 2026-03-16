%[text] %[text:anchor:T_C44ECA99] # Test Grid-Forming Converter Input Parameters
%[text] ## 
%[text] %[text:anchor:H_66280954] ## Grid-Forming Converter Specification
gridInverter.apparentPower   = 500;  % kVA, Apparent power
gridInverter.frequency       = 50;   % Hz, Grid frequency
gridInverter.DCVoltage       = 1100; % V, DC bus voltage
gridInverter.lineRMSVoltage  = 415;  % V, Line RMS voltage at the point of interconnection
gridInverter.measurementSampleTime = 100e-6; % s, Power measurement time constant
%[text] %[text:anchor:H_05CC1A24] ## Base Parameters
% Estimating the base values
base.power = gridInverter.apparentPower; % kVA
base.frequency = gridInverter.frequency; % Hz
base.lineVoltage = gridInverter.lineRMSVoltage; % V
base.basePhasePower = base.power*1e3/3; % kVA
base.basePhaseVoltage = base.lineVoltage/sqrt(3); % V
base.voltage = base.basePhaseVoltage*sqrt(2); % V
base.basePhaseCurrent = base.basePhasePower/base.basePhaseVoltage; % A
base.current = base.basePhaseCurrent*sqrt(2); % A

base.impedance = base.basePhaseVoltage/base.basePhaseCurrent; % Ohm
base.inductance = base.impedance/(2*pi*base.frequency); % H
base.capacitance = 1/(base.impedance*2*pi*base.frequency); % F
%[text] %[text:anchor:H_39C75938] ## GFM Filter Inductor Design
gridInverter.ratedrmsCurrent = gridInverter.apparentPower*1e3/(sqrt(3)*gridInverter.lineRMSVoltage); % A, Filter rated current
gridInverter.L = (0.1*gridInverter.lineRMSVoltage/(gridInverter.ratedrmsCurrent*gridInverter.frequency*2*pi*sqrt(3))); % H, Filter inductance
gridInverter.lineResistance = 0.1; % Ohm, Filter resistance
%[text] %[text:anchor:H_FB94CEFA] ### Grid-Forming Converter Power Control
%[text] %[text:anchor:H_DFF69727] ### Active Power Controller
%[text] Two active power control techniques are implemented
%[text] 1. Droop control
%[text] 2. Virtual synchronous method \
%[text] %[text:anchor:H_89D8F516] #### Droop Active Power Control Parameters
gridInverter.droopControl.freqSlopeMp = 0.01; % pu, Hz/W, Power droop value

gridInverter.droopControl.lpfTimeConst = 0.015; % s, Low pass filter time constant

% Lead-lag parameter for three phase power measurement
gridInverter.droopControl.T2 = 0.006; % s, Denominator time constant
gridInverter.droopControl.T1 = 0.005; % s, Numerator time constant
gridInverter.droopControl.sampleTime = 100e-6; % s, Sampling time

gridInverter.freqMeasTimeConst = 150e-3; % s, Frequency measurement time constant
%[text] %[text:anchor:H_A2DB50D6] #### Virtual Synchrnous Machine (VSM) Active Power Control Parameters 
gridInverter.vsm.inertiaConstant = 1; % s, Mechanical time constant
gridInverter.vsm.dampingCoefficent = 1.056; % pu/Hz, Damping coefficient
gridInverter.vsm.freqDroop  = 10; % pu, W(pu)/Hz(pu) VSM Frequency droop
gridInverter.vsm.PmeasTimeConst = 1e-3; % s, Power measurement filter time constant
gridInverter.vsm.maxDampingPower = 0.7; % pu
gridInverter.vsm.minDampingPower = -0.6; % pu
gridInverter.vsm.samplingTime = gridInverter.droopControl.sampleTime; % s
gridInverter.vsm.dampingPowerOption = 'Grid Frequency Measurement'; % Selecting the damping frequency option
%[text] %[text:anchor:H_CA73D394] ### Reactive Power Droop Control
gridInverter.Qcontrol.voltageDroop = 0.3; % pu, V/VAR
gridInverter.Qcontrol.QmeasTimeConst = 1e-3; % s, Power measurement time constant
gridInverter.Qcontrol.voltageReference = 1.0; % pu
gridInverter.Qcontrol.lowVoltageSupportGain = 1.5; % pu.A/V, it adds more reactive current (Iq), during the low voltage condition
%[text] %[text:anchor:H_DD5EF4A9] ## Fault Ride-Through Method
%[text] Three current limiting techniques are implemented to provide fault ride-through capability. Those are:
%[text] 1. Virtual Impedance
%[text] 2. Current Limiting
%[text] 3. Virtual Impedance and Current Limiting \
%[text] %[text:anchor:H_8083B0B0] ### Virtual Impedance Parameters
gridInverter.currentLimit.virImpResistanceCoeff = 0.1875; % pu, Resistance
gridInverter.currentLimit.virImpXbyR = 13.2; % X/R ratio
gridInverter.currentLimit.viCurrentLimit = 1.2; % A, Maximum current
gridInverter.currentLimit.viFilterTimeConst = 1e-3; % s, Filter time constant
%[text] %[text:anchor:H_52FA1355] ### Current Limiting Parameters
gridInverter.currentLimit.maxSaturationCurrent = 1.4; % pu
gridInverter.currentLimit.maxSaturationDelay = 1e-3; % s
%[text] %[text:anchor:H_2989A77D] ###  Virtual Impedance and Current Limiting Parameters
gridInverter.currentLimit.satCurrentRunTime = 1e-3; % s % Current saturation run time
%[text] %[text:anchor:H_28A361D7] ## Current Controller Parameters
gridInverter.controller.CurrentControlSampleTime = 100e-6; % s, Controller sampling time
gridInverter.controller.ctControllerKp = 1.5; % Proportional gain
gridInverter.controller.ctControllerKi = 10; % Integral gain
%[text] %[text:anchor:H_7DDB6115] ## Voltage Controller Parameters
gridInverter.controller.VoltageControlSampleTime = 100e-6; % s, Controller sampling time
gridInverter.controller.voltControllerKp = 0.3; % Proportional gain
gridInverter.controller.voltControllerKi = 180; % Integral gain

gridInverter.controller.voltageMaxId = 1.8; % Id controller saturation maximum limit
gridInverter.controller.voltageMinId = -1.8; % Id controller saturation minimum limit
gridInverter.controller.voltageMaxIq = 1.8; % Iq controller saturation maximum limit
gridInverter.controller.voltageMinIq = -1.8; % Iq controller saturation minimum limit
gridInverter.controller.voltMeasTimeConst = 5e-3; % Voltage measurement low pass filter time constant

%[text] %[text:anchor:H_65C54DE3] ## Default Test Condition
 gfmRealPowerRefProfileVal = [0 0.6 0.6 0.8 0.8];
 gfmRealPowerRefProfileTime = [0 1 3-1e-3 3 6];

gfmReactivePowerRefProfileVal = [0 0.3 0.3 0.3];  % pu, Reactive power reference, linear interpolation applied
gfmReactivePowerRefProfileTime = [0 1 3 6]; % s, Time array

testCondition.gfmRealPowerRefProfile = timetable(gfmRealPowerRefProfileVal','RowTimes',seconds(gfmRealPowerRefProfileTime'));
testCondition.gfmReactivePowerRefProfile = timetable(gfmReactivePowerRefProfileVal','RowTimes',seconds(gfmReactivePowerRefProfileTime'));
localSolverSampleTime = 100e-6;
clear primaryBaseImpedance secondaryBaseImpedance
%%
%[text] Copyright 2023 The MathWorks, Inc.
%[text] %[text:anchor:H_CDD095DA] ## 

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":8.3}
%---
