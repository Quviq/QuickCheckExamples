%%% @author Thomas Arts 
%%% @copyright (C) Quviq AB 2017. All Rights Reserved.
%%% 
%%% Licensed under the Quviq QuickCheck end-user licence agreement.
%%% This software and modifications hereof may only be used when user
%%% has a valid licence to run Quviq QuickCheck.
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%
%%% @doc This is a model for a CRUD resource that when created returns a unique
%%%      identifier. It shows how QuickCheck can be used to model such a resource.
%%%      As a simple example, we use processes as our resources. Each process 
%%%      contains a value set by its creation. This value can be changed by an 
%%%      update function and read by sending a message to obtain the value.
%%%
%%%      The data we put in processes are integers generated using the eqc_gen:int/0
%%%      generator.
%%%
%%% @end
%%% Created : 21 Feb 2017 by Thomas Arts

-module(crud_unique_id_eqc).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eqc/include/eqc_statem.hrl").

-compile(export_all).

%% -- Generators -------------------------------------------------------------

%% Pick an existing resource from the state
resource(S) ->
  elements(maps:keys(S)).

%% create content for a resource
resource_data() ->
  int().


%% -- State ------------------------------------------------------------------
initial_state() ->
  #{}.

%% --- Operation: create ---
create_args(_S) ->
  [resource_data()].

create(Data) ->
  spawn(?MODULE, resource_loop, [Data]).

%% Here Value is symbolic. Never match on it or perform computations on it.
create_next(S, Value, [Data]) ->
  S#{ Value => Data }.

create_post(_S, [_Data], Res) ->
  is_pid(Res).

%% --- Operation: read ---
%% The positive case, only read resources that exist.
%% See read2 for the case in which we also read non-exisiting resources and
%% expect an error returned.
read_pre(S) ->
  maps:size(S) > 0.

read_args(S) ->
  [resource(S)].

%% For shrinking, we must make sure the resource still exists
read_pre(S, [Resource]) ->
  maps:is_key(Resource, S).

read(Resource) ->
  Resource ! {read, self()},
  receive
    {Resource, X} -> X
  after 100 ->
      timeout
  end.

read_post(S, [Resource], Res) ->
  eq(maps:get(Resource, S), Res).


%% --- Operation: update ---
%% Update only makes sense if the resource exists. Hence checked in precondition.
update_pre(S) ->
  maps:size(S) > 0.

update_args(S) ->
  [resource(S), resource_data()].

%% For shrinking, the resource should exist during shrinking
update_pre(S, [Resource, _Data]) ->
  maps:is_key(Resource, S).

update(Resource, Data) ->
  Resource ! {update, self(), Data},
  receive
    {Resource, ok} -> ok
  after 100 ->
      timeout
  end.

update_next(S, _Value, [Resource, Data]) ->
  S#{ Resource => Data }.

update_post(_S, [_, _], Res) ->
  eq(Res, ok).

%% --- Operation: delete ---
delete_pre(S) ->
  maps:size(S) > 0.

delete_args(S) ->
  [resource(S)].

delete_pre(S, [Resource]) ->
  maps:is_key(Resource, S).

delete(Resource) ->
  exit(Resource, kill).

delete_next(S, _Value, [Resource]) ->
  maps:remove(Resource, S).

delete_post(_S, [_], Res) ->
  eq(Res, true).


%% -- Property ---------------------------------------------------------------

weight(_S, update) -> 10;
weight(_S, read) -> 10;
weight(_S, _Cmd) -> 1.

prop_crud() ->
  ?FORALL(Cmds, commands(?MODULE),
  begin
    {H, S, Res} = run_commands(Cmds),
    cleanup(S),
    check_command_names(Cmds,
        measure(length, commands_length(Cmds),
        aggregate(call_features(H),
        pretty_commands(?MODULE, Cmds, {H, S, Res},
                        Res == ok))))
  end).

prop_crud_parallel() ->
  ?FORALL(Cmds, parallel_commands(?MODULE),
  begin
    {H, S, Res} = run_parallel_commands(Cmds),
    %% Cannot do cleanup here... S does not contain "state"
    %% We get the pids from the history results.
    cleanup_parallel(H),
    pretty_commands(?MODULE, Cmds, {H, S, Res},
                    Res == ok)
  end).

%% Make sure no zombie resources hang around at test start
cleanup(S) ->
  [ exit(Resource, kill) || Resource <- maps:keys(S)].

cleanup_parallel(Hs) ->
  [ exit(Pid, kill) || H<-Hs, 
                       {normal, Pid} <- [ eqc_statem:history_result(H) ], 
                       is_pid(Pid) ].
  
resource_loop(X) ->
  receive
    {read, Pid} -> 
      Pid ! {self(), X},
      resource_loop(X);             
    {update, Pid, NewX} ->
      Pid ! {self(), ok}, 
      resource_loop(NewX)
      %% Change this to resource_loop(X) if you like 
      %% to see how errors are reported
  after 10000 ->
      stop  
  end.
