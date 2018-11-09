%% Scene reconstruction using differencing method (Fig4 column c)
% 3D chair occluder
% ------------------------------Pseudo-code------------------------------
% 1. Simulate light transport matrix A given scene geometry parameters.
%    
% 2. Solve TV regularized optimization problem to reconstruct scene
% (FISTA).
% -----------------------------------------------------------------------

% Last Modified by Charles Saunders at Boston University
% 09-Nov-2018 (Clean-up and commented for sharing)

% Manuscript:
%   Saunders, C. and Murray-Bruce, J and Goyal, V.K., 'Computational
%               Periscopy with and Ordinary Digital Camera', Nature, 2018.

% Functions
addpath('Functions')

clear variables;

TestLetter = 'Chair';
numPixels = 1008;

% Parameters
Ndiscr_mon = 6; %Discretization of each scene patch
downsamp_factor = 3; %Downsampling of measurements 2^downsamp_factor
viewAngleCorrection = 1;  %True/False
useEstimatedOccPos = true; %Use estimated occluder position or not

load_experiment_config_data_reconstruction

%Data path
if ismac
    calibParams.filepath = './Data/TestPosChair/';
elseif ispc
    calibParams.filepath = '.\Data\TestPosChair\';
end


%%%%%%% Setup %%%%%%%% (Nothing to manually set here)

% Wall/imaging plane
wall_point = [FOV_LLCorner(1) + FOV_size(1)/2,D,FOV_LLCorner(2)+FOV_size(2)/2];  %Point on plane
wall_vector_1 = [FOV_size(1)/2,0,0]; %Vector defining one direction of FOV (and extent)
wall_vector_2 = [0,0,FOV_size(2)/2]; %Vector defining the orthogonal direction (and extent)
wall_normal = cross(wall_vector_1,wall_vector_2);
wall_normal = wall_normal./norm(wall_normal);

walln_points = floor(numPixels/(2^downsamp_factor)); %Number of points to render in each direction

% Discretize imaging plane
f_imageplane = gpuArray((zeros(walln_points)));
wall_vec = (-1:2/(walln_points-1):1);
wall_matr(1,:) = gpuArray((wall_point(1) + wall_vec*wall_vector_1(1) + wall_vec*wall_vector_2(1)));
wall_matr(2,:) = gpuArray((wall_point(2) + wall_vec*wall_vector_1(2) + wall_vec*wall_vector_2(2)));
wall_matr(3,:) = gpuArray((wall_point(3) + wall_vec*wall_vector_1(3) + wall_vec*wall_vector_2(3)));

Monitor_xlim = [0 NumBlocks_col]*IlluminationBlock_Size(1) + Mon_Offset(1);
Monitor_y = 0;
Monitor_zlim = [0 NumBlocks_row]*IlluminationBlock_Size(2) + Mon_Offset(2);
Mon_xdiscr = (linspace(Monitor_xlim(1),Monitor_xlim(2),NumBlocks_col));
Mon_zdiscr = (linspace(Monitor_zlim(2),Monitor_zlim(1),NumBlocks_row));

wallparam.wall_matr = wall_matr;
wallparam.wall_point = wall_point;
wallparam.wall_vector_1 = wall_vector_1;
wallparam.wall_vector_2 = wall_vector_2;
wallparam.wall_normal = wall_normal;
wallparam.walln_points = walln_points;

numPixels = floor(numPixels/(2^downsamp_factor));

%%%%%%%%%%%%%

% Occluder  (Each individually convex part of occluder split (:,:,1), (:,:,2) etc

%Base
occ_corner(1,:,1) = Occ_LLcorner;
occ_corner(2,:,1) = Occ_LLcorner + [Occ_size(1),0,0];
occ_corner(3,:,1) = Occ_LLcorner + [Occ_size(1),0.075,0];
occ_corner(4,:,1) = Occ_LLcorner + [0, 0.075,0];

occ_corner(1,:,end+1) = Occ_LLcorner + [0,0,-0.004];
occ_corner(2,:,end) = Occ_LLcorner + [0,0,-0.004] + [Occ_size(1),0,0];
occ_corner(3,:,end) = Occ_LLcorner + [0,0,-0.004] + [Occ_size(1),0.075,0];
occ_corner(4,:,end) = Occ_LLcorner + [0,0,-0.004] + [0, 0.075,0];

%Back
occ_corner(1,:,end+1) = Occ_LLcorner + [0,0.075,0];
occ_corner(2,:,end) = Occ_LLcorner + [Occ_size(1),0.075,0];
occ_corner(3,:,end) = Occ_LLcorner + [Occ_size(1),0.075,0.075];
occ_corner(4,:,end) = Occ_LLcorner + [0, 0.075,0.075];

%Legs
occ_corner(1,:,end+1) = Occ_LLcorner + [0, 0, 0];
occ_corner(2,:,end) = Occ_LLcorner + [0.015, 0,0];
occ_corner(3,:,end) = Occ_LLcorner + [0.015, 0,-Occ_LLcorner(3)];
occ_corner(4,:,end) = Occ_LLcorner + [0,  0, -Occ_LLcorner(3)];

occ_corner(1,:,end+1) = Occ_LLcorner + [0, 0.075, 0];
occ_corner(2,:,end) = Occ_LLcorner + [0.015, 0.075,0];
occ_corner(3,:,end) = Occ_LLcorner + [0.015, 0.075,-Occ_LLcorner(3)];
occ_corner(4,:,end) = Occ_LLcorner + [0,  0.075, -Occ_LLcorner(3)];

occ_corner(1,:,end+1) = Occ_LLcorner + [Occ_size(1)-0.015,0,0] + [0, 0, 0];
occ_corner(2,:,end) = Occ_LLcorner + [Occ_size(1)-0.015,0,0] + [0.015, 0,0];
occ_corner(3,:,end) = Occ_LLcorner + [Occ_size(1)-0.015,0,0] + [0.015, 0,-Occ_LLcorner(3)];
occ_corner(4,:,end) = Occ_LLcorner + [Occ_size(1)-0.015,0,0] + [0,  0, -Occ_LLcorner(3)];

occ_corner(1,:,end+1) = Occ_LLcorner + [Occ_size(1)-0.015,0,0] + [0, 0.075, 0];
occ_corner(2,:,end) = Occ_LLcorner + [Occ_size(1)-0.015,0,0] + [0.015, 0.075,0];
occ_corner(3,:,end) = Occ_LLcorner + [Occ_size(1)-0.015,0,0] + [0.015, 0.075,-Occ_LLcorner(3)];
occ_corner(4,:,end) = Occ_LLcorner + [Occ_size(1)-0.015,0,0] + [0,  0.075, -Occ_LLcorner(3)];

% Back of legs
occ_corner(1,:,end+1) = Occ_LLcorner + [0, 0.005, 0];
occ_corner(2,:,end) = Occ_LLcorner+ [0, 0.005, 0] + [0.015, 0,0];
occ_corner(3,:,end) = Occ_LLcorner + [0, 0.005, 0]+ [0.015, 0,-Occ_LLcorner(3)];
occ_corner(4,:,end) = Occ_LLcorner + [0, 0.005, 0]+ [0,  0, -Occ_LLcorner(3)];

occ_corner(1,:,end+1) = Occ_LLcorner+ [0, -0.005, 0] + [0, 0.075, 0];
occ_corner(2,:,end) = Occ_LLcorner + [0, -0.005, 0]+ [0.015, 0.075,0];
occ_corner(3,:,end) = Occ_LLcorner+ [0, -0.005, 0] + [0.015, 0.075,-Occ_LLcorner(3)];
occ_corner(4,:,end) = Occ_LLcorner + [0, -0.005, 0]+ [0,  0.075, -Occ_LLcorner(3)];

occ_corner(1,:,end+1) = Occ_LLcorner+ [0, 0.005, 0] + [Occ_size(1)-0.015,0,0] + [0, 0, 0];
occ_corner(2,:,end) = Occ_LLcorner+ [0, 0.005, 0] + [Occ_size(1)-0.015,0,0] + [0.015, 0,0];
occ_corner(3,:,end) = Occ_LLcorner + [0, 0.005, 0]+ [Occ_size(1)-0.015,0,0] + [0.015, 0,-Occ_LLcorner(3)];
occ_corner(4,:,end) = Occ_LLcorner+ [0, 0.005, 0] + [Occ_size(1)-0.015,0,0] + [0,  0, -Occ_LLcorner(3)];

occ_corner(1,:,end+1) = Occ_LLcorner + [0, -0.005, 0]+ [Occ_size(1)-0.015,0,0] + [0, 0.075, 0];
occ_corner(2,:,end) = Occ_LLcorner + [0, -0.005, 0]+ [Occ_size(1)-0.015,0,0] + [0.015, 0.075,0];
occ_corner(3,:,end) = Occ_LLcorner + [0, -0.005, 0]+ [Occ_size(1)-0.015,0,0] + [0.015, 0.075,-Occ_LLcorner(3)];
occ_corner(4,:,end) = Occ_LLcorner + [0, -0.005, 0]+ [Occ_size(1)-0.015,0,0] + [0,  0.075, -Occ_LLcorner(3)];

% Bar
occ_corner(1,:,end+1) = Occ_LLcorner + [0,0, -0.06];
occ_corner(2,:,end) = Occ_LLcorner + [0, 0, -0.075];
occ_corner(3,:,end) = Occ_LLcorner + [Occ_size(1),0,-0.06];
occ_corner(4,:,end) = Occ_LLcorner + [Occ_size(1),0,-0.075];

%%%%%%%%%%%%%%

tic
disp('Simulating light transport matrix...')
[simA] = simulate_A(wallparam, (occ_corner),simuParams, Mon_xdiscr,Mon_zdiscr, 0);
toc

%% Load data

[test_image1,ground_truth1]=load_image1('image_test_mushroom.mat',calibParams.filepath,downsamp_factor);   
[test_image2,ground_truth2]=load_image1('image_test_smilehat.mat',calibParams.filepath,downsamp_factor);
[test_image3,ground_truth3]=load_image1('image_test_colbar.mat',calibParams.filepath,downsamp_factor);
[test_image4,ground_truth4]=load_image1('image_test_bur.mat',calibParams.filepath,downsamp_factor);

%% Reconstruction

sr = 1.3438e+04/(Ndiscr_mon^2)*prod(subblocksperaxis); 
sg = 1.4688e+04/(Ndiscr_mon^2)*prod(subblocksperaxis); 
sb = 15625/(Ndiscr_mon^2)*prod(subblocksperaxis);
final_im1 = reconstruct_tv_it_cbg(simA,[sr,sg,sb],  test_image1, [72000000,79200000,345600000], NumBlocks_sim, [0,0,0]);

sr = 1.2*1.1338e+04/(Ndiscr_mon^2)*prod(subblocksperaxis); 
sg = 1*1.3581e+04/(Ndiscr_mon^2)*prod(subblocksperaxis); 
sb = 1.1*18950/(Ndiscr_mon^2)*prod(subblocksperaxis);
final_im2 = reconstruct_tv_it_cbg(simA,[sr,sg,sb].*[0.7,0.85,1.2],  test_image2, 2.2*40000000*[1.1,1.1,1.1], NumBlocks_sim, [0,0,0]);

sr = 1.1*1.4363e+04/(Ndiscr_mon^2)*prod(subblocksperaxis); 
sg = 1.1*1.4363e+04/(Ndiscr_mon^2)*prod(subblocksperaxis); 
sb = 1.1*1.4363e+04/(Ndiscr_mon^2)*prod(subblocksperaxis);
final_im3 = reconstruct_tv_it_cbg(simA,[sr,sg,sb].*[0.9,0.9,0.9],  test_image3, 3.4*50000000*[2.1,2.1,2.1], NumBlocks_sim, [0,0,0]);

sr = 1.1*1.3281e+04/(Ndiscr_mon^2)*prod(subblocksperaxis); 
sg = 1.1*1.7188e+04/(Ndiscr_mon^2)*prod(subblocksperaxis); 
sb = 1.1*1.7188e+04/(Ndiscr_mon^2)*prod(subblocksperaxis);
final_im4 = reconstruct_tv_it_cbg(simA,[sr,sg,sb].*[0.85,1.1,1.1],  test_image4, 2.4*50000000*[1,7,7], NumBlocks_sim, [0,0,0]);

%%      

% Plot
figure()

subplot(4,2,1)
imshow(ground_truth1/255)
title('Ground truths')
subplot(4,2,2)
imshow(final_im1(:,:,:))

title('Reconstruction')
subplot(4,2,3)
imshow(ground_truth2/255)
subplot(4,2,4)
imshow(final_im2(:,:,:))

subplot(4,2,5)
imshow(ground_truth3/255)
subplot(4,2,6)
imshow(final_im3(:,:,:))

subplot(4,2,7)
imshow(ground_truth4/255)
subplot(4,2,8)
imshow(final_im4(:,:,:))