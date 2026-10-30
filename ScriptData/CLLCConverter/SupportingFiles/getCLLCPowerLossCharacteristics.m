function lossData = getCLLCPowerLossCharacteristics(ModelName,options)
%   This function estimates switching and conduction losses for primary MOSFETs,
%   conduction losses for secondary diodes, passive element losses, and overall
%   efficiency of a CLLC resonant converter at a specified operating point.
%   It configures the model, runs a simulation, and generates:
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
%       .primaryMOSFETName               Names of primary MOSFETs
%       .mosfetLossMatrix         Matrix of conduction, switching, and total losses (W)
%       .secondaryMOSFETName                Names of secondary diodes
%       .secondaryMOSFETLossMatrix          Matrix of diode conduction losses (W)
%       .primaryMOSFETLoss       Total inverter MOSFET loss (W)
%       .secondaryMOSFETLoss       Total rectifier diode loss (W)
%       .passiveElements          Total passive element loss (W)
%       .outputPower              Output power (W)
%       .overallLoss              Total loss (W)
%       .efficiency               Converter efficiency (%)
%       .PercentageLossSummaryTable Table of loss distribution for pie chart
%
%   Notes:
%     - This function supports only the original unmasked CLLC plant subsystem, whose
%       switches are named Primary Converter/PriMOSFETA1..B2 and Secondary
%       Converter/SecMOSFETA1..B2. The masked ConverterLibrary "CLLC Converter Power
%       Circuit" block used by CLLCResonantConverter has a different internal
%       hierarchy, so it raises an error that points to the converter-agnostic
%       engine instead:
%           lossData = getConverterPowerLoss(ModelName, Converter="CLLC", ...)
%     - The model must use 'MOSFET (Ideal, Switching) with Thermal' on both bridges.
%     - The function requires auxiliary functions: setupCLLCConverterModel and
%       ee_getPowerLossSummary.
%     - The function restores the original referenced subsystems after execution.
%
%   Example:
%     lossData = getCLLCPowerLossCharacteristics("CLLCConverterModel", ...
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

% This code works for both the masked CLLC power circuit library block and the
% unmasked subsystem in the "CLLCResonantConverterFullBridge" model
topLevelBlocks = find_system(ModelName, 'SearchDepth', 1, 'Type', 'block');
CLLCPowerCircuit = topLevelBlocks(contains(topLevelBlocks,"CLLC Converter Power Circuit"));
if isempty(CLLCPowerCircuit)
    error("Subsystem CLLC Converter Power Circuit does not exist in the model");
end
maskObj = Simulink.Mask.get(CLLCPowerCircuit{1});
numMaskParam = length(maskObj.Parameters);

if numMaskParam==0
    % Get current subsystem reference
    pathPrimaryMOSFET = strcat(CLLCPowerCircuit{1},"/Primary Converter");
    pathSecondaryMOSFET = strcat(CLLCPowerCircuit{1},"/Secondary Converter");

    currentPrimaryMOSFETA1 = get_param(strcat(pathPrimaryMOSFET,"/PriMOSFETA1"),"ReferencedSubsystem");
    currentPrimaryMOSFETB1 = get_param(strcat(pathPrimaryMOSFET,"/PriMOSFETB1"),"ReferencedSubsystem");
    currentPrimaryMOSFETA2 = get_param(strcat(pathPrimaryMOSFET,"/PriMOSFETA2"),"ReferencedSubsystem");
    currentPrimaryMOSFETB2 = get_param(strcat(pathPrimaryMOSFET,"/PriMOSFETB2"),"ReferencedSubsystem");

    currentSecondaryMOSFETA1 = get_param(strcat(pathSecondaryMOSFET,"/SecMOSFETA1"),"ReferencedSubsystem");
    currentSecondaryMOSFETB1 = get_param(strcat(pathSecondaryMOSFET,"/SecMOSFETB1"),"ReferencedSubsystem");
    currentSecondaryMOSFETA2 = get_param(strcat(pathSecondaryMOSFET,"/SecMOSFETA2"),"ReferencedSubsystem");
    currentSecondaryMOSFETB2 = get_param(strcat(pathSecondaryMOSFET,"/SecMOSFETB2"),"ReferencedSubsystem");

    % Configure model
    primaryMOSFETBlock =  "MOSFET (Ideal, Switching) with Thermal";
    secondaryMOSFETBlock = "MOSFET (Ideal, Switching) with Thermal";

    % Set the parameters in the model
    simIn = setupCLLCConverterModel(ModelName,PrimaryMOSFETModel=primaryMOSFETBlock, SecondaryMOSFETModel=secondaryMOSFETBlock,...
        Vref=options.Vref, Pload = options.Pload, Vin=options.Vin, SimTime = options.SimTime);
else
    % Masked ConverterLibrary "CLLC Converter Power Circuit" block. Its internal
    % hierarchy differs (nested variant subsystems, switches named MOSFETA1..B2 rather
    % than PriMOSFETA1..B2 / SecMOSFETA1..B2), so the simlog navigation below cannot
    % resolve against it. Fail with a pointer to the converter-agnostic engine rather
    % than erroring later on an unassigned simIn.
    error("CLLCConverter:getCLLCPowerLossCharacteristics:MaskedPlantUnsupported", ...
        ['Model "%s" uses the masked CLLC Converter Power Circuit library block. ' ...
        'This function supports only the original unmasked plant. For the ' ...
        'library-block plant, use:\n' ...
        '    lossData = getConverterPowerLoss("%s", Converter="CLLC", ...)'], ...
        ModelName, ModelName);
end
% Simulation
simOut = sim(simIn);

simTime_s = convert(options.SimTime, "s");
timeWindow=[0.9,1]*simTime_s.value;

% Prepare for plotting the total power loss
if max(contains(fieldnames(simOut.SimlogCLLCConverter.CLLC_Converter_Power_Circuit.Primary_Converter.PriMOSFETA2),...
        "MOSFET_with_Thermal"))>0
    powerLoss = ee_getPowerLossSummary(simOut.SimlogCLLCConverter,timeWindow(1),timeWindow(2));

    % MOSFET Power Loss
    mosfetTempIdx = find(contains(powerLoss.LoggingNode,"MOSFET_with_Thermal")&contains(powerLoss.LoggingNode,"PriMOSFET"));
    primaryMOSFETNameTemp = cell(1,length(mosfetTempIdx));

    % Find Primary MOSFET subsystem name
    findMOSFETExpr = "PriMOSFET[ABCD]\d+";
    for i = 1:length(mosfetTempIdx)
        matches = regexp(powerLoss.LoggingNode{mosfetTempIdx(i)}, findMOSFETExpr, 'match');
        primaryMOSFETNameTemp{i} = matches{1};
    end
    figure("Name","Switching and Conduction Loss of the Primary MOSFET")

    [lossData.primaryMOSFETName, idx] = sort(primaryMOSFETNameTemp);
    mosfetIdx = mosfetTempIdx(idx);
    for i = 1:length(mosfetIdx)
        lossData.mosfetLossMatrix(i,:) = [powerLoss.Power(mosfetIdx(i)) powerLoss.SwitchingLosses(mosfetIdx(i)) ...
            powerLoss.Power(mosfetIdx(i))+powerLoss.SwitchingLosses(mosfetIdx(i))];
    end
    b = bar(categorical(lossData.primaryMOSFETName),lossData.mosfetLossMatrix);
    b(1).Interpreter = "none";
    b(2).Interpreter = "none";
    b(3).Interpreter = "none";
    legend("Conduction", "Switching","Total");
    ylabel('Power (W)');
    title('Primary Converter MOSFET Power Loss (W)');
    grid on
    box on
    set(gcf, 'Position',  [400   525   830   471]);
    legend('Location','northwest')

    % Secondary MOSFET Power Loss
    secondaryMOSFETTempIdx = find(contains(powerLoss.LoggingNode,"MOSFET_with_Thermal")&contains(powerLoss.LoggingNode,"SecMOSFET"));
    secondaryMOSFETNameTemp = cell(1,length(secondaryMOSFETTempIdx));

    % Find Diode subsystem names
    secondaryMOSFETExpr = 'SecMOSFET[ABCD]\d+'; % 'Diode' followed by one or more digits
    for i = 1:length(secondaryMOSFETTempIdx)
        matches = regexp(powerLoss.LoggingNode{secondaryMOSFETTempIdx(i)}, secondaryMOSFETExpr, 'match');
        secondaryMOSFETNameTemp{i} = matches{1};
    end
    [lossData.secondaryMOSFETName, idx] = sort(secondaryMOSFETNameTemp);
    secMOSFETIdx = secondaryMOSFETTempIdx(idx);
    for i = 1:length(secMOSFETIdx)
        lossData.secondaryMOSFETLossMatrix(i,:) = [powerLoss.Power(secMOSFETIdx(i)) powerLoss.SwitchingLosses(secMOSFETIdx(i)) ...
            powerLoss.Power(secMOSFETIdx(i))+powerLoss.SwitchingLosses(secMOSFETIdx(i))];
    end
    figure("Name","Switching and Conduction Loss of the Secondary MOSFET")
    bar(categorical(lossData.secondaryMOSFETName),lossData.secondaryMOSFETLossMatrix);
    ylabel('Power (W)');
    title('Secondary Converter Power Loss (W)');
    grid on
    box on
    set(gcf, 'Position',  [400   525   830   471]);

    % Total Power Loss
    lossData.primaryMOSFETLoss = sum(lossData.mosfetLossMatrix(:,3))  +...
        sum(powerLoss.Power(contains(powerLoss.LoggingNode,".Cds"))); % W
    lossData.secondaryMOSFETLoss = sum(lossData.secondaryMOSFETLossMatrix(:,3)); % W
    lossData.outputPower = powerLoss.Power(contains(powerLoss.LoggingNode,"Rload")); % W

    lossData.passiveElements = sum(powerLoss.Power(~contains(powerLoss.LoggingNode,["Rload","PriMOSFET","SecMOSFET"]))); % W

    % Compute Efficiency
    lossData.overallLoss = lossData.primaryMOSFETLoss+lossData.secondaryMOSFETLoss+lossData.passiveElements;
    lossData.efficiency = 100*lossData.outputPower/(lossData.outputPower+lossData.overallLoss);

    % Pie Chart
    lossArray = 100*[lossData.primaryMOSFETLoss,lossData.secondaryMOSFETLoss,lossData.passiveElements]'/lossData.overallLoss;
    lossArrayName = ["Primary";"Secondary";"Passive Device"];
    lossData.PercentageLossSummaryTable = table(lossArrayName,lossArray);
    figure("Name","Percentage Subsystem Loss");
    piechart(lossData.PercentageLossSummaryTable,"lossArray","lossArrayName");
    title("CLLC Converter Percentage Loss"+", Total Efficiency = " + ...
        num2str(round(lossData.efficiency,2))+ "%");
    set(gcf, 'Position',  [400   525   830   471]);
else
    error("To plot the loss curve, at the CLLC Converter Plant, choose MOSFET(Ideal,Switching) with Thermal as primary switching device and Tabulated diode as secondary diode");
end

% Restore the reference model

if numMaskParam==0
    set_param(strcat(pathPrimaryMOSFET,"/PriMOSFETA1"),"ReferencedSubsystem",currentPrimaryMOSFETA1);
    set_param(strcat(pathPrimaryMOSFET,"/PriMOSFETB1"),"ReferencedSubsystem",currentPrimaryMOSFETB1);
    set_param(strcat(pathPrimaryMOSFET,"/PriMOSFETA2"),"ReferencedSubsystem",currentPrimaryMOSFETA2);
    set_param(strcat(pathPrimaryMOSFET,"/PriMOSFETB2"),"ReferencedSubsystem",currentPrimaryMOSFETB2);

    set_param(strcat(pathSecondaryMOSFET,"/SecMOSFETA1"),"ReferencedSubsystem",currentSecondaryMOSFETA1);
    set_param(strcat(pathSecondaryMOSFET,"/SecMOSFETB1"),"ReferencedSubsystem",currentSecondaryMOSFETB1);
    set_param(strcat(pathSecondaryMOSFET,"/SecMOSFETA2"),"ReferencedSubsystem",currentSecondaryMOSFETA2);
    set_param(strcat(pathSecondaryMOSFET,"/SecMOSFETB2"),"ReferencedSubsystem",currentSecondaryMOSFETB2);
end
end