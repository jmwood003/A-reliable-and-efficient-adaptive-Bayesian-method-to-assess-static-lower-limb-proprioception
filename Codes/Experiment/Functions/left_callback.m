function response = left_callback(src,event,AllResponses)

% disp('Response = Left');
% response = 'l';
% AllResponses{trial} = 'l';
% % keyboard;
fig = ancestor(src,'figure','toplevel')
fig.resp_text.Value = AllResponses
% fig.UserData
end