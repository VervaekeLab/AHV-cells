function [AMATALL] = pupilVeloSession_scatter(Results,session,param)


fontSize = 12;


%%

hfig4 = figure('Units','normalized','OuterPosition',[0.1,0.1,0.45,0.8]); 


uniqTrialFactor = unique([Results.trialFilter]);
            
%if plotfig4, hfig4 = figure(1000); set(hfig4,'Units','normalized','OuterPosition',[0.05,0.1,0.45,0.5]); end

clear AN
cw_ccw_mat = {'CW','CCW'};
for icw = 1:2
    
    cw_ccw = cw_ccw_mat(icw);
    
    %Collect
    switch char(cw_ccw)
        case 'CW' , col2 = 1;
        case 'CCW', col2 = 2;
        otherwise
            error('')
    end
        
    ax1 = [];
    ax2 = [];
    ax3 = [];
    ax4 = []; ylim4 = [];
    ax4r = []; ylim4r = [];
    ax5 = []; ylim5 = [];
    ax5r = []; ylim5r = [];
    
    nTrialFactor = size(Results,1);
    for iFactor = 1:nTrialFactor
        
        trials = Results(iFactor,col2).trials;
        idxT = Results(iFactor,col2).idxT;
        PMat = Results(iFactor,col2).PMat;
        VMat = Results(iFactor,col2).VMat;
        ZMat = Results(iFactor,col2).ZMat;
        OmegaMat = Results(iFactor,col2).OmegaMat;
        tmax = Results(iFactor,col2).tmax;
        meanDeconvolvedMat = Results(iFactor,col2).meanDeconvolvedMat;
        meanDffMat = Results(iFactor,col2).meanDffMat;
        bodyMovementMat = Results(iFactor,col2).bodyMovementMat;
        dpupilMat = Results(iFactor,col2).dpupilMat;
        velocity =  Results(iFactor,col2).velocity;
        
             
        %% Figure 4
        
        
        figure(hfig4)
        set(gcf,'Name', 'Figure4')
        
        % 0 Velocity
        % 1 Vestibular
        % 2 Pupil velocity
        % 3 Pupil resets
        % 4 Neural Activity
        % 5 Body movement
       
        
        if ~isempty(param.timeCut)
            tmax = ceil(param.timeCut/1000 / session.dt);
        end
        
        %
        clear A;
        A = {};
        A{ length(A)+1 } = {  nanmean(VMat(:,1:tmax),1) , sprintf('Velocity (%s/s)',char(176)) , true };
        %A{  length(A)+1 } = {  nanmean(ZMat(:,1:tmax),1) , 'Vestibular (a.u.)' , true };
        A{  length(A)+1 } = {  nanmean(dpupilMat(:,1:tmax),1) , 'Pupil velocity (a.u.)' , true };
        %A{  length(A)+1 } = {  smooth(nanmean(PMat(:,1:tmax),1) , param.smoothFactor) , 'Nysparam.tagmus frequency' ,true };
        A{  length(A)+1 } = {  abs(smooth(nanmean(PMat(:,1:tmax),1) , param.smoothFactor)) , 'Frequency (Hz)'  , false };
        A{  length(A)+1 } = {  smooth(nanmean(meanDeconvolvedMat(:,1:tmax),1) , param.smoothFactor) , 'Average rate (a.u.)', false };
        %A{ length(A)+1 } = {  smooth(nanmean(bodyMovementMat(:,1:tmax),1)    , param.smoothFactor) , 'bodyMovement' , false };
        
        AN{iFactor,icw} = A;
        
        if (0)
            nrows = length(A);
            for irow = 1:nrows
                for icol =1:nrows
                    subplot(nrows,nrows, (irow-1)*nrows + icol )
                    %plot( A{irow}{1} , A{icol}{1} ,'.b','MarkerSize',10)
                    plot( A{icol}{1} , A{irow}{1} ,'k.','MarkerSize',10)
                    hold all
                    if irow==nrows, xlabel(A{icol}{2} ), end
                    if icol==1, ylabel(A{irow}{2} ), end
                    xlim auto; if A{icol}{3}, xl = xlim; xlim( [-1,1]*max(abs(xl))), end
                    ylim auto; if A{irow}{3}, yl = ylim; ylim( [-1,1]*max(abs(yl))), end
                    %grid on
                end
            end
        end
            
            
        
        drawnow
        
        
    end % nTrialFactor
    
    
    
    
    
end % CW CCW




%% ----
AMATALL = [];
for icw = 1:2
    for iN = 1:size(AN,1)
        %% Figure 4
        
        
        figure(hfig4)
        
        % 0 Velocity
        % 1 Vestibular
        % 2 Pupil resets
        % 3 Neural Activity
        % 4 Body movement
        A = AN{iN,icw};
        nrows = length(A);
        clear AMAT ALABEL
        for irow = 1:nrows
            AMAT(:,irow) = A{irow}{1};
            ALABEL{irow} = A{irow}{2};
        end
        AMATALL = vertcat(AMATALL, AMAT);
        
    end
end

for irow = 1:nrows
    for icol =1:nrows
        
        figure(hfig4)
        set(gca,'FontSize',fontSize)
        subplot(nrows,nrows, (irow-1)*nrows + icol )
        %plot( A{irow}{1} , A{icol}{1} ,'.b','MarkerSize',10)
        %plot( A{icol}{1} , A{irow}{1} ,'k.','MarkerSize',10)
        %plot( AMAT(:,icol) , AMAT(:,irow) ,'k.','MarkerSize',10)
        
        x = AMATALL(:,icol);
        y = AMATALL(:,irow);    
        xedges = linspace( nanmin(x), nanmax(x), 11 );
        clear ymean ystd yse
        for ix = 1:length(xedges)-1
            fidx = find( x > xedges(ix) & x <= xedges(ix+1)) ;
            ymean(ix) = nanmean( y(fidx) ) ;
            ystd(ix)  = nanstd( y(fidx) ) ;
            yse(ix)   = nanstd( y(fidx) ) / sqrt(length(fidx)) ;
        end
        xmean = (xedges(1:end-1) + xedges(2:end))/2;
        %xmean = xedges;
        plot( AMATALL(:,icol) , AMATALL(:,irow) ,'o','MarkerSize',4,'Color', [0.8,0.8,0.8])
        hold all
        %plot( xedges, ymean, 'bo-', 'LineWidth',1)
        shadedErrorBar ( xmean , ymean, yse, 'lineProps', {'k-' } )
        hold all
        plot( xmean, ymean, 'ok')
        
        hold all
        if irow==nrows, 
            xlabel(A{icol}{2} , 'FontSize',fontSize),
        end
        %if icol==1, ylabel(A{irow}{2} ), end
        ylabel(A{irow}{2} , 'FontSize',fontSize)
        %title( A{irow}{2} )
        xlim auto; if A{icol}{3}, xl = xlim; xlim( [-1,1]*max(abs(xl))), end
        ylim auto; if A{irow}{3}, yl = ylim; ylim( [-1,1]*max(abs(yl))), end
        %grid on
    end
end



%%

% Figure vestibular vs pupil
figure(hfig4)
suptitle( sprintf('%s (%s), %s', ...
    session.sessionID, session.fovLocationName, param.tag) )
drawnow
%fov = regexprep(session.fovLocationName,'[^a-zA-Z0-9]','');



% Save dir
subdir = sprintf('%s/%s-pupilResetQ%2g-%s/', param.rootdir, datestr(now,'yyyymmdd'), param.quantileReset*100, param.tag);
%subdir = sprintf('%s', param.rootdir);
if ~exist(subdir,'dir'),  mkdir(savedir), end
savename = sprintf('%s/scatterV_%s_%s_window%d_tmax%d_%s', subdir, session.sessionID, param.tag, param.windowSize,param.timeCut);
saveas(hfig4,savename,'png')
saveas(hfig4,savename,'fig')
fprintf(1,'saved to %s\n',savename)




end