function PSIfig = plotPsi(T, X)

%Description: plots the psi algorithm data, stride by stride and the
%estimate

%Inputs: 
% T = data table from the experiment
% X = all possible stimulus positions

%Output
%Fig = figure handle

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

BslDiff = T.BslDiff(end);

%Plot the estimated psi and the actual data
psi_est = normcdf(X,T.Alpha_EV(end)+round(BslDiff),T.Beta_EV(end));

C = lines(5);
dataC = C(1,:);
psiC = C(2,:);

%Create new vectors for repeated stimuli 
Unique_stims = unique(T.AllStims+round(BslDiff));
Nstims = []; Kleft = [];
for s = 1:length(Unique_stims)
  stim_idx = find(Unique_stims(s)==T.AllStims+round(BslDiff));
  Nstims(s) = length(stim_idx);
  Kleft(s) = sum(T.BinaryResponses(stim_idx));
end

t_x = 1:length(T.AllStims);
Corrected_stims = T.AllStims+round(BslDiff); 

%Plot
PSIfig = figure; subplot(2,4,1:2); hold on
plot(t_x,T.Alpha_EV+round(BslDiff),'o-','linewidth',2);
plot(t_x(T.BinaryResponses==1), Corrected_stims(T.BinaryResponses==1),'ko','MarkerFaceColor','k');
plot(t_x(T.BinaryResponses==0), Corrected_stims(T.BinaryResponses==0),'ko','MarkerFaceColor','none');
plot(1:length(T.AllStims),T.AllStims+round(BslDiff),'k-','linewidth',1.5);
plot(1:length(T.Alpha_EV),zeros(1,length(T.Alpha_EV)),'k--','linewidth',2);
xlabel('Trial'); ylabel('Stimiulus');
legend(['\alpha estimate = ' num2str(round(T.Alpha_EV(end)+round(BslDiff),2))],'Stimulus (r = "left")','Stimulus (r = "right")');
legend('boxoff');
ylim([-100 100]);
title([strrep(T.SID{1},'_',' '), T.Test{1}, ' - trial by trial']);
set(gca,'FontName','Ariel','FontSize',15);

subplot(2,4,5:6); hold on
plot(1:length(T.Beta_EV),T.Beta_EV,'ro-','linewidth',2);
plot(1:length(T.Beta_EV),zeros(1,length(T.Beta_EV)),'k--','linewidth',2);
xlabel('Trial'); ylabel('Stimiulus');
legend(['\beta = ' num2str(round(T.Beta_EV(end),2))]);
legend('boxoff');
ylim([0 100]);
set(gca,'FontName','Ariel','FontSize',15);

subplot(2,4,[3 4 7 8]); hold on
plot(X,psi_est,'Color',psiC,'linewidth',2);
plot(Unique_stims,(Kleft./Nstims),'o', 'MarkerEdgeColor',dataC, 'MarkerFaceColor',dataC);
legend('Estimated Psi','Responses','location','northwest'); legend('boxoff');
ylabel('p_{left more foreward}'); xlabel('Stimulus')
title('Estimate');    
xlim([-100 100]); ylim([0 1]);
set(gca,'FontName','Ariel','FontSize',15);

end