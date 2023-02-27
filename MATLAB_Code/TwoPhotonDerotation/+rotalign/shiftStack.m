function imArray = shiftStack(imArray, dx, dy, dtheta)
%shiftStack displaces a stack dx pixels to the right and dy pixels down.

%stackInfo = whos('imArray');

if nargin < 3 % should have seen that coming sooner...
    shifts = dx;
    dx = shifts(1); dy = shifts(2);
end

if nargin < 4
    dtheta = 0;
end

dx=round(dx); dy = round(dy);

% Apply shifts first
if dx ~= 0 || dy ~= 0
    % Create an empty canvas to hold the image
    imdim = size(imArray);
    canvas = zeros(imdim(1) + abs(dy)*2, ...
                   imdim(2) + abs(dx)*2, imdim(3), class(imArray));

    canvas(abs(dy) + (1 : imdim(1)), ...
           abs(dx) + (1 : imdim(2)), :) = imArray; % put im in cntr...


    % Crop frame
    imArray = canvas( abs(dy) - dy + (1:imdim(1)), ...
                      abs(dx) - dx + (1:imdim(2)), :);

end

if dtheta ~= 0
    imArray = imrotate(imArray, dtheta, 'bicubic', 'crop');
end

end