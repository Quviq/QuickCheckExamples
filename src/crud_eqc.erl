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
%%% @doc This is a model for a CRUD resource. It shows how QuickCheck can
%%%      be used to model such a resource and can easily be extended to 
%%%      cover more resources.
%%%      As a simple example, we use a file as our resource.
%%%
%%%      The data we put in files is generated using the eqc_gen:utf8/0 generator.
%%%      This generates a random sequence of utf8 characters, but as can be seen 
%%%      from the features we record while testing, it will hardly ever create 
%%%      more than 100 characters. Features are useful to detect whether certain 
%%%      things have been tested or when assuring that a certain requirement has 
%%%      been covered.
%%%
%%% @end
%%% Created : 20 Feb 2017 by Thomas Arts

-module(crud_eqc).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eqc/include/eqc_statem.hrl").

-compile(export_all).

%% -- Generators -------------------------------------------------------------

-define(RESOURCES, ["/tmp/res1", "/tmp/res2"]).

%% Pick one of the predifined resources
resource() ->
  elements(?RESOURCES).

%% Pick an existing resource from the state
resource(S) ->
  elements(maps:keys(S)).

%% create content for a resource
resource_data() ->
  utf8().
  

%% -- State ------------------------------------------------------------------
initial_state() ->
  #{}.

%% --- Operation: create ---
create_args(_S) ->
  [resource(), resource_data()].

create_pre(S, [Resource, _Data]) ->
  not maps:is_key(Resource, S).

create(Resource, Data) ->
  file:write_file(Resource, Data).

create_next(S, _Value, [Resource, Data]) ->
  S#{ Resource => Data }.

create_post(_S, [_Resource, _Data], Res) ->
  eq(Res, ok).

create_features(_S, [Resource, Data], _Res) ->
  [{created, Resource, empty} || Data == <<>> ] ++
  [{created, Resource, small} || size(Data) < 100 ] ++
  [{created, Resource, large} || size(Data) >= 100 ].

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
  file:read_file(Resource).

read_post(S, [Resource], Res) ->
  eq({ok, maps:get(Resource, S)}, Res).

%% --- Operation: read with possibly non existing resource ---
%% The negative case, read any resource.
read2_args(_S) ->
  [resource()].

read2(Resource) ->
  file:read_file(Resource).

read2_post(S, [Resource], Res) ->
  case Res of
    {ok, Data} -> 
      maps:is_key(Resource, S) andalso eq(Data, maps:get(Resource, S));
    {error, enoent} ->
      not maps:is_key(Resource, S);
    _ ->
      Res
  end.

%% We should test both reading existing and non-existing resources
read2_features(_S, [Resource], {Tag, _}) ->
  [{read, Resource, Tag}].


%% --- Operation: update ---
%% Update only makes sense if the resource exists. Hence checked in precondition.
%% In this case, update is the same as replacement, but one could think of tinkering
%% the model to make it into an append.
update_pre(S) ->
  maps:size(S) > 0.

update_args(S) ->
  [resource(S), resource_data()].

%% For shrinking, the resource should exist during shrinking
update_pre(S, [Resource, _Data]) ->
  maps:is_key(Resource, S).

update(Resource, Data) ->
  file:write_file(Resource, Data).

update_next(S, _Value, [Resource, Data]) ->
  S#{ Resource => Data }.

update_post(_S, [_, _], Res) ->
  eq(Res, ok).

%% --- Operation: delete ---
%% One could instead also choose to try and delete non-existing resources, 
%% e.g. those that were created before.
delete_pre(S) ->
  maps:size(S) > 0.

delete_args(S) ->
  [resource(S)].

delete_pre(S, [Resource]) ->
  maps:is_key(Resource, S).

delete(Resource) ->
  file:delete(Resource).

delete_next(S, _Value, [Resource]) ->
  maps:remove(Resource, S).

delete_post(_S, [_], Res) ->
  eq(Res, ok).


%% -- Property ---------------------------------------------------------------

weight(_S, update) -> 2;
weight(_S, _Cmd) -> 1.

prop_crud() ->
  ?FORALL(Cmds, commands(?MODULE),
  begin
    cleanup(),
    {H, S, Res} = run_commands(Cmds),
    check_command_names(Cmds,
        measure(length, commands_length(Cmds),
        aggregate(call_features(H),
        pretty_commands(?MODULE, Cmds, {H, S, Res},
                        Res == ok))))
  end).

prop_crud_parallel() ->
  ?FORALL(Cmds, parallel_commands(?MODULE),
  begin
    cleanup(),
    {H, S, Res} = run_parallel_commands(Cmds),
    pretty_commands(?MODULE, Cmds, {H, S, Res},
                    Res == ok)
  end).

%% Make sure no zombie resources hang around at test start
cleanup() ->
  [ file:delete(Resource) || Resource <- ?RESOURCES].
  
