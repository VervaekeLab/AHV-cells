function [im] = imcropcircle(im, filling, makeSquare)
% imcropcircle - Make a "circular crop" around an image or imageArray.
%
%    [im] = circularCrop(im, filling)
%       filling: 'black', 'random'

    if nargin < 2 || isempty(filling)
        filling = 'zeros';
    end

    if nargin < 3; makeSquare = false; end
    
    imcls = class(im);
    
    nDim = length(size(im));
    
    if nDim == 2
        [num_row, num_col] = size(im);
    elseif nDim == 3
        [num_row, num_col, num_frames] = size(im);
    end
    
    % Define center coordinates and radius
    x = num_row/2;
    y = num_col/2;
    radius = min(x, y);

    if makeSquare
        num_row = radius*2; num_col = radius*2;
        im = rotalign.utility.stack.imcropcenter(im, [num_row, num_col]);
        x = radius; y = radius; 
    end

    % Generate grid with binary mask representing the circle. Credit
    % StackOverflow??
    [xx, yy] = ndgrid((1:num_row) - y, (1:num_col) - x);
    mask = (xx.^2 + yy.^2) > radius^2;

    % Mask the original image
    if nDim == 2
        im(mask) = cast(0, imcls);
    elseif nDim == 3
                
        switch filling
            case 'zeros'
                im = cast(~mask, 'like', im) .* im;
%                
%                 mask = repmat(mask, [1, 1, num_frames]);
%                 im(mask) = cast(0, imcls);

            case 'random'
                mask = repmat(mask, [1, 1, num_frames]);
                fillVal = median(im(:));
                randArr = randi(fillVal, [squareSize(1), squareSize(2), num_frames], 'like', im);
                im(mask) = randArr(mask);
        end

    end
    
end         