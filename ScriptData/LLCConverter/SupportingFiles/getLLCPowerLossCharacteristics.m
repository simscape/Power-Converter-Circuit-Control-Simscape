function lossData = getLLCPowerLossCharacteristics(ModelName,options)
%   This function estimates switching and conduction losses for primary MOSFETs,
%   conduction losses for secondary diodes, passive element losses, and overall
%   efficiency of an LLC resonant converter at a specified operating point.
%   It automatically configures the model, runs a simulation, and generates:
%       1. Bar chart of conduction and switching losses for each primary MOSFET.
%       2. Bar chart of conduction losses for each secondary diode.
%       3. Pie chart of percentage losses in inverter, rectifier, and passive elements.
%
%   Inputs:
%     ModelName       Name of the Simulink model (string or char).
%     options         Structure with the following optional fields:
%       .Vref         Reference output voltage (simscape.Value, default: 320 V).
%       .Vin          Input DC voltage (simscape.Value, default: 380 V).
%       .Pload        Output load power (simscape.Value, default: 5000 W).
%       .SimTime      Simulation time (simscape.Value, default: 0.01 s).
%
%   Outputs:
%     lossData        Structure with the following fields:
%       .mosfetName               Names of primary MOSFETs
%       .mosfetLossMatrix         Matrix of conduction, switching, and total losses (W)
%       .diodeName                Names of secondary diodes
%       .diodeLossMatrix          Matrix of diode conduction losses (W)
%       .InverterMOSFETLoss       Total inverter MOSFET loss (W)
%       .RectifierDiodeLoss       Total rectifier diode loss (W)
%       .passiveElements          Total passive element loss (W)
%       .outputPower              Output power (W)
%       .overallLoss              Total loss (W)
%       .efficiency               Converter efficiency (%)
%       .PercentageLossSummaryTable Table of loss distribution for pie chart
%
%   Notes:
%     - The model must use 'MOSFET (Ideal, Switching) with Thermal' as the primary
%       switching device and 'Tabulated Diode' as the secondary rectifier.
%     - The function requires auxiliary functions: setupLLCConverterModel and
%       ee_getPowerLossSummary.
%     - The function restores the original referenced subsystems after execution.
%
%   Example:
%     lossData = getLLCPowerLossCharacteristics("LLCConverterModel", ...
%                  Vref=simscape.Value(320,"V"), ...
%                  Vin=simscape.Value(400,"V"), ...
%                  Pload=simscape.Value(4000,"W"), ...
%                  SimTime=simscape.Value(0.02,"s"));

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    ModelName
    options.Vref (1,1)  = simscape.Value(320,"V"); % Reference voltage
    options.Vin (1,1)  = simscape.Value(380,"V"); % Input voltage
    options.Pload (1,1)  = simscape.Value(5000,"W"); % Output power
    options.SimTime (1,1) = simscape.Value(0.01,"s"); % Simulation time
end
load_system(ModelName);

% This code works for both masked LLC power circuit library block and the
% unmasked subsystem in the "LLCResonantConverterFullBridge" model
topLevelBlocks = find_system(ModelName, 'SearchDepth', 1, 'Type', 'block');
llcPowerCircuit = topLevelBlocks(contains(topLevelBlocks,"LLC Converter Power Circuit"));
if isempty(llcPowerCircuit)
    error("Subsystem LLC Converter Power Circuit doesnot exist in the model");
end
maskObj = Simulink.Mask.get(llcPowerCircuit{1});
numMaskParam = length(maskObj.Parameters);

if numMaskParam==0
    % Get current subsystem reference
    pathNameMOSFET = strcat(llcPowerCircuit{1},"/Inverter");
    pathNameDiode = strcat(llcPowerCircuit{1},"/Rectifier");

    currentMOSFETA1 = get_param(strcat(pathNameMOSFET,"/MOSFETA1"),"ReferencedSubsystem");
    currentMOSFETB1 = get_param(strcat(pathNameMOSFET,"/MOSFETB1"),"ReferencedSubsystem");
    currentMOSFETA2 = get_param(strcat(pathNameMOSFET,"/MOSFETA2"),"ReferencedSubsystem");
    currentMOSFETB2 = get_param(strcat(pathNameMOSFET,"/MOSFETB2"),"ReferencedSubsystem");

    currentDiode1 = get_param(strcat(pathNameDiode,"/Diode1"),"ReferencedSubsystem");
    currentDiode2 = get_param(strcat(pathNameDiode,"/Diode2"),"ReferencedSubsystem");
    currentDiode3 = get_param(strcat(pathNameDiode,"/Diode3"),"ReferencedSubsystem");
    currentDiode4 = get_param(strcat(pathNameDiode,"/Diode4"),"ReferencedSubsystem");

    % Configure model
    primaryMOSFETBlock =  "MOSFET (Ideal, Switching) with Thermal";
    secondaryDiodeBlock = "Tabulated Diode";

    % Set the parameter into the model
    simIn = setupLLCConverterModel(ModelName,MOSFETModel=primaryMOSFETBlock, DiodeModel=secondaryDiodeBlock,...
        Vref=options.Vref, Pload = options.Pload, Vin=options.Vin, SimTime = options.SimTime);
else
    % For masked subsystem block
    primaryMOSFETMaskedLibraryBlock = get_param(llcPowerCircuit{1},"primaryDeviceOption");
    secondaryDiodeMaskedLibraryBlock = get_param(llcPowerCircuit{1},"secondaryDeviceOption");
end
% Simulation
simOut = sim(simIn);

simTime_s = convert(options.SimTime, "s");
timeWindow=[0.9,1]*simTime_s.value;

% Prepare for plotting the total power loss
if max(contains(fieldnames(simOut.SimlogLLCConverter.LLC_Converter_Power_Circuit.Inverter.MOSFETA2),...
        "MOSFET_with_Thermal"))>0
    powerLoss = ee_getPowerLossSummary(simOut.SimlogLLCConverter,timeWindow(1),timeWindow(2));

    % MOSFET Power Loss
    mosfetTempIdx = find(contains(powerLoss.LoggingNode,"MOSFET_with_Thermal"));
    mosfetNameTemp = cell(1,length(mosfetTempIdx));

    % Find MOSFET subsystem name
    findMOSFETExpr = "MOSFET[ABCD]\d+";
    for i = 1:length(mosfetTempIdx)
        matches = regexp(powerLoss.LoggingNode{mosfetTempIdx(i)}, findMOSFETExpr, 'match');
        mosfetNameTemp{i} = matches{1};
    end
    figure("Name","Switching and Conduction Loss of the MOSFET")

    [lossData.mosfetName, idx] = sort(mosfetNameTemp);
    mosfetIdx = mosfetTempIdx(idx);
    for i = 1:length(mosfetIdx)
        lossData.mosfetLossMatrix(i,:) = [powerLoss.Power(mosfetIdx(i)) powerLoss.SwitchingLosses(mosfetIdx(i)) ...
            powerLoss.Power(mosfetIdx(i))+powerLoss.SwitchingLosses(mosfetIdx(i))];
    end
    b = bar(categorical(lossData.mosfetName),lossData.mosfetLossMatrix);
    b(1).Interpreter = "none";
    b(2).Interpreter = "none";
    b(3).Interpreter = "none";
    legend("Conduction", "Switching","Total");
    ylabel('Power (W)');
    title('Inverter MOSFET Power Loss (W)');
    grid on
    box on
    set(gcf, 'Position',  [400   525   830   471]);
    legend('Location','northwest')

    % Diode Power Loss
    DiodeTempIdx = find(contains(powerLoss.LoggingNode,"Diode"));
    diodeNameTemp = cell(1,length(DiodeTempIdx));

    % Find Diode subsystem names
    findDiodeExpr = 'Diode\d+'; % 'Diode' followed by one or more digits
    for i = 1:length(DiodeTempIdx)
        matches = regexp(powerLoss.LoggingNode{DiodeTempIdx(i)}, findDiodeExpr, 'match');
        diodeNameTemp{i} = matches{1};
    end
    [lossData.diodeName, idx] = sort(diodeNameTemp);
    diodetIdx = mosfetTempIdx(idx);
    for i = 1:length(mosfetIdx)
        lossData.diodeLossMatrix(i,:) = [powerLoss.Power(diodetIdx(i))];
    end
    figure("Name","Power Loss in the Rectifier Diodes")
    bar(categorical(lossData.diodeName),lossData.diodeLossMatrix);
    ylabel('Power (W)');
    title('Rectifier Diode Power Loss (W)');
    grid on
    box on
    set(gcf, 'Position',  [400   525   830   471]);

    % Total Power Loss
    lossData.InverterMOSFETLoss = sum(lossData.mosfetLossMatrix(:,3))  +...
        sum(powerLoss.Power(contains(powerLoss.LoggingNode,".Cds"))); % W
    lossData.RectifierDiodeLoss = sum(lossData.diodeLossMatrix); % W
    lossData.outputPower = powerLoss.Power(contains(powerLoss.LoggingNode,"Rload")); % W

    lossData.passiveElements = sum(powerLoss.Power(~contains(powerLoss.LoggingNode,["Rload","MOSFET","Rectifier.D"]))); % W

    % Compute Efficiency
    lossData.overallLoss = lossData.InverterMOSFETLoss+lossData.RectifierDiodeLoss+lossData.passiveElements;
    lossData.efficiency = 100*lossData.outputPower/(lossData.outputPower+lossData.overallLoss);

    % Pie Chart
    lossArray = 100*[lossData.InverterMOSFETLoss,lossData.RectifierDiodeLoss,lossData.passiveElements]'/lossData.overallLoss;
    lossArrayName = ["Inverter";"Rectifier";"Passive Device"];
    lossData.PercentageLossSummaryTable = table(lossArrayName,lossArray);
    figure("Name","Percentage Subsystem Loss");
    piechart(lossData.PercentageLossSummaryTable,"lossArray","lossArrayName");
    title("LLC Converter Percentage Loss"+", Total Efficiency = " + ...
        num2str(round(lossData.efficiency,2))+ "%");
    set(gcf, 'Position',  [400   525   830   471]);
else
    error("To plot the loss curve, at the LLC Converter Plant, choose MOSFET(Ideal,Switching) with Thermal as primary switching device and Tabulated diode as secondary diode");
end

% Restore the reference model

if numMaskParam==0
    set_param(strcat(pathNameMOSFET,"/MOSFETA1"),"ReferencedSubsystem",currentMOSFETA1);
    set_param(strcat(pathNameMOSFET,"/MOSFETB1"),"ReferencedSubsystem",currentMOSFETB1);
    set_param(strcat(pathNameMOSFET,"/MOSFETA2"),"ReferencedSubsystem",currentMOSFETA2);
    set_param(strcat(pathNameMOSFET,"/MOSFETB2"),"ReferencedSubsystem",currentMOSFETB2);

    set_param(strcat(pathNameDiode,"/Diode1"),"ReferencedSubsystem",currentDiode1);
    set_param(strcat(pathNameDiode,"/Diode2"),"ReferencedSubsystem",currentDiode2);
    set_param(strcat(pathNameDiode,"/Diode3"),"ReferencedSubsystem",currentDiode3);
    set_param(strcat(pathNameDiode,"/Diode4"),"ReferencedSubsystem",currentDiode4);
else
    set_param(llcPowerCircuit{1},"primaryDeviceOption",primaryMOSFETMaskedLibraryBlock);
    set_param(llcPowerCircuit{1},"secondaryDeviceOption",secondaryDiodeMaskedLibraryBlock);
end
end