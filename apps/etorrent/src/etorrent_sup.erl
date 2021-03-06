%%%-------------------------------------------------------------------
%%% File    : etorrent.erl
%%% Author  : User Jlouis <jesper.louis.andersen@gmail.com>
%%% License : See COPYING
%%% Description : Start up etorrent and supervise it.
%%%
%%% Created : 30 Jan 2007 by User Jlouis <jesper.louis.andersen@gmail.com>
%%%-------------------------------------------------------------------
-module(etorrent_sup).

-behaviour(supervisor).

-include("supervisor.hrl").
-include("log.hrl").

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%% ====================================================================
-spec start_link([binary()]) -> {ok, pid()} | ignore | {error, term()}.
start_link(PeerId) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, [PeerId]).


%% ====================================================================
init([PeerId]) ->
    ?INFO([etorrent_supervisor_starting, PeerId]),
    Tables       = ?CHILD(etorrent_table),
    Torrent      = ?CHILD(etorrent_torrent),
    FSJanitor    = ?CHILD(etorrent_fs_janitor),
    Counters     = ?CHILD(etorrent_counters),
    EventManager = ?CHILD(etorrent_event_mgr),
    PeerMgr      = ?CHILDP(etorrent_peer_mgr, [PeerId]),
    FastResume   = ?CHILD(etorrent_fast_resume),
    RateManager  = ?CHILD(etorrent_rate_mgr),
    PieceManager = ?CHILD(etorrent_piece_mgr),
    ChunkManager = ?CHILD(etorrent_chunk_mgr),
    Choker       = ?CHILDP(etorrent_choker, [PeerId]),
    Listener     = ?CHILD(etorrent_listener),
    AcceptorSup = {acceptor_sup,
                   {etorrent_acceptor_sup, start_link, [PeerId]},
                   permanent, infinity, supervisor, [etorrent_acceptor_sup]},
    UdpTracking = {udp_tracker_sup,
		   {etorrent_udp_tracker_sup, start_link, []},
		   transient, infinity, supervisor, [etorrent_udp_tracker_sup]},
    TorrentPool = {torrent_pool_sup,
                   {etorrent_t_pool_sup, start_link, []},
                   transient, infinity, supervisor, [etorrent_t_pool_sup]},
    TorrentMgr   = {etorrent_mgr,
		    {etorrent_mgr, start_link, [PeerId]},
		    permanent, 120*1000, worker, [etorrent_mgr]},
    DirWatcherSup = {dirwatcher_sup,
                  {etorrent_dirwatcher_sup, start_link, []},
                  transient, infinity, supervisor, [etorrent_dirwatcher_sup]},

    % Make the DHT subsystem optional
    DHTSup = case application:get_env(etorrent, dht) of
        undefined -> [];
        {ok, false} -> [];
        {ok, true} ->
            [{dht_sup,
                {etorrent_dht, start_link, []},
                permanent, infinity, supervisor, [etorrent_dht]}]
    end,

    {ok, {{one_for_all, 3, 60},
          [Tables, Torrent, FSJanitor,
           Counters, EventManager, PeerMgr,
           FastResume, RateManager, PieceManager,
           ChunkManager, Choker, Listener, AcceptorSup,
	   UdpTracking, TorrentPool, TorrentMgr,
	   DirWatcherSup] ++ DHTSup}}.
