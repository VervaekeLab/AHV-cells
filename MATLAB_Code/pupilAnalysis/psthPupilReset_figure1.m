function [hfig1] = psthPupilReset_figure1( SN, session, hfig1)

s = SN.stats;
v2struct(s)
if isempty(hfig1)
    hfig1 = figure();
    set(gca,'Units','normalized', 'OuterPosition', [0.1,0.1,0.8,0.8] );
    hfig1(1) = [ hfig1 ];
end
[ ~, idxsort ] = sort(s.trialVelocity,'ascend');

% Figure 1
figure(hfig1(1))
subplot(2,3,1)
x = [-intv:intv]*session.dt;
y = 1:length(fPupilResetIdx);
z = PSTH.pupilResetMat(idxsort,:); % .* dPupilMat;
%imAlpha=ones(size(dPupilMat));
%imAlpha(isnan(dPupilMat))=0;
%imagesc(x,y,z,'AlphaData',imAlpha);
%set(gca,'color',1*[1 1 1]);
z(isnan(z)) = 0;
imagesc(x,y,z);
xlabel('time around pupilReset')
ylabel('pupil Reset')
colormap gray %jet
colorbar

subplot(2,3,3)
x = [-intv:intv]*session.dt;
y = 1:length(fPupilResetIdx);
z = PSTH.dPupilMat(idxsort,:);
%imAlpha=ones(size(dPupilMat));
%imAlpha(isnan(dPupilMat))=0;
%imagesc(x,y,z,'AlphaData',imAlpha);
%set(gca,'color',1*[1 1 1]);
z(isnan(z)) = 0;
imagesc(x,y,z);
xlabel('time around pupilReset')
ylabel('dPupilMat')
colormap jet
colorbar

subplot(2,3,2)
x = [-intv:intv]*session.dt;
y = 1:length(fPupilResetIdx);
z = PSTH.pupilMat(idxsort,:) ;
z(isnan(z)) = 0;
imagesc( x, y, z)
xlabel('time around pupilReset')
ylabel('pupilMat')
colormap jet
colorbar

subplot(2,3,3)
z = PSTH.velocityMat(idxsort,:);
z(isnan(z)) = 0;
imagesc( x, y, z )
xlabel('time around pupilReset')
ylabel('velocity')
colormap jet
colorbar

subplot(2,3,4)
x = [-intv:intv]*session.dt;
y = 1:length(fPupilResetIdx);
z = nanmean(PSTH.DeconvPupilMat,3) ;
z(isnan(z)) = 0;
imagesc( x, y, z(idxsort,:) )
xlabel('time around pupilReset')
ylabel('Mean deconvolved signal')
colormap jet
colorbar

end