function [gbestX, gbestfitness, gbesthistory] = AELSO(mainHandle, PopSize, D, xmax, xmin, vmax, vmin, MaxIter, fCalculation, FuncId, VisualSwitch)
% =========================================================================
%  AELSO -- Adaptive Equilibrium Learning Swarm Optimizer
%
%  Reference implementation of the algorithm described in:
%    "AELSO: Adaptive Equilibrium Learning Swarm Optimizer for Large-Scale
%     Global Optimization and Engineering Applications"
%
%  Copyright (c) 2026  Qingke Zhang, Xiaolin Wang
%  School of Computer Science and Artificial Intelligence
%  Shandong Normal University, Jinan 250358, China
%
%  Released under the MIT License. See the LICENSE file in the repository
%  root for the full text. If you use this code in academic work, please
%  cite the paper above (see also CITATION.cff).
%
%  Version : V10.0
%  Updated : 2025-09-29
%
% -------------------------------------------------------------------------
%  Input arguments
%    mainHandle    - reserved handle for an external driver (currently unused)
%    PopSize       - population size. NOTE: overridden below, see "Design note"
%    D             - problem dimensionality
%    xmax, xmin    - upper / lower bounds on the decision variables; scalar or
%                    1-by-D vectors
%    vmax, vmin    - upper / lower bounds on the velocity; scalar or 1-by-D
%    MaxIter       - reserved iteration cap (currently unused; the loop is
%                    governed by MaxFEs, see "Design note")
%    fCalculation  - function handle of the objective, called as f(x, FuncId)
%    FuncId        - numeric identifier forwarded to fCalculation
%    VisualSwitch  - reserved display flag (currently unused)
%
%  Output arguments
%    gbestX        - best solution found, 1-by-D
%    gbestfitness  - objective value of gbestX
%    gbesthistory  - 1-by-MaxFEs record of the best-so-far objective value
%
% -------------------------------------------------------------------------
%  Design note on the fixed budget and population size
%    MaxFEs is fixed to 3e6 and PopSize is fixed to 1200 below so that the
%    file reproduces the CEC'2010 / CEC'2013 LSGO configuration reported in
%    the paper without any external setup. To reuse the optimizer on a
%    different budget or population, comment out the two hard-coded lines in
%    the parameter block and pass the values through the argument list.
% =========================================================================

%% ------------------------------------------------------------------------
%  Algorithm-level parameters
%  The defaults below form the "general-purpose robust" configuration used in
%  the paper and can be re-tuned for a specific problem.
% -------------------------------------------------------------------------

% --- Overrides that pin the benchmark configuration ----------------------
PopSize = 1200;                  % forces the paper's population size
MaxFEs  = 3 * 10^6;              % evaluation budget for the benchmark runs

% --- DCE (Dual-exemplar cooperative evolution) parameters ----------------
NP_max    = PopSize;
% NP_min = round(0.1 * NP_max);  % removed: the population is never shrunk
beta_mean = 0.4;                 % mean of the DCE inertia coefficient
beta_std  = 0.01;                % std  of the DCE inertia coefficient
TS_range  = [2, 6];              % range of the sampled exemplar-pool size

% --- CSP (Core-solution perturbation) parameters -------------------------
ratio_max     = 0.2;             % elite ratio at the start of a run
ratio_min     = 0.05;            % elite ratio at the end of a run
N_GT_per_elite = 1;              % perturbation trials per elite
Pj_mean       = 0.01;            % mean of the per-dimension mutation rate
Pj_std        = 0.01;            % std  of the per-dimension mutation rate
Pm            = 0.01;            % probability of drawing a random component
F_mean        = 0.5;             % mean of the difference-vector scale factor
F_std         = 0.1;             % std  of the difference-vector scale factor

% --- AELSO control parameters --------------------------------------------
epsilon = 1e-4;                  % floor on the update probability, keeps a
                                 % small escape chance for every individual
P_start = 0.8;                   % exploration probability at the start
P_end   = 0.2;                   % exploration probability at the end

% --- Framework-level settings --------------------------------------------
Fitness        = fCalculation;
FEs            = 0;
print_interval = floor(MaxFEs / 10);   % progress report every 10% of budget

% Expand scalar bounds into full vectors so the vectorised updates below work
if isscalar(xmin); xmin = repmat(xmin, 1, D); end
if isscalar(xmax); xmax = repmat(xmax, 1, D); end
if isscalar(vmin); vmin = repmat(vmin, 1, D); end
if isscalar(vmax); vmax = repmat(vmax, 1, D); end

%% Step 1 -- population initialisation
% Positions and velocities are drawn uniformly inside the box; every initial
% individual costs one function evaluation.

X = zeros(NP_max, D);
V = zeros(NP_max, D);
f = zeros(NP_max, 1);

for i = 1:NP_max
    X(i, :) = xmin + (xmax - xmin) .* rand(1, D);
    V(i, :) = vmin + (vmax - vmin) .* rand(1, D);
    f(i)    = Fitness(X(i, :)', FuncId);
end
FEs = FEs + NP_max;

[gbestfitness, gbest_idx] = min(f);
gbestX       = X(gbest_idx, :);
gbesthistory = inf(1, MaxFEs);
gbesthistory(1:FEs) = gbestfitness;

%% Step 2 -- main loop
% Each iteration runs the two mechanisms back to back: first CSP refines the
% elites, then DCE redistributes the learned information across the swarm.
while FEs < MaxFEs

    % Rank the swarm from best to worst before either mechanism runs
    [f_sorted_val, sorted_idx] = sort(f, 'ascend');
    X_sorted = X(sorted_idx, :);
    V_sorted = V(sorted_idx, :);

    % ---------------------------------------------------------------------
    % Part 1: CSP -- core-solution perturbation
    % The elite ratio decays with the square root of the consumed budget, so
    % the effort spent on refinement shrinks as the search matures.
    % ---------------------------------------------------------------------
    current_elite_ratio = ratio_max - (ratio_max - ratio_min) * (FEs / MaxFEs)^0.5;
    num_elites          = max(2, floor(NP_max * current_elite_ratio));

    for i = 1:num_elites
        if FEs >= MaxFEs; break; end

        elite_particle_X = X_sorted(i, :);
        elite_particle_f = f_sorted_val(i);

        for gt_iter = 1:N_GT_per_elite
            if FEs >= MaxFEs; break; end

            % Sparsely pick the dimensions that are allowed to move; at least
            % one dimension is forced so the candidate never equals the elite
            selected_dims_idx = rand(1, D) < abs(normrnd(Pj_mean, Pj_std));
            if ~any(selected_dims_idx); selected_dims_idx(randi(D)) = true; end

            % Two reference individuals are drawn from the elite set; if the
            % elite set is too small, the whole swarm is used as the pool
            v_best = zeros(1, D);
            elite_indices = 1:num_elites;
            available_ref_indices = setdiff(elite_indices, i);
            if length(available_ref_indices) < 2
                all_indices_sorted = 1:NP_max;
                available_ref_indices = setdiff(all_indices_sorted, i);
            end

            ref_indices_in_sorted = available_ref_indices(randperm(length(available_ref_indices), 2));

            xr1 = X_sorted(ref_indices_in_sorted(1), :);
            xr2 = X_sorted(ref_indices_in_sorted(2), :);
            F   = normrnd(F_mean, F_std);

            % Base difference vector, with a small chance of swapping one
            % component for a fresh random value inside the box
            for j = 1:D
                if rand < Pm
                    x_rand_j = xmin(j) + (xmax(j) - xmin(j)) * rand;
                    v_best(j) = elite_particle_X(j) + F * (xr1(j) - x_rand_j);
                else
                    v_best(j) = elite_particle_X(j) + F * (xr1(j) - xr2(j));
                end
            end
            v_best = max(min(v_best, xmax), xmin);      % clamp to the box

            % Only the sparsely selected dimensions are actually replaced
            candidate_X = elite_particle_X;
            candidate_X(selected_dims_idx) = v_best(selected_dims_idx);

            FEs = FEs + 1;
            if FEs > MaxFEs; break; end
            candidate_f = Fitness(candidate_X', FuncId);

            % Strict acceptance: the elite is replaced only on improvement
            if candidate_f < elite_particle_f
                elite_particle_X = candidate_X;
                elite_particle_f = candidate_f;
            end

            if candidate_f < gbestfitness
                gbestfitness = candidate_f;
                gbestX       = candidate_X;
            end
            gbesthistory(FEs) = gbestfitness;

            if mod(FEs, print_interval) == 0 && print_interval > 0
                fprintf('AELSO: FEs = %d, best fitness = %e\n', FEs, gbestfitness);
            end
        end

        X_sorted(i, :) = elite_particle_X;
        f_sorted_val(i) = elite_particle_f;
    end

    % Write the improved elites back into the swarm
    X(sorted_idx, :) = X_sorted;
    V(sorted_idx, :) = V_sorted;
    f(sorted_idx)    = f_sorted_val;

    % ---------------------------------------------------------------------
    % Part 2: DCE -- dual-exemplar cooperative evolution
    % Every individual is considered once per iteration, from the worst to
    % the best, and the activation probability grows with its rank.
    % ---------------------------------------------------------------------
    [~, worst_to_best_idx] = sort(f, 'descend');

    P_explore = P_start - (P_start - P_end) * (FEs / MaxFEs);

    % Rank weights follow a discretised Gaussian profile; the worst
    % individual keeps the floor probability epsilon instead of zero
    ranks_descend = 1:NP_max;
    W_all = (1 / (sqrt(2*pi) * NP_max)) * exp(-((ranks_descend-1).^2) / (2 * NP_max^2));
    W_min = min(W_all); W_max = max(W_all);

    for i = 1:NP_max
        if FEs >= MaxFEs; break; end

        current_particle_original_idx = worst_to_best_idx(i);
        rank_i = i;

        W_i = W_all(rank_i);
        if W_max == W_min; P_i_raw = 1; else; P_i_raw = (W_i - W_min) / (W_max - W_min); end
        P_i = epsilon + (1 - epsilon) * P_i_raw;

        if rand < P_i
            % --- Assemble the learning candidate set Omega_i --------------
            elite_original_indices = sorted_idx(1:num_elites);
            is_elite = ismember(current_particle_original_idx, elite_original_indices);

            if is_elite
                % An elite learns only from strictly better individuals
                [~, current_rank_ascend] = ismember(current_particle_original_idx, sorted_idx);
                if current_rank_ascend == 1; continue; end
                learning_pool_indices = sorted_idx(1:current_rank_ascend-1);
            else
                % A non-elite either explores the better part of the swarm
                % or exploits the elite set, depending on the schedule
                if rand < P_explore
                    [~, current_rank_ascend] = ismember(current_particle_original_idx, sorted_idx);
                    learning_pool_indices = sorted_idx(1:current_rank_ascend-1);
                else
                    learning_pool_indices = elite_original_indices;
                end
            end

            if length(learning_pool_indices) < 2; continue; end

            % --- Xe1: best of a randomly sampled candidate subset ---------
            subset_size = randi(TS_range);
            if length(learning_pool_indices) < subset_size; continue; end
            subset_cand_indices = learning_pool_indices(randperm(length(learning_pool_indices), subset_size));
            [~, best_local_idx] = min(f(subset_cand_indices));
            Xe1_original_idx = subset_cand_indices(best_local_idx);

            % --- Xe2: a random elite, different from Xe1 ------------------
            pool_for_Xe2 = setdiff(elite_original_indices, Xe1_original_idx);
            if isempty(pool_for_Xe2)
                % Fall back to the learning pool when no other elite exists
                pool_for_Xe2 = setdiff(learning_pool_indices, Xe1_original_idx);
                if isempty(pool_for_Xe2); continue; end
            end
            Xe2_original_idx = pool_for_Xe2(randi(length(pool_for_Xe2)));

            % --- Velocity and position update -----------------------------
            Xe1 = X(Xe1_original_idx, :);
            Xe2 = X(Xe2_original_idx, :);

            % Guarantee that Xe1 is the stronger of the two exemplars
            if f(Xe2_original_idx) < f(Xe1_original_idx)
                [Xe1, Xe2] = deal(Xe2, Xe1);
            end

            beta = max(0, min(1, normrnd(beta_mean, beta_std)));
            R1 = rand(1, D); R2 = rand(1, D); R3 = rand(1, D);

            V(current_particle_original_idx, :) = R1 .* V(current_particle_original_idx, :) ...
                + R2 .* (Xe1 - X(current_particle_original_idx, :)) ...
                + beta .* R3 .* (Xe2 - X(current_particle_original_idx, :));
            V(current_particle_original_idx, :) = max(min(V(current_particle_original_idx, :), vmax), vmin);
            X(current_particle_original_idx, :) = X(current_particle_original_idx, :) + V(current_particle_original_idx, :);
            X(current_particle_original_idx, :) = max(min(X(current_particle_original_idx, :), xmax), xmin);

            FEs = FEs + 1;
            if FEs > MaxFEs; break; end
            f(current_particle_original_idx) = Fitness(X(current_particle_original_idx, :)', FuncId);

            if f(current_particle_original_idx) < gbestfitness
                gbestfitness = f(current_particle_original_idx);
                gbestX       = X(current_particle_original_idx, :);
            end
            gbesthistory(FEs) = gbestfitness;

            if mod(FEs, print_interval) == 0 && print_interval > 0
                fprintf('AELSO: FEs = %d, best fitness = %e\n', FEs, gbestfitness);
            end
        end
    end
end

%% Step 3 -- align the recorded history with the exact evaluation budget
% The loop can overshoot or undershoot the budget by a fraction of one
% iteration; pad or truncate so that gbesthistory is exactly MaxFEs long.
if FEs < MaxFEs
    gbesthistory(FEs+1:MaxFEs) = gbestfitness;
elseif FEs > MaxFEs
    gbesthistory(MaxFEs+1:end) = [];
end

end
