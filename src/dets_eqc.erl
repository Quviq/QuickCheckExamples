%%% @author John Hughes
%%% @copyright (C) Quviq AB 2010-2017. All Rights Reserved.
%%% 
%%% Licensed under the Quviq QuickCheck end-user licence agreement.
%%% This software and modifications hereof may only be used when user
%%% has a valid licence to run Quviq QuickCheck.
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%%
%%% @doc This is a model to test the Erlang dets module. It shows how QuickCheck can
%%%      be used to find race conditions. The original model was used to find a few
%%%      notoriously hard to discover bugs in dets.
%%%
%%%
%%% @end
%%% Modified : 22 Feb 2017 by Thomas Arts
%%%            (adopted to QuickCheck version 1.39.2)
%%%
-module(dets_eqc).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eqc/include/eqc_statem.hrl").

-compile(export_all).

-record(state, {type, contents = [], is_open = 0}).

%% -- Generators -------------------------------------------------------------

-define(dets_table, dets_table).

dets_type() ->
  oneof([set,bag]).

object() ->
    {nat(), choose($a,$z)}.

%% -- State ------------------------------------------------------------------
initial_state() ->
  #state{}.

model_insert(set, S, {K,_}=Obj) ->
  lists:keydelete(K,1,S) ++ [Obj];
model_insert(bag, S, {_,_} = Obj) ->
  (S--[Obj])++[Obj];   % surprise! why can't Obj appear twice?
model_insert(T, S, [Obj|Objs]) ->
  model_insert(T, model_insert(T, S, Obj), Objs);
model_insert(_, S, []) ->
  S.

any_exist(Obj, S) when is_tuple(Obj) ->
  any_exist([Obj], S);
any_exist(Objs, S) ->
  [K || {K,_} <- Objs, lists:keymember(K,1,S)] /= [].

model_delete(S, K) ->
  [Obj || Obj={K1,_} <- S, K1/=K].


%% -- Operations -------------------------------------------------------------

%% We can always open a file, but only perform another operation 
%% when it is open.
command_precondition_common(S, Cmd) ->
  Cmd == open_file orelse S#state.is_open > 0.

%% --- Operation: open_file ---
open_file_args(_) ->
  [dets_type()].

%% Only re-open with the same type.
open_file_pre(#state{type = T}, [Type]) ->
  T == undefined orelse T == Type.

open_file(Type) ->
  dets:open_file(?dets_table, [{type, Type}]).

open_file_next(S, _V, [Type]) ->
  S#state{type = Type, is_open = S#state.is_open + 1}.

open_file_post(_S, [_Type], Res) ->
  eq(Res, {ok, ?dets_table}).

open_file_features(S, [_Type], _Res) ->
  [reopened || S#state.is_open > 1].


%% --- Operation: close ---
close_args(_S) ->
  [].

close() ->
  dets:close(?dets_table).

close_next(S, _Value, []) ->
  S#state{is_open = S#state.is_open - 1}.

close_post(_S, [], Res) ->
  Res==ok orelse Res=={error,not_owner}.

%% --- Operation: read ---
read_args(_S) ->
  [].

read() ->
  dets:traverse(?dets_table, fun(X) -> {continue,X} end).

read_post(S, [], Res) ->
  lists:sort(Res) == lists:sort(S#state.contents).

%% --- Operation: insert ---
insert_args(_S) ->
  [oneof([object(), list(object())])].

insert(Objs) ->
  dets:insert(?dets_table, Objs).

insert_next(S, _Value, [Objs]) ->
  S#state{contents = model_insert(S#state.type, S#state.contents, Objs)}.

insert_post(_S, [_], Res) ->
  eq(Res, ok).

insert_features(S, [{K,V}], Res) ->
  insert_features(S, [[{K,V}]], Res);
insert_features(S, [Objs], _Res) ->
  [{insert_duplicate, S#state.type} || 
    lists:any(fun(Obj) -> lists:member(Obj, S#state.contents) end, Objs)] ++
    [{insert_same_key, S#state.type} || any_exist(Objs, S#state.contents)] ++
    [{insert_fresh, S#state.type} || not any_exist(Objs, S#state.contents)].

%% --- Operation: insert_new ---
insert_new_args(_S) ->
  [oneof([object(), list(object())])].

insert_new(Objs) ->
  dets:insert_new(?dets_table, Objs).

insert_new_next(S, _Value, [Objs]) ->
  case any_exist(Objs, S#state.contents) of
    true ->
      S;
    false ->
      S#state{contents=model_insert(S#state.type, S#state.contents, Objs)}
  end.

insert_new_post(S, [Objs], Res) ->
  Res==not any_exist(Objs, S#state.contents).

%% --- Operation: delete ---
delete_args(_S) ->
  [nat()].

delete(Key) ->
  dets:delete(?dets_table, Key).

delete_next(S, _Value, [Key]) ->
  S#state{contents = model_delete(S#state.contents, Key)}.

delete_post(_S, [_Key], Res) ->
  eq(Res, ok).

%% -- Property ---------------------------------------------------------------

weight(_S, _Cmd) -> 1.

prop_dets() ->
  ?FORALL(Cmds, more_commands(3, commands(?MODULE)),
  begin
    {H, S, Res} = run_commands(Cmds),
    cleanup(S#state.is_open),
    check_command_names(Cmds,
        measure(length, commands_length(Cmds),
        aggregate(call_features(H),
        pretty_commands(?MODULE, Cmds, {H, S, Res},
                        Res == ok))))
  end).

prop_dets_parallel() ->
  ?FORALL(Cmds, parallel_commands(?MODULE),
  begin
    {H, S, Res} = run_parallel_commands(Cmds),
    %% tables opened in parallel branches are automatically 
    %% closed when those processes terminate. We only
    %% need to close the tables opened in sequential prefix.
    %% There probably are no more than 50 of them.
    cleanup(50),
    pretty_commands(?MODULE, Cmds, {H, S, Res},
                    Res == ok)
  end).

%% Close dets equally often as it is opened
cleanup(N) ->
  [ close() || _<-lists:seq(1,N) ],
  file_delete(?dets_table).

file_delete(Name) ->
  case file:delete(Name) of
    {error, enoent} ->
      ok;
    _Bad ->
      file_delete(Name)
  end.
