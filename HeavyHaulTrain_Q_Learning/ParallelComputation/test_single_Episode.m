% test_single_Episode.m


% clear;clc


episode_loops = 10; 

large_neg_reward = -1e10;    % һ���ܴ�ĸ�reward

%%
dt = 0.1;
T = 500;
detaT = 5;
tvec = dt:dt:T;

v_speed = 60/3.6;

Nt = 200+2;
Ne = 1;

X = zeros(Nt*2, Ne);     % ǰ�� Nt �����ٶȣ����� Nt ����λ��
U = zeros(Nt, Ne);     % ǰ�� Nt �����ٶȣ����� Nt ����λ��

X(1:Nt, :) = v_speed;     % ���ٶ�


carType = zeros(Nt, 1) == 1;  % �������ͣ����������ϳ�
carType([1 end]) = true;        % һͷһβ��������

Nl = sum(carType);
Nw = sum(~carType);

MotorNotch = zeros(Nl, Ne) + 6;     % ÿ�������ж����ļ�λ

% TBCL_force

%% initialization

[Ad, Bd, TBcl, airTimeDelay, Abr, LenTrain, mTrainGroup, C0, Ca, KK, DD] = ...
    initialize_locomotive_char(dt, carType, Ne);

% Bd = -Bd * 1e3;

LenTrains = LenTrain'*ones(1, Ne);


%% Load the infrastructure
load('RampPositionList');  % 1.Format:start(m) end(m) gradient, 2.Range: [-10000m,100000m]
% load('RampPoint'); % 1.Format:position(m) Height(m),  2.Range:[9000m,37972m]

rampList = RampPositionList(:, [1 3]);

%% Air break

air_timer = zeros(Nw, Ne);        % �����ƶ���ʱ��, ��ǰ��
air_timer_ = zeros(Nw, Ne);        % �����ƶ���ʱ���� ��һ����
% AirBrkNotch = round(-rand(1, Ne)*2);       % �����ƶ���-2, -1, 0;
AirBrkNotch = round(-rand(1, Ne)*0);       % �����ƶ���-2, -1, 0;
AirBrkNotch_ = zeros(1, Ne);      % �����ƶ�֮ǰһ�ο�������1��ʾ�ƶ���0��ʾ����

F_target = zeros(Nw, Ne);
currentF = zeros(Nw, Ne);

%% Q matrix

S = 100/3.6*T;

dl = 300;   % meter
dv = 1;     % km/h

s_vec = 0:dl:S+dl*3;
v_vec = -dv*1:dv:110+dv*3;

ActionSet = get_ActionSet();
n_act = size(ActionSet, 1);
% ActionSet = zeros(27,3);
% NumOfActions = size(ActionSet,1);

Q = zeros(length(s_vec), length(v_vec), n_act);

action = ones(1, Ne);
% action_ = action;

MotorNotch = MotorNotch + ActionSet(action, 1:2)';
AirBrkNotch = AirBrkNotch + ActionSet(action, 3)';

v_tmp = ceil(X(1, :)*3.6)+2;
s_tmp = ceil(X(Nt+1, :)/dl)+1;

% figure; mesh(Q(:, : , 5))

%% Reinforcement Learning paramerters

gamma = 1;
alpha = 0.8;

% epsilons = [linspace(0.5, 1e-2, episode_loops*8/10) zeros(1, episode_loops*2/10)];
epsilons = [linspace(0.5, 1e-2, episode_loops*8/10) zeros(1, episode_loops*2/10)];


%% Recorder


X_Recorder = zeros(length(tvec), Ne);

F_l =  zeros(length(tvec), Ne);
F_w =  zeros(length(tvec), Ne);
F_c =  zeros(length(tvec), Ne);
errV =  zeros(length(tvec), Ne);

air_Notchs =  zeros(length(tvec), Ne);
loc_Notchs1 =  zeros(length(tvec), Ne);
loc_Notchs2 =  zeros(length(tvec), Ne);

locF = zeros(length(tvec), Ne);
airF = zeros(length(tvec), Ne);
addF = zeros(length(tvec), Ne);
basF = zeros(length(tvec), Ne);

in_epi_number = round(T/detaT);                         %

reward_Record = zeros(in_epi_number, Ne, 4);

R_Recorder = zeros(episode_loops, 1);

U_recorder = zeros(Nt, length(tvec));
L_recorder = zeros(2, length(tvec));
V_recorder = zeros(Nt, length(tvec));
RP_recorder = zeros(Nt, length(tvec));


%% ���١����ٱ�������

lowSpeedFlag = zeros(1, Ne) == 1;
highSpeedFlag = zeros(1, Ne) == 1;

%% weight

% reward_weigh = [1/2.4e+14 1/6.64e+5 2e-6 1/1.63e3];
reward_weigh = [0 0 0 1/1.63e3];

%% ��ѭ��


hwait = waitbar(0, 'Processing ...');
for etr = 1 : episode_loops
    
    if rem(etr, 10) == 0
        waitbar(etr/episode_loops, hwait, [sprintf('Processing ... %2.1f',etr/episode_loops*100) '%']);
    end
    
    %% initialization 
    
%     epsilon  = epsilons(etr);
    epsilon  = 0;
    
    X = zeros(Nt*2, Ne);     % ǰ�� Nt �����ٶȣ����� Nt ����λ��
    X(1:Nt, :) = v_speed;     % ���ٶ�
    
    v_tmp = ceil(X(1, :)*3.6)+2;
    s_tmp = ceil(X(Nt+1, :)/dl)+1;
    
    for i = 1:Ne
        if rand > epsilon      % epsilon - greedy
            [~, action(i)] = max(Q(s_tmp(i), v_tmp(i), :));
        else
            action(i) = ceil(rand*n_act);
        end
    end
    
    MotorNotch = zeros(Nl, Ne) + 6;     % ÿ�������ж����ļ�λ
    MotorNotch = MotorNotch + ActionSet(action, 1:2)';
    
    AirBrkNotch = -zeros(1, Ne);       % �����ƶ���-2, -1, 0;
    AirBrkNotch = AirBrkNotch + ActionSet(action, 3)';
    
    bo = AirBrkNotch > 0;
    
    AirBrkNotch(AirBrkNotch > 0) = 0;
    AirBrkNotch(AirBrkNotch < -2) = -2;
    
    count = 0;
    for itr = 1:length(tvec)
        %% �����ĸ���
        
        U = zeros(Nt, Ne);     % ǰ�� Nt �����ٶȣ����� Nt ����λ��
        % ---------------------------------------------- ����ǣ����
        tmp_Fl = GetLocomotiveF(X(carType, :)*3.6, MotorNotch, TBcl);
        U(carType, :) = tmp_Fl * 1e3;
        
        % ---------------------------------------------- �����ƶ���
%         air_timer = air_timer+dt;     % ʱ������һ��
%         air_timer_ = air_timer_+dt;   % ʱ������һ��
%         air_time_d = air_timer - airTimeDelay;          % �����ƶ�ʱ������0��ʾ�Ѿ����С��0��ʾ��δ����
%         air_time_d_ = air_timer_ - airTimeDelay;          % �����ƶ�ʱ������0��ʾ�Ѿ����С��0��ʾ��δ����
%         [currentF, F_target] = GetAirBrakeF(currentF, F_target, ...
%             AirBrkNotch, AirBrkNotch_, air_time_d, air_time_d_, Abr, dt);  % �����ƶ���
%         
%         tmp = currentF;
%         tmp(X(~carType, :) <= 0) = 0;
%         U(~carType, :) = tmp  * 1e3;   % �����ƶ���
        
        % ---------------------------------------------- ������������
        pTrains = LenTrains + X(Nt+1:end, :);         % -------- ����ÿ�����ӵ�λ��
        [addForce, rempTrains] = GetAdditionalF(mTrainGroup, pTrains, rampList);
        U = U + addForce ;                           %
        
        % ---------------------------------------------- ��������
        basicForce = GetBasicF(mTrainGroup, X(1:Nt, :), C0, Ca);
        basicForce(X(1:Nt, :) <= 0) = 0;
        U = U + basicForce ;     
        
        % 
        %% ����״̬����
        
        X = Ad*X + Bd*U;
        
        %% ��¼״̬����
        
        %     locF(itr, :) = tmp_Fl(1, :);
        %     airF(itr, :) = mean(currentF);
        %     addF(itr, :) = mean(addForce);
        %     basF(itr, :) = mean(basicForce);
        
        X_Recorder(itr, :) = X(1, :);
        
        U_recorder(:, itr) = U;
        L_recorder(:, itr) = tmp_Fl;
        V_recorder(:, itr) = X(1:Nt, :);
        RP_recorder(:, itr) = rempTrains;
        
        F_c_ = KK.*diff(X(Nt+1:Nt*2, :)) + DD.*diff(X(1:Nt, :));
        F_c(itr, :) = sum(F_c_.^2);
        
        F_l(itr, :) = sum(tmp_Fl.^2);
%         F_w(itr, :) = sum(currentF.^2);
        
        errV(itr, :) = sum((X(1:Nt, :) - v_speed).^2);
        
        
        %% -------- ���ٱ���  % -------- ���ٱ���
        
        boSpeedFlag = X(1,:)*3.6 <= 10 & X(1,:)*3.6 >= 100; 
        
        if any(boSpeedFlag)     % �κ�һ�������ˣ��ж�����
            
            disp('Speed limit, break the loop!');
            
            v_tmp_ = v_tmp;
            s_tmp_ = s_tmp;
            
            v_tmp = ceil(X(1, :)*3.6) + 2;
            s_tmp = ceil(X(Nt+1, :)/dl) + 1;
            
            for i = 1:Ne
                if boSpeedFlag(i)
                    Q(s_tmp_(i), v_tmp_(i), action(i)) = Q(s_tmp_(i), v_tmp_(i), action(i))...
                        + alpha*(large_neg_reward + gamma*max(Q(s_tmp(i), v_tmp(i), :)) - Q(s_tmp_(i), v_tmp_(i), action(i)));
                end
            end
            break;
        end
        
        %% ����֪ʶ��
        if rem(itr, floor(detaT/dt)) == 0   % ÿ 10 �� ������һ�β���
            
            count = count+1;
            reward_Record(count, :, 1) = sum(F_c);
            reward_Record(count, :, 2) = sum(F_l);
            reward_Record(count, :, 3) = sum(F_w);
            reward_Record(count, :, 4) = sum(errV);
            
            R = zeros(1, Ne);
            for atr = 1:4
                R = R - reward_weigh(atr)*reward_Record(count, :, atr);
            end
            
            R_Recorder(etr) = R_Recorder(etr) + max(R);
            
            v_tmp_ = v_tmp;
            s_tmp_ = s_tmp;
            
            v_tmp = ceil(X(1, :)*3.6) + 2;
            s_tmp = ceil(X(Nt+1, :)/dl) + 1;
            
            for i = 1:Ne
                Q(s_tmp_(i), v_tmp_(i), action(i)) = Q(s_tmp_(i), v_tmp_(i), action(i))...
                    + alpha*(R(i) + gamma*max(Q(s_tmp(i), v_tmp(i), :)) - Q(s_tmp_(i), v_tmp_(i), action(i)));
            end
            %% ѡ����һ���Ĳ��� % epsilon - greedy
            
            for i = 1:Ne
                if rand > epsilon      % epsilon - greedy 
                    [~, action(i)] = max(Q(s_tmp(i), v_tmp(i), :));
                else
                    action(i) = ceil(rand*n_act);
                end
            end
            
            %%
            MotorNotch = MotorNotch + ActionSet(action, 1:2)';   % ÿ�α仯 -1, 0 or 1. 
            MotorNotch(MotorNotch > 12) = 12;
            MotorNotch(MotorNotch < -12) = -12;
            
            %%
            AirBrkNotch_ = AirBrkNotch;
            AirBrkNotch = AirBrkNotch + ActionSet(action, 3)';       % �����ƶ���-2, -1, 0; 
            AirBrkNotch(AirBrkNotch > 0) = 0;
            AirBrkNotch(AirBrkNotch < -2) = -2;
            
            
            %%
            tmpBo = ones(Nw, 1)*(AirBrkNotch_ ~= AirBrkNotch) == 1;  % ��λ�����仯�������ü�ʱ��
            air_timer_(tmpBo) = air_timer(tmpBo);
            air_timer(tmpBo) = 0;
            
        end
        
        loc_Notchs1(itr, :) = MotorNotch(1, :);
        loc_Notchs2(itr, :) = MotorNotch(2, :);
        air_Notchs(itr, :) = AirBrkNotch;
        
    end
end

close(hwait)

%%  plot


figure(1); plot(R_Recorder)

%% 

% figure(1);clf
% mesh(U_recorder')
% 
% figure(2);clf
% plot(V_recorder')

col = [1 202];
figure(101);clf
axes(1) = subplot(411);
hold on;
plot(U_recorder(col(1), :)/1e3, 'linewidth', 2);
plot(U_recorder(col(2), :)/1e3, 'linewidth', 2);
ylabel('ǣ����');
axes(2) = subplot(412);
hold on;
plot(V_recorder(col(1), :)*3.6, 'linewidth', 2);
plot(V_recorder(col(2), :)*3.6, 'linewidth', 2);
ylabel('�ٶ� km/h');
axes(3) = subplot(413);
hold on;
plot(loc_Notchs1, 'linewidth', 2);
plot(loc_Notchs2, 'linewidth', 2);
ylabel('��λ km/h');
axes(4) = subplot(414);
hold on;
plot(RP_recorder(col(1), :), 'linewidth', 2);
plot(RP_recorder(col(2), :), 'linewidth', 2);
ylabel('�¶�');
linkaxes(axes, 'x');

% % col = 2;
% figure(102);clf
% axes(1) = subplot(411);
% plot(U_recorder(2, :)/1e3, 'linewidth', 2);
% ylabel('ǣ����');
% axes(2) = subplot(412);
% plot(V_recorder(1, :)*3.6, 'linewidth', 2);
% ylabel('�ٶ� km/h');
% axes(3) = subplot(413);
% plot(loc_Notchs1, 'linewidth', 2);
% ylabel('��λ km/h');
% axes(4) = subplot(414);
% plot(RP_recorder(1, :), 'linewidth', 2);
% ylabel('�¶�');
% linkaxes(axes, 'x');




% figure; 
% hold on;
% for itr = 1:4
%     plot(reward_Record(:, 1, itr)*reward_weigh(itr))
% end

% for itr = 1:4
%     wei(itr) = mean(max(reward_Record(:, :, itr)));
% end















