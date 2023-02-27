function options = getDefaultOptions()

    options.BaseFilename = '';
    options.OutputDirectory = '';
    options.StackOutputFormat = 'tif';
    options.RecordingName = '';     % Used as prefix for all filenames. Defaults to name of input file if available
    options.BidirBatchSize  = 100;
    options.RedoAligning    = false;
    options.PartsToAlign    = 'all';
    
    options.NumFlybackLines = 0;
    
    options.CenterOfRotationOffset = [0, 0]; 
    options.AngularSampleOffset = nan; % if known & constant
    
    options.CorrectRotation = false;
    options.DoCircularCrop  = false;
    options.DoConvertToUint8 = false;
end