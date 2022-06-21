function error_callback(src,event)

Fig = ancestor(src,"figure","toplevel");
Fig.UserData.Switch.Value = 'Stop';
Fig.UserData.Message.Value = 'Error!';

inputdlg(prompt,dlgtitle,dims,definput,opts)

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