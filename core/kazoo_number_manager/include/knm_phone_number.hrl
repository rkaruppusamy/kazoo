-ifndef(KNM_NUMBER_MANAGER_HRL).

-include_lib("kazoo/include/kz_log.hrl").
-include_lib("kazoo/include/kz_types.hrl").

-define(KNM_DEFAULT_AUTH_BY, <<"system">>).

-type knm_phone_number_return() ::
        {'ok', knm_phone_number:knm_phone_number()} |
        {'error', any()}.

-type dry_run_return() ::
        {'dry_run', kz_services:services(), non_neg_integer()}.

-type knm_number_return() ::
        {'ok', knm_number:knm_number()} |
        dry_run_return() |
        {'error', atom()} |
        {'error', knm_errors:error()}.

-define(PVT_DB_NAME, <<"pvt_db_name">>).
-define(PVT_ASSIGNED_TO, <<"pvt_assigned_to">>).
-define(PVT_PREVIOUSLY_ASSIGNED_TO, <<"pvt_previously_assigned_to">>).
-define(PVT_AUTH_BY, <<"pvt_authorizing_account">>).
-define(PVT_USED_BY, <<"pvt_used_by">>).
-define(PVT_FEATURES, <<"pvt_features">>).
-define(PVT_STATE, <<"pvt_state">>).
-define(PVT_STATE_LEGACY, <<"pvt_number_state">>).
-define(PVT_RESERVE_HISTORY, <<"pvt_reserve_history">>).
-define(PVT_PORTED_IN, <<"pvt_ported_in">>).
-define(PVT_MODULE_NAME, <<"pvt_module_name">>).
-define(PVT_CARRIER_DATA, <<"pvt_carrier_data">>).
-define(PVT_REGION, <<"pvt_region">>).
-define(PVT_MODIFIED, <<"pvt_modified">>).
-define(PVT_CREATED, <<"pvt_created">>).
-define(PVT_TYPE, <<"pvt_type">>).

-define(KNM_DB_PREFIX, "numbers/+").
-define(KNM_DB_PREFIX_ENCODED, "numbers%2F%2B").
-define(KNM_DB_PREFIX_encoded, "numbers%2f%2b").

-define(NUMBER_STATE_AGING, <<"aging">>).
-define(NUMBER_STATE_AVAILABLE, <<"available">>).
-define(NUMBER_STATE_DELETED, <<"deleted">>).
-define(NUMBER_STATE_DISCONNECTED, <<"disconnected">>).
-define(NUMBER_STATE_DISCOVERY, <<"discovery">>).
-define(NUMBER_STATE_IN_SERVICE, <<"in_service">>).
-define(NUMBER_STATE_PORT_IN, <<"port_in">>).
-define(NUMBER_STATE_PORT_OUT, <<"port_out">>).
-define(NUMBER_STATE_RELEASED, <<"released">>).
-define(NUMBER_STATE_RESERVED, <<"reserved">>).

-define(KNM_AVAILABLE_STATES, [?NUMBER_STATE_DISCOVERY, ?NUMBER_STATE_AVAILABLE]).

-define(EMERGENCY_SERVICES_KEY, <<"e911">>).
-define(VITELITY_KEY, <<"vitelity_e911">>).
-define(DASH_KEY, <<"dash_e911">>).

-define(CARRIER_INUM, <<"knm_inum">>).
-define(CARRIER_LOCAL, <<"knm_local">>).
-define(CARRIER_MANAGED, <<"knm_managed">>).
-define(CARRIER_MDN, <<"knm_mdn">>).
-define(CARRIER_OTHER, <<"knm_other">>).
-define(CARRIER_RESERVED, <<"knm_reserved">>).
-define(CARRIER_RESERVED_RESELLER, <<"knm_reserved_reseller">>).

-define(KNM_ACCOUNTID_CARRIER, <<"account_id">>).
-define(KNM_RESELLERID_CARRIER, <<"reseller_id">>).

-define(KNM_NUMBER_MANAGER_HRL, 'true').
-endif.
