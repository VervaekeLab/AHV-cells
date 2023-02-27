function [imArray, pixelBaseline] = subtractBaseline(imArray, pixelBaseline)

    if nargin < 2 || isempty(pixelBaseline)
        pixelBaseline = min( imArray(:) );
    end
    imArray = imArray - cast(pixelBaseline, 'like', imArray);
    if nargout == 2
        clear pixelBaseline
    end
end