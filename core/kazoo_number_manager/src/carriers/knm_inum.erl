%%%-------------------------------------------------------------------
%%% @copyright (C) 2011-2016, 2600Hz INC
%%% @doc
%%%
%%% Carrier for inums
%%%
%%% @end
%%% @contributors
%%%   Karl Anderson
%%%   Pierre Fenoll
%%%-------------------------------------------------------------------
-module(knm_inum).
-behaviour(knm_gen_carrier).

-export([is_local/0]).
-export([find_numbers/3]).
-export([acquire_number/1]).
-export([disconnect_number/1]).
-export([is_number_billable/1]).
-export([should_lookup_cnam/0]).

-export([generate_numbers/3]).

-include("knm.hrl").

-define(KZ_INUM,<<"numbers%2Finum">>).
-define(INUM_VIEW_FILE, <<"views/numbers_inum.json">>).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Is this carrier handling numbers local to the system?
%% Note: a non-local (foreign) carrier module makes HTTP requests.
%% @end
%%--------------------------------------------------------------------
-spec is_local() -> boolean().
is_local() -> 'true'.

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Query the local system for a quantity of available numbers
%% in a rate center
%% @end
%%--------------------------------------------------------------------
-spec find_numbers(ne_binary(), pos_integer(), kz_proplist()) ->
                          {'ok', knm_number:knm_numbers()} |
                          {'error', any()}.
find_numbers(<<"+", _/binary>>=Number, Quantity, Opts) ->
    AccountId = props:get_value(?KNM_ACCOUNTID_CARRIER, Opts),
    find_numbers_in_account(Number, Quantity, AccountId, Opts);
find_numbers(Number, Quantity, Opts) ->
    find_numbers(<<"+",Number/binary>>, Quantity, Opts).

-spec find_numbers_in_account(ne_binary(), pos_integer(), api_binary(), kz_proplist()) ->
                                     {'ok', knm_number:knm_numbers()} |
                                     {'error', any()}.
find_numbers_in_account(Number, Quantity, AccountId, Opts) ->
    case do_find_numbers_in_account(Number, Quantity, AccountId) of
        {'error', 'not_available'}=Error ->
            ResellerId = props:get_value(?KNM_RESELLERID_CARRIER, Opts),
            case AccountId =:= 'undefined'
                orelse AccountId =:= ResellerId
            of
                'true' -> Error;
                'false' ->
                    find_numbers_in_account(Number, Quantity, ResellerId, Opts)
            end;
        Result -> Result
    end.

-spec do_find_numbers_in_account(ne_binary(), pos_integer(), api_binary()) ->
                                        {'ok', knm_number:knm_numbers()} |
                                        {'error', any()}.
do_find_numbers_in_account(Number, Quantity, AccountId) ->
    ViewOptions = [{'startkey', [AccountId, ?NUMBER_STATE_AVAILABLE, Number]}
                  ,{'endkey', [AccountId, ?NUMBER_STATE_AVAILABLE, <<Number/binary,"\ufff0">>]}
                  ,{'limit', Quantity}
                  ,'include_docs'
                  ],
    case kz_datamgr:get_results(?KZ_INUM, <<"numbers_inum/status">>, ViewOptions) of
        {'ok', []} ->
            lager:debug("found no available inum numbers for account ~s", [AccountId]),
            {'error', 'not_available'};
        {'ok', JObjs} ->
            lager:debug("found available inum numbers for account ~s", [AccountId]),
            {'ok', format_numbers_resp(AccountId, JObjs)};
        {'error', _R}=E ->
            lager:debug("failed to lookup available local numbers: ~p", [_R]),
            E
    end.

-spec format_numbers_resp(ne_binary(), kz_json:objects()) -> knm_number:knm_numbers().
format_numbers_resp(AccountId, JObjs) ->
    [N || JObj <- JObjs,
          {'ok', N} <- [format_number_resp(AccountId, JObj)]
    ].

-spec format_number_resp(ne_binary(), kz_json:object()) -> knm_number:knm_number_return().
format_number_resp(AccountId, JObj) ->
    Num = kz_doc:id(kz_json:get_value(<<"doc">>, JObj)),
    knm_carriers:create_found(Num, ?MODULE, AccountId, kz_json:new(), ?NUMBER_STATE_AVAILABLE).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec is_number_billable(knm_number:knm_number()) -> boolean().
is_number_billable(_Number) -> 'false'.

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Acquire a given number from the carrier
%% @end
%%--------------------------------------------------------------------
-spec acquire_number(knm_number:knm_number()) ->
                            knm_number:knm_number().
acquire_number(Number) ->
    PhoneNumber = knm_number:phone_number(Number),
    lager:debug("acquiring number ~s", [knm_phone_number:number(PhoneNumber)]),
    update_doc(Number, [{?PVT_STATE, knm_phone_number:state(PhoneNumber)}
                       ,{?PVT_ASSIGNED_TO, knm_phone_number:assigned_to(PhoneNumber)}
                       ]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Release a number from the routing table
%% @end
%%--------------------------------------------------------------------
-spec disconnect_number(knm_number:knm_number()) ->
                               knm_number:knm_number().
disconnect_number(Number) ->
    lager:debug("disconnect number ~s in managed provider"
               ,[knm_phone_number:number(knm_number:phone_number(Number))]),
    update_doc(Number, [{?PVT_STATE, ?NUMBER_STATE_RELEASED}
                       ,{?PVT_ASSIGNED_TO, 'undefined'}
                       ,{?PVT_RESERVE_HISTORY, []}
                       ]).

-spec generate_numbers(ne_binary(), pos_integer(), non_neg_integer()) -> 'ok'.
generate_numbers(AccountId, <<"8835100",_/binary>> = Number, Quantity)
  when byte_size(Number) =:= 15 ->
    generate_numbers(AccountId, kz_util:to_integer(Number), kz_util:to_integer(Quantity));
generate_numbers(_AccountId, _Number, 0) -> 'ok';
generate_numbers(?MATCH_ACCOUNT_RAW(AccountId), Number, Quantity)
  when is_integer(Number),
       is_integer(Quantity),
       Quantity > 0 ->
    _R = save_doc(AccountId, <<"+",(kz_util:to_binary(Number))/binary>>),
    lager:info("number ~p/~p/~p", [Number, Quantity, _R]),
    generate_numbers(AccountId, Number+1, Quantity-1).


-spec save_doc(ne_binary(), ne_binary()) -> {'ok', kz_json:object()} |
                                            {'error', any()}.
save_doc(AccountId, Number) ->
    JObj = kz_json:from_list([{<<"_id">>, knm_converters:normalize(Number)}
                             ,{<<"pvt_account_id">>, AccountId}
                             ,{?PVT_STATE, ?NUMBER_STATE_AVAILABLE}
                             ,{?PVT_TYPE, <<"number">>}
                             ]),
    save_doc(JObj).

-spec save_doc(kz_json:object()) -> {'ok', kz_json:object()} |
                                    {'error', any()}.
save_doc(JObj) ->
    case kz_datamgr:save_doc(?KZ_INUM, JObj) of
        {'error', 'not_found'} ->
            'true' = kz_datamgr:db_create(?KZ_INUM),
            {'ok', _View} = kz_datamgr:revise_doc_from_file(?KZ_INUM, ?APP, ?INUM_VIEW_FILE),
            save_doc(JObj);
        Result -> Result
    end.

-spec update_doc(knm_number:knm_number(), kz_proplist()) ->
                        knm_number:knm_number().
update_doc(Number, UpdateProps) ->
    PhoneNumber = knm_number:phone_number(Number),
    Num = knm_phone_number:number(PhoneNumber),
    case kz_datamgr:update_doc(?KZ_INUM, Num, [{?PVT_MODULE_NAME, kz_util:to_binary(?MODULE)}
                                               | UpdateProps
                                              ])
    of
        {'ok', _UpdatedDoc} -> Number;
        {'error', Reason} ->
            knm_errors:database_error(Reason, PhoneNumber)
    end.

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec should_lookup_cnam() -> 'true'.
should_lookup_cnam() -> 'true'.
