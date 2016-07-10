%% -------------------------------------------------------------------
%%
%% Copyright (c) 2014 SyncFree Consortium.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
%% @doc log_test: Test that perform NumWrites increments to the key:abc.
%%      Each increment is sent to a random node of the cluster.
%%      Test norml behaviour of the logging layer
%%      Perflorms a read to the first node of the cluster to check whether all the
%%      increment operations where successfully applied.
%%  Input:  N:  Number of nodes
%%          Nodes: List of the nodes that belong to the built cluster.
%%

-module(log_SUITE).
-author("Annette Bieniusa <bieniusa@cs.uni-kl.de>").

-compile({parse_transform, lager_transform}).

%% common_test callbacks
-export([%% suite/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_testcase/2,
         end_per_testcase/2,
         all/0]).

%% tests
-export([log_test/1]).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/inet.hrl").

init_per_suite(Config) ->
    test_utils:at_init_testsuite(),
    Config.


end_per_suite(Config) ->
    Config.

init_per_testcase(Case, Config) ->
    Nodes = test_utils:pmap(fun(N) ->
                    test_utils:start_node(N, Config, Case)
            end, [dev1, dev2]),

    test_utils:connect_dcs(Nodes),
   
    lager_common_test_backend:bounce(debug),
    [{nodes, Nodes}|Config].
    
end_per_testcase(_, _) ->
    ok.

all() -> [log_test].

log_test(Config) ->
    Nodes = proplists:get_value(nodes, Config),
    N = length(Nodes),

    % Distribute the updates randomly over all DCs
    NumWrites = 5,
    ListIds = [random:uniform(N) || _ <- lists:seq(1, NumWrites)],

    F = fun(Elem) ->
            Node = lists:nth(Elem, Nodes),
            ct:print("Inc at node: ~p",[Node]),

            {ok,_} = rpc:call(Node, antidote, append, 
                                [key1, crdt_pncounter, {increment, a}])
    end,

    lists:foreach(F, ListIds),

    FirstNode = hd(Nodes),
    
    G = fun() -> 
            rpc:call(FirstNode, antidote, read, [key1, crdt_pncounter])
        end,
    Delay = 1000,
    Retry = 360000 div Delay, %wait for max 1 min
    ok = test_utils:wait_until_result(G, {ok, NumWrites}, Retry, Delay),
    
    pass.
