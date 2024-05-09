# Singleton - NET
extends Node

var server : Server
var client : Client

var chat_log : String

func make_server():
	if server != null:
		return
	if client:
		client.close()
		client.queue_free()
		remove_child(client)
		client = null
	server = Server.new()
	server.name = "TheServer"
	add_child(server)


func make_client() -> void:
	if client != null:
		return
	if server:
		server.close()
		server.queue_free()
		remove_child(server)
		server = null
	client = Client.new()
	client.name = "TheClient"
	add_child(client)


func server_listen(address : String, port : int, username : String):
	make_server()
	server.listen(address, port, username)


func server_close():
	if not server:
		return
	server.close()


func server_kick_all():
	if not server:
		return
	server.kick_all()


func client_connect_and_login(address : String, port : int, login : String):
	make_client()
	client.connect_to_server(address, port)
	client.queue_login(login)


func client_logout_and_disconnect():
	if not client:
		return
	client.logout_if_needed()
	client.close()


func server_connection() -> bool:
	return server and server.enet_network


func client_connection() -> bool:
	return client and client.enet_network


func get_current_login() -> String: # TODO rename username to login
	if server_connection():
		return server.server_username
	if client_connection():
		return client.username
	return CFG.DEFAULT_USER_NAME # TODO rename to PLACEHOLDER_LOGIN

func send_chat_message(message : String) -> void:
	if not client:
		append_message_to_local_chat_log(message, get_current_login())
	if server:
		server.broadcast_say(message)
	elif client:
		client.queue_say(message)


func append_message_to_local_chat_log(message : String, \
		author : String) -> void:
	append_to_local_chat_log("%s: %s" % [ author, message ])


func append_to_local_chat_log(line : String) -> void:
	chat_log += line + '\n'


func clear_local_chat_log() -> void:
	chat_log = ""

## tries to determine probable address by witch a server running on this
## machine could be reached, usually by making a call to an external
## HTTP service that will check where request came from
func fetch_external_address_guess() -> String:
	var request = HTTPRequest.new()
	add_child(request)
	var url = CFG.FETCH_EXTERNAL_IP_GET_URL
	request.request(url)
	var results = await request.request_completed
	# results = [_result, _response_code, _headers, body]
	var external_address = results[3].get_string_from_utf8();
	remove_child(request)
	request.queue_free()
	print("external address from '", url, "' is : ", external_address)
	return external_address

