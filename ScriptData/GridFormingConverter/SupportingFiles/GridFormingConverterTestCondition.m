%[text] %[text:anchor:T_76D33CB4] # Input Test Conditions for Grid-Forming Converter
%[text:tableOfContents]{"heading":"Table of Contents"}
%[text] This file sets the required test condition variables as the time-table data. You can change the test variables over the entire simulation time. This time profile input is fed into the model using the from workspace Simulink© block, it allows you to choose the proper interpolation technique,
%[text] %[text:anchor:H_C67F7C14] ## Simulation and Disturbance Time
%[text] The example provides two fidelity levels for the GFM converter power circuit: average and two‑level switching. To set the fidelity level, specify `"Average"` or `"Switching"` for the `Converter` name-value argument of the `setGFMConverterModelFidelity` function, respectively. It also set the suitable model sample time.

simulationTime = 8;             % s, Total simulation time
disturbanceTime = 3;            % s, Time at which disturbance is included
[gridInverter, localSolverSampleTime] = setGFMConverterModelFidelity(Converter="Average",SampleTime=simscape.Value(1e-4,"s")); % Selecting average converter model
%[text] %[text:anchor:H_BE42EAB8] ## Compute the Short Circuit Ratio, X/R Ratio Scale Factor
%[text] To achieve the required short circuit ratio and X/R ratio, you need to scale the grid source impedance, transmission line and transformer impedances appropriately.
realPart = real(shortCircuit.overallGridImpedance);
imaginaryPart = imag(shortCircuit.overallGridImpedance);
XbyRtempFactor = sqrt(1+testCondition.XbyR^2);

scrFactorRg = 1/(testCondition.SCR*realPart*XbyRtempFactor);
scrFactorXg = testCondition.XbyR*scrFactorRg*realPart/imaginaryPart;

scrOut = 1/sqrt((scrFactorRg*realPart)^2+(scrFactorXg*imaginaryPart)^2);
XbyROut = scrFactorXg*imaginaryPart/(scrFactorRg*realPart);
%[text] %[text:anchor:H_5A9C8D47] ## Setting Up the Model
% Setting the current limiting and active power method
set_param([bdroot,'/Grid-Forming Converter/Grid-Forming Converter Control'],'powerControl',testCondition.activePowerMethod);
set_param([bdroot,'/Grid-Forming Converter/Grid-Forming Converter Control'],'currentLimit',testCondition.currentLimitMethod);
set_param([bdroot,'/Grid-Forming Converter/Grid-Forming Converter Control'],'freqOption',gridInverter.vsm.dampingPowerOption);
%[text] %[text:anchor:H_E1F3CD97] ## Normal Operation Test Parameters
%[text] Test condition variables for normal operating condition without any disturbances.
% Default input for normal operation in pu
gridVoltageProfileVal = [1 1 1]; % pu, Grid voltage array
gridVoltageProfileTime = [0 disturbanceTime simulationTime]; % s, Time array

gridFrequencyProfileVal = [50 50 50]; % Hz, Grid frequency, linear interpolation applied
gridFrequencyProfileTime = [0 disturbanceTime simulationTime]; % s, Time array

gridPhaseProfileVal = [0 0 0]; % degrees, Grid phase
gridPhaseProfileTime = [0 disturbanceTime simulationTime]; % s, Time array

gfmRealPowerRefProfileVal = [0 0.5 0.5 0.5]; % pu, Active power reference, linear interpolation applied
gfmRealPowerRefProfileTime = [0 1 disturbanceTime simulationTime]; % s, Time array

gfmReactivePowerRefProfileVal = [0 0.3 0.3 0.3];  % pu, Reactive power reference, linear interpolation applied
gfmReactivePowerRefProfileTime = [0 1 disturbanceTime simulationTime]; % s, Time array

localLoadRealProfileVal = [0.7 0.7 0.7 0.7]; % pu, Load active power
localLoadRealProfileTime = [0 disturbanceTime disturbanceTime+1e-1 simulationTime];  % s, Time array

localLoadReactiveProfileVal = [0.4 0.4 0.4];  % pu, Load reactive power
localLoadReactiveProfileTime = [0 disturbanceTime simulationTime];  % s, Time array

faultTriggerVal = [0 0 0]; % Three-phase ground fault trigger
faultTriggerTime = [0 disturbanceTime simulationTime];  % s, Time array

circuitBreakerTripSignalVal = [0 0 0]; % Grid circuit breaker trip signal
circuitBreakerTripSignalTime = [0 disturbanceTime simulationTime];  % s, Time array

testCondition.faultResistance = 0.5; % ohm, Fault resistance
%[text] %[text:anchor:H_1F940A3B] ## Configure Different Test Scenarios
%[text] The required disturbances are defined in the appropriate test condition variables.
switch testCondition.testCondition
    case 'Normal operation'

%[text] %[text:anchor:H_EBA8462D] ### Change in Active Power Reference
    case 'Change in active power reference'
        gfmRealPowerRefProfileVal = [0 0.6 0.6 0.8 0.8];
        gfmRealPowerRefProfileTime = [0 1 disturbanceTime-1e-3 disturbanceTime simulationTime];

        gfmReactivePowerRefProfileVal = [0 0.3 0.3 0.3];
        gfmReactivePowerRefProfileTime = [0 1 disturbanceTime simulationTime];
%[text] %[text:anchor:H_E910C04B] ### Change in Reactive Power Reference
    case 'Change in reactive power reference'
        gfmReactivePowerRefProfileVal = [0 0.2 0.2 0.4 0.4];
        gfmReactivePowerRefProfileTime = [0 1 disturbanceTime-1e-1 disturbanceTime simulationTime];

        gfmRealPowerRefProfileVal = [0 0.5 0.5 0.5 0.5];
        gfmRealPowerRefProfileTime = [0 1 disturbanceTime-1e-1 disturbanceTime simulationTime];
%[text] %[text:anchor:H_9C124407] ### Change in Grid Voltage
    case 'Change in grid voltage'
        gridVoltageProfileVal = [1 0.9 0.9]; % in pu
        gridVoltageProfileTime = [0 disturbanceTime simulationTime];

%[text] %[text:anchor:H_2B347A4D] ### Change in Local Load
    case 'Change in local load'
        localLoadRealProfileVal = [0.4 0.7 0.7];
        localLoadRealProfileTime = [0 disturbanceTime simulationTime];

        localLoadReactiveProfileVal = [0.1 0.1 0.1];
        localLoadReactiveProfileTime = [0 disturbanceTime simulationTime];
%[text] %[text:anchor:H_9BAAA741] ### Change in Grid Frequency 0.5Hz

    case 'Change in grid frequency 1Hz/s, +0.5Hz'
        gridFrequencyProfileVal = [50 50 50.5 50.5];
        gridFrequencyProfileTime = [0 disturbanceTime disturbanceTime+0.5 simulationTime];

%[text] %[text:anchor:H_5D8B16B1] ### Large Change in Grid Frequency
    case 'Change in grid frequency 2Hz/s, +2Hz'
        gridFrequencyProfileVal = [50 50 52 52];
        gridFrequencyProfileTime = [0 disturbanceTime disturbanceTime+1 simulationTime];

        gfmRealPowerRefProfileVal = [0 0.75 0.75 0.75 0.75];
        gfmRealPowerRefProfileTime = [0 1 disturbanceTime-1e-3 disturbanceTime simulationTime];

        gfmReactivePowerRefProfileVal = [0 0 0];
        gfmReactivePowerRefProfileTime = [0 disturbanceTime simulationTime];
        localLoadRealProfileVal = [0.2 0.2 0.2]; 
        localLoadRealProfileTime = [0 disturbanceTime simulationTime];  
        localLoadReactiveProfileVal = [0 0 0];  
        localLoadReactiveProfileTime = [0 disturbanceTime simulationTime]; 

%[text] %[text:anchor:H_AEA114B8] ### Full Range Change in Grid Frequency

    case 'Change in grid frequency 2Hz/s, +2Hz and 1Hz/s till -5Hz'
        simulationTime = 20; % seconds
        gridFrequencyProfileVal = [50 50 52 52 47 47];
        gridFrequencyProfileTime = [0 disturbanceTime disturbanceTime+1 disturbanceTime+6 disturbanceTime+11 simulationTime];

        gfmRealPowerRefProfileVal = [0 0.75 0.75 0.75 0.75];
        gfmRealPowerRefProfileTime = [0 1 disturbanceTime-1e-3 disturbanceTime simulationTime];

        gfmReactivePowerRefProfileVal = [0 0 0];
        gfmReactivePowerRefProfileTime = [0  disturbanceTime simulationTime];

        localLoadRealProfileVal = [0.2 0.2 0.2]; 
        localLoadRealProfileTime = [0 disturbanceTime simulationTime];  
        localLoadReactiveProfileVal = [0 0 0];  
        localLoadReactiveProfileTime = [0 disturbanceTime simulationTime];  

%[text] %[text:anchor:H_F3EF9080] ### 10deg Grid Voltage Phase Jump

    case 'Change in grid phase by 10 degrees'
        gridPhaseProfileVal = [0 10 10]; % degree
        gridPhaseProfileTime = [0 disturbanceTime simulationTime];

        gfmRealPowerRefProfileVal = [0.75 0.75 0.75];
        gfmRealPowerRefProfileTime = [0 disturbanceTime simulationTime];
        gfmReactivePowerRefProfileVal = [0 0 0];
        gfmReactivePowerRefProfileTime = [0 disturbanceTime simulationTime];

%[text] %[text:anchor:H_72BF5F25] ### 60deg Grid Voltage Phase Jump
    case 'Change in grid phase by 60 degrees'
        simulationTime = 10; % seconds
        gridPhaseProfileVal = [0 60 60]; % degree
        gridPhaseProfileTime = [0 disturbanceTime simulationTime];

        gfmRealPowerRefProfileVal = [0 0.75 0.75 0.75];
        gfmRealPowerRefProfileTime = [0 1 disturbanceTime simulationTime];
        gfmReactivePowerRefProfileVal = [0 0 0];
        gfmReactivePowerRefProfileTime = [0 disturbanceTime simulationTime];

%[text] %[text:anchor:H_2D8EFDB4] ### Permanent Three-Phase Fault

    case 'Permanent three-phase fault'
        testCondition.faultResistance = 0.15; % ohm
        faultTriggerVal = [0 1 1 1];
        faultTriggerTime = [0 disturbanceTime disturbanceTime+2 simulationTime];

        gfmRealPowerRefProfileVal = [0 0.75 0.75 0.75];
        gfmRealPowerRefProfileTime = [0 1 disturbanceTime simulationTime];
        gfmReactivePowerRefProfileVal = [0.4 0.4 0.4];
        gfmReactivePowerRefProfileTime = [0 disturbanceTime simulationTime];
%[text] %[text:anchor:H_B207B7DD] ### Temporary Three-Phase Fault

    case 'Temporary three-phase fault'
        testCondition.faultResistance = 0.2; % ohm
        faultTriggerVal = [0 1 0 0];
        faultTriggerTime = [0 disturbanceTime disturbanceTime+2 simulationTime];

        gfmRealPowerRefProfileVal = [0 0.75 0.75 0.75 0 0.75 0.75];
        gfmRealPowerRefProfileTime = [0 1 disturbanceTime disturbanceTime+2 disturbanceTime+2.1 disturbanceTime+3.5 simulationTime];
        gfmReactivePowerRefProfileVal = [0.4 0.4 0.4];
        gfmReactivePowerRefProfileTime = [0 disturbanceTime simulationTime];
%[text] %[text:anchor:H_DBF3A514] ### Islanding Operation
    case 'Islanding condition'
        circuitBreakerTripSignalVal = [0 1 1]; 
        circuitBreakerTripSignalTime = [0 disturbanceTime simulationTime];  

        gfmRealPowerRefProfileVal = [0 0.6 0.6 0.8 0.8];
        gfmRealPowerRefProfileTime = [0 1 disturbanceTime-1e-3 disturbanceTime simulationTime];

        gfmReactivePowerRefProfileVal = [0 0.3 0.3 0.3];
        gfmReactivePowerRefProfileTime = [0 1 disturbanceTime simulationTime];

        localLoadRealProfileVal = [0.9 0.9 0.9];
        localLoadRealProfileTime = [0 disturbanceTime simulationTime];

        localLoadReactiveProfileVal = [0.4 0.4 0.4];
        localLoadReactiveProfileTime = [0 disturbanceTime simulationTime];
    otherwise
        disp('Select the proper test condition')
end
%[text] %[text:anchor:H_9C6CE655] ### Forming Test Condition Time Table
testCondition.gridVoltageProfile = timetable(gridVoltageProfileVal','RowTimes',seconds(gridVoltageProfileTime')); %[text:anchor:M_7B962347]
testCondition.gridFrequencyProfile = timetable(gridFrequencyProfileVal','RowTimes',seconds(gridFrequencyProfileTime'));
testCondition.gridPhaseProfile = timetable(gridPhaseProfileVal','RowTimes',seconds(gridPhaseProfileTime'));
testCondition.gfmRealPowerRefProfile = timetable(gfmRealPowerRefProfileVal','RowTimes',seconds(gfmRealPowerRefProfileTime'));
testCondition.gfmReactivePowerRefProfile = timetable(gfmReactivePowerRefProfileVal','RowTimes',seconds(gfmReactivePowerRefProfileTime'));
testCondition.localLoadRealProfile = timetable(localLoadRealProfileVal','RowTimes',seconds(localLoadRealProfileTime'));
testCondition.localLoadReactiveProfile = timetable(localLoadReactiveProfileVal','RowTimes',seconds(localLoadReactiveProfileTime'));
testCondition.faultTrigger = timetable(faultTriggerVal','RowTimes',seconds(faultTriggerTime'));
testCondition.circuitBreakerTripSignalProfile = timetable(circuitBreakerTripSignalVal','RowTimes',seconds(circuitBreakerTripSignalTime'));

clear gridVoltageProfileVal gridVoltageProfileTime
clear gridFrequencyProfileVal gridFrequencyProfileTime
clear gridVoltageProfileVal gridVoltageProfileTime
clear gridFrequencyProfileVal gridFrequencyProfileTime
clear gridPhaseProfileVal gridPhaseProfileTime
clear gfmRealPowerRefProfileVal gfmRealPowerRefProfileTime
clear gfmControllerRippleInjectMagVal gfmControllerRippleInjectMagTime
clear gfmControllerRippleInjectFreqVal gfmControllerRippleInjectFreqTime
clear gfmReactivePowerRefProfileVal gfmReactivePowerRefProfileTime
clear localLoadRealProfileVal localLoadRealProfileTime
clear localLoadReactiveProfileVal localLoadReactiveProfileTime
clear faultTriggerVal faultTriggerTime
clear circuitBreakerTripSignalVal circuitBreakerTripSignalTime
%%
%[text] Copyright 2023 The MathWorks, Inc.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":11.4}
%---
