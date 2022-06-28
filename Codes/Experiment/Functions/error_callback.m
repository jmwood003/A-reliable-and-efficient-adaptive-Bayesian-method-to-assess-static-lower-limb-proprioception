function error_callback(src,event, t, alpha_range, beta_range, prior, extreme_trials, iqr_trials, X, pr_left_lookup, pr_right_lookup, strtpos_sigma, TBidx, TLstr)

%Stop the treadmill
accR = 1500;
accL = 1500;   
TMtestSpeed = 0;   
TMrefSpeed = 0; 
format=0;
speedRR=0;
speedLL=0;
accRR=0;
accLL=0;
incline=0;
%Format treadmill input
aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
actualData=reshape(aux',size(aux,1)*2,1);
secCheck=255-actualData; %Redundant data to avoid errors in comm
padding=zeros(1,27);
%Set speeds
Payload=[format actualData' secCheck' padding];
fwrite(t,Payload,'uint8');

%Set the user input configuration 
Fig = ancestor(src,"figure","toplevel");
Fig.UserData.Switch.Value = 'Stop';
Fig.UserData.Message.Value = 'Error!';
Fig.UserData.Message.BackgroundColor = 'r';              

%get user input for the error trial
error_trial = inputdlg('Which trial was wrong?');
error_trial = str2double(error_trial{1});

next_trial = error_trial+1;

%Correct erroneous response
Error_response = Fig.UserData.Resp_Text.Value{error_trial};
if strcmp(Error_response,'left')==1
    Fig.UserData.Resp_Text.Value{error_trial} = 'right';
elseif strcmp(Error_response,'right')==1
    Fig.UserData.Resp_Text.Value{error_trial} = 'left';
end

%Index all stimuli and start positions
AllStims_str = Fig.UserData.Stims.Value;
AllStarts_str = Fig.UserData.Starts.Value;
AllTrials_str = Fig.UserData.Trials.Value;
for i = 1:length(AllTrials_str)
    AllStims(i) = str2double(AllStims_str{i});
    AllStarts(i) = str2double(AllStarts_str{i});
    AllTrials(i) = str2double(AllTrials_str{i});
end
AllStarts(isnan(AllStarts)==1) = [];
AllStims(isnan(AllStims)==1) = [];

%Index the next stimulus and start position
next_start = AllStarts(end);
next_stim = AllStims(end);

%Delete data after the error
AllStims = AllStims(1:error_trial);
AllStarts = AllStarts(1:error_trial);
AllTrials = AllTrials(1:error_trial);
Fig.UserData.Resp_Text.Value = Fig.UserData.Resp_Text.Value(1:error_trial); %Responses
Fig.UserData.Stims.Value = Fig.UserData.Stims.Value(1:error_trial); %Stimulus positions
Fig.UserData.Trials.Value = Fig.UserData.Trials.Value(1:error_trial); %Trials
Fig.UserData.Starts.Value = Fig.UserData.Starts.Value(1:error_trial); %Start positions

%Select a new stimulus position 
%Before calculating the next trial, make sure it is not a preset trial
if ismember(next_trial,extreme_trials)==0 && ismember(next_trial,iqr_trials)==0

    %Binarize the responses
    BinaryResponses = contains(Fig.UserData.Resp_Text.Value,'left');
    
    %Create new vectors for repeated stimuli 
    Unique_stims = unique(AllStims,'stable');
    Nstims = []; Kleft = [];
    for s = 1:length(Unique_stims)
      stim_idx = find(Unique_stims(s)==AllStims);
      Nstims(s) = length(stim_idx);
      Kleft(s) = sum(BinaryResponses(stim_idx));
    end
    
    %Calculate the likelihood of this response given the current parameters
    for a = 1:length(alpha_range)
      for b = 1:length(beta_range)
          psi = normcdf(Unique_stims,alpha_range(a),beta_range(b));
          likelihood(b,a) = prod((psi.^Kleft).*((1-psi).^(Nstims - Kleft)));
      end
    end
    
    %Calculate the posterior and normalize
    posterior = likelihood.*prior;
    posterior = posterior./nansum(nansum(posterior));
    
    %The posterior becomes the prior
    prior = posterior;

    %Calculate the best stimulus for the next trial using information entropy     
    %Loop through all potential stimulus values
    for x = 1:length(X) 
    
        %Calculate the probability of getting response r, after presenting
        %test x at the next trial
        pr_left_x = nansum(nansum(pr_left_lookup(:,:,x).*prior));
        pr_right_x = nansum(nansum(pr_right_lookup(:,:,x).*prior));
    
        %Calculate the posterior distribution for both responses
        Post_left = pr_left_lookup(:,:,x).*prior;
        Post_left = Post_left./pr_left_x;
        Post_right = pr_right_lookup(:,:,x).*prior;
        Post_right = Post_right./pr_right_x;        
    
        %Estimate the entropy of the posterior distribution for each response
        H_left = -nansum(nansum(Post_left.*log2(Post_left)));
        H_right = -nansum(nansum(Post_right.*log2(Post_right)));
    
        EH(x) = (H_left*pr_left_x) + (H_right*pr_right_x);
    end
    %Find the simulus that minimizes entropy
    [~,minH_idx] = min(EH);
    AllStims(next_trial) = X(minH_idx);

    %Get a new start position 
    startpos = round(normrnd(AllStims(next_trial),strtpos_sigma));
    while TBidx(next_trial)==1 && startpos <= AllStims(next_trial) %This means that the start position should be above but it is below
        startpos = round(normrnd(AllStims(next_trial),strtpos_sigma));
    end
    while TBidx(next_trial)==0 && startpos >= AllStims(next_trial) %This means that the start position should be below but it is above
        startpos = round(normrnd(AllStims(next_trial),strtpos_sigma));
    end
    AllStarts(next_trial) = startpos;
  
    %Update interface
    AllTrials(next_trial) = next_trial;
    Fig.UserData.Trials.Value = sprintf('%d \n', AllTrials);
    Fig.UserData.Stims.Value = sprintf('%d \n', [AllStims, nan]);
    Fig.UserData.Starts.Value = sprintf('%d \n', AllStarts);  

else

    AllStims(next_trial) = next_stim;
    AllStarts(next_trial) = next_start;
    startpos = next_start;

    %Update interface
    AllTrials(next_trial) = next_trial;
    Fig.UserData.Trials.Value = sprintf('%d \n', AllTrials);
    Fig.UserData.Stims.Value = sprintf('%d \n', [AllStims, nan]);
    Fig.UserData.Starts.Value = sprintf('%d \n', AllStarts);  

end

%Retrieve marker position data
MkrDiff = Fig.UserData.Position.Value;

%Move treadmill to new stimulus position   
%Treadmill Speeds
minspeed = 10;
maxspeed = 50;
speed = round(minspeed + (maxspeed-minspeed)*rand);

%Update interface
Fig.UserData.Message.BackgroundColor = 'white';
Fig.UserData.Switch.Value = 'Go';              
Fig.UserData.Message.Value = ['Moving to start position (speed=' num2str(speed) ')'];

if startpos < MkrDiff
  TMtestSpeed = speed;
else
  TMtestSpeed = -speed;
end

% %Open treadmill communication 
% t=tcpclient('localhost',1000);
% set(t,'InputBufferSize',32,'OutputBufferSize',64);
% fopen(t);

%Format treadmill input
if strcmp(TLstr,'Left')==1
  aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
elseif strcmp(TLstr,'Right')==1
  aux=int16toBytes([TMtestSpeed TMrefSpeed speedRR speedLL accR accL accRR accLL incline]);      
end
actualData=reshape(aux',size(aux,1)*2,1);
secCheck=255-actualData; %Redundant data to avoid errors in comm
padding=zeros(1,27);
%Set speeds
Payload=[format actualData' secCheck' padding];
fwrite(t,Payload,'uint8');

end