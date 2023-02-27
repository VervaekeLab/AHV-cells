function ncShifts = addNormcorreShifts(ncShifts, ncShiftsStack)
    for k = 1:numel(ncShifts)
        ncShifts(k).shifts(:,:,:,1) = ncShifts(k).shifts(:,:,:,1) + ncShiftsStack.shifts(1);
        ncShifts(k).shifts_up(:,:,:,1) = ncShifts(k).shifts_up(:,:,:,1) + ncShiftsStack.shifts_up(1);
        
        ncShifts(k).shifts(:,:,:,2) = ncShifts(k).shifts(:,:,:,2) + ncShiftsStack.shifts(2);
        ncShifts(k).shifts_up(:,:,:,2) = ncShifts(k).shifts_up(:,:,:,2) + ncShiftsStack.shifts_up(2);
    end  
end
