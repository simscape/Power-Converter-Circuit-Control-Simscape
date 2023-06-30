function outputTable = PlotCompareFaultRideThroughMethod(testCondition, plotFlag)
    % Copyright 2023 The MathWorks, Inc.

    testConditionSelected = testCondition; % Storing the selected test condition
    
    % Input the grid-forming converter parameters
    run("GridFormingConverterInputParameters.mlx");
    
    testCondition.activePowerMethod = testConditionSelected.activePowerMethod;
    testCondition.currentLimitMethod = testConditionSelected.currentLimitMethod;
    testCondition.testCondition = testConditionSelected.testCondition;
    testCondition.XbyR = testConditionSelected.XbyR;
    testCondition.SCR = testConditionSelected.SCR;
    
    % Input to the test condition data
    run('GridFormingConverterTestCondition.mlx');

    % Defining Simulink simulation input
    simIn = Simulink.SimulationInput('GridFormingConverter');

    % Setting up the current limiting method
    %% Virtual Impedance Method
    testCondition.currentLimitMethodSelected = 'Virtual Impedance' ;
    set_param([bdroot,'/Grid-Forming Converter/Grid-Forming Converter Control'],'currentLimit',testCondition.currentLimitMethodSelected);
    
    % Setting up the simulation test condition
    simIn = setVariable(simIn,'testCondition',testCondition);

    % Running the simulation
    outData = sim(simIn);
    
    if plotFlag>0
        figure('Name', 'GridFormingConverterCompareFaultRideMethod');
        set(gcf, 'Position',  [400, 300, 800, 650]);
        hold all
    end
    outputTable = plotCurrentLimitingMethod(testCondition, disturbanceTime, outData,plotFlag,[1 4 7]);
    
    %% Current Limiting Method
    testCondition.currentLimitMethodSelected = 'Current Limiting' ;
    set_param([bdroot,'/Grid-Forming Converter/Grid-Forming Converter Control'],'currentLimit',testCondition.currentLimitMethodSelected);
    
    % Setting up the simulation test condition
    simIn = setVariable(simIn,'testCondition',testCondition);

    % Running the simulation
    outData = sim(simIn);

    outputTable(2,1:6) = plotCurrentLimitingMethod(testCondition, disturbanceTime,outData,plotFlag,[2 5 8]);
    
    %% Combining Virtual Impedance and Current Limiting
    testCondition.currentLimitMethodSelected = 'Virtual Impedance and Current Limiting' ;
    set_param([bdroot,'/Grid-Forming Converter/Grid-Forming Converter Control'],'currentLimit',testCondition.currentLimitMethodSelected);
    
    % Setting up the simulation test condition
    simIn = setVariable(simIn,'testCondition',testCondition);

    % Running the simulation
    outData = sim(simIn);
    
    outputTable(3,1:6) = plotCurrentLimitingMethod(testCondition, disturbanceTime, outData,plotFlag,[3 6 9]);
    
    disp('Steady State Grid-Forming Converter Output to Compare Fault Ride-Through Methods');
    disp(outputTable);
    end
    
    function outputTable = plotCurrentLimitingMethod(testCondition,disturbanceTime,outData,plotFlag,subplotNum)
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
    testListCtLimit = testCondition.currentLimitMethodSelected;
    
    TestName = string(testListCtLimit); ActivePower = [outValue.P]'; ReactivePower = [outValue.Q]';
    Voltage = [outValue.V]'; Current = [outValue.I]'; TestResult = string(outValue.testOutcome);
    outputTable=table(TestName,ActivePower,ReactivePower,Voltage,Current,TestResult);
    
    if plotFlag>0
    
        subplot(3,3,subplotNum(1))
        plot(timeArrayIgq,Is, 'LineWidth',2);
        xlim([disturbanceTime*0.8, timeArrayVgd(end)]);
        grid on
        xlabel('time (s)');
        ylabel('Peak Current (pu)');
    
        if contains( testCondition.currentLimitMethodSelected, 'Virtual Impedance') && ...
                ~contains( testCondition.currentLimitMethodSelected, 'and')
            title(sprintf('Virtual Impedance \n GFM Peak Current'));
        elseif contains( testCondition.currentLimitMethodSelected, 'Current Limiting') && ...
                ~contains( testCondition.currentLimitMethodSelected, 'and')
            title(sprintf('Current Limiting \n GFM Peak Current'));
        else
            title(sprintf('Combining Both Method \n GFM Peak Current'));
        end
    
        box on
        hold all
    
        subplot(3,3,subplotNum(2))
        timeStart = disturbanceTime-2*1/50;
        timeEnd = disturbanceTime+12*1/50; % s
        plot(timeArrayIabc,Iabc,'LineWidth',1);
        xlim([timeStart timeEnd]);
        grid on
        xlabel('time (s)');
        ylabel('Current (pu)');
        title('Virtual Impedance GFM Current ')
        box on
        hold all
    
        subplot(3,3,subplotNum(3))
        plot(timeArrayVabc,Vabc,'LineWidth',1);
        ylim([-1.3  1.3]);
        xlim([timeStart timeEnd]);
        grid on
        xlabel('time (s)');
        ylabel('Voltage (pu)');
        title('Virtual Impedance Voltage')
        box on
        hold all
    end
end

