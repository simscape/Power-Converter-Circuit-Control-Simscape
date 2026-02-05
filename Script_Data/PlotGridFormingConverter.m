
% This MATLAB function plots the simulation results of the GridFormingConverter model  
% Copyright 2023 The MathWorks, Inc.
function outputTable = PlotGridFormingConverter(testCondition,plotFlag,varargin)
testConditionSelected = testCondition; % Storing the selected test condition
if nargin>2
    if strcmp(varargin(1),'All')
        testList = {'Normal operation';...
            'Change in active power reference';...
            'Change in reactive power reference';...
            'Change in grid voltage';...
            'Change in local load';...
            'Change in grid frequency 1Hz/s, +0.5Hz';...
            'Change in grid frequency 2Hz/s, +2Hz';...
            'Change in grid frequency 2Hz/s, +2Hz and 1Hz/s till -5Hz';...
            'Change in grid phase by 10 degrees';...
            'Change in grid phase by 60 degrees';...
            'Permanent three-phase fault';...
            'Temporary three-phase fault';...
            'Islanding condition';...
            };
    else
        error('Provide proper parameter in the plot function');
    end
else
    testList = {testConditionSelected.testCondition};
end

% Setting up the grid-forming converter parameters
run("GridFormingConverterInputParameters.mlx");

% Applying the original test condition
testCondition.activePowerMethod = testConditionSelected.activePowerMethod;
testCondition.currentLimitMethod = testConditionSelected.currentLimitMethod;
testCondition.testCondition = testConditionSelected.testCondition;
testCondition.XbyR = testConditionSelected.XbyR;
testCondition.SCR = testConditionSelected.SCR;

count = 0;
testNameList = cell(1,length(testList));

% Defining function output variable
outValue = struct('P',0,'Q',0,'F',0,'V',0,'I',0,'testOutcome','Initialization');

% Defining Simulink simulation input
simIn = Simulink.SimulationInput('GridFormingConverter');

for i = 1:length(testList)
    testCondition.testCondition = testList{i};

    % Setting up the test conditions
    run('GridFormingConverterTestCondition.mlx');
   
    % Setting up the simulation test condition
    simIn = setVariable(simIn,'testCondition',testCondition);
    simIn = setModelParameter(simIn,StopTime=num2str(simulationTime));

    % Running the simulation
    outData = sim(simIn);

    timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
    if timeArrayPmeas(end)<disturbanceTime
        disturbanceTime = timeArrayPmeas(end)*0.9;
    end
    %% Selecting the required test condition
    switch testCondition.testCondition
        case 'Normal operation'

            count = count+1;
            outValue(count) = plotNormalOperation(outData,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

        case 'Change in active power reference'
            % Change in Active Power Reference
            count = count+1;
            outValue(count) = plotActivePowerReferenceChange(outData,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

        case 'Change in reactive power reference'
            % Change in Reactive Power Reference
            count = count+1;
            outValue(count) = plotReactivePowerReferenceChange(outData,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

        case 'Change in grid voltage'
            % Change in Grid Voltage
            count = count+1;
            outValue(count) = plotGridVoltageChange(outData,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

        case 'Change in local load'
            % Change in Local Load
            count = count+1;
            outValue(count) = plotLocalLoadChange(outData,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

        case 'Change in grid frequency 1Hz/s, +0.5Hz'
            % Change in grid Frequency
            count = count+1;
            outValue(count) = plotGridFrequencySmallChange(outData,testCondition,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};


        case 'Change in grid frequency 2Hz/s, +2Hz'
            % Large change in grid Frequency
            count = count+1;
            outValue(count) = plotGridFrequencyLargeChange(outData,testCondition,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

        case 'Change in grid frequency 2Hz/s, +2Hz and 1Hz/s till -5Hz'
            % Full range change in grid Frequency
            count = count+1;
            outValue(count) = plotGridFrequencyFullChange(outData,testCondition,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};


        case 'Change in grid phase by 10 degrees'
            % 10deg grid voltage phase jump
            count = count+1;
            outValue(count) = plotGridPhase10DegChange(outData,testCondition,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

        case 'Change in grid phase by 60 degrees'
            % 60deg grid voltage phase jump
            count = count+1;
            outValue(count) = plotGridPhase60DegChange(outData,testCondition,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

        case 'Permanent three-phase fault'
            % Permanent three-phase fault
            count=count+1;
            outValue(count) = plotPermanentThreePhaseFault(outData,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

        case 'Temporary three-phase fault'
            % Temporary three-phase fault
            count=count+1;
            outValue(count) = plotTemporaryThreePhaseFault(outData,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};

            % Islanding operation
        case 'Islanding condition'
            count=count+1;
            outValue(count) = plotIslandedCondition(outData,disturbanceTime,plotFlag);
            testNameList{count} = testList{count};
        otherwise
            disp('Select the proper test condition')
    end
end

TestName = string(testNameList'); ActivePower = [outValue.P]'; ReactivePower = [outValue.Q]';
Voltage = [outValue.V]'; Current = [outValue.I]'; TestResult = string({outValue.testOutcome}');
outputTable = table(TestName,ActivePower,ReactivePower,Voltage,Current,TestResult);
if nargin>2
    if strcmp(varargin(1),'All')
        outputTableTemp = table(TestName,ActivePower,ReactivePower,TestResult);
        clear outputTable
        outputTable = outputTableTemp;
    end
end
format default
disp('Steady State Grid-Forming Converter Output Measurement in pu');
disp(outputTable);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%% Functions To Plot the Simulation Results  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function outValue = plotNormalOperation(outData,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu


timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);


if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterNormalOperation');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(2,2,1)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    ylim([0 1]);
    grid on
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(2,2,2)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);
    grid on
    xlabel('time (s)');
    ylim([0 1]);
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on

    subplot(2,2,3)
    plot(timeArrayVabc,Vabc, 'LineWidth',2);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage');
    xlim([timeArrayVabc(end)*0.99,timeArrayVabc(end)]);
    box on
    hold on

    subplot(2,2,4)
    plot(timeArrayIabc,Iabc, 'LineWidth',2);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    xlim([timeArrayIabc(end)*0.99,timeArrayIabc(end)]);
    box on
    hold on
    figTitle = 'Normal GFM Operation';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotActivePowerReferenceChange(outData,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayPref = outData.LogsoutGridFormingConverter.get('Pref').Values.Time; % s
Pref = reshape(outData.LogsoutGridFormingConverter.get('Pref').Values.Data,[1,length(timeArrayPref)]); % pu

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterActivePowerChange');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(2,2,1)
    plot(timeArrayPref,Pref, 'LineWidth',2);
    hold on
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on
    legend('Pref','Pmeas');

    subplot(2,2,2)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on
    subplot(2,2,3)
    timeStart = disturbanceTime-2*1/50; % s
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(2,2,4)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on

    figTitle = 'Change in Active Power Reference';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotReactivePowerReferenceChange(outData,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

timeArrayQref = outData.LogsoutGridFormingConverter.get('Qref').Values.Time; % s
Qref = reshape(outData.LogsoutGridFormingConverter.get('Qref').Values.Data,[1,length(timeArrayQref)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterReactivePowerChange');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(2,2,1)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(2,2,2)
    plot(timeArrayQref,Qref, 'LineWidth',2);
    hold on
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on
    legend('Qref','Qmeas');

    subplot(2,2,3)
    timeStart = disturbanceTime-2*1/50;
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(2,2,4)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on

    figTitle = 'Change in Reactive Power Reference';
    figureTitle(figTitle,outValue);
end
end

function outValue = plotGridVoltageChange(outData,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayVgrid = outData.LogsoutGridFormingConverter.get('GridMag').Values.Time; % s
Vgrid = reshape(outData.LogsoutGridFormingConverter.get('GridMag').Values.Data,[1,length(timeArrayVgrid)]); % pu


timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterGridVoltageChange');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(3,2,1:2)
    plot(timeArrayVgrid,Vgrid, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayVgrid(end)]);
    xlabel('time (s)');
    ylabel('Grid Voltage (pu)');
    title('GFM Grid Internal Voltage')
    box on
    hold on

    subplot(3,2,3)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayVgrid(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(3,2,4)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayVgrid(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on

    subplot(3,2,5)
    timeStart = disturbanceTime-2*1/50; % s
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(3,2,6)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on
    figTitle = 'Change in Grid Internal Voltage';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotLocalLoadChange(outData,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayPloadref = outData.LogsoutGridFormingConverter.get('Ploadref').Values.Time; % s
Ploadref = reshape(outData.LogsoutGridFormingConverter.get('Ploadref').Values.Data,[1,length(timeArrayPloadref)]); % pu

timeArrayPload = outData.LogsoutGridFormingConverter.get('Pload').Values.Time; % s
Pload = reshape(outData.LogsoutGridFormingConverter.get('Pload').Values.Data,[1,length(timeArrayPload)]); % pu

timeArrayQloadref = outData.LogsoutGridFormingConverter.get('Qloadref').Values.Time; % s
Qloadref = reshape(outData.LogsoutGridFormingConverter.get('Qloadref').Values.Data,[1,length(timeArrayPloadref)]); % pu

timeArrayQload = outData.LogsoutGridFormingConverter.get('Qload').Values.Time; % s
Qload = reshape(outData.LogsoutGridFormingConverter.get('Qload').Values.Data,[1,length(timeArrayPload)]); % pu

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterLocalLoadChange');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(3,2,1)
    plot(timeArrayPloadref,Ploadref, 'LineWidth',2);
    hold on
    plot(timeArrayPload,Pload, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPload(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('Local Load Active Power');
    legend('Pref', 'Pmeas');
    box on
    hold on

    subplot(3,2,2)
    plot(timeArrayQloadref,Qloadref, 'LineWidth',2);
    hold on
    plot(timeArrayQload,Qload, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQload(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('Local Load Reactive Power');
    legend('Qref', 'Qmeas');
    box on
    hold on

    subplot(3,2,3)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(3,2,4)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on

    subplot(3,2,5)
    timeStart = disturbanceTime-2*1/50; % s
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(3,2,6)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on

    figTitle = 'Change in Local Load Power';
    figureTitle(figTitle,outValue);
end
end

function outValue = plotGridFrequencySmallChange(outData,testCondition,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayGridFreq = outData.LogsoutGridFormingConverter.get('GridFreq').Values.Time; % s
gridFreq = reshape(outData.LogsoutGridFormingConverter.get('GridFreq').Values.Data,[1,length(timeArrayGridFreq)]); % pu

if strcmp(testCondition.activePowerMethod, 'Virtual Synchronous Machine')
    timeArrayPdamping = outData.LogsoutGridFormingConverter.get('Pdamping').Values.Time; % s
    Pdamping = reshape(outData.LogsoutGridFormingConverter.get('Pdamping').Values.Data,[1,length(timeArrayPdamping)]); % pu
else
    timeArrayPdamping = timeArrayGridFreq; % s
    Pdamping = zeros(1,length(timeArrayGridFreq));
end

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterSmallGridFreqChange');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(3,2,1)
    plot(timeArrayGridFreq,gridFreq, 'LineWidth',2);
    hold on
    plot(timeArrayGridFreq,freq, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayGridFreq(end)]);
    xlabel('time (s)');
    ylabel('Frequency (Hz)');
    title('Small Change in Grid Frequency');
    legend('Grid','GFM');
    ylim([min(gridFreq)-2,max(gridFreq)+2]);
    box on
    hold on

    subplot(3,2,2)
    plot(timeArrayPdamping,Pdamping, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPdamping(end)]);

    xlabel('time (s)');
    ylabel('Power (pu)');
    title('Damping Power');
    box on
    hold on

    subplot(3,2,3)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    grid on
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(3,2,4)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);

    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on

    subplot(3,2,5)
    timeStart = disturbanceTime-2*1/50; % s
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(3,2,6)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on

    figTitle = 'Small Change (0.5Hz) in Grid Frequency with 1Hz/s';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotGridFrequencyLargeChange(outData,testCondition,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayGridFreq = outData.LogsoutGridFormingConverter.get('GridFreq').Values.Time; % s
gridFreq = reshape(outData.LogsoutGridFormingConverter.get('GridFreq').Values.Data,[1,length(timeArrayGridFreq)]); % pu

if strcmp(testCondition.activePowerMethod, 'Virtual Synchronous Machine')
    timeArrayPdamping = outData.LogsoutGridFormingConverter.get('Pdamping').Values.Time; % s
    Pdamping = reshape(outData.LogsoutGridFormingConverter.get('Pdamping').Values.Data,[1,length(timeArrayPdamping)]); % pu
else
    timeArrayPdamping = timeArrayGridFreq; % s
    Pdamping = zeros(1,length(timeArrayGridFreq));
end

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterLargeGridFreqChange');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(3,2,1)
    plot(timeArrayGridFreq,gridFreq, 'LineWidth',2);
    hold on
    plot(timeArrayGridFreq,freq, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayGridFreq(end)]);
    xlabel('time (s)');
    ylabel('Frequency (Hz)');
    title('Large Change in Grid Frequency');
    legend('Grid','GFM');
    ylim([min(gridFreq)-2,max(gridFreq)+2]);
    box on
    hold on

    subplot(3,2,2)
    plot(timeArrayPdamping,Pdamping, 'LineWidth',2);
    xlim([disturbanceTime*0.8 timeArrayPdamping(end)]);
    grid on
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('Damping Power');
    box on
    hold on

    subplot(3,2,3)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(3,2,4)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on

    subplot(3,2,5)
    timeStart = disturbanceTime-2*1/50; % s
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(3,2,6)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on

    figTitle = 'Large Change (2Hz) in Grid Frequency with 2Hz/s';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotGridFrequencyFullChange(outData,testCondition,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayGridFreq = outData.LogsoutGridFormingConverter.get('GridFreq').Values.Time; % s
gridFreq = reshape(outData.LogsoutGridFormingConverter.get('GridFreq').Values.Data,[1,length(timeArrayGridFreq)]); % pu

if strcmp(testCondition.activePowerMethod, 'Virtual Synchronous Machine')
    timeArrayPdamping = outData.LogsoutGridFormingConverter.get('Pdamping').Values.Time; % s
    Pdamping = reshape(outData.LogsoutGridFormingConverter.get('Pdamping').Values.Data,[1,length(timeArrayPdamping)]); % pu
else
    timeArrayPdamping = timeArrayGridFreq; % s
    Pdamping = zeros(1,length(timeArrayGridFreq));
end

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterFullGridFreqChange');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(3,2,1)
    plot(timeArrayGridFreq,gridFreq, 'LineWidth',2);
    hold on
    plot(timeArrayGridFreq,freq, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayGridFreq(end)]);
    xlabel('time (s)');
    ylabel('Frequency (Hz)');
    title('Full Change in Grid Frequency');
    legend('Grid','GFM');
    ylim([min(gridFreq)-2,max(gridFreq)+2]);
    box on
    hold on

    subplot(3,2,2)
    plot(timeArrayPdamping,Pdamping, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPdamping(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('Damping Power');
    box on
    hold on

    subplot(3,2,3)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(3,2,4)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on

    subplot(3,2,5)
    timeStart = disturbanceTime-2*1/50; % s
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(3,2,6)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on

    figTitle = 'Full Change in Grid Frequency +2Hz with 2Hz/s and -5Hz with 1Hz/s';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotGridPhase10DegChange(outData,testCondition,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayGridFreq = outData.LogsoutGridFormingConverter.get('GridFreq').Values.Time; % s
gridFreq = reshape(outData.LogsoutGridFormingConverter.get('GridFreq').Values.Data,[1,length(timeArrayGridFreq)]); % pu

timeArrayGridPhase = outData.LogsoutGridFormingConverter.get('GridPhase').Values.Time; % s
gridPhase = reshape(outData.LogsoutGridFormingConverter.get('GridPhase').Values.Data,[1,length(timeArrayGridPhase)]); % pu


if strcmp(testCondition.activePowerMethod, 'Virtual Synchronous Machine')
    timeArrayPdamping = outData.LogsoutGridFormingConverter.get('Pdamping').Values.Time; % s
    Pdamping = reshape(outData.LogsoutGridFormingConverter.get('Pdamping').Values.Data,[1,length(timeArrayPdamping)]); % pu
else
    timeArrayPdamping = timeArrayGridFreq; % s
    Pdamping = zeros(1,length(timeArrayGridFreq));
end

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverter10DegGridPhaseChange');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(3,2,1)
    plot(timeArrayGridPhase,gridPhase, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayGridPhase(end)]);
    xlabel('time (s)');
    ylabel('Phase (degree)');
    title('Grid Phase Angle');
    box on
    hold on

    subplot(3,2,2)
    plot(timeArrayGridFreq,freq, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayGridFreq(end)]);
    xlabel('time (s)');
    ylabel('Frequency (Hz)');
    title('GFM Frequency');
    ylim([min(gridFreq)-2,max(gridFreq)+2]);
    box on
    hold on

    subplot(3,2,3)
    plot(timeArrayPdamping,Pdamping, 'LineWidth',2);
    xlim([disturbanceTime*0.8 timeArrayPdamping(end)]);
    grid on
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('Damping Power');
    box on
    hold on

    subplot(3,2,4)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    hold on
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Active and Reactive Power Output')
    legend('Pmeas','Qmeas')
    box on
    hold on

    subplot(3,2,5)
    timeStart = disturbanceTime-2*1/50; % s
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(3,2,6)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on

    figTitle = '10 Degree Change in Grid Phase Angle';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotGridPhase60DegChange(outData,testCondition,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayGridFreq = outData.LogsoutGridFormingConverter.get('GridFreq').Values.Time; % s
gridFreq = reshape(outData.LogsoutGridFormingConverter.get('GridFreq').Values.Data,[1,length(timeArrayGridFreq)]); % pu

timeArrayGridPhase = outData.LogsoutGridFormingConverter.get('GridPhase').Values.Time; % s
gridPhase = reshape(outData.LogsoutGridFormingConverter.get('GridPhase').Values.Data,[1,length(timeArrayGridPhase)]); % pu


if strcmp(testCondition.activePowerMethod, 'Virtual Synchronous Machine')
    timeArrayPdamping = outData.LogsoutGridFormingConverter.get('Pdamping').Values.Time; % s
    Pdamping = reshape(outData.LogsoutGridFormingConverter.get('Pdamping').Values.Data,[1,length(timeArrayPdamping)]); % pu
else
    timeArrayPdamping = timeArrayGridFreq; % s
    Pdamping = zeros(1,length(timeArrayGridFreq));
end

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverter60DegGridPhaseChange');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(3,2,1)
    plot(timeArrayGridPhase,gridPhase, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayGridPhase(end)]);
    xlabel('time (s)');
    ylabel('Phase (degree)');
    title('Grid Phase Angle');
    box on
    hold on

    subplot(3,2,2)
    plot(timeArrayGridFreq,freq, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayGridFreq(end)]);
    xlabel('time (s)');
    ylabel('Frequency (Hz)');
    title('GFM Frequency');
    ylim([min(gridFreq)-2,max(gridFreq)+2]);
    box on
    hold on

    subplot(3,2,3)
    plot(timeArrayPdamping,Pdamping, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPdamping(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('Damping Power');
    box on
    hold on

    subplot(3,2,4)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    hold on
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Active and Reactive Power Output')
    legend('Pmeas','Qmeas')
    box on
    hold on

    subplot(3,2,5)
    timeStart = disturbanceTime-2*1/50; % s
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(3,2,6)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on

    figTitle = '60 Degree Change in Grid Phase Angle';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotPermanentThreePhaseFault(outData,disturbanceTime,plotFlag)

timeFaultSignal = outData.LogsoutGridFormingConverter.get('faultSignal').Values.Time; % pu
faultSignal = reshape(outData.LogsoutGridFormingConverter.get('faultSignal').Values.Data,[1,length(timeFaultSignal)]); % pu

timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);
if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterPermanentFault');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(3,2,1)
    plot(timeFaultSignal,faultSignal, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeFaultSignal(end)]);
    xlabel('time (s)');
    ylabel('Fault Trigger)');
    title('Fault Trigger Signal');
    box on
    hold on

    subplot(3,2,2)
    plot(timeArrayIgd,Is, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayIgd(end)]);
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('Fault Current');
    box on
    hold on

    subplot(3,2,3)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(3,2,4)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on

    subplot(3,2,5)
    timeStart = disturbanceTime-2/50; % s
    timeEnd = disturbanceTime+17/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('Voltage at Fault')
    box on
    hold on

    subplot(3,2,6)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('Current at Fault')
    box on
    hold on
    figTitle = 'Permanent Three-Phase Fault';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotTemporaryThreePhaseFault(outData,disturbanceTime,plotFlag)

timeFaultSignal = outData.LogsoutGridFormingConverter.get('faultSignal').Values.Time; % pu
faultSignal = reshape(outData.LogsoutGridFormingConverter.get('faultSignal').Values.Data,[1,length(timeFaultSignal)]); % pu

timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu

timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);
if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterTemporaryFault');
    set(gcf, 'Position',  [400, 300, 800, 700]);

    subplot(3,4,1:2)
    plot(timeFaultSignal,faultSignal, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeFaultSignal(end)]);
    xlabel('time (s)');
    ylabel('Fault Trigger)');
    title('Fault Trigger Signal');
    box on
    hold on

    subplot(3,4,3:4)
    plot(timeArrayIgd,Is, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayIgd(end)]);
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('Fault Current');
    box on
    hold on

    subplot(3,4,5:6)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(3,4,7:8)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on

    subplot(3,4,9)
    timeStart = disturbanceTime-2/50; % s
    timeEnd = disturbanceTime+17/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('Voltage at Fault')
    box on
    hold on

    subplot(3,4,11)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('Current at Fault')
    box on
    hold on

    subplot(3,4,10)
    timeStart = disturbanceTime+2-2/50; % s
    timeEnd = disturbanceTime+2+17/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('Voltage After Fault')
    box on
    hold on

    subplot(3,4,12)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('Current After Fault')
    box on
    hold on

    figTitle = 'Temporary Three-Phase Fault';
    figureTitle(figTitle,outValue);
end
end


function outValue = plotIslandedCondition(outData,disturbanceTime,plotFlag)
% Recording the output
timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu

timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu

timeArrayVabc = outData.LogsoutGridFormingConverter.get('Vabc').Values.Time; % s
Vabc = reshape(outData.LogsoutGridFormingConverter.get('Vabc').Values.Data,[3,length(timeArrayVabc)]); % pu

timeArrayIabc = outData.LogsoutGridFormingConverter.get('Iabc').Values.Time; % s
Iabc = reshape(outData.LogsoutGridFormingConverter.get('Iabc').Values.Data,[3,length(timeArrayIabc)]); % pu



timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu

timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu

timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz

timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu

timeArrayTripSignal = outData.LogsoutGridFormingConverter.get('Tripsignal').Values.Time; % s
tripSignal = reshape(outData.LogsoutGridFormingConverter.get('Tripsignal').Values.Data,[1,length(timeArrayTripSignal)]); % pu



Is = sqrt(Igd.*Igd+Igq.*Igq);
outValue.P = Pmeas(end);
outValue.Q = Qmeas(end);
outValue.F = freq(end);
outValue.V = Vgd(end);
outValue.I = Is(end);
outValue.testOutcome = FindTestOutCome(Pmeas, Vgd, freq);

if plotFlag>0
    % Plotting the result
    figure('Name', 'GridFormingConverterIslanding');
    set(gcf, 'Position',  [400, 300, 800, 700]);


    subplot(3,2,1)
    plot(timeArrayTripSignal,tripSignal, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayTripSignal(end)]);
    xlabel('time (s)');
    ylabel('Trip Signal (pu)');
    title('Grid Circuit Breaker Trip Signal');
    box on
    hold on

    subplot(3,2,2)
    plot(timeArrayFreq,freq, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayFreq(end)]);
    xlabel('time (s)');
    ylabel('Frequency (Hz)');
    title('GFM Frequency');
    box on
    hold on

    subplot(3,2,3)
    plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayPmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold on

    subplot(3,2,4)
    plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
    grid on
    xlim([disturbanceTime*0.8 timeArrayQmeas(end)]);
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold on

    subplot(3,2,5)
    timeStart = disturbanceTime-2*1/50; % s
    timeEnd = disturbanceTime+12*1/50; % s

    plot(timeArrayVabc,Vabc,'LineWidth',1);
    ylim([-1.3  1.3]);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage')
    box on
    hold on

    subplot(3,2,6)
    plot(timeArrayIabc,Iabc,'LineWidth',1);
    xlim([timeStart timeEnd]);
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current')
    box on
    hold on

    figTitle = 'Islanding Condition';
    figureTitle(figTitle,outValue);
end
end



function figureTitle(figTitle,outValue)
figure(gcf)

if ~contains(outValue.testOutcome, 'Unstable') && ~contains(outValue.testOutcome, 'Faulted')
    sgtitle(sprintf('%s \n (Test Result -> %s)',string(figTitle), outValue.testOutcome),'FontSize',13,'Color',[0,100,0]/256);
else
    sgtitle(sprintf('%s \n (Test Result -> %s)',string(figTitle), outValue.testOutcome),'FontSize',13,'Color',[139,0,0]/256);
end
end
