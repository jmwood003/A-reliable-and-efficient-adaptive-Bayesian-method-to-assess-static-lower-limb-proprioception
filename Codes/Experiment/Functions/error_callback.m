function error_callback(src, event, t, alpha_range, beta_range, prior, extreme_trials, random_trials, X, pr_left_lookup, pr_right_lookup, strtpos_mu, strtpos_sigma, TBidx, TLstr)

%Description: function for when the error button is pressed in the
%experimenter interface

%Inputs: 
% src: the current user interface object (required for a callback function)
% event: the button press event structure (required for a callback function)
% t: the treadmill controller object
% alpha_range: vector of the range of possible alpha values
% beta_range: vector of the range of possible beta values
% prior: the current prior for the alpha and beta estimates, matrix
% extreme_trials: the trial index for the extreme stimuli 
% random_trials: the trial index for the randomly stimuli 
% X: vector of all possible simulus location
% pr_left_lookup: matrix, look-up table for the probability of responding 'left'
% pr_right_lookup: matrix, look-up table for the probability of responding 'right'
% strtpos_sigma: the variability for the start position selection
% TBidx: index for the start position being above or below the stim position
% TLstr: string, specifying which limb is the test limb ('left' or 'right')


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

%Index the user interface object
Fig = ancestor(src,"figure","toplevel");

%Update the interface
Fig.UserData.Switch.Value = 'Stop';
Fig.UserData.Message.Value = 'Error!';
Fig.UserData.Message.BackgroundColor = 'r';              

%Get user input for the error trial
error_trial = inputdlg('Which trial was wrong?');
error_trial = str2double(error_trial{1});

%Set the default
incorrect_response = Fig.UserData.Resp_Text.Value{error_trial};
if strcmp(incorrect_response,'left')
    default = 'right';
else
    default = 'left';
end

%Input the correct response
correct_respponse = questdlg('Select the correct response','Enter correct response','left','right',default);

%Correct erroneous response
Fig.UserData.Resp_Text.Value{error_trial} = correct_respponse;

%Set the next trial after the error
next_trial = error_trial+1;

%Index all stimuli and start positions and turn the into numerical format
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

%Delete all trials after the error and update the display
AllStims = AllStims(1:error_trial);
AllStarts = AllStarts(1:error_trial);
AllTrials = AllTrials(1:error_trial);
Fig.UserData.Resp_Text.Value = Fig.UserData.Resp_Text.Value(1:error_trial); %Responses
Fig.UserData.Stims.Value = sprintf('%d \n', AllStims); %Stimulus positions
Fig.UserData.Trials.Value = sprintf('%d \n', AllTrials); %Trial number
Fig.UserData.Starts.Value = sprintf('%d \n', AllStarts); %Start positions

%Select a new stimulus position 
%Before calculating the next trial, make sure it is not a pre-set stimulus
if ismember(next_trial,extreme_trials)==0 && ismember(next_trial,random_trials)==0

    %If not a pre-set response, use the corrected responses to calculate
    %the next stim position 

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
    if TBidx(next_trial)==1
        startpos = round(normrnd(strtpos_mu,strtpos_sigma));
    elseif TBidx(next_trial)==0
        startpos = round(normrnd(-strtpos_mu,strtpos_sigma));
    end    
    AllStarts(next_trial) = startpos;
  
    %Update interface
    AllTrials(next_trial) = next_trial;
    Fig.UserData.Trials.Value = sprintf('%d \n', AllTrials);
    Fig.UserData.Stims.Value = sprintf('%d \n', [AllStims, nan]);
    Fig.UserData.Starts.Value = sprintf('%d \n', AllStarts);  

else %If it is a pre-set stimulus, keep the same stimulus value

    %Set the origional stim and start position
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

%Update interface
Fig.UserData.Message.BackgroundColor = 'white';
Fig.UserData.Switch.Value = 'Go';              

%Move treadmill to new stimulus position   
%Treadmill Speeds
minspeed = 10;
maxspeed = 30;
speed = round(minspeed + (maxspeed-minspeed)*rand);
Fig.UserData.Message.Value = ['Moving to start position (speed=' num2str(speed) ')'];
if startpos < MkrDiff
  TMtestSpeed = speed;
else
  TMtestSpeed = -speed;
end
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