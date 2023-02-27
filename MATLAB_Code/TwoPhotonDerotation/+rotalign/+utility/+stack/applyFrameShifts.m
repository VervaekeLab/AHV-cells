function imArray = applyFrameShifts(imArray, frameShifts)
% applyFrameShifts Shift images in array according to matrix of frameshifts
%   imArray = applyFrameShifts(imArray, frameShifts) return an image array
%   where images are shifted in the x and y direction. If imArray is 
%   nRows x nCols x nFrames, frameShifts should be nFrames x 2. Shifts in x
%   are stored in the first column and shifts in y are stored in the second
%   column. Positive shifts move image leftwards and downwards.

    [nRows, nCols, nFrames] = size(imArray);
    
    assert(nFrames == size(frameShifts, 1), 'Image array and frame shifts should have the same dimensions')

    for fr = 1:nFrames

        dx = frameShifts(fr, 1);
        dy = frameShifts(fr, 2);
        
        if dx ~= 0 || dy ~= 0
            % Create an empty expanded canvas to hold the image
            canvas = zeros(nRows + abs(dy)*2, ...
                           nCols + abs(dx)*2, 'like', imArray);

            canvas(abs(dy) + (1 : nRows), ...
                   abs(dx) + (1 : nCols), :) = imArray(:, :, fr); % put im in cntr...


            % Crop to original size off center to move frame.
            shiftedFrame = canvas( abs(dy) - dy + (1:nRows), ...
                                   abs(dx) - dx + (1:nCols), :);
    
            imArray(:, :, fr) = shiftedFrame;

        end
    end
end