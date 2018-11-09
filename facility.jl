using Distributed
@everywhere using Random
@everywhere function f_discrete_batch(s, data_mat)
    indices = [i for i in s];
    max_values, max_idx = findmax(data_mat[indices, :], 1);
    sum_f = sum(max_values);
    return sum_f;
end

@everywhere function f_extension_sample(x, ratings, sample_times = 1e5) # ratings is a n-by-2 matrix sorted in descendant order, where n denotes #movies some user has rated
    res = 0;
    for j in 1:sample_times
        # 1. Generate a random set X
        tmp_f = 0;
        for index in 1:size(ratings, 2)
            if rand() <= x[round(Int, ratings[1, index])]
                tmp_f = ratings[2, index];
                break;
            end
        end
        res += tmp_f;
    end
    res /= sample_times;
    return res;
end

@everywhere function f_extension(x, ratings) # ratings is a n-by-2 matrix sorted in descendant order, where n denotes #movies some user has rated
    res = 0;
    prod = 1;
    for index in 1:size(ratings, 2) # for all rated movies from high to low
        x_current_coord = x[round(Int, ratings[1, index])];
        res += ratings[2, index] * x_current_coord * prod;
        prod *= 1 - x_current_coord;
        if prod == 0
            break;
        end
    end
    return res;
end

@everywhere function f_extension_batch(x, batch_ratings) # ratings is a n-by-2 matrix sorted in descendant order, where n denotes #movies some user has rated
    sum_f = 0;
    for ratings in batch_ratings
        sum_f += f_extension(x, ratings);
    end
    return sum_f;
end

@everywhere function partial_extension_sample(x, ratings, i, sample_times = 1e5) # compute partial derivative : O(#sample * #ratings)
    res = 0;

    index_of_i_in_ratings = findfirst(ratings[1, :], i);
    if index_of_i_in_ratings == 0 # this means f(R+{i}) = f(R\{i}), for any R, then no need to sample
        return 0;
    end

    for j in 1:sample_times
        # 1. Generate a random set X\i
        tmp_f = 0;
        for index in 1:size(ratings, 2)
            if index == index_of_i_in_ratings # exclude the i'th index
                continue;
            end
            if rand() <= x[round(Int, ratings[1, index])]
                tmp_f = ratings[2, index];
                break;
            end
        end
        # 2. compute f(X+i) - f(X\i)
        tmp_partial = max(0, ratings[2, index_of_i_in_ratings] - tmp_f);
        res += tmp_partial;
    end
    res /= sample_times;
    return res;
end

@everywhere function partial_extension(x, ratings, i) # compute partial derivative : O(#ratings)
    res_union = 0;
    res_diff = 0;
    prod = 1;

    # index_of_i_in_ratings = findfirst(ratings[1, :], i);  # @NOTE bottleneck
    index_of_i_in_ratings = 0;  # the for loop is equivilant to the above line, but faster
    for tmp_i in 1 : size(ratings, 2)
        if i == ratings[1, tmp_i]
            index_of_i_in_ratings = tmp_i;
            break;
        end
    end

    if index_of_i_in_ratings == 0 # this means f(R+{i}) = f(R\{i}), for any R, then no need to sample
        return 0;
    end

    for index in 1:size(ratings, 2) # for all rated movies from high to low
        if index == index_of_i_in_ratings
            res_union = res_diff + ratings[2, index] * 1 * prod;
        else
            x_current_coord = x[round(Int, ratings[1, index])];
            res_diff += ratings[2, index] * x_current_coord * prod;  # @NOTE bottleneck
            prod *= 1 - x_current_coord;
        end
        if prod == 0
            break;
        end
    end
    return res_union - res_diff;
end

@everywhere function gradient_extension(x, ratings) # compute the gradient: O(n + #sample * #ratings^2)
    dim = length(x);
    res = zeros(dim);
    for i in 1:dim
        res[i] = partial_extension(x, ratings, i);
    end
    return res;
end

@everywhere function gradient_extension_batch(x, batch_ratings) # ratings is a n-by-2 matrix sorted in descendant order, where n denotes #movies some user has rated
    sum_gradient = 0;
    for ratings in batch_ratings
        sum_gradient += gradient_extension(x, ratings);
    end
    return sum_gradient;
end

@everywhere function stochastic_gradient_extension!(x::Vector{Float64}, ratings::Array{Float64, 2}, sample_times::Int64, indices_in_ratings::Vector{Int64}, ret_stochastic_grad::Vector{Float64}, rand_vec::Vector{Float64}) # compute stochastic gradient: O(???)
    # function stochastic_partial_extension(x, ratings, i, rand_vec, index_of_i_in_ratings)
    #     # index_of_i_in_ratings = findfirst(ratings[:, 1], i);
    #     # if index_of_i_in_ratings == 0 # this means f(R+i) = f(R\i), for any R, then no need to sample
    #     #     return 0;
    #     # end
    #     assert(index_of_i_in_ratings != 0);
    #     # 1. Generate a random set X\i
    #     tmp_f = 0;
    #     for index = 1:size(ratings, 1)
    #         if index == index_of_i_in_ratings # exclude the i'th index
    #             continue;
    #         end
    #         tmp_index = round(Int, ratings[index, 1]);
    #         if rand_vec[tmp_index] <= x[tmp_index]
    #             tmp_f = ratings[index, 2];
    #             break;
    #         end
    #     end
    #     # 2. compute f(X+i) - f(X\i)
    #     stochastic_partial = max(tmp_f, ratings[index_of_i_in_ratings, 2]) - tmp_f;
    #     return stochastic_partial;
    # end

    dim = length(x);
    # stochastic_grad = zeros(dim);
    # indices_in_ratings = zeros(Int, dim);
    fill!(indices_in_ratings, zero(Int));
    tmp_idx = 0;
    nnz = size(ratings, 2);
    for i = 1 : nnz
        tmp_idx = round(Int, ratings[1, i]);
        indices_in_ratings[tmp_idx] = i;
    end

    rand_vec_view = view(rand_vec, 1:nnz);
    for j = 1:sample_times
        Random.rand!(rand_vec_view);
        index_of_i_in_ratings = 0;
        for i in 1:dim
            index_of_i_in_ratings = indices_in_ratings[i];
            if (index_of_i_in_ratings == 0)
                continue;
            end

            tmp_f = 0;
            for index = 1 : nnz
                if index == index_of_i_in_ratings # exclude the i'th index
                    continue;
                end
                double_index = ratings[1, index];
                tmp_index = round(Int, double_index);
                if rand_vec_view[index] <= x[tmp_index]
                    tmp_f = ratings[2, index];
                    break;
                end
            end
            # 2. compute f(X+i) - f(X\i)
            tmp_res = max(0.0, ratings[2, index_of_i_in_ratings] - tmp_f);
            ret_stochastic_grad[i] += tmp_res;
            # stochastic_grad[i] += stochastic_partial_extension(x, ratings, i, rand_vec, index_of_i_in_ratings);
        end
    end
    nothing
end

@everywhere function stochastic_gradient_extension_C_wrapper(x, ratings, sample_times, indices_in_ratings, ret_stoch_grad)
    dim = length(x);
    nnz = size(ratings, 2);  # ratings is a 2-by-nnz matrix
    num_rows = 2;
    ccall((:stochastic_gradient_extension, "libfacility"),
        Cvoid,
        (Ref{Cdouble}, Clonglong,
        Ref{Cdouble}, Clonglong, Clonglong, Clonglong,
        Ref{Clonglong}, Ref{Cdouble}),
        Ref(x), dim,
        Ref(ratings), num_rows, nnz, sample_times,
        Ref(indices_in_ratings), Ref(ret_stoch_grad));
end

@everywhere function stochastic_gradient_extension_batch(x, batch_ratings, sample_times = 1) # ratings is a n-by-2 matrix sorted in descendant order, where n denotes #movies some user has rated
    # dim = length(x);
    # sum_stochastic_gradient = zeros(dim);
    # for ratings in batch_ratings
    #     sum_stochastic_gradient += stochastic_gradient_extension(x, ratings, sample_times);
    # end
    # return sum_stochastic_gradient;

    dim = length(x);
    stochastic_gradient = zeros(dim);
    indices_in_ratings = zeros(Int64, dim);
    rand_vec = zeros(dim);
    for ratings in batch_ratings
        stochastic_gradient_extension!(x, ratings, sample_times, indices_in_ratings, stochastic_gradient, rand_vec);
    end
    return stochastic_gradient;

    # dim = length(x);
    # nnz = size(ratings, 2);  # ratings is a 2-by-nnz matrix
    # num_rows = 2;
    # stochastic_gradient = zeros(dim);
    # indices_in_ratings = zeros(Int64, dim);
    # rand_vec = zeros(dim);
    # ccall((:stochastic_gradient_extension, "libfacility"),
    #     Cvoid,
    #     (Ref{Cdouble}, Clonglong,
    #     Ref{Cdouble}, Clonglong, Clonglong, Clonglong,
    #     Ref{Clonglong}, Ref{Cdouble}, Ref{Cdouble}),
    #     Ref(x), dim,
    #     Ref(ratings), num_rows, nnz, sample_times,
    #     Ref(indices_in_ratings), Ref(stochastic_gradient), Ref(rand_vec));
    # return stochastic_gradient;

    # num_users_on_curr_agent = length(batch_ratings);
    # idx = rand(1:num_users_on_curr_agent);
    # ratings = batch_ratings[idx];
    # doubly_stochastic_gradient = stochastic_gradient_extension(x, ratings, sample_times);
    # return doubly_stochastic_gradient * num_users_on_curr_agent;
end
