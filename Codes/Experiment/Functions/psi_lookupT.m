function [pr_left_x, pr_right_x] = psi_lookupT(X, alpha_range, beta_range)

%Create a look up table for success and failure trials given both
%parameters
pr_left_x = nan(length(X),length(beta_range),length(alpha_range));
pr_right_x = nan(length(X),length(beta_range),length(alpha_range));
for x = 1:length(X)
    for a = 1:length(alpha_range)
        for b = 1:length(beta_range)
            psi = normcdf(X(x),alpha_range(a),beta_range(b));
            pr_left_x(b,a,x) = psi;
            pr_right_x(b,a,x) = 1-psi;
        end
    end
end  
%betas in rows, alpha in column, stim values in pages

end