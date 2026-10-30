%[text] %[text:anchor:T_DABTHERM] # Dual Active Bridge Temperature Rise Input Parameters
%[text] This script holds every parameter that the dual active bridge temperature rise model resolves from the base workspace. Each section covers one group of data, so you can edit one group and leave the rest unchanged. `DABThermalAnalysisWithCustomMOSFETMain` runs this script, and you can also run it before you open the model.
%[text:tableOfContents]{"heading":"Table of Contents"}
%%
%[text] %[text:anchor:H_power] ## Power Stage Data
%[text] The power stage data sets the transformer, the series inductor and the output capacitor of the converter.
% Transformer
DAB.turnsRatio = 1.428571429;       % -, Transformer turns ratio (Np/Ns)
DAB.Lm         = 0.00140625;        % H, Magnetizing inductance
DAB.Llk1       = 2.445652174e-06;   % H, Primary leakage inductance
DAB.RLlk1      = 0.01;              % Ohm, Primary winding resistance
DAB.Llk2       = 1.198369565e-06;   % H, Secondary leakage inductance
DAB.RLlk2      = 0.01;              % Ohm, Secondary winding resistance

% Series inductor
DAB.Lr  = 4.402173913e-05;   % H, Series inductance
DAB.RLr = 0.01;              % Ohm, Series inductor resistance

% Output capacitor
DAB.Co  = 2.962962963e-05;   % F, Output capacitance
DAB.Rco = 1e-06;             % Ohm, Output capacitor ESR
DAB.Vco = 525;               % V, Initial output capacitor voltage
%%
%[text] %[text:anchor:H_heatsink] ## Heatsink Data
%[text] Each bridge mounts on its own forced-air heatsink. The sink to ambient thermal resistance sets the steady heatsink temperature, the heatsink mass and specific heat set how fast it reaches it, and the interface resistance sits between each device case and the heatsink.
DAB.HeatsinkPri.sinkToAmbientResistance = 0.4;    % K/W, Primary heatsink to ambient
DAB.HeatsinkPri.mass                    = 0.9;    % kg, Primary heatsink mass
DAB.HeatsinkPri.specificHeat            = 900;    % J/(K*kg), Primary heatsink specific heat (aluminum)
DAB.HeatsinkSec.sinkToAmbientResistance = 0.24;   % K/W, Secondary heatsink to ambient
DAB.HeatsinkSec.mass                    = 0.8;    % kg, Secondary heatsink mass
DAB.HeatsinkSec.specificHeat            = 900;    % J/(K*kg), Secondary heatsink specific heat (aluminum)
DAB.caseToSinkResistance                = 0.1;    % K/W, Device case to heatsink interface
DAB.HeatsinkPri.initialTemperature      = 63.9;   % degC, Primary heatsink initial temperature (steady at the rated point)
DAB.HeatsinkSec.initialTemperature      = 60.4;   % degC, Secondary heatsink initial temperature (steady at the rated point)
%%
%[text] %[text:anchor:H_pri] ## Primary Device Data
%[text] The four primary bridge devices use this datasheet data: the channel conduction table, the switching loss tables, the body diode table and the junction thermal properties.
%[text] %[text:anchor:H_pri_rating] ### Primary Device Ratings and Thermal Properties
%[text] The junction thermal mass and the junction to case thermal resistance set how fast the junction temperature rises.
DAB.SwitchPri.Vth                   = 3.2;     % V, Gate threshold voltage
DAB.CossPri                         = 2e-10;   % F, Output capacitance (Coss)
DAB.SwitchPri.junction_thermal_mass = 0.01;    % J/K, Junction thermal mass
DAB.SwitchPri.R                     = 0.001;   % K/W, Junction to case thermal resistance
DAB.simTempPri                      = DAB.HeatsinkPri.initialTemperature;   % degC, Initial junction temperature
%%
%[text] %[text:anchor:H_pri_elec] ### Primary Electrical Switch Data
%[text] The MOSFET Model block conducts through an on-state resistance and a body diode with a forward voltage and an on resistance.
DAB.SwitchPri.Rds        = 0.044;                  % Ohm, On-state resistance
DAB.SwitchPri.Goff       = 8.33333333333333e-13;   % S, Off-state conductance
DAB.SwitchPri.diode_Vf   = 2.72;                   % V, Body diode forward voltage
DAB.SwitchPri.diode_Ron  = 0.023;                  % Ohm, Body diode on resistance
DAB.SwitchPri.diode_Goff = 1e-05;                  % S, Body diode off-state conductance
%%
%[text] %[text:anchor:H_pri_cond] ### Primary Channel Conduction Data
%[text] The on-state voltage is tabulated against junction temperature and drain-source current.
DAB.SwitchPri.Tj = [-55 25 150 900];   % degC, Junction temperature breakpoints
% A, Drain-source current breakpoints
DAB.SwitchPri.Iout_data = [ ...
    -99.94 -39.11 -14.94 -5.333 -1.517 0 1.517 5.334 14.94 39.12 99.97];
% V, On-state voltage Vds(Tj, Ids)
DAB.SwitchPri.Von_data = [ ...
    -3.075 -1.321 -0.5334 -0.2017 -0.05735 0 0.05654 0.1988 0.6074 1.756 5.672; ...
    -4.404 -1.709 -0.657 -0.2346 -0.0667 0 0.06456 0.227 0.6342 1.831 6.194; ...
    -4.759 -3.111 -1.191 -0.4253 -0.1209 0 0.1049 0.369 1.1 3.268 12.47; ...
    -5.366 -4.667 -1.787 -0.638 -0.1813 0 0.1573 0.5535 1.65 4.902 18.71];
%%
%[text] %[text:anchor:H_pri_loss] ### Primary Switching Loss Data
%[text] The turn-on and turn-off energy are tabulated against junction temperature and drain-source current, at an off-state voltage of 800 V. The energy scales linearly with the drain-source voltage at the switching instant.
DAB.SwitchPri.Tj_loss = [-55 25 150 900 1000];   % degC, Junction temperature breakpoints
DAB.SwitchPri.Iout_data_loss = [0 16.04 32.08 48.12 64.15 80.19];   % A, Drain-source current breakpoints
DAB.SwitchPri.Voff = 800;   % V, Off-state voltage of the loss data
% J, Turn-on loss Eon(Tj, Ids)
DAB.SwitchPri.Eon_data = [ ...
    0 0.000253 0.0007404 0.001481 0.002418 0.003535; ...
    0 0.0002341 0.000685 0.00137 0.002237 0.00327; ...
    0 0.0002172 0.0006356 0.001272 0.002076 0.003035; ...
    0 0.0001955 0.000572 0.001145 0.001868 0.002732; ...
    0 0.0001955 0.000572 0.001145 0.001868 0.002732];
% J, Turn-off loss Eoff(Tj, Ids)
DAB.SwitchPri.Eoff_data = [ ...
    0 0.0001079 0.0002792 0.0006058 0.001107 0.001708; ...
    0 0.0001046 0.0002706 0.0005872 0.001073 0.001655; ...
    0 0.0001303 0.0003368 0.000731 0.001336 0.002061; ...
    0 0.0001433 0.0003705 0.0008041 0.00147 0.002267; ...
    0 0.0001433 0.0003705 0.0008041 0.00147 0.002267];
%%
%[text] %[text:anchor:H_pri_diode] ### Primary Body Diode Data
%[text] The body diode forward voltage is tabulated against junction temperature and forward current.
DAB.SwitchPri.diode_TjVec = [-55 25 150 900 1000];   % degC, Junction temperature breakpoints
DAB.SwitchPri.diode_IfVec = [0 1.516 5.33 14.93 39.07 99.82];   % A, Forward current breakpoints
% V, Forward voltage Vf(Tj, If)
DAB.SwitchPri.diode_VfMat = [ ...
    0 3.294 3.769 4.385 5.249 6.672; ...
    0 2.997 3.415 3.921 4.714 5.992; ...
    0 2.624 2.988 3.498 4.274 5.6; ...
    0 2.362 2.689 3.148 3.847 5.04; ...
    0 2.362 2.689 3.148 3.847 5.04];
%%
%[text] %[text:anchor:H_sec] ## Secondary Device Data
%[text] The four secondary bridge devices use this datasheet data: the channel conduction table, the switching loss tables, the body diode table and the junction thermal properties.
%[text] %[text:anchor:H_sec_rating] ### Secondary Device Ratings and Thermal Properties
%[text] The junction thermal mass and the junction to case thermal resistance set how fast the junction temperature rises.
DAB.SwitchSec.Vth                   = 3.2;     % V, Gate threshold voltage
DAB.CossSec                         = 2e-10;   % F, Output capacitance (Coss)
DAB.SwitchSec.junction_thermal_mass = 0.1;     % J/K, Junction thermal mass
DAB.SwitchSec.R                     = 0.001;   % K/W, Junction to case thermal resistance
DAB.simTempSec                      = DAB.HeatsinkSec.initialTemperature;   % degC, Initial junction temperature
%%
%[text] %[text:anchor:H_sec_elec] ### Secondary Electrical Switch Data
%[text] The MOSFET Model block conducts through an on-state resistance and a body diode with a forward voltage and an on resistance.
DAB.SwitchSec.Rds        = 0.044;                  % Ohm, On-state resistance
DAB.SwitchSec.Goff       = 8.33333333333333e-13;   % S, Off-state conductance
DAB.SwitchSec.diode_Vf   = 2.72;                   % V, Body diode forward voltage
DAB.SwitchSec.diode_Ron  = 0.023;                  % Ohm, Body diode on resistance
DAB.SwitchSec.diode_Goff = 1e-05;                  % S, Body diode off-state conductance
%%
%[text] %[text:anchor:H_sec_cond] ### Secondary Channel Conduction Data
%[text] The on-state voltage is tabulated against junction temperature and drain-source current.
DAB.SwitchSec.Tj = [-55 25 150 900];   % degC, Junction temperature breakpoints
% A, Drain-source current breakpoints
DAB.SwitchSec.Iout_data = [ ...
    -99.94 -39.11 -14.94 -5.333 -1.517 0 1.517 5.334 14.94 39.12 99.97];
% V, On-state voltage Vds(Tj, Ids)
DAB.SwitchSec.Von_data = [ ...
    -3.075 -1.321 -0.5334 -0.2017 -0.05735 0 0.05654 0.1988 0.6074 1.756 5.672; ...
    -4.404 -1.709 -0.657 -0.2346 -0.0667 0 0.06456 0.227 0.6342 1.831 6.194; ...
    -4.759 -3.111 -1.191 -0.4253 -0.1209 0 0.1049 0.369 1.1 3.268 12.47; ...
    -5.366 -4.667 -1.787 -0.638 -0.1813 0 0.1573 0.5535 1.65 4.902 18.71];
%%
%[text] %[text:anchor:H_sec_loss] ### Secondary Switching Loss Data
%[text] The turn-on and turn-off energy are tabulated against junction temperature and drain-source current, at an off-state voltage of 800 V. The energy scales linearly with the drain-source voltage at the switching instant.
DAB.SwitchSec.Tj_loss = [-55 25 150 900 1000];   % degC, Junction temperature breakpoints
DAB.SwitchSec.Iout_data_loss = [0 16.04 32.08 48.12 64.15 80.19];   % A, Drain-source current breakpoints
DAB.SwitchSec.Voff = 800;   % V, Off-state voltage of the loss data
% J, Turn-on loss Eon(Tj, Ids)
DAB.SwitchSec.Eon_data = [ ...
    0 0.000253 0.0007404 0.001481 0.002418 0.003535; ...
    0 0.0002341 0.000685 0.00137 0.002237 0.00327; ...
    0 0.0002172 0.0006356 0.001272 0.002076 0.003035; ...
    0 0.0001955 0.000572 0.001145 0.001868 0.002732; ...
    0 0.0001955 0.000572 0.001145 0.001868 0.002732];
% J, Turn-off loss Eoff(Tj, Ids)
DAB.SwitchSec.Eoff_data = [ ...
    0 0.0001079 0.0002792 0.0006058 0.001107 0.001708; ...
    0 0.0001046 0.0002706 0.0005872 0.001073 0.001655; ...
    0 0.0001303 0.0003368 0.000731 0.001336 0.002061; ...
    0 0.0001433 0.0003705 0.0008041 0.00147 0.002267; ...
    0 0.0001433 0.0003705 0.0008041 0.00147 0.002267];
%%
%[text] %[text:anchor:H_sec_diode] ### Secondary Body Diode Data
%[text] The body diode forward voltage is tabulated against junction temperature and forward current.
DAB.SwitchSec.diode_TjVec = [-55 25 150 900 1000];   % degC, Junction temperature breakpoints
DAB.SwitchSec.diode_IfVec = [0 1.516 5.33 14.93 39.07 99.82];   % A, Forward current breakpoints
% V, Forward voltage Vf(Tj, If)
DAB.SwitchSec.diode_VfMat = [ ...
    0 3.294 3.769 4.385 5.249 6.672; ...
    0 2.997 3.415 3.921 4.714 5.992; ...
    0 2.624 2.988 3.498 4.274 5.6; ...
    0 2.362 2.689 3.148 3.847 5.04; ...
    0 2.362 2.689 3.148 3.847 5.04];
%%
%[text] %[text:anchor:H_ctrl] ## Controller Data
%[text] The controller data sets the two cascaded PI loops, the phase shift limits, the gate drive voltage and the controller sample time.
DABController.voltageLoopProportionalGain = 0.0075;   % -, Output voltage loop proportional gain
DABController.voltageLoopIntegralGain     = 400;      % -, Output voltage loop integral gain
DABController.currentLoopProportionalGain = 0.0008;   % -, Current loop proportional gain
DABController.currentLoopIntegralGain     = 600;      % -, Current loop integral gain
DABController.phaseShiftMin               = -pi/2;    % rad, Minimum phase shift
DABController.phaseShiftMax               = pi/2;     % rad, Maximum phase shift
DABController.gateVoltage                 = 15;       % V, Gate drive voltage
DABController.sampleTime                  = 1e-07;    % s, Controller sample time
%%
%[text] %[text:anchor:H_design] ## Design Data
%[text] The controller normalizes its voltage and power signals against these values, and it takes the switching frequency and the dead time from them.
DABDesign.V2nom              = simscape.Value(525, "V");   % Nominal output voltage, the voltage base
DABDesign.ratedPower         = simscape.Value(10000, "W");   % Rated power, the power base
DABDesign.switchingFrequency = simscape.Value(100000, "Hz");   % Bridge switching frequency
DABDesign.deadTime           = simscape.Value(4.3943253825073928e-07, "s");   % Bridge dead time
%[text] Copyright 2026 The MathWorks, Inc.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
