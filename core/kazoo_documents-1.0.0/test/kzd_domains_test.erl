%%%-------------------------------------------------------------------
%%% @copyright (C) 2015, 2600Hz
%%% @doc
%%% Account document
%%% @end
%%% @contributors
%%%   James Aimonetti
%%%-------------------------------------------------------------------
-module(kzd_domains_test).

-include_lib("eunit/include/eunit.hrl").
-include_lib("whistle/include/wh_databases.hrl").

-define(DOMAIN, <<"2600hz.com">>).

-define(CNAM
        ,<<"{\"CNAM\":{\"portal.{{domain}}\":{\"name\":\"Web GUI\",\"mapping\":[\"ui.zswitch.net\"]},\"api.{{domain}}\":{\"name\":\"API\",\"mapping\":[\"api.zswitch.net\"]}}}">>
       ).

-define(A_RECORD
        ,<<"{\"A\":{\"us-east.{{domain}}\":{\"name\":\"Primary Proxy\",\"zone\": \"us-east\",\"mapping\":[\"8.36.70.3\"]},\"us-central.{{domain}}\":{\"name\":\"Secondary Proxy\",\"zone\": \"us-central\",\"mapping\":[\"166.78.105.67\"]},\"us-west.{{domain}}\":{\"name\":\"Tertiary Proxy\",\"zone\": \"us-west\",\"mapping\":[\"8.30.173.3\"]}}}">>
       ).

-define(NAPTR
        ,<<"{\"NAPTR\":{\"proxy-east.{{domain}}\":{\"name\":\"East NAPTR\",\"mapping\":[\"10 100 \\\"S\\\" \\\"SIP+D2U\\\" \\\"\\\" _sip._udp.proxy-east.{{domain}}.\"]},\"proxy-central.{{domain}}\":{\"name\":\"Central NAPTR\",\"mapping\":[\"10 100 \\\"S\\\" \\\"SIP+D2U\\\" \\\"\\\" _sip._udp.proxy-central.{{domain}}.\"]},\"proxy-west.{{domain}}\":{\"name\":\"West NAPTR\",\"mapping\":[\"10 100 \\\"S\\\" \\\"SIP+D2U\\\" \\\"\\\" _sip._udp.proxy-west.{{domain}}.\"]}}}">>
       ).

-define(SRV
        ,<<"{\"SRV\":{\"_sip._udp.proxy-east.{{domain}}\":{\"name\":\"East SRV\",\"mapping\":[\"10 10 7000 us-east.{{domain}}.\",\"15 15 7000 us-central.{{domain}}.\",\"20 20 7000 us-west.{{domain}}.\"]}}}">>
       ).

domains_test_() ->
    {'foreach'
     ,fun init/0
     ,fun stop/1
     ,[fun format_host/1
       ,fun cnam/1
       ,fun a_record/1
       ,fun naptr/1
       ,fun srv/1
      ]
    }.

-define(DOMAINS_SCHEMA, <<"domains">>).
-define(HOSTS_SCHEMA, <<"domain_hosts">>).

-record(state, {domains
                ,domain_hosts
                ,loader_fun
               }).

init() ->
    CrossbarDir = code:lib_dir('crossbar'),

    DomainsSchema = load(CrossbarDir, ?DOMAINS_SCHEMA),
    DomainHostsSchema = load(CrossbarDir, ?HOSTS_SCHEMA),

    LoaderFun = fun(?DOMAINS_SCHEMA) -> DomainsSchema;
                   (?HOSTS_SCHEMA) -> DomainHostsSchema
                end,

    #state{domains=DomainsSchema
           ,domain_hosts=DomainHostsSchema
           ,loader_fun=LoaderFun
          }.

load(AppPath, Filename) ->
    SchemaPath = filename:join([AppPath, "priv", "couchdb", "schemas"
                                ,<<Filename/binary, ".json">>
                               ]),
    {'ok', SchemaFile} = file:read_file(SchemaPath),
    wh_json:decode(SchemaFile).

stop(_) -> 'ok'.

format_host(_) ->
    [{"Verify host replacement happens"
      ,?_assertEqual(<<"api.", (?DOMAIN)/binary>>
                     ,kzd_domains:format_host(<<"api.{{domain}}">>
                                              ,?DOMAIN
                                             )
                    )
     }
    ].

cnam(#state{domains=DomainsSchema
            ,loader_fun=LoaderFun
           }
    ) ->
    CNAM = wh_json:decode(?CNAM),

    Hosts = kzd_domains:cnam_hosts(CNAM),

    [{"Validate cnam property in domains object"
      ,?_assertEqual({'ok', CNAM}
                     ,wh_json_schema:validate(DomainsSchema
                                              ,CNAM
                                              ,[{'schema_loader_fun', LoaderFun}]
                                             )
                    )
     }
     ,{"Validate list of hosts"
       ,?_assertEqual([<<"portal.{{domain}}">>
                       ,<<"api.{{domain}}">>
                      ]
                      ,Hosts
                     )
      }
     | validate_cnam_hosts(CNAM, Hosts)
    ].

validate_cnam_hosts(CNAM, Hosts) ->
    lists:flatten(
      lists:map(fun(H) -> validate_cnam_host(CNAM, H) end
                ,Hosts
               )
     ).

validate_cnam_host(CNAM, Host) ->
    _HostMappings = kzd_domains:cnam_host_mappings(CNAM, Host),
    WhitelabelHost = kzd_domains:format_host(Host, ?DOMAIN),

    [{"Verify whitelabel host"
      ,?_assert('nomatch' =/= binary:match(WhitelabelHost, ?DOMAIN))
     }
    ].

a_record(#state{domains=DomainsSchema
                ,loader_fun=LoaderFun
               }) ->
    A_RECORD = wh_json:decode(?A_RECORD),

    Hosts = kzd_domains:a_record_hosts(A_RECORD),

    [{"Validate a_record property in domains object"
      ,?_assertEqual({'ok', A_RECORD}
                     ,wh_json_schema:validate(DomainsSchema
                                              ,A_RECORD
                                              ,[{'schema_loader_fun', LoaderFun}]
                                             )
                    )
     }
     ,{"Validate list of hosts"
       ,?_assertEqual([<<"us-east.{{domain}}">>
                       ,<<"us-central.{{domain}}">>
                       ,<<"us-west.{{domain}}">>
                      ]
                      ,Hosts
                     )
      }
     | validate_a_record_hosts(A_RECORD, Hosts)
    ].

validate_a_record_hosts(A_RECORD, Hosts) ->
    lists:flatten(
      lists:map(fun(H) -> validate_a_record_host(A_RECORD, H) end
                ,Hosts
               )
     ).

validate_a_record_host(A_RECORD, Host) ->
    _HostMappings = kzd_domains:a_record_host_mappings(A_RECORD, Host),
    WhitelabelHost = kzd_domains:format_host(Host, ?DOMAIN),

    [{"Verify whitelabel host"
      ,?_assert('nomatch' =/= binary:match(WhitelabelHost, ?DOMAIN))
     }
    ].

naptr(#state{domains=DomainsSchema
             ,loader_fun=LoaderFun
            }) ->
    NAPTR = wh_json:decode(?NAPTR),

    Hosts = kzd_domains:naptr_hosts(NAPTR),

    [{"Validate naptr property in domains object"
      ,?_assertEqual({'ok', NAPTR}
                     ,wh_json_schema:validate(DomainsSchema
                                              ,NAPTR
                                              ,[{'schema_loader_fun', LoaderFun}]
                                             )
                    )
     }
     ,{"Validate list of hosts"
       ,?_assertEqual([<<"proxy-east.{{domain}}">>
                       ,<<"proxy-central.{{domain}}">>
                       ,<<"proxy-west.{{domain}}">>
                      ]
                      ,Hosts
                     )
      }
     | validate_naptr_hosts(NAPTR, Hosts)
    ].

validate_naptr_hosts(NAPTR, Hosts) ->
    lists:flatten(
      lists:map(fun(H) -> validate_naptr_host(NAPTR, H) end
                ,Hosts
               )
     ).

validate_naptr_host(NAPTR, Host) ->
    WhitelabelHost = kzd_domains:format_host(Host, ?DOMAIN),

    [{"Verify whitelabel host"
      ,?_assert('nomatch' =/= binary:match(WhitelabelHost, ?DOMAIN))
     }
     | validate_naptr_host_mappings(NAPTR, Host)
    ].

validate_naptr_host_mappings(NAPTR, Host) ->
    HostMappings = [kzd_domains:format_mapping(Mapping, ?DOMAIN)
                    || Mapping <- kzd_domains:naptr_host_mappings(NAPTR, Host)
                   ],
    [{"Verify whitelabel mappings"
      ,?_assert(
          lists:all(fun(Mapping) ->
                            'nomatch' =/= binary:match(Mapping, ?DOMAIN)
                    end
                    ,HostMappings
                   )
         )
     }
    ].

srv(#state{domains=DomainsSchema
             ,loader_fun=LoaderFun
            }) ->
    SRV = wh_json:decode(?SRV),

    Hosts = kzd_domains:srv_hosts(SRV),

    [{"Validate srv property in domains object"
      ,?_assertEqual({'ok', SRV}
                     ,wh_json_schema:validate(DomainsSchema
                                              ,SRV
                                              ,[{'schema_loader_fun', LoaderFun}]
                                             )
                    )
     }
     ,{"Validate list of hosts"
       ,?_assertEqual([<<"_sip._udp.proxy-east.{{domain}}">>
                      ]
                      ,Hosts
                     )
      }
     | validate_srv_hosts(SRV, Hosts)
    ].

validate_srv_hosts(SRV, Hosts) ->
    lists:flatten(
      lists:map(fun(H) -> validate_srv_host(SRV, H) end
                ,Hosts
               )
     ).

validate_srv_host(SRV, Host) ->
    WhitelabelHost = kzd_domains:format_host(Host, ?DOMAIN),

    [{"Verify whitelabel host"
      ,?_assert('nomatch' =/= binary:match(WhitelabelHost, ?DOMAIN))
     }
     | validate_srv_host_mappings(SRV, Host)
    ].

validate_srv_host_mappings(SRV, Host) ->
    HostMappings = [kzd_domains:format_mapping(Mapping, ?DOMAIN)
                    || Mapping <- kzd_domains:srv_host_mappings(SRV, Host)
                   ],
    [{"Verify whitelabel mappings"
      ,?_assert(
          lists:all(fun(Mapping) ->
                            'nomatch' =/= binary:match(Mapping, ?DOMAIN)
                    end
                    ,HostMappings
                   )
         )
     }
    ].
