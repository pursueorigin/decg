using LaTeXStrings

include("nqp.jl");
include("algorithms/CenFW.jl"); include("algorithms/DeCG.jl"); include("algorithms/DeGSFW.jl"); include("algorithms/AccDeGSFW.jl");
include("comm.jl");

function main(left::Int, interval::Int, right::Int, repeated::Int, FIX_COMM::Bool)
    # Step 1: initialization
    num_agents = 50;
    # num_iters = Int(20);
    # alpha = 1/sqrt(num_iters);
    # phi = 1/num_iters^(2/3);

    # load data
    # data_cell[i][j] is a dim-by-dim matrix H, i for agent, j for index in the batch
    data_cell, A, dim, u, b = load_nqp_partitioned_data(num_agents);
    # the NQP problem is defined as f_i(x) = ( x/2 - u )^T H_i x, s.t. {x | 0<=x<=u, Ax<=b}, where A is the constraint_mat of size num_constraints-by-dim

    # load weights matrix
    weights, beta = load_network_50();
    num_out_edges = count(i->(i>0), weights) - num_agents;

    x0 = zeros(dim);
    # generate LMO
    LMO = generate_linear_prog_function(u, A, b);

    # num_iters_arr = Int[2e2, 4e2, 6e2, 8e2, 10e2];
    # num_iters_arr = Int[1e0, 2e0, 3e0, 4e0, 5e0];
    # num_iters_arr = Int[1:14;];
    # num_iters_arr = Int[10:10:200;];
    # num_iters_arr = Int[1:20;];
    num_iters_arr = left:interval:right;
    res = zeros(length(num_iters_arr), 7);

    t_start = time();
    for i = 1 : repeated
        final_res = zeros(length(num_iters_arr), 5);
        for i = 1 : length(num_iters_arr)
            # set the value of K (the degree of the chebyshev polynomial)
            if 1/(1-beta) <= ((e^2 + 1)/(e^2 - 1))^2
                K = 1;
            else
                K = round(Int, ceil(sqrt((1 + beta)/(1 - beta))) + 1);
            end
            num_iters = num_iters_arr[i];
            if FIX_COMM
                non_acc_num_iters = num_iters * K;
                decg_num_iters = num_iters * K;
            else
                non_acc_num_iters = num_iters;
                decg_num_iters = round(Int, num_iters*(num_iters+1)*(2*num_iters+1)/6);
            end
            alpha = 1/sqrt(num_iters);
            phi = 1/num_iters^(2/3);

            println("repeated: $(i), algorithm: DeSCG, T: $(decg_num_iters), time: $(Dates.Time(now()))");
            res_DeSCG = DeSCG(dim, data_cell, num_agents, weights, num_out_edges, LMO, f_batch, stochastic_gradient_batch, decg_num_iters, alpha, phi);
            final_res[i, 2] = res_DeSCG[4];
            final_res[i, 4] = res_DeSCG[3];

            println("repeated: $(i), algorithm: DeSGSFW, T: $(non_acc_num_iters), time:$(Dates.Time(now()))");
            res_DeSGSFW = DeSGSFW(dim, data_cell, num_agents, weights, num_out_edges, LMO, f_batch, stochastic_gradient_batch, non_acc_num_iters);
            final_res[i, 3] = res_DeSGSFW[4];
            final_res[i, 5] = res_DeSGSFW[3];

            println("repeated: $(i), algorithm: AccDeSGSFW, T: $(num_iters), time: $(Dates.hour(now())):$(Dates.minute(now())):$(Dates.second(now()))");
            res_AccDeSGSFW = AccDeSGSFW(dim, data_cell, num_agents, weights, num_out_edges, LMO, f_batch, stochastic_gradient_batch, num_iters, beta, K);
            final_res[i, 6] = res_AccDeSGSFW[4];
            final_res[i, 7] = res_AccDeSGSFW[3];


            final_res[i, 1] = num_iters;
        end
        res = res + final_res;
    end
    final_res = res ./ repeated;

    # res_CenFW = CenFW(dim, data_cell, LMO, f_batch, gradient_batch, num_iters);
    #
    # res_DeCG = DeCG(dim, data_cell, num_agents, weights, num_out_edges, LMO, f_batch, gradient_batch, num_iters, alpha);
    #
    # res_DESAGAFW = DeGSFW(dim, data_cell, num_agents, weights, num_out_edges, LMO, f_batch, gradient_batch, num_iters);



    # res_CenSFW = CenSFW(dim, data_cell, LMO, f_batch, stochastic_gradient_batch, num_iters);
    # #
    # res_DeSCG = DeSCG(dim, data_cell, num_agents, weights, num_out_edges, LMO, f_batch, stochastic_gradient_batch, num_iters, alpha, phi);
    # #
    # res_DeSGSFW = DeSGSFW(dim, data_cell, num_agents, weights, num_out_edges, LMO, f_batch, stochastic_gradient_batch, num_iters);
    return final_res;
end
