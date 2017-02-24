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
%%% @doc This is a model demonstrating how random Erlang programs can 
%%%      be generated using QuickCheck.
%%%      These programs are useful when testing the Erlang compiler, but 
%%%      also when you write your own parse transformation or cover tool.
%%%      
%%%      Quviq can build program language generators for any language.
%%%      The Erlang program generator comes for free with the tool,
%%%      other languages can be ordered.
%%%
%%%
%%% @end
%%% Created : 23 Feb 2017 by Thomas Arts
-module(erlang_eqc).
-include_lib("eqc/include/eqc.hrl").

-compile(export_all).

-define(TEST_MODULE, myprog).

compile(Code) ->
  compile(Code, []).

compile(Code, Options) ->
  File = lists:concat([?TEST_MODULE, ".erl"]),
  ok = file:write_file(File, Code),
  compile:file(File, Options).

%% In the proeprty you can pass all kind of options to the compiler as well, e.g. 'P'.
prop_compile() ->
  ?FORALL(Code, eqc_erlang_program:module(?TEST_MODULE, [macros, maps, recursive_funs]),
	  begin
	    Res      = compile(Code),
	    ?WHENFAIL(
	       begin
		 eqc:format("~s\n", [Code]),
		 compile(Code, [report_errors])
	       end,
	       equals(Res, {ok, ?TEST_MODULE}))
	  end).
