% LittleRampCar_NN1.m

clear; clc

%%
episode_loops = 1e3;

nT = 1e3;
r = -1;

%%

detaS = 0.5; % unit m
rangS = [-1.2 0.5]; % unit m
detaV = 0.04;  % unit km/h
rangV = [-0.07 0.07];  % unit km/h
nTiling = 10;  % number of tiling
% ActionSet;
ActionSet = [-1 0 1];
n_act = length(ActionSet);
nHidden = 400;
W_obj = get_W_obj_LitleCar_NN1(nHidden, rangV, rangS, detaS, detaV, nTiling, ActionSet);

%% Reinforcement Learning paramerters

gamma = 1;
alpha = 0.5*0.1/nTiling;

epsilons = [linspace(1e-1, 1e-3, episode_loops-1) 0];
W_obj.gamma = gamma;
W_obj.alpha = alpha;

%% Recorder

xr = zeros(episode_loops, 1);


W_obj_copy = W_obj;
wobj_copy_num = 10;
wobj_copy_count = 0;

%% experience replay

% replay_buffer_size = 80;
% replay_buffer_size = episode_loops;
% replay_point = 0;    % ���ݼ�¼ָ��
% replay_flag = 0;     % ��ʶ��¼����
% replay_batch = in_epi_number * Ne;
% Rs_record = zeros(in_epi_number, Ne);    % ÿһ���Ļر�
% Qloc = zeros(in_epi_number, 6, Ne);    % ÿһ���� state-action
% QLOC = zeros(replay_batch * replay_buffer_size, 6)*NaN;    % ÿһ���� state-action
%% 

s = linspace(W_obj.rangS(1), W_obj.rangS(2), 200);
v = linspace(W_obj.rangV(1), W_obj.rangV(2), 200);
[Ms, Mv] = meshgrid(s, v);

Val = zeros(size(Ms));
current_ind_sv = W_obj.coding_index_transform(W_obj, [Ms(:), Mv(:)]');
for itr = 1:numel(Ms)
    Val(itr) = W_obj.max_Q_value_of_State(W_obj, [Ms(itr); Mv(itr)]);
end

figure(2);clf
hmesh = mesh(Ms, Mv, Val);
view(-159, 58)
set(gca, 'zdir', 'reverse')

x_record = zeros(nT, 3)*NaN;
figure(3);clf
hplot = plot(x_record(:, 1), x_record(:, 2), '.'); 

%% ��ѭ��

tic
hwait = waitbar(0, 'Processing ...');
for etr = 1 : episode_loops
    
    if rem(etr, 10) == 0
        waitbar(etr/episode_loops, hwait, [sprintf('Processing ... %2.1f',etr/episode_loops*100) '%']);
    end
    
%     epsilon = epsilons(etr);
    epsilon = 0.01;
%     epsilon = 0;
    
    %% initialization
    
    x = [-pi/6; 0];
    action = 0;
    itr_flag = false;
    
    x_record = zeros(nT, 3)*NaN;
    
    for itr = 1:nT
        
        wobj_copy_count = wobj_copy_count + 1;
        if wobj_copy_count >= wobj_copy_num
            W_obj_copy = W_obj;      % ��¡һ����ǰֵ��������ѡ�� aciton
            wobj_copy_count = 0;
        end
        
        %% ����״̬����
        
        x_record(itr, :) = [x' action];
        
        x_ = x;
        x = W_obj.state_update(W_obj, x, action);
        
        if x(1) >= W_obj.rangS(2) - 1e-4
            itr_flag = true;
            break;
        end
        
        %% ��¼״̬����
        
        %% ����֪ʶ��
        
        W_obj = W_obj.update_ActionFunction(W_obj, W_obj_copy, x_, action, x, r);
        
        %% ѡ����һ���Ĳ��� % epsilon - greedy
        
        action = W_obj.choose_next_action(W_obj, x, epsilon);
        
    end
    
    xr(etr) = itr;
    
    if ~itr_flag
        disp(['train finished, itr_flag = false, itr = ' num2str(itr)]);
%         disp(['train finished, itr_flag = true, itr = ' num2str(itr)]);
    end
    
    if rem(etr, 2) == 0
        for itr = 1:numel(Ms)
            Val(itr) = W_obj.max_Q_value_of_State(W_obj, [Ms(itr); Mv(itr)]);
        end
        set(hmesh, 'zdata', Val);
%         title(etr);
        
        set(hplot, 'xdata', x_record(:, 1), 'ydata', x_record(:, 2));
        title(xr(etr));
        
        drawnow;
        pause(0.00001);
    end
    
    %%
    %     %% ��һ��̽����ɺ󣬸���Q����
    %
    %     Qloc_ = reshape(permute(Qloc, [1 3 2]), [], 6);
    %     W_obj = update_ActionFunction_linear(W_obj, Qloc_(end:-1:1, :), alpha);
    %
%     %% ����׷������� replay_buffer_size ��������
%     
%     replay_point = replay_point + 1;
%     if replay_point > replay_buffer_size
%         replay_point = 1;
%     end
%     
%     QLOC((replay_point-1)*replay_batch+1:replay_point*replay_batch, :) = Qloc_;
%     
%     if replay_flag < replay_point*replay_batch
%         replay_flag = replay_point*replay_batch;
%     end
%     
%     % experience replay
%     uniform_ind = ceil(rand(replay_batch*min([replay_point 5]), 1)*replay_flag);
%     W_obj = update_ActionFunction_linear(W_obj, QLOC(uniform_ind, :), alpha);
    
    %%
    %         Rs_record4(etr, :) = Rsum';
    %         R_Recorder(etr, :) = sum(Rs_record);
    
end

close(hwait)
tooc = toc;
toc

%%

%% initialize figure

% 
% figure(601);clf
% % semilogy(Rs_record4.*(ones(size(Rs_record4,1), 1)*reward_weigh))
% hRs = plot(Rs_record4.*(ones(size(Rs_record4,1), 1)*reward_weigh));
% legend('������','����ǣ��������', '�ϳ�������' ,'�ٶ�ƫ��');
% set(gca, 'xlim', [0 episode_loops]);

% nei = 1;
% figure(101);clf
% hold on;
% hnei(1) = plot(initial_notch(1, :), initial_notch(2, :), 'ks', 'linewidth', 2);
% hnei(2) = plot(loc_Notchs1(:), loc_Notchs2(:), 'co');
% hnei(3) = plot(loc_Notchs1(:, nei), loc_Notchs2(:, nei), 'r.-');
% set(gca, 'xlim', [-1 1]*12, 'ylim', [-1 1]*12);
% box on;
% grid on;





















