-module(worker).

-export([start/1, remote_start/1]).


start(Boss) ->
    Boss ! {request_work, self()},

    receive

        {work, Prefix, Start, End, K} ->
            mine(
                Boss,
                Prefix,
                Start,
                End,
                K
            ),

            start(Boss);

        stop ->
            ok
    end.


remote_start([ServerIP]) ->
    ServerNode = list_to_atom(
        "server@" ++ ServerIP
    ),

    Boss = {boss, ServerNode},

    Boss ! {register_worker, self()},

    remote_loop(Boss).


remote_loop(Boss) ->
    receive

        {work, Prefix, Start, End, K} ->
            mine(
                Boss,
                Prefix,
                Start,
                End,
                K
            ),

            Boss ! {request_work, self()},

            remote_loop(Boss);

        stop ->
            ok
    end.


mine(Boss, Prefix, N, End, K)
        when N =< End ->

    Input = list_to_binary(
        Prefix ++ integer_to_list(N)
    ),

    Hash = crypto:hash(
        sha256,
        Input
    ),

    HashText = string:lowercase(
        binary_to_list(
            binary:encode_hex(Hash)
        )
    ),

    case has_leading_zeros(HashText, K) of
        true ->
            Boss ! {
                coin,
                Input,
                HashText
            };

        false ->
            ok
    end,

    mine(
        Boss,
        Prefix,
        N + 1,
        End,
        K
    );

mine(_Boss, _Prefix, _N, _End, _K) ->
    ok.


has_leading_zeros(Hash, K) ->
    Prefix = lists:sublist(Hash, K),

    Prefix =:= lists:duplicate(K, $0)
        andalso
        (K =:= length(Hash) orelse
         lists:nth(K + 1, Hash) =/= $0).