% This script tests the performance of the RT-PCVM for the Reuters, 20
% newsgroup and image dataset.
% BETA VERSION: To evaluate th RT-PCVM for only one dataset-type, comment
% the others.

close all;
clear all;
addpath(genpath('../../libsvm/matlab'));
addpath(genpath('../../data'));
addpath(genpath('../code'));

options.ker = 'rbf';      % TKL: kernel: | 'rbf' |'srbf | 'lap'
options.eta = 2.0;        % TKL: eigenspectrum damping factor
options.gamma = 1;        % TKL: width of gaussian kernel
options.svmc = 10.0;      % SVM: complexity regularizer in LibSVM
options.theta = 1;

testSize= 5;
for strData = {'org_vs_people','org_vs_place', 'people_vs_place'} %
    
    errResult = [];
    nvecResult = [];
    
    for iData = 1:2
        data = char(strData);
        data = strcat(data, '_', num2str(iData));
        load(strcat('../../data/Reuters/', data));
        
        fprintf('data=%s\n', data);
        
        Z =full(Xs);
        X = full(Xt);
        
        %% Z-SCORE and Sampling
        Z=bsxfun(@rdivide, bsxfun(@minus,Z,mean(Z)), std(Z));
        X=bsxfun(@rdivide, bsxfun(@minus,X,mean(X)), std(X));
        Z = Z';X = X';
        soureIndx = crossvalind('Kfold', Ys, 2);
        targetIndx = crossvalind('Kfold', Yt, 2);
        
        Z = Xs(find(soureIndx==1),:);
        Ys = Ys(find(soureIndx==1),:);
        
        
        X = Xt(find(targetIndx==1),:);
        Yt = Yt(find(targetIndx==1),:);
        
        %% SVM 
        K = kernel(options.ker, [Z', X'], [],options.gamma);
        
        model = svmtrain(full(Ys), [(1:m)', K(1:m, 1:m)], ['-c ', num2str(options.svmc), ' -t 4 -q 1']);
        [label, acc,scores] = svmpredict(full(Yt), [(1:n)', K(m+1:end, 1:m)], model);
        
        fprintf('SVM = %0.4f\n', acc(1));
        
        %% PCVM
        
        model = pcvm_train(Z,Ys,options.gamma);
        [erate, nvec, label, y_prob] = pcvm_predict(Z,Ys,X,Yt,model);
         erate = erate*100;
        fprintf('\nPCVM %.2f%% \n', erate);
        
        %% BTPCVM
        model = rtpcvm_train(full(Z),full(Ys),full(X),options);
        [erate, nvec, label, y_prob] = rtpcvm_predict(Yt,model);
        erate = erate*100;
        fprintf('\nBTPCVM %.2f%% \n', erate);
    end
end

for ngData = {'comp_vs_rec','comp_vs_sci','comp_vs_talk','rec_vs_sci','rec_vs_talk','sci_vs_talk'}%
    for j=1:36
        
        data = char(ngData);
        data = strcat(data, '_', num2str(j));
        load(strcat('../../data/20Newsgroup/', data));
        fprintf('data=%s\n', data);
        
        %% Z-SCORE and Sampling
        Xs=bsxfun(@rdivide, bsxfun(@minus,Xs,mean(Xs)), std(Xs));
        Xt=bsxfun(@rdivide, bsxfun(@minus,Xt,mean(Xt)), std(Xt));
        
        Z = Xs';
        X = Xt';
        soureIndx = crossvalind('Kfold', Ys, 2);
        targetIndx = crossvalind('Kfold', Yt,2);
        
        Z = Z(find(soureIndx==1),:);
        Ys = Ys(find(soureIndx==1),:);
        
        
        X = X(find(targetIndx==1),:);
        Yt = Yt(find(targetIndx==1),:);
       
        %% SVM 
        K = kernel(options.ker, [Z', X'], [],options.gamma);
        
        model = svmtrain(full(Ys), [(1:m)', K(1:m, 1:m)], ['-c ', num2str(options.svmc), ' -t 4 -q 1']);
        [label, acc,scores] = svmpredict(full(Yt), [(1:n)', K(m+1:end, 1:m)], model);
        
        fprintf('SVM = %0.4f\n', acc(1));
        
        %% PCVM
        model = pcvm_train(Z,Ys,options.gamma);
        [erate, nvec, label, y_prob] = pcvm_predict(Z,Ys,X,Yt,model);
         erate = erate*100;
        fprintf('\nPCVM %.2f%% \n', erate);
        
        %% BTPCVM
        model = rtpcvm_train(full(Z),full(Ys),full(X),options);
        [erate, nvec, label, y_prob] = rtpcvm_predict(Yt,model);
        erate = erate*100;
        fprintf('\nBTPCVM %.2f%% \n', erate);
    end
end
