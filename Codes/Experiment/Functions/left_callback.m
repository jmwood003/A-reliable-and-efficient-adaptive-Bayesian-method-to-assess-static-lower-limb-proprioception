function left_callback(src,event)

Fig = ancestor(src,"figure","toplevel");
Responses = Fig.UserData.Resp_Text.Value;
trials = Fig.UserData.Trials.Value;

current_trial = str2num(trials{end});
Responses{current_trial} = 'left';
Responses{current_trial+1} = ' ';

Fig.UserData.Resp_Text.Value = Responses;
scroll(Fig.UserData.Resp_Text,'bottom');

Fig.UserData.Switch.Value = 'Go';

uiresume(Fig);

end