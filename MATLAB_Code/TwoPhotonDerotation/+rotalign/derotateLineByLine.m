function imArray = derotateLineByLine(imArray, thetaFrame, origNLines, crop, us)
%derotate Derotate an image stack based on vector of angles. 
%
% imArrayOut = derotate(imArrayIn, angles) derotates an image stack based
% on a vector of angles. Angles are the same size as nLines x nFrames
%
% imArrayOut = derotate(imArrayIn, angles, crop) crops the output array so
% that it is the same size as the input array
%
% This function warps the image according to the speed of rotation, in 
% other words, it corrects for differences in rotation between the first 
% and last lines of the image.
%
% Note: Acquisition in SciScan creates stretched images in the x direction.
% The correction typically crops the image in the y to make square images. 
% Since the angle vector is per line, this function need to know how many 
% lines were originally acquired

% Written by Eivind Hennestad | Vervaeke Lab

if nargin < 3
    origNLines = size(imArray, 1);
end

if nargin < 4
    crop = true;
end

if nargin < 5
    resizeFactor = 1;
else
    resizeFactor = us;
end

version = 2;

% Create rotation vector to optimize image rotation when there is no 
% rotation during image acquisition.

thetaFrame = thetaFrame(:); % Must be column vector in this function
rotating = vertcat(0, abs(diff(thetaFrame)) > 0.1);

if numel(thetaFrame) < 9 % IF a subpart is very short. Which only happens at end of recording..
    thetaLine = repmat(thetaFrame, origNLines, 1);
else
    thetaLine = interp(thetaFrame, origNLines);
end

% % thetaLine = shiftvector(thetaLine, 256); Is this right after
% calculating the correction????

thetaLine = reshape(thetaLine, origNLines, []);  % New shape nLines x nFrames

[nRows, nCols, nFrames] = size(imArray);

trim = round((origNLines - nRows) / 2) + 1;

thetaTrimmed = thetaLine(trim:trim+nRows-1, :);

if ~crop

    % Pad imArrayIn with zeroes
    testIm = imrotate(imArray(:,:,1), 45);
    newSize = size(testIm);

    imArray = imexpand(imArray, newSize);
    [nRows, nCols, ~] = size(imArray);
        
    % Expand angular vector to correspond with number of rows in new array.
    thetaTrimmed = imexpand(thetaTrimmed, [nRows, nFrames], 'nan');
    thetaTrimmed = fillmissing(thetaTrimmed, 'linear', 1);
    
end

origSize = [size(imArray, 1), size(imArray, 2)];
upSize = floor(origSize .* resizeFactor);

if version == 2

    D = rotalign.createDerotationDisplacementField([origSize, nFrames], thetaTrimmed, 4);

    for n = 1:nFrames
        imN = imresize(imArray(:,:,n), upSize);
        DN = squeeze(D(:,:,n,:));
        imN = imwarp(imN, imresize(DN*resizeFactor, upSize), 'cubic');
        imN = imresize(imN, origSize);

        BW = DN(:,:,1)==0;
        imN(BW) = 0;
        imArray(:,:,n) = imN;
    end
    
elseif version == 1
    for n = 1:nFrames

        if rotating(n)

            tmpIm = imresize(imArray(:,:,n), upSize);
            if resizeFactor >= 1
                tmpTheta = repmat(thetaTrimmed(:, n), 1, resizeFactor);
                tmpTheta = reshape(tmpTheta', [], 1);
            elseif  resizeFactor < 1
                % This has to do for now-.-
                tmpTheta = thetaTrimmed(1:round(1/resizeFactor):end, n);
                if size(tmpIm, 1) > numel(tmpTheta)
                    tmpTheta(end+1) = tmpTheta(end);
                elseif size(tmpIm, 1) < numel(tmpTheta)
                    tmpTheta = tmpTheta(1:end-1);
                end
            end

            tmpIm = imwarprotate( tmpIm, tmpTheta );
            imArray(:,:,n) = imresize(tmpIm, origSize);

    %         imArray(:,:,n) = imwarprotate( imArray(:,:,n), thetaTrimmed(:, n));
        else
            tmpIm = imresize(imArray(:,:,n), upSize);
            tmpIm = imrotate( tmpIm, thetaFrame(n), 'bicubic', 'crop');
            imArray(:,:,n) = imresize(tmpIm, origSize);
    %         imArray(:,:,n) = imrotate(imArray(:,:,n), thetaFrame(n), 'bicubic', 'crop');
        end
    end
end

end
