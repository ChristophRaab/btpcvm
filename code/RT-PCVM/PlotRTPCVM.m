rand('state', 1);
randn('state', 1);

perp=[50,30,40];
pcadim=[70,50,100];
for n=3:1:3
    j=perp(n);
    i=pcadim(n);
    % Load Ripley's synthetic training data (see reference in manual)
    load org_vs_people_1
    
    
    trainX = Xs'; trainY = Ys; testX = Xt'; testY = Yt;
    
    %
    % N		= 100;
    %
    % num = size(trainX,1);
    % p = randperm(num);
    %
    % trainX = trainX(p(1:N),:);
    % trainY = trainY(p(1:N),:);
    
    % The initial version of Gaussian width: theta
    % Note: to make the theta positive in the optimization process
    % the kernel is calculated as exp(- theta*theta* DistMat)
    % Due to the EM algorithm, the initial value of theta is important and
    % should be chosen for different data sets
    options.ker = 'rbf';      % TKL: kernel: 'linear' | 'rbf' | 'lap'
    options.eta = 2.0;           % TKL: eigenspectrum damping factor
    options.gamma = 1.0;         % TKL: width of gaussian kernel
    options.k = 100;              % JDA: subspaces bases
    options.lambda = 1.0;        % JDA: regularization parameter
    options.svmc = 10.0;         % SVM: complexity regularizer in LibSVM
    options.g = 40;              % GFK: subspace dimension
    options.tcaNv = 50;          % TCA: numbers of Vectors after reduction
    options.theta = 1;
    
    Xs = trainX'; Xt = testX'; Ys = trainY; Yt = testY;
    
    Xs=bsxfun(@rdivide, bsxfun(@minus,Xs,mean(Xs)), std(Xs));
    Xt=bsxfun(@rdivide, bsxfun(@minus,Xt,mean(Xt)), std(Xt));
    trainX = Xs';
    testX = Xt';
    
    
    model = rtpcvm_train(full(trainX),full(trainY),full(testX),options);
    [erate, nvec, label, y_prob] = rtpcvm_predict(full(testY),model);
    theta_initial	= 1;
    
    
    fprintf('\nPCVM CLASSIFICATION test error: %.2f%%', erate*100)
    fprintf('\nThe initial theta is : %.2f', theta_initial)
    fprintf('\nThe optimized theta is : %.2f', options.theta)
    fprintf('\nNumber of vectors : %d \n \n',nvec)
    
    [trainX,loss1]  = tsne(full(trainX),'Algorithm','barneshut','NumDimensions',2,'NumPCAComponents',i,'Perplexity',j);
    [testX,loss2]  = tsne(full(testX),'Algorithm','barneshut','NumDimensions',2,'NumPCAComponents',i,'Perplexity',j);
    
    % % Plot it
    figure
    plot(trainX(trainY==-1,1),trainX(trainY==-1,2),'r.');
    hold on
    plot(trainX(trainY==1,1),trainX(trainY==1,2),'bx');
    box = 1.5*[min(testX(:,1)) max(testX(:,1)) min(testX(:,2)) max(testX(:,2))];
    axis(box)
    drawnow
    
    hold on
    
    h = gca;
    a = get(h,'Xlim');
    dd = get(h,'Ylim');
    box = [a dd];
    
    % Visualise the results
    gsteps		= 100;
    range1		= box(1):(box(2)-box(1))/(gsteps-1):box(2);
    range2		= box(3):(box(4)-box(3))/(gsteps-1):box(4);
    [grid1 grid2]	= meshgrid(range1,range2);
    Xgrid		= [grid1(:) grid2(:)];
    
    % Compute PCVM over a grid for visualisation purposes
    %         modelplot = pctkvm_train(trainX,Ys,Xgrid,options);
    %         [erate1, nvec1, label, y_grid] = pctkvm_predict(Ys,Yt,modelplot);
    %
    % Show decision boundary (p=0.5) and illustrate p=0.25 and 0.75
    %contour(range1,range2,reshape(y_grid,size(grid1)),[0.5 0.5],'--','Color','g','LineWidth',2);
    %contour(range1,range2,reshape(y_grid,size(grid1)),[0.25 0.75],'--','Color',0.7*[1 1 1],'LineWidth',2);
    
    plot(trainX(model.used,1),trainX(model.used,2),'ko','LineWidth',2);
    xlabel("Kullback�Leibler divergence Original vs Reduced Space = "+num2str(loss1+loss2/2));
    title("PCTKVM, Number Vectors = "+num2str(nvec)+", Error = "+num2str(round(erate*100))+"%" ,'FontSize',14)
end

