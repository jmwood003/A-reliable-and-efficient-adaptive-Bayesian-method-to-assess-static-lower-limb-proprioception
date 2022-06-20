function error_callback(src,event)

Fig = ancestor(src,"figure","toplevel");
Fig.UserData.Switch.Value = 'Stop';
Fig.UderData.Message.Value = 'Error!';

uiwait(Fig);

Responses = Fig.UserData.Resp_Text.Value;
trials = Fig.UserData.Trials.Value;
% 
% current_trial = str2num(trials{end});
% Responses{current_trial} = 'right';
% 
% Fig.UserData.Resp_Text.Value = Responses;
% 
% uiresume(Fig);
% 
% Fig.UserData.Switch.Value = 'Go';

end