function response = left_callback(src,event)

Fig = ancestor(src,"figure","toplevel");
Responses = Fig.UserData.Resp_Text.Value;
trials = Fig.UserData.Trials.Value;

current_trial = str2num(trials{end});
Responses{current_trial} = 'left';

Fig.UserData.Resp_Text.Value = Responses;

end