-module(project1).

-export([main/1, start/2, server/1, server/2, server/3]).


main([Arg]) ->
    case string:to_integer(Arg) of
        {K, ""} when K >= 0 ->
            start_node("server"),
            server(K, 10000, 10000000);

        _ ->
            start_node("worker"),
            worker:remote_start([Arg])
    end;

main(_) ->
    io:format("Usage: ./project1 <number_of_zeros | server_ip>~n").

start_node(Type) ->
    {ok, Interfaces} = inet:getif(),

    IP = find_ip(Interfaces),

    Name =
        case Type of
            "server" ->
                "server@" ++ IP;

            "worker" ->
                "worker_" ++ os:getpid() ++ "@" ++ IP
        end,

    {ok, _} = net_kernel:start([
        list_to_atom(Name),
        longnames
    ]),

    erlang:set_cookie(node(), dops123).


find_ip(Interfaces) ->
    Addresses = [Addr || {Addr, _, _} <- Interfaces],

    case lists:dropwhile(
        fun({127, 0, 0, 1}) -> true;
           (_) -> false
        end,
        Addresses
    ) of
        [IP | _] ->
            inet:ntoa(IP);

        [] ->
            "127.0.0.1"
    end.


start(K, WorkSize) ->
    application:ensure_all_started(crypto),

    Boss = self(),
    Prefix = "psheshadrireddy;",

    W1 = spawn(worker, start, [Boss]),
    W2 = spawn(worker, start, [Boss]),
    W3 = spawn(worker, start, [Boss]),
    W4 = spawn(worker, start, [Boss]),

    Workers = [W1, W2, W3, W4],

    boss_loop(
        Prefix,
        K,
        1,
        1000000,
        Workers,
        WorkSize
    ).


server([KAtom, WorkAtom]) ->
    K = list_to_integer(atom_to_list(KAtom)),
    WorkSize = list_to_integer(atom_to_list(WorkAtom)),
    server(K, WorkSize).


server(K, WorkSize) ->
    server(K, WorkSize, 1000000).


server(K, WorkSize, Max) ->
    application:ensure_all_started(crypto),

    Boss = self(),
    register(boss, Boss),

    Prefix = "psheshadrireddy;",

    Local = spawn(worker, start, [Boss]),

    io:format("Server started.~n"),
    io:format("Local worker: ~p~n", [Local]),
    io:format("Waiting for remote workers...~n"),

    boss_loop(
        Prefix,
        K,
        1,
        Max,
        [Local],
        WorkSize
    ).


boss_loop(Prefix, K, Next, Max, Workers, WorkSize) ->
    receive

        {request_work, Worker} ->
            if
                Next =< Max ->
                    End = min(
                        Next + WorkSize - 1,
                        Max
                    ),

                    Worker ! {
                        work,
                        Prefix,
                        Next,
                        End,
                        K
                    },

                    boss_loop(
                        Prefix,
                        K,
                        End + 1,
                        Max,
                        Workers,
                        WorkSize
                    );

                true ->
                    Worker ! stop,

                    remaining_workers(
                        Workers -- [Worker]
                    )
            end;


        {register_worker, Worker} ->
            io:format(
                "Remote worker connected: ~p~n",
                [Worker]
            ),

            if
                Next =< Max ->
                    End = min(
                        Next + WorkSize - 1,
                        Max
                    ),

                    Worker ! {
                        work,
                        Prefix,
                        Next,
                        End,
                        K
                    },

                    boss_loop(
                        Prefix,
                        K,
                        End + 1,
                        Max,
                        [Worker | Workers],
                        WorkSize
                    );

                true ->
                    Worker ! stop,

                    boss_loop(
                        Prefix,
                        K,
                        Next,
                        Max,
                        Workers,
                        WorkSize
                    )
            end;


        {coin, String, Hash} ->
            io:format(
                "~s\t~s~n",
                [String, Hash]
            ),

            boss_loop(
                Prefix,
                K,
                Next,
                Max,
                Workers,
                WorkSize
            )
    end.


remaining_workers([]) ->
    io:format("Mining finished.~n"),
    init:stop();

remaining_workers(Workers) ->
    receive

        {coin, String, Hash} ->
            io:format(
                "~s\t~s~n",
                [String, Hash]
            ),

            remaining_workers(Workers);

        {request_work, Worker} ->
            Worker ! stop,

            remaining_workers(
                Workers -- [Worker]
            );

        {register_worker, Worker} ->
            Worker ! stop,

            remaining_workers(Workers)
    end.