function setSecondaryDiode(LLCPlantPath,options)
%   This function updates the referenced subsystem for the four secondary diodes
%   in the rectifier stage of an LLC converter Simulink model to the specified
%   diode device option. Use this function to switch between ideal and tabulated
%   diode models for loss and efficiency analysis.
%
%   Inputs:
%     LLCPlantPath    String. Path to the LLC converter plant subsystem in the model.
%     options         Structure with the following optional field:
%       .DeviceOption   Char. Device model to use for the secondary diodes.
%                      Must be one of:
%                       - 'Ideal Diode' (default)
%                       - 'Tabulated Diode'
%
%   Example:
%     setSecondaryDiode("LLCConverterModel/LLC Converter Power Circuit", ...
%                       DeviceOption="Tabulated Diode")

% Copyright 2025-2026 The MathWorks, Inc.
    arguments
    LLCPlantPath string
    options.DeviceOption (1,:) char {mustBeMember(options.DeviceOption,{'Ideal Diode','Tabulated Diode'})} = 'Ideal Diode';
    end
    secondaryDiodeChoice = options.DeviceOption;
    
    secondaryDiodeLoc1 =  strcat(LLCPlantPath, "/Rectifier/Diode1"); 
    secondaryDiodeLoc2 =  strcat(LLCPlantPath, "/Rectifier/Diode2"); 
    secondaryDiodeLoc3 =  strcat(LLCPlantPath, "/Rectifier/Diode3"); 
    secondaryDiodeLoc4 =  strcat(LLCPlantPath, "/Rectifier/Diode4"); 
    
    switch secondaryDiodeChoice
        case 'Ideal Diode'
            set_param(secondaryDiodeLoc1,"ReferencedSubsystem", 'LLCModelBasicDiode');
            set_param(secondaryDiodeLoc2,"ReferencedSubsystem", 'LLCModelBasicDiode');
            set_param(secondaryDiodeLoc3,"ReferencedSubsystem", 'LLCModelBasicDiode');
            set_param(secondaryDiodeLoc4,"ReferencedSubsystem", 'LLCModelBasicDiode');
        case 'Tabulated Diode'
            set_param(secondaryDiodeLoc1,"ReferencedSubsystem", 'LLCModelTabulatedDiode');
            set_param(secondaryDiodeLoc2,"ReferencedSubsystem", 'LLCModelTabulatedDiode');
            set_param(secondaryDiodeLoc3,"ReferencedSubsystem", 'LLCModelTabulatedDiode');
            set_param(secondaryDiodeLoc4,"ReferencedSubsystem", 'LLCModelTabulatedDiode');
        otherwise
            disp('Select the proper secondary diode option')
    end
end