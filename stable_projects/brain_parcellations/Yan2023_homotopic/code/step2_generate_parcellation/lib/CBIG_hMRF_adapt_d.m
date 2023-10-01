function [likelihood, results, label, params, tau] = CBIG_hMRF_adapt_d(params, label, i, full_corr_mat,...
    lh_mask, rh_mask, avg_mesh, tau, Neighborhood_lh, Neighborhood_rh, Neighborhood_lh_rh)
% [likelihood, results, label, params, tau] = CBIG_hMRF_adapt_d(params, label, i, full_corr_mat,...
% lh_mask, rh_mask, avg_mesh, tau, Neighborhood_lh, Neighborhood_rh, Neighborhood_lh_rh)
%
% This function runs the increase-tau algorithm.

% For the notations below:
% N = no of vertices per hemisphere; 
% M = no of cortical vertices for both hemispheres;
% k = total no of parcels 
% NL = no of vertices per hemisphere;
% NR = no of vertices per hemisphere;

% Input
%   - params: (struct)
%     The structure containing the input arguments.
%   - label: (matrix)
%     Resultant Mx1 parcellation label at the current step.
%   - i: (integer)
%     An integer controlling the run iterations and termination criteria for GCO.
%   - full_corr_mat: (matrix)
%     The 2Nx2N premultiplied matrix computed from multiplying normalized concatenated fMRI data.
%   - lh_mask: (matrix)
%     A Nx1 binary array indicating whether a vertex belongs to cortex or the medial wall on the left hemisphere.
%   - rh_mask: (matrix)
%     A Nx1 binary array indicating whether a vertex belongs to cortex or the medial wall on the right hemisphere.
%   - avg_mesh: (struct)
%     The structure containing meshes for both left and right hemispheres.
%   - tau: (matrix)
%     An 1xk array representing the current values for the tau hyperparameter.
%   - Neighborhood_lh: (matrix)
%     NLxNL matrix representing the left hemisphere neighborhood.
%   - Neighborhood_rh: (matrix)
%     NRxNR matrix representing the right hemisphere neighborhood.
%   - Neighborhood_lh_rh: (matrix)
%     MxM Matrix representing the interhemisphere connections.

% Output
%   - likelihood: (matrix)
%     The Mxk updated likelihoods after tau adaptation.
%   - results: (struct)
%     The updated results after tau adaptation.
%   - label: (struct)
%     The Mx1 updated parcellation labels after tau adaptation.
%   - params: (struct)
%     The updated params after tau adaptation.
%   - tau: (struct)
%     The 1xk updated tau after tau adaptation.

% Example
%   - [likelihood, results, label, params, tau] = CBIG_hMRF_adapt_d(params, label, i, full_corr_mat,...
% lh_mask, rh_mask, avg_mesh, tau, Neighborhood_lh, Neighborhood_rh, Neighborhood_lh_rh)
%
% Written by Xiaoxuan Yan and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md
fileID = fopen(params.convergence_log_path, 'a');
fprintf(fileID, '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% \n');
fprintf(fileID, 'Perform decrease d algorithm... \n');
fprintf(fileID, '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% \n');
fclose(fileID);

for iter_reduce_d = 1:100
    fprintf('Now is the %dth iteration of d reduction... \n', iter_reduce_d);

    %% check if there are mismatched parcels under current d
    [lh_full_label, rh_full_label] = CBIG_hMRF_get_left_right_overlapping_labels(lh_mask, rh_mask, label,...
        params.num_cluster_per_hemi);
    mismatched_parcels = CBIG_hMRF_find_parcels_mismatched_topology_indirect_nbors(lh_full_label,...
        rh_full_label);
    
    %% also check if V1 & CS alignment got worse
    [mean_V1_perc, mean_hd_dist] = CBIG_hMRF_compute_architectonic_metrics(label, params.mesh_type, params.V1,...
        params.CS, params.num_cluster_per_hemi, params.debug_out_folder);

    is_good_visual = mean_V1_perc > 0.94 & mean_hd_dist < 3.2;
    if(iter_reduce_d == 1)
        if(params.premature_stopping)
            if(~isempty(mismatched_parcels))
                error('Current seed has mismatched parcels. abort.');
            end

            if(~is_good_visual)
                error('Current seed has suboptimal V1 & CS alignment. abort.');
            end
        end
    else
        if(~isempty(mismatched_parcels) || ~is_good_visual)
            fprintf('%dth iteration: d = %d results in mismatched parcels and-or bad & CS... \n',...
                iter_reduce_d, params.d);
            disp('Restoring the parameters to previous d.');
            params.d = d_original;
            label = label_ori;
            tau = tau_ori;
            break;
        else
            fprintf('%dth iteration: d = %d results in NO mismatched parcels... \n', iter_reduce_d, params.d);
            disp('Continue running d reduction.');
        end
    end
    
    d_original = params.d;
    label_ori = label;
    tau_ori = tau;
    params.d = floor(d_original/2);
    
    if(iter_reduce_d > 1 && params.d < 500)
        params.d = d_original;
        break;
    end

    % update neighborhood according to updated d
    Neighborhood = CBIG_hMRF_update_whole_brain_neighborhood(Neighborhood_lh, Neighborhood_rh,...
        Neighborhood_lh_rh, params.c, params.d);
    Smooth_cost = CBIG_hMRF_initialize_homotopic_smoothcost_mat(params.num_cluster_per_hemi, params.d);

    % rerun GCO
    [likelihood, results, label, tau] = CBIG_hMRF_update_labels_via_graphcut(full_corr_mat, params,...
    lh_mask, rh_mask, avg_mesh, label, Neighborhood, Smooth_cost, i, tau);
end
end