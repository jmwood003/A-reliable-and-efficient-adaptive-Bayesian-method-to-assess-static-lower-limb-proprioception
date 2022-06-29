function left_callback(src,event)   

%Description: function for when the left button is pressed in the
%experimenter interface

%Inputs: required for a callback function
%src: the current user interface object
%event: the button press event structure

%index the figure object
Fig = ancestor(src,"figure","toplevel");

%Disable the buttons so they cant be pressed again
Fig.UserData.Left_btn.Enable = 'off';
Fig.UserData.Right_btn.Enable = 'off';

%Update the response in the user interface 
Responses = Fig.UserData.Resp_Text.Value;
trials = Fig.UserData.Trials.Value; %Index the current trial number
current_trial = str2double(trials{end});
Responses{current_trial} = 'left'; %update the response for the current trial
Responses{current_trial+1} = ' '; %add a space so the stim position and response align
Fig.UserData.Resp_Text.Value = Responses;  %update the display
scroll(Fig.UserData.Resp_Text,'bottom'); %scroll to the bottom 

%Resume the trial
Fig.UserData.Switch.Value = 'Go';
uiresume(Fig);

%Update the message display
Fig.UserData.Message.BackgroundColor = 'white';

%Enable the error button
Fig.UserData.Error_btn.Enable = 'on';

end