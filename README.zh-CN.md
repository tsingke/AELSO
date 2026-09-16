<div align="center">

<h1>AELSO</h1>

<p><b>自适应均衡学习群智能优化算法</b></p>

<p><i>不依赖变量分解的全维大规模全局优化</i></p>

<p><img src="assets/badge-paradigm.svg" alt="不依赖变量分解">&nbsp;<img src="assets/badge-benchmarks.svg" alt="CEC 基准测试">&nbsp;<img src="assets/badge-matlab.svg" alt="MATLAB">&nbsp;<img src="assets/badge-license.svg" alt="MIT 许可"></p>

<p><a href="README.md">English</a> &nbsp;·&nbsp; <b>简体中文</b></p>

</div>

<br>

| | |
|:--|:--|
| **论文题目** | AELSO: Adaptive Equilibrium Learning Swarm Optimizer for Large-Scale Global Optimization and Engineering Applications |
| **作者** | 王晓琳、**张庆科**\*、周光辉、吕蕾、李俊青 |
| **单位** | <sup>1</sup> 山东师范大学 计算机与人工智能学院，济南 250358<br><sup>2</sup> 云南师范大学 数学学院，昆明 650500 |
| **通讯作者** | 张庆科 教授 — [tsingke@sdnu.edu.cn](mailto:tsingke@sdnu.edu.cn) |

<br>

**要点速览**

- 全维大规模优化，全流程不做任何变量分解。
- 更新激活与学习范围由预算进度和种群质量共同决定，而非固定的日程安排。
- 精炼与传播在同一循环内排序执行，使两个阶段相互加强而非相互竞争。
- 在 CEC'2010 与 CEC'2013 两套基准上均取得最优的总体 Friedman 排名（11 个算法，各 30 次独立运行）。

<br>

## 目录

1. [背景与动机](#1-背景与动机)
2. [方法概述](#2-方法概述)
3. [主要贡献](#3-主要贡献)
4. [框架与机制](#4-框架与机制)
5. [基准实验评估](#5-基准实验评估)
6. [应用案例研究](#6-应用案例研究)
7. [参考实现](#7-参考实现)
8. [引用方式](#8-引用方式)
9. [资助与致谢](#9-资助与致谢)
10. [许可与联系方式](#10-许可与联系方式)

<br>

## 1. 背景与动机

当维数上升到数千维时，元启发式算法会逐渐失去立足点。原因不在于候选解不够多，而在于**信息**不足：固定的评价预算被摊薄到整个搜索空间之后，每一个新的目标函数值所能告诉优化器的"下一步该往哪走"的信息越来越少。

在这种压力下，基于种群的搜索面临一个真实的困境。若只集中在少数几个看起来有希望的解上，群体会在预算耗尽之前很久就收敛到某个局部盆地；若把学习范围铺得很开，预算则会在任何区域被真正打磨完成之前就被消耗殆尽。

文献中的很大一部分通过**分解**来回答这个问题——把变量切成若干组分别优化。当分组准确时，这样做效果很好；但分组本身就是一个困难问题，而且无论底层优化器多强，一个糟糕的划分都会封住解质量的上限。

AELSO 选择另一条路。它让搜索始终保持**全维**，并从相反的方向处理上述困境：不去重构问题，而是调节可靠的搜索信息如何产生，以及这些信息被允许在种群中传播多远。

<br>

## 2. 方法概述

AELSO 在每次迭代中依次运行两个互补的机制，并让它们各司其职。第一个机制从已经领先群体的那些解中再榨出一点精度；第二个机制则逐个个体地决定：谁有权学习、向谁学习、学多少——而这个决定的严格程度会随着评价预算的消耗而放松或收紧。于是"精炼"与"再分配"在同一个循环内相互加强，而不是争夺同一批评价次数。

<br>

## 3. 主要贡献

与常见的大规模优化方案相比，AELSO 有三个不同之处。

**更新规则由搜索状态驱动，而非固定日程。** 一个个体是否被更新、它的学习来源被允许伸得多远，都由运行过程自身产生的信号决定：评价预算已经消耗了多少，以及当前种群在质量上的分布如何。更新机会被有意导向那些仍然需要调整的解，而不是均匀地摊给整个群体。

**精炼与传播是排序关系，而非混合关系。** 混合式方案通常让"精炼"和"再分配"争夺同一批评价次数。AELSO 则让二者在同一次迭代中先后执行：先打磨精英，再把改善后的信息释放到种群中。精炼因此成为传播的输入而不是它的竞争者——消融实验表明，去掉任一阶段都会造成整体性能下降，二者是互补的而非冗余的。

**该框架在构造上就是无分解的。** 全程不构建任何变量分组，因此没有会出错的划分、没有需要选择的组数，也不存在由糟糕划分带来的精度天花板。整个评价预算都用于搜索，而不是用于估计一个随后还得去信任的结构。

三点合起来描述的其实是一个转向：算法的行为由逐步展开的搜索过程本身决定，而它的两个阶段被安排成「一个阶段的收益正是另一个阶段的工作材料」。

<br>

## 4. 框架与机制

整体控制流程如下。每次迭代在完成种群排序之后，先执行精炼机制，再执行协同进化机制，最后经预算检查把控制权交回循环顶部。

<p align="center">
  <img src="figures/fig1_framework.png" alt="AELSO 整体流程图" width="86%">
</p>

<p align="center">
  <em><b>图 1.</b> AELSO 的整体控制流程。排序、精英精炼与协同进化交织在同一个循环中，两个阶段共享同一份评价预算。</em>
</p>

两个机制分别详述如下。

**核心解扰动（Core-solution perturbation, CSP）**只作用于当前精英集，而该集合随运行推进不断收缩。候选解通过移动一个*稀疏*的维度子集产生——绝大多数坐标保持不变——并且只有在严格优于父代时才会替换父代。稀疏性让精英已有的结构得以保持，同时允许缓慢、低风险的收益；严格接受则意味着精英永远不会向下漂移。图 2a 给出了这一序列：精英选择、对目标维度的扰动、向搜索边界的截断，以及接受判定。

**双范例协同进化（Dual-exemplar cooperative evolution, DCE）**随后处理群体中的其余个体。个体按从差到好的顺序排序，激活概率被设为随质量上升而下降，因此最常被修订的正是那些仍需要调整的解；一个很小的下界保证每个个体都有被激活的机会，不会被完全冻结。当更新真正触发时，该个体借鉴*两个*范例而非一个——一个来自小规模随机采样子集中的最优者，另一个从精英池中随机抽取——从而避免单一主导吸引子吞掉整个种群。另有一条探索日程决定非精英个体是朝向整个群体的领先前沿学习，还是只在精英池内学习，而这条日程随预算的消耗而收紧。

<p align="center">
  <img src="figures/fig2a_csp.png" alt="核心解扰动框架" width="88%">
  <br>
  <em><b>图 2a.</b> 核心解扰动。仅扰动一个稀疏的维度子集，候选解只有在严格优于父代时才被保留。</em>
</p>

<p align="center">
  <img src="figures/fig2b_dce.png" alt="双范例协同进化框架" width="88%">
  <br>
  <em><b>图 2b.</b> 双范例协同进化。名次决定是否触发更新；随后组装学习候选集与两个范例，并更新速度。</em>
</p>

<br>

## 5. 基准实验评估

AELSO 在两套标准大规模基准上、于统一的实验协议下完成评测。全部十一种算法——AELSO 与十种代表性 LSGO 方法——使用相同的评价预算、相同的维数和相同次数的独立运行，比较结果由 Wilcoxon 秩和检验与覆盖整套基准的 Friedman 排名共同支撑。

| 基准套件 | 函数个数 | 维数 | 预算 | 独立运行 | AELSO 的 Friedman 排名 | 第二名 |
|:--|:--:|:--:|:--:|:--:|:--:|:--|
| CEC'2010 LSGO | 20 | 1000 | 3 × 10⁶ 次评价 | 30 | **2.90 — 11 个算法中第 1** | APSO_DEE (3.43) |
| CEC'2013 LSGO | 15 | 1000 | 3 × 10⁶ 次评价 | 30 | **3.15 — 11 个算法中第 1** | APSO_DEE (4.29) |

AELSO 在两套基准上都取得最优的总体 Friedman 排名。这一优势并非建立在少数几个容易的函数上：成对显著性检验显示，AELSO 在**两套基准上都领先于全部十个对比算法**，且在每套基准上胜出的函数数都多于落败的函数数——在 CEC'2010 的 20 个函数中胜出 11 至 18 个，在 CEC'2013 的 15 个函数中胜出 8 至 13 个。此外还有收敛性与参数敏感性分析作为补充。

<p align="center">
  <img src="figures/fig3a_rank_cec2010.png" alt="CEC'2010 LSGO 上的平均排名与 Friedman 排名" width="88%">
  <br>
  <em><b>图 3a.</b> CEC'2010 LSGO 套件上逐函数的平均排名与总体 Friedman 排名。AELSO 在十一个算法中取得最低的 Friedman 排名。</em>
</p>

<p align="center">
  <img src="figures/fig3b_rank_cec2013.png" alt="CEC'2013 LSGO 上的平均排名与 Friedman 排名" width="88%">
  <br>
  <em><b>图 3b.</b> CEC'2013 LSGO 套件上的同一套排名分析，AELSO 再次取得最优的总体 Friedman 排名。</em>
</p>

<br>

## 6. 应用案例研究

基准套件衡量的是解的质量，而不是优化器能否在真实模型中存活。因此 AELSO 被嵌入到两个决策结构差异很大的应用问题中。

**面向序列比对的轮廓隐马尔可夫模型参数拟合。** 这里优化器搜索模型的转移与发射参数；每个候选向量都被解码为一组合法参数，比对质量通过 Viterbi 推断打分。编码之后搜索空间是连续的，但目标函数经由一个离散解码过程定义，因此优化器必须应对一个带噪且不可分的响应曲面。

**基于 Kapur 熵的图像多阈值分割。** 这里每个候选解是一组递增的灰度阈值，先被修复到可行域，再由图像直方图上的 Kapur 熵打分。难度随阈值个数增加而上升，且随着阈值数量增多，目标函数变得越来越崎岖。

两个应用都在固定协议下进行了多次独立重复实验，分割质量还额外用标准图像质量指标（PSNR、MSE、MAE、SSIM 与 FSIM）评估。结论的边界是刻意收窄的：实验说明的是 AELSO 能够被*嵌入*到这两个截然不同的黑箱模型中并给出稳定可用的结果，而不是说它能在这两个领域击败所有专用求解器。

<p align="center">
  <img src="figures/fig4_segmentation.png" alt="不同阈值个数下的多阈值分割结果" width="92%">
  <br>
  <em><b>图 4.</b> 对 Cameraman 测试图像进行 Kapur 熵多阈值分割。当阈值个数 K 从 2 增加到 100 时，分割结果保留了越来越精细的灰度结构，与所报告的目标熵和图像质量指标增益一致。</em>
</p>

<br>

## 7. 参考实现

参考实现是一个自包含的 MATLAB 函数。除调用方提供的目标函数句柄外没有任何外部依赖，并且复现了论文中所报告的 CEC'2010 / CEC'2013 实验配置。

```matlab
% 调用方提供目标函数句柄与问题定义。
% MaxFEs 与种群规模在文件内部被固定为论文所用的基准配置。
[gbestX, gbestfitness, gbesthistory] = AELSO( ...
    [], 1200, 1000, 100, -100, 0.2*100, -0.2*100, ...
    [], @myObjective, 1, false);
```

<details>
<summary><b>点击展开完整的 <code>AELSO.m</code> 源码（含逐段注释）</b></summary>

<br>

```matlab
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
```

</details>

<br>

## 8. 引用方式

如果 AELSO 对你的研究有帮助，请引用本工作：

```bibtex
@misc{wang2026aelso,
  title        = {AELSO: Adaptive Equilibrium Learning Swarm Optimizer for
                  Large-Scale Global Optimization and Engineering Applications},
  author       = {Wang, Xiaolin and Zhang, Qingke and Zhou, Guanghui and
                  Lyu, Lei and Li, Junqing},
  year         = {2026},
  howpublished = {Reference implementation and project documentation},
  url          = {https://github.com/tsingke/AELSO}
}
```

本仓库同时提供机器可读的 [`CITATION.cff`](CITATION.cff)。

<br>

## 9. 资助与致谢

本工作得到国家自然科学基金（项目编号 62006144）资助。

<br>

## 10. 许可与联系方式

本实现以 [MIT 许可证](LICENSE) 发布。`figures/` 目录中的图片在此仅用于说明，引用时请注明本工作。代码与图片分别适用的条款见 [NOTICE.md](NOTICE.md)。

关于算法、实验或代码的问题，欢迎联系 **[tsingke@sdnu.edu.cn](mailto:tsingke@sdnu.edu.cn)**。

<br>

<div align="center">
<sub>山东师范大学 计算机与人工智能学院</sub>
</div>
