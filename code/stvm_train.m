function [model] = stvm_train(Xs,Ys,Xt,options)
% Implementations of Probabilistic Classification Transfer Kernel Vector Machines.
%
% The original PCVM Algorithm is presented in the following paper:
% Huanhuan Chen, Peter Tino and Xin Yao. Probabilistic Classification Vector Machines.
% IEEE Transactions on Neural Networks. vol.20, no.6, pp.901-914, June 2009.
%	Copyright (c) Huanhuan Chen
% The following improvments by Christoph Raab:
% Ability to Transfer Learning with SVD Rotation to algin source and target
% distributions.
% BETA VERSION
% Optional: theta estimation
% Multi-Class Label with One vs One
%--------------------------------------------------------------------------
%Parameters:
% [Xs] - (N,M) Matrix with training data. M refers to dims
% [Ys] - Corrosponding training label for the training
% [Xt] - Testdata to train the Transfer Kernel. (Optional)
% [options] - Struct which contains parameters:
%          .theta - Parameter for theta. Give -1 to make a theta estimation
%                   with theta ~= 0. The theta is fixed to this.
%          .eta - eigenspectrum damping factor for TKL
%          .ker - Kernel Type: 'linear' | 'rbf' | 'lap'
% Output:
% The trained model as struct. For multiclass problems struct array

C = unique(Ys,'stable');
sizeC = size(C,1);

if sizeC == 2
    
    %    Align of feature space examples
    if size(Xs,1) > size(Xt,1) && size(Xt,1)< size(Xt,2)
        
        fprintf("Not Smaller, but not sufficient large\n");
        indxYs1 = find(Ys==1);
        indxYs2 = find(Ys==-1);
        
        s1 = size(indxYs1,1);
        s2 = size(indxYs2,1);
        
        if (s1 >= round(size(Xt,1)/2)) &&(s2 >= round(size(Xt,1)/2))
            s1 = round(size(Xt,1)/2); s2 = round(size(Xt,1)/2);
        elseif s1 < round(size(Xt,1)/2)
            labelDiff = abs(size(Xt,1)/2-s1);
            s2 =s1+2*labelDiff;
        elseif s2 < round(size(Xt,1)/2)
            labelDiff = abs(size(Xt,1)/2-s2);
            s1 =s2+2*labelDiff;
        end
        
        
        Xs1 = Xs(indxYs1,:);
        C1 = cov(Xs1');
        [v,e] = eigs(C1,s1);
        Xs1 = (Xs1' * v)';
        
        Xs2 = Xs(indxYs2,:);
        C2 = cov(Xs2');
        [v,e] = eigs(C2,s2);
        Xs2 = (Xs2' * v)';
        
        Xs = [Xs1;Xs2];
        Ys = [ones(size(Xs1,1),1);ones(size(Xs2,1),1)*-1];
        
        if(size(Xs,1) > size(Xt,1))
            Xs = Xs(1:size(Xt,1),:);
            Ys = Ys(1:size(Xs,1),:);
        end
    end
    if size(Xs,1) > size(Xt,1) && size(Xt,1)> size(Xt,2)
        fprintf("Not Smaller, but sufficient large\n");
%             continue;
    end
    if size(Xs,1) < size(Xt,1)
        %
        %             XsX = zeros(size(Xt));
        %             XsX(1:size(Xs,1),1:size(Xs,2)) = Xs;
        %             Xs = XsX;
        %             nullLabels = size(Xt,1)-size(Ys,1);
        %             addTrainLabels = randi([0 1], nullLabels,1);
        %             addTrainLabels(find(addTrainLabels==0)) = -1;
        %             Ys = [Ys;addTrainLabels];
        fprintf("Smaller")
        data = [];
        label = [];
        diff = size(Xt,1) - size(Xs,1);
        sampleSize = floor(diff / sizeC);
        for c = C'
            idxs = find(Ys == c);
            classData= Xs(idxs,:);
            m = mean(classData); sd = std(classData);
            augmentationData = mvnrnd(m,sd,sampleSize);
            data = [data; classData;augmentationData];
            label = [label;ones(size(classData,1),1)*c;ones(sampleSize,1)*c];
            
        end
        
        sampleSize = mod(diff,sizeC);
        c = C(end);
        idxs = find(Ys == c);
        classData= Xs(idxs,:);
        m = mean(classData); sd = std(classData);
        augmentationData = mvnrnd(m,sd,sampleSize);
        data = [data;augmentationData];
        label = [label;ones(sampleSize,1)*c];
        Xs = data;Ys = label;
    end
    
    
    [US,SZ,VS] = svd(Xs,'econ');
    [U,S,V] = svd(Xt,'econ');
    Xs = U*SZ*V';
    %     Xt = US*S*VS';
    %
    % the maximal iterations
    niters = 600;
    
    pmin=10^-5;
    errlog = zeros(1, niters);
    
    ndata= size(Xs,1);
    
    display = 0; % can be zero
    
    % Initial weight vector to let w to be large than zero
    w = rand(ndata,1)+ 0.2;
    
    % Initial bias b
    b = randn;
    
    % initialize the auxiliary variables Ht to follow the target labels of the training set
    Ht = 10*rand(ndata,1).*Ys + rand(ndata,1);
    
    % Threshold to determine whether this is small
    w_minimal = 1e-3;
    
    % Threshold for convergence
    threshold = 1e-3;
    
    % all one vector
    I = ones(ndata,1);
    
    y = Ys;
    
    % active vector indicator
    nonZero = ones(ndata,1);
    
    % non-zero wegith vector
    w_nz = w(logical(nonZero));
    
    wold = w;
    
    repy=repmat(Ys(:)', ndata, 1);
    
    if display
        number_of_RVs = zeros(niters,1);
    end
    
    
    theta = options.theta;
    K = kernel(options.ker, [Xs', Xt'], [],theta);
    
    % Take the left upper square of the K Matrix for the learning algorithm
    Kl = K(1:ndata,1:ndata);
    
    
    % Main loop of algorithm
    for n = 1:niters
        %     fprintf('\n%d. iteration.\n',n);
        
        
        % Note that theta^2
        % scale columns of kernel matrix with label Ys
        Ky = Kl.*repmat(Ys(:)', ndata, 1);
        
        % non-zero vector
        Ky_nz = Ky(:,logical(nonZero));
        
        if n==1
            Ht_nz = Ht;
        else
            Ht_nz = Ky_nz*w_nz + b*ones(ndata,1);
        end
        
        Z = Ht_nz + y.*normpdf(Ht_nz)./(normcdf(y.*Ht_nz)+ eps);
        
        % Adjust the new estimates for the parameters
        M = sqrt(2)*diag(w_nz);
        
        % new weight vector
        Hess = eye(size(M,1))+M*Ky_nz'*Ky_nz*M;
        Hess = Hess+eps*ones(size(Hess));
        U    = chol(Hess);
        Ui   = inv(U);
        
        w(logical(nonZero)) = M*Ui*Ui'*M*(Ky_nz'*Z - b*Ky_nz'*I);
        
        S = sqrt(2)*abs(b);
        b = S*(1+ S*ndata*S)^(-1)*S*(I'*Z - I'*Ky*w);
        
        
        % expectation
        A=diag(1./(2*w_nz.^2));
        beta=(0.5+pmin)/(b^2+pmin);
        
        
        nonZero	= (w > w_minimal);
        
        % determine used vectors
        used = find(nonZero==1);
        
        w(~nonZero)	= 0;
        
        % non-zero weight vector
        w_nz = w(nonZero);
        
        if display % && mod(n,10)==0
            number_of_RVs(n) = length(used);
            plot(1:n, number_of_RVs(1:n));
            title('non-zero vectors')
            drawnow;
        end
        
        if (n >1 && max(abs(w - wold))< threshold)
            
            
            
            break;
        else
            wold = w;
        end
        
    end
    
    if n<niters
        %         fprintf('PCVM terminates in %d iteration.\n',n);
        
    else
        %         fprintf('Exceed the maximal iterations (500). \nConsider to increase niters.\n')
    end
    model.w = w;
    model.b = b;
    model.used = used;
    model.theta = theta;
    model.errlog = errlog;
    model.K = K;
    model.Ys = Ys;
elseif sizeC > 2
    fprintf('\nMulticlass Problem detected! Splitting up label vector..\n');
    u = 1;
    
    %For Loops to calculate the One vs One Models
    for j = 1:sizeC
        for i=j+1:sizeC
            
            one = C(j,1);
            two = C(i,1);
            
            oneIndx = find(Ys == one);
            twoIndx = find(Ys == two);
            
            YsOR = [ones(size(oneIndx,1),1); ones(size(twoIndx,1),1)*-1];
            
            XsOR= [Xs(oneIndx,:); Xs(twoIndx,:)];
            
            singleM = stvm_train(XsOR,YsOR,Xt,options);
            singleM.one = one; singleM.two = two;
            model(u) = singleM;
            
            u = u+1;
        end
    end
    fprintf('\nPCTKVM: Training finished\n');
else
    fprintf('\nNo suitable labels found! Please enter a valid class labels\n');
end

