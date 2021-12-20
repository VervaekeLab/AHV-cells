figure,
ax1= subplot(3,1,1);
plot(session.velocity)
ylabel('velocity')
ylim([-200,200])

ax2= subplot(3,1,2);
%yyaxis left
plot(pupil,'-')
hold all
plot(find(pupilResetIdx),pupil(pupilResetIdx),'ro','MarkerSize',10)
hold all
ylabel('pupil displacement')
%yyaxis right


ax3= subplot(3,1,3);
plot(dpupil,'-')
hold all
plot(find(pupilResetIdx),dpupil(pupilResetIdx),'ro','MarkerSize',10)
hold all
plot(xlim, [-1,-1]* max(abs(dpupil)),'-')
plot(xlim, [1,1]* max(abs(dpupil)),'-')
xlabel('time')
ylabel('pupil velocity')
linkaxes([ax1,ax2,ax3], 'x')
