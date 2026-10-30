function setCLLCSecondaryMOSFET(CLLCPlantPath,options)
%   This function updates the referenced subsystem for the four secondary MOSFETs
%   in the inverter stage of a CLLC converter Simulink model to the specified
%   device option: a MOSFET model with or
%   without thermal effects.
%
%   Inputs:
%     CLLCPlantPath    String. Path to the CLLC converter plant subsystem in the model.
%     options         Structure with the following optional field:
%       .DeviceOption   Char. Device model to use for the secondary MOSFETs.
%                      Must be one of:
%                       - 'MOSFET (Ideal, Switching) without Thermal' (default)
%                       - 'MOSFET (Ideal, Switching) with Thermal'
%
%   Example:
%     setPrimaryMOSFET("CLLCResonantConverter/CLLC Converter Power Circuit", ...
%                      DeviceOption="MOSFET (Ideal, Switching) with Thermal")

% Copyright 2025-2026 The MathWorks, Inc.
    arguments
    CLLCPlantPath string
    options.DeviceOption (1,:) char {mustBeMember(options.DeviceOption,{'MOSFET (Ideal, Switching) without Thermal','MOSFET (Ideal, Switching) with Thermal'})} = 'MOSFET (Ideal, Switching) without Thermal';
    end
    primarySwitchChoice = options.DeviceOption;
    
    primarySwitchLoc1 = strcat(CLLCPlantPath, "/Secondary Converter/SecMOSFETA1");
    primarySwitchLoc2 = strcat(CLLCPlantPath, "/Secondary Converter/SecMOSFETA2");
    primarySwitchLoc3 = strcat(CLLCPlantPath, "/Secondary Converter/SecMOSFETB1");
    primarySwitchLoc4 = strcat(CLLCPlantPath, "/Secondary Converter/SecMOSFETB2");
    
    switch primarySwitchChoice
    case 'MOSFET (Ideal, Switching) without Thermal'
        set_param(primarySwitchLoc1,"ReferencedSubsystem", 'CLLCModelIdealMOSFETWithoutThermal');
        set_param(primarySwitchLoc2,"ReferencedSubsystem", 'CLLCModelIdealMOSFETWithoutThermal');
        set_param(primarySwitchLoc3,"ReferencedSubsystem", 'CLLCModelIdealMOSFETWithoutThermal');
        set_param(primarySwitchLoc4,"ReferencedSubsystem", 'CLLCModelIdealMOSFETWithoutThermal');
    case 'MOSFET (Ideal, Switching) with Thermal'
        set_param(primarySwitchLoc1,"ReferencedSubsystem", 'CLLCSecondaryIdealMOSFETWithThermal');
        set_param(primarySwitchLoc2,"ReferencedSubsystem", 'CLLCSecondaryIdealMOSFETWithThermal');
        set_param(primarySwitchLoc3,"ReferencedSubsystem", 'CLLCSecondaryIdealMOSFETWithThermal');
        set_param(primarySwitchLoc4,"ReferencedSubsystem", 'CLLCSecondaryIdealMOSFETWithThermal');
    otherwise
        disp('Select the proper primary switch option')
    end
end