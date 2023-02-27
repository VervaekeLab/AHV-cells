function [imArrayCorrected, summary] = alignStationaryPrimarySegment(imArray, referenceImage, options)
% alignStationaryPrimarySegment Align a set of frames in the zero deg position
%
%   INPUTS:
%       imArray : 3d array of image (height x width x numFrames)
%       referenceImage : 2d reference image (height x width) used for aligning
%       options : struct containing options (see rotalign.getDefaultOptions)
%
%   OUTPUTS:
%       imArrayCorrected :  3d array of image (height x width x numFrames)
%           of motion corrected images
%       summary : struct containing some summary data.
%
%  This function does mainly two things
%     1) Align images using normcorre with preset options
%     2) Determine (and correct) time-dependent drift 

    options.RegistrationMethod = 'nonrigid';
    pixelBaseline = options.BlackLevel;

    stackSize = size(imArray);
    frameSize = stackSize(1:2);
    frameSizeSmall = repmat( floor( sqrt(min(frameSize).^2 / 2) ), 1, 2);

    %% Motion correct images
    switch options.RegistrationMethod

        case 'rigid'
            [imArrayCorrected, ~, ncShifts, ncOptions] = rotalign.wrapper.rigid(imArray);
        case 'nonrigid'
            [imArrayCorrected, ~, ncShifts, ncOptions] = rotalign.wrapper.nonrigid(imArray, [], '8x1d');
    end

    %% Find drift of images from current trial relative to main reference
    trialReference = mean(imArrayCorrected, 3);
    trialReference = rotalign.utility.stack.removeDarkPixels(trialReference, pixelBaseline);

    if isempty(referenceImage)
        summary.imageDrift = [0, 0];
    else
        trialRefSmall = rotalign.utility.stack.imcropcenter(trialReference, frameSizeSmall);
        sessionRefSmall = rotalign.utility.stack.imcropcenter(referenceImage, frameSizeSmall);
        [~, ~, ncShiftsTrial, ~] = rotalign.wrapper.rigid(trialRefSmall, sessionRefSmall);
        
        summary.imageDrift = fliplr(squeeze(ncShiftsTrial.shifts)');

        if any(summary.imageDrift ~= 0)
            % Add together individual frame shifts and substack frame shifts.
            ncShifts = rotalign.addNormcorreShifts(ncShifts, ncShiftsTrial);
            
            % Call normcorres apply_shift function do subpixel shifts.
            ncOptions.shifts_method = 'cubic';
            ncOptions.d1 = size(imArray, 1); ncOptions.d2 = size(imArray, 2);
            imArrayCorrected = apply_shifts(imArray, ncShifts, ncOptions); % normcorre method
        end
    end

    %% Collect summary
    summary.trialReference = trialReference;

    % Save individual frame shifts.
    switch options.RegistrationMethod
        case 'rigid'
            summary.shiftsNcRigid = ncShifts;
            summary.rigidShifts = fliplr(squeeze(cat(1, ncShifts.shifts)));
        case 'nonrigid'
            summary.shiftsNcNonrigid = ncShifts;
    end
    
    % Save root mean square movement of frames.
    rmsmov = cellfun(@(shifts) sqrt(sum(shifts(:).^2)), {ncShifts(:).shifts} );
    summary.rmsMovement = rmsmov;
end
