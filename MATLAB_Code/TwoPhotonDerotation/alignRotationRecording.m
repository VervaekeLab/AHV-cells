function alignRotationRecording(imageData, derotationAngles, options)
%alignRotationRecording Align a stack where images are rotated.
%
%   INPUTS:
%       imageData : A memory-mapped stack or an image array (height, width, n). 
%           This should be a data variable where images can be retrieved using
%           standard array indexing.
%
%       derotationAngles : Vector (1 x n) of angular orientations for each frame
%       
%       options : struct with options (see rotalign.getDefaultOptions)


    % Handle options
    if nargin < 3; options = struct; end
    derotationAngles = derotationAngles(:)'; % Make sure it is a row vector
    
    % Start clock 
    tBegin = tic;

    % Populate options from default options if any options are not provided
    options = addDefaultOptionsIfMissing(options); % local function

    stackSize = size(imageData);

    lineInd = options.NumFlybackLines+1 : stackSize(1);
    stackSize(1) = numel(lineInd);

    frameSize = stackSize(1:2);
    frameSizeSquare = repmat(min(frameSize), 1, 2);

    % Todo: create output stacks...
    filePaths = getFilePaths(options);
    
    pixelStats = getPixelStats(imageData, filePaths, options);
    [options.BlackLevel, options.WhiteLevel] = getImageIntensityBounds(pixelStats);

    % Todo: % Load (from file) or initialize trialInfo/frameInfo
    if isfile( filePaths.CorrectionSummary )
        S = load(filePaths.CorrectionSummary); trialInfo = S.trialInfo;
    else
        trialInfo = rotalign.getTrialInfo(derotationAngles);
    end

    %frameInfo = rotalign.initializeFrameInfo(numFrames);    

    numTrials = numel(trialInfo);

    dataType = class(imageData);
    dataType = regexprep(dataType, '\s\(.*\)', ''); % remove potential nansen quirk...

    correctedStack = getImageStack(filePaths.CorrectedStack, stackSize, dataType);
    referenceStack = getImageStack(filePaths.ReferenceImageStack, [frameSize, numTrials], dataType);
    avgProjectionStack = getImageStack(filePaths.AvgProjectionStack, [frameSize, numTrials], dataType);
    maxProjectionStack = getImageStack(filePaths.MaxProjectionStack, [frameSize, numTrials], dataType);
    
    partsToAlign = getPartsToAlign(trialInfo, options);
    numPartsToAlign = numel(partsToAlign);

    for iPart = 1:numPartsToAlign

        iTrial = partsToAlign(iPart);

        % Skip trial if it is aligned from before
        if trialInfo(iTrial).isTrialFinished && ~options.RedoAligning
            continue
        end

        fprintf('Aligning trial %d (%d/%d)...', iTrial, iPart, numPartsToAlign)

        % Assign the first and last frame number to process for this trial.
        ii = trialInfo(iTrial).startIdx;
        ie = trialInfo(iTrial).stopIdx;
        isStationaryTrial = not( trialInfo(iTrial).isRotationTrial );
                
        % Get image data for current trial
        imArray = single(imageData(lineInd, :, ii:ie));

        % Todo ?:
        % imArray = rotalign.preprocessImages(imArray, iTrial, trialInfo);

        imArray = rotalign.subtractBaseline(imArray, options.BlackLevel);
        
        % Todo: Why was this necessary? Is it?
        sessionRef = getReferenceImage(referenceStack, iTrial, trialInfo);

        % Place relevant data in a struct...?

        if isStationaryTrial && trialInfo(iTrial).stationaryPosition == 0

            [imArrayCorr, summary] = rotalign.alignStationaryPrimarySegment(...
                imArray, sessionRef, options);
            trialInfo(iTrial).imageDrift = summary.imageDrift;

        elseif isStationaryTrial && trialInfo(iTrial).stationaryPosition ~= 0 % Todo later

            [imArrayCorr, summary] = rotalign.alignStationaryNonPrimarySegment(...
                imArray, sessionRef, options);

        else % Rotation trial

            [imArrayCorr, summary] = rotalign.alignRotationSegment(...
                imArray, sessionRef, derotationAngles(ii:ie), options);
            trialInfo(iTrial).angularSamplingDelay = summary.angularSamplingDelay;
        end

        % Reset the baseline offset correction
        imArrayCorr = imArrayCorr + options.BlackLevel;

        % Todo: Crop images using circular crop 
        if options.DoCircularCrop
            imArrayCorr = rotalign.utility.stack.imcropcircle( ...
                rotalign.utility.stack.imcropcenter(imArrayCorr, frameSizeSquare) );
        end

        if options.DoConvertToUint8
            imArrayCorr = rotalign.utility.makeuint8(imArrayCorr, [options.Blacklevel, options.WhiteLevel]);
        else
            imArrayCorr = cast(imArrayCorr, dataType);
        end
    
        % Add results to corrected stack
        correctedStack.Data(:, :, ii:ie) = imArrayCorr;

        referenceStack.Data(:, :, iTrial) = cast(summary.trialReference, dataType);

        % Save projection images 
        avgProjectionStack(:, :, iTrial) = cast( mean(imArrayCorr, 3), dataType );
        maxProjectionStack(:, :, iTrial) = max(imArrayCorr, [], 3);

        % Save updated results (trial info and frame info)
        trialInfo(iTrial).isTrialFinished = true;

        save(filePaths.CorrectionSummary, 'trialInfo')

        strElapseTime = strFormatElapsedTime( toc(tBegin) );
        fprintf('Finished. Elapsed time %s\n', strElapseTime)
    end

    fprintf('Completed derotation and motion correction.\n')
    
end

function options = addDefaultOptionsIfMissing(options)
%addDefaultOptionsIfMissing Add default options to options struct if missing

    defaultOptions = rotalign.getDefaultOptions();
    optionsFields = fieldnames(defaultOptions);

    for i = 1:numel(optionsFields)
        if ~isfield(options, optionsFields{i})
            options.(optionsFields{i}) = defaultOptions.(optionsFields{i});
        end
    end
end

function filePaths = getFilePaths(options)

    % Assign output
    filePaths = struct;
    
    % Create folder for aligned images.
    rootDirectory = options.OutputDirectory;
    if isempty(rootDirectory); rootDirectory = pwd; end
    if ~exist(rootDirectory, 'dir'); mkdir(rootDirectory); end
    
    baseFilename = options.BaseFilename;
    
    % Assign extension for stack files.
    stackFileExtension = options.StackOutputFormat;
    stackFileExtension = strrep(stackFileExtension, '.', '');
    
    buildFilename = @(filePostfix, fileExtension) ... 
        sprintf('%s_%s.%s', baseFilename, filePostfix, fileExtension);

    buildFilepath = @(subFolder, filePostfix, fileExtension) ...
        fullfile(rootDirectory, subFolder, buildFilename(filePostfix, fileExtension) );

    % Create filepath for corrected file.
    filePaths.CorrectedStack = ...
        buildFilepath('motion_corrected', 'motion_corrected', stackFileExtension);

    % Create filename for file containing variables from the aligning
    filePaths.CorrectionSummary = ...
        buildFilepath('correction_data', 'correction_summary', 'mat');
       
    % Create filename for file containing variables from the aligning
    filePaths.PixelStats = ...
        buildFilepath('raw_image_stats', 'pixel_stats', 'mat');

    % Create filenames for referenceImages
    filePaths.ReferenceImageStack = ...
        buildFilepath('correction_data', 'reference_images', stackFileExtension);
    
    filePaths.Options = ...
        buildFilepath('correction_data', 'correction_options', 'mat');

    % Create filenames for avg and max projections stacks
    filePaths.AvgProjectionStack = ...
        buildFilepath('correction_data', 'avg_projections', stackFileExtension);    
    
    filePaths.MaxProjectionStack = ...
        buildFilepath('correction_data', 'max_projections', stackFileExtension);

    if ~isfolder( fullfile(rootDirectory, 'correction_data') )
        mkdir( fullfile(rootDirectory, 'correction_data') )
    end
    if ~isfolder( fullfile(rootDirectory, 'motion_corrected') )
        mkdir( fullfile(rootDirectory, 'motion_corrected') )
    end
end

function imageStack = getImageStack(filePath, stackSize, dataType, varargin)
%getImageStack Open (or create) and an image stack at a file location

    [~, filename] = fileparts(filePath);

    if ~isfile(filePath)
        fprintf('Creating image stack for %s...', filename);
        imageStackData = nansen.stack.open(filePath, stackSize, dataType, varargin{:});
        fprintf('Done\n')
    else
        fprintf('Opening existing image stack for %s.\n', filename);
        imageStackData = nansen.stack.open(filePath, varargin{:});
    end
    
    imageStack = nansen.stack.ImageStack(imageStackData);
end

function partsToAlign = getPartsToAlign(trialInfo, options)
    
    if ~isfield(options, 'partsToAlign') || isempty(options.partsToAlign)
        partsToAlign = 1:numel(trialInfo);
        
        % Sort to place all stationary trials before all rotation trials
        partsToAlign = [partsToAlign(~[trialInfo.isRotationTrial]), ...
                         partsToAlign([trialInfo.isRotationTrial]) ];

    else
        partsToAlign = options.partsToAlign;
    end
end

function strElapseTime = strFormatElapsedTime(elapsedTime)

    strElapseTime = sprintf('%02d:%02d:%02d', floor(elapsedTime/3600), ...
        floor(mod(elapsedTime, 3600) / 60), floor(mod(elapsedTime, 60)));
end

function sessionRef = getReferenceImage(referenceImageStack, iTrial, trialInfo)
%getReferenceImage Get reference image for current trial
%
%   The sessionRef is used for alignment of frames undergoing rotation,
%   and updating the sessionRef should reduce misalignment effects due to
%   drift of recording and warping of tissue during recording. That is
%   why nonrigid alignment is used. Still not sure if this is the best way...

    if iTrial == 1
        sessionRef = []; return
    end

    statPositions = [trialInfo.stationaryPosition];
    
    % Find the previous trial which was recorded at 0 degrees.
    prevZeroTrialIdx = find(statPositions(1:iTrial-1)==0, 1, 'last');

    % Align the reference image for that trial non-rigidly to the reference
    % image of the first trial of the session (which was also 0 deg).
    prevRef = referenceImageStack.Data(:, :, prevZeroTrialIdx);
    
    frameSize = size(prevRef);
    frameSizeSquare = repmat( min(frameSize), 1, 2);

    if prevZeroTrialIdx ~= 1
        prevRefSqr = rotalign.utility.stack.imcropcenter(prevRef, frameSizeSquare);
        firstRefSqr = rotalign.utility.stack.imcropcenter(referenceImageStack.Data(:, :, 1), frameSizeSquare);
        [~, ~, nrShifts, nrOpts] = rotalign.wrapper.nonrigid(prevRefSqr, firstRefSqr, 'finetune');
        nrOpts.d1 = frameSize(1); nrOpts.d2 = frameSize(2);
        sessionRef = apply_shifts(prevRef, nrShifts, nrOpts); % Normcorre function
    else
        sessionRef = prevRef;
    end
end

function pixelStats = getPixelStats(imageData, filePaths, options)
    
    if ~isfile(filePaths.PixelStats)
        
        dataset = nansen.dataio.dataset.SingleFolderDataSet(options.OutputDirectory);
        dataset.addVariable('ImageStats', 'FilePath', filePaths.PixelStats)
    
        processor = nansen.stack.processor.PixelStatCalculator(...
            nansen.stack.ImageStack(imageData), 'DataIoModel', dataset);
        processor.IsSubProcess = true;
        processor.runMethod()
    end

    S = load(filePaths.PixelStats);
    pixelStats = S.ImageStats{1};

end

function [lowerBound, upperBound] = getImageIntensityBounds(pixelStats)
    lowerBound = mean( pixelStats.prctileL2 );
    upperBound = mean( pixelStats.prctileU2 );
end