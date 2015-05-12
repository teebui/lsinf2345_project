-module (chat).
-export ([disconnect/1, server_run/1, start_server/0,connect/1, start_client/2, send_message/2, send_message_all/2, broadcast/2]).

connect(Username) ->
	% spawn a client process to handle request send to a client once connected
	% global:register_name(client_pid, spawn(chat, start_client, [Username, server_node()])).
	global:register_name(Username, spawn(chat, start_client, [Username, server_node()])).

%disconnect last connected user
disconnect(Username) ->
	% client_pid ! {disconnect, self(), server_node()}.	
	{chat_server, server_node()} ! {global:whereis_name(Username), client_disconnected},
	unregister(Username).

broadcast(Username, Pid) ->
	%self() ! {broadcast, Username, node(), global:whereis_name(client_pid)}.
	self() ! {broadcast, Username, node(), whereis(client_pid)}.

%broadcast(User_list)
	% if [User|Other_users] -> it's a list, send recursively to all
		% broadcast(User)
		% broadcast(Other_users)
	% if User -> it's just a user, send 1


start_client(Username, ServerNode) ->
	io:format("Hello ~p~n", [Username]),
	{chat_server, ServerNode} ! {self(), connect, Username},
	%broadcast(Username),
	client_handler([], []).

% a loop process that handles requests from client
% GroupList = [{GroupName, StarterPID GroupUser_list}]
% Maybe there could be another client_handler which has only 1 param (withtout grouplist)
client_handler(User_list, GroupList) ->
	receive		
		{broadcast, _Username, _Node, _Pid} -> % handles the broadcats message
			io:format("broadcast arrived: ~n"),
			% lists:foreach(
			% 	fun(X)->
			% 		io:format("~w ",[X]) 
			% 	end, 
			% 	User_list
			% ).
			[{Pid, Node} ! {bc_hello, _Pid, _Node, _Username} || {Pid, Node, Username} <- User_list],				
			client_handler(User_list, GroupList);
		{bc_hello, Pid, Node, Username} -> % receives a hello from other client
			[{Pid, Node, Username} | User_list],
			client_handler(User_list, GroupList);
		{msg_sent, RecipientUsn, Msg, SenderUsn} ->
			% should be handled by lower layer
			% User_list format: [{Username, Pid, Node}]
			% search for the username in the tuple list
			case lists:keysearch(RecipientUsn, 1, User_list) of
					false -> % nothing found
						recipient_username_not_found;
					{value, {Username, Pid}} -> % tuple returned
						Pid ! {Username, msg_received, Msg, SenderUsn, self()}
			end;
		{RecipientUsn, msg_received, Msg, SenderUsn, SenderPid} ->
			% when receiving a message sent by another
			io:format("~p: ~p", [SenderUsn, Msg]);
			%log system works here to record into Riak later

		{regular_msg, Msg} ->
			io:format("Receive msg: ~w~n", [Msg]);

		{online_user_updated, Updated_user_list} ->
			% maybe more work on this to remove self()
			User_list = Updated_user_list,
			client_handler(Updated_user_list, GroupList)

		% {disconnect, Pid, ServerNode} ->
		% 	{chat_server, ServerNode} ! {Pid, client_disconnected}
	end.

% send_message(Username, Msg) -> % send a message to another user
% 	client_pid ! {msg_sent, Username, Msg}.

send_message(Username, Msg) ->
	Username ! {regular_msg, Msg}.

 
send_message_all(User_list, Msg) ->
	pass.

%%%% ROUTER LAYER %%%%%%%%%
%%% Involve logical dispatching
client_router_layer() ->
	receive
		% Message = {Pid, Usersname}
		{broadcast, Message} -> %send message to all nodes connected
			sent,
			client_link_layer();
		{unicast, Node, Message} -> % send message to 1 specific node
			sent,
			client_link_layer()
	end.

%%% LINK LAYER OF CLIENT
%%% 
client_link_layer() ->
	receive
		% Message = {Pid, Message}, Message = {Username, Node, etc}
		{broadcast, Message} -> %send message to all nodes connected
			sent,
			client_link_layer();
		{unicast, Node, Message} -> % send message to 1 specific node
			sent,
			client_link_layer()
	end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%% SERVER SIDE %%%%%%%%%%%%%%%%%%%%%%%%%%%%

server_node() ->
	chat_server@localhost.

start_server() -> % start chat server
	register(chat_server, spawn(chat, server_run, [[]])).

%%% Server should maintain the list of online user
server_run(User_list) ->
	receive
		{From, connect, Name} ->
            Updated_user_list = server_logon(From, Name, User_list),
            io:format("User ~w signed in!~n", [Name]),
            io:format("Current online user(s): ~p~n", [Updated_user_list]),
            server_run(Updated_user_list);
        {From, client_disconnected} ->
            Updated_user_list = server_logoff(From, User_list),
            io:format("User ~w signed out!~n", [From]),
            io:format("Current online user(s): ~p~n", [Updated_user_list]),
            server_run(Updated_user_list);
        % {From, message_to, To, Message} ->
        %     server_transfer(From, To, Message, User_list),
        %     io:format("list is now: ~p~n", [User_list]),
        %     server_run(User_List)
        {query_username, Username, SenderPid, Message} ->
        	case lists:keysearch(Username, 2, User_list) of
        		false ->
        			pass;
        		{value, {RecvPid, Username}} -> % found username
        			SenderPid ! {recv_pid, Message, SenderPid}
        	end
	end.

server_logon(SenderPid, Username, User_list) ->
    %% check if logged on anywhere else
    case lists:keymember(Username, 2, User_list) of
        true -> % if the username is already used on other node
            SenderPid ! {messenger, stop, user_exists_at_other_node},  %reject logon
            User_list;
        false ->
            SenderPid! {messenger, logged_on},
            [{SenderPid, Username} | User_list]        %add user to the list
    end.

%%% Server deletes a user from the user list
server_logoff(From, User_List) ->
    lists:keydelete(From, 1, User_List).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CHAT ROOM %%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Group infor should also be stored on server/private
create_group(GroupName) ->
	% {GroupName, User_list}
	% % GroupList = [{GroupName, StarterPID GroupUser_list}]
	pass.

list_group(ServerNode) ->
	pass.

join_group(GroupName) ->
	pass.

leave_group(GroupName) ->
	pass.
	



