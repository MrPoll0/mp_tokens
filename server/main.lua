ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local tokens = nil
local whitelists = nil

MySQL.ready(function()
	local sqlTasks = {}

    table.insert(sqlTasks, function(callback)        
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS `mp_tokens` (
              `ID` int(11) NOT NULL AUTO_INCREMENT,
			  `identifier` varchar(50) NOT NULL DEFAULT '',
			  `token` varchar(50) NOT NULL,
			  `assigned` varchar(50) NULL,
			  `date` varchar(50) NOT NULL,
			  PRIMARY KEY (`identifier`)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {
        	
            callback(true)
        }, function(rowsChanged)
            ESX.Trace("Refreshed tokens in database.")
        end)
    end)

    -- ALTER TABLE `users` ADD COLUMN `tokens` INT(11) NULL DEFAULT '1';
    
    Async.parallel(sqlTasks, function(responses)
            
    end)

    MySQL.Async.fetchAll(
		'SELECT * FROM mp_tokens',
		{},
		function(result)
			tokens = result
		end
	)

	MySQL.Async.fetchAll(
		'SELECT * FROM user_whitelist',
		{},
		function(result)
			whitelists = result
		end
	)
end)

RegisterServerEvent('mp:invite')
AddEventHandler('mp:invite', function()
	local _source = source
	local player = ESX.GetPlayerFromId(_source)

	if player then 
		local date = os.date("%c",os.time())
		local sql = [[INSERT INTO mp_tokens (identifier, token, date) VALUES (@identifier, @token, @date)]]

		MySQL.Async.execute(sql, {
		    ["@identifier"] = player.identifier,
		    ["@token"] = RandomVariable(15),
		    ["@date"] = date,
		}, function(rowsChanged)
		 	if rowsChanged > 0 then 
		 		local sql = [[SELECT * from users WHERE identifier = @identifier]]

				MySQL.Async.fetchAll(sql, {
			    	["@identifier"] = player.identifier
			    }, function(response)
			    	if response and response[1] then 
						if response[1].identifier == player.identifier then
							local sql = [[UPDATE users SET tokens = @tokens WHERE identifier = @identifier]]

					 		MySQL.Async.execute(sql, {
							    ["@identifier"] = player.identifier,
							    ["@tokens"] = response[1].tokens-1,
							}, function(rowsChanged2)
							 	if rowsChanged2 > 0 then 
									TriggerClientEvent('esx:showNotification', _source, 'La invitación se ha creado con éxito.')
									updateTokens()
								else
									TriggerClientEvent('esx:showNotification', _source, 'Ha ocurrido un error con la base de datos. [4]')
								end
							end)
						end
					else
						TriggerClientEvent('esx:showNotification', _source, 'Ha ocurrido un error con la base de datos. [3]')
					end
				end)
		   	else
		   		TriggerClientEvent('esx:showNotification', _source, 'Ha ocurrido un error con la base de datos. [2]')
		   	end
		end)
	else
		TriggerClientEvent('esx:showNotification', _source, 'Ha ocurrido un error inesperado. [1]')
	end
end)

RegisterServerEvent('mp:delete')
AddEventHandler('mp:delete', function(token)
	local _source = source
	local player = ESX.GetPlayerFromId(_source)

	if player and token then 
		local sql = [[DELETE FROM mp_tokens WHERE identifier = @identifier and token = @token]]

		MySQL.Async.execute(sql, {
		    ["@identifier"] = player.identifier,
		    ["@token"] = token
		}, function(rowsChanged)
		  	if rowsChanged > 0 then 

		  		local sql = [[SELECT * from users WHERE identifier = @identifier]]

				MySQL.Async.fetchAll(sql, {
			    	["@identifier"] = player.identifier
			    }, function(response)
			    	if response and response[1] then 
						if response[1].identifier == player.identifier then
							local sql = [[UPDATE users SET tokens = @tokens WHERE identifier = @identifier]]

							MySQL.Async.execute(sql, {
								["@identifier"] = player.identifier,
								["@tokens"] = response[1].tokens+1,
							}, function(rowsChanged2)
								if rowsChanged2 > 0 then 
									TriggerClientEvent('esx:showNotification', _source, 'La invitación se ha revocado con éxito.')
									updateTokens()
								else
									TriggerClientEvent('esx:showNotification', _source, 'Ha ocurrido un error con la base de datos. [4]')
								end
							end)
						end
					else
						TriggerClientEvent('esx:showNotification', _source, 'Ha ocurrido un error con la base de datos. [3]')
					end
				end)
		   	else
		   		TriggerClientEvent('esx:showNotification', _source, 'Ha ocurrido un error con la base de datos. [2]')
		   	end
		end)
	else
		TriggerClientEvent('esx:showNotification', _source, 'Ha ocurrido un error inesperado. [1]')
	end
end)

ESX.RegisterServerCallback('mp:checkInvite', function(source, cb)
	local _source = source
	local player = ESX.GetPlayerFromId(_source)

	local sql = [[SELECT * from mp_tokens WHERE identifier = @identifier]]

	MySQL.Async.fetchAll(sql, {
    	["@identifier"] = player.identifier
    }, function(response)
    	local tokens = {}

    	if response and response[1] then 
			if response[1].identifier == player.identifier then
				if #response > 1 then 
					for i=1, #response do 
						table.insert(tokens, response[i].token)
					end
					cb(true, tokens)
				else
					cb(true, response[1].token)
				end
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)
end)

ESX.RegisterServerCallback('mp:checkTokens', function(source, cb)
	local _source = source
	local player = ESX.GetPlayerFromId(_source)

	local sql = [[SELECT * from users WHERE identifier = @identifier]]

	MySQL.Async.fetchAll(sql, {
    	["@identifier"] = player.identifier
    }, function(response)
    	if response and response[1] then 
			if response[1].identifier == player.identifier then
				cb(response[1].tokens)
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)
end)

function isWhitelisted(license)
	for i,v in pairs(whitelists) do
		if v.identifier == tostring(license) then
			if v.active >= 1 then
				return true
			end
		end
	end
	return false
end

Slice = function(str, from, to)
	if str then
		if type(str) ~= "string" then str = tostring(str) end
		if from and to then
			if type(from) == "number" and type(to) == "number" then
				return string.sub(str, from, to)
			end	
		elseif from then
			if type(from) == "number" then
				return string.sub(str, from)
			end	
		else
			return str
		end
	end

	return ""
end

Find = function(str, input)
	if str and input then
		if type(str) ~= "string" then str = tostring(str) end
		if type(input) ~= "string" then str = tostring(input) end
		local a,b = string.find(str, input)
		if a ~= nil then return a,b end
	end

	return 0,0
end

function RandomVariable(length)
	local res = ""
	for i = 1, length do
		res = res .. string.char(math.random(50, 122))
	end
	return res
end

updateTokens = function()
	MySQL.Async.fetchAll(
	'SELECT * FROM mp_tokens',
	{},
	function(result)
		tokens = result
	end)

	MySQL.Async.fetchAll(
	'SELECT * FROM user_whitelist',
	{},
	function(result)
		whitelists = result
	end)

	print("[mp_tokens] Tokens and whitelist refreshed")
end

Citizen.CreateThread(function()
	Citizen.Wait(25000)
	while true do
		updateTokens()
		Citizen.Wait(1800000)
	end
end)

validToken = function(identifier) 
	for k,v in pairs(tokens) do
		if v.assigned == identifier then
			if v.identifier ~= identifier then
				return true
			end
		end
	end
	return false
end

AddEventHandler('playerConnecting', function(name, skr, d) -- 76561198106802918
	local identifier = GetPlayerIdentifiers(source)[1]
	local license = GetPlayerIdentifiers(source)[2]
	local playerName = GetPlayerName(source)

	print("[mp_tokens] El identifier "..identifier.." está intentando entrar.")

	if not validToken(identifier) then
		d.defer()
		Wait(50)
		card(d, identifier, playerName, license)
	else
		local a,b = Find(identifier, 'steam')
		if b ~= 0 then
			local id = Slice(identifier, 7)
			local id64 = tonumber(id, 16)
			if not isWhitelisted(id64) then
				d.defer()
				Wait(50)
				card(d, identifier, playerName, license)
			else
				for k,v in pairs(tokens) do 
					if v.assigned == identifier then 
						if v.time == nil then 
							local sql = [[UPDATE mp_tokens SET time = @time WHERE assigned = @identifier]]

							MySQL.Async.execute(sql, {
								["@identifier"] = identifier,
								["@time"] = os.time()
							}, function(rowsChanged2)
								if rowsChanged2 > 0 then 
									updateTokens()
								else
									print("--------------- [mp_tokens] Ha ocurrido un error en la base de datos en: UPDATE TIME")
								end
							end)
						else
							local month = 30*24*60*60
							if ((os.time() - month) - v.time) > 0 then 
								local sql = [[SELECT * from users WHERE identifier = @identifier]]

								MySQL.Async.fetchAll(sql, {
									["@identifier"] = identifier
								}, function(response2)
									if response2 and response2[1] then 
										if response2[1].identifier == identifier then
											local playerTokens = response2[1].tokens
											local sql = [[UPDATE users SET tokens = @tokens WHERE identifier = @identifier]]

											MySQL.Async.execute(sql, {
												["@identifier"] = identifier,
												["@tokens"] = (playerTokens + 1)
											}, function(rowsChanged3)
												if rowsChanged3 > 0 then 
													local sql = [[UPDATE mp_tokens SET time = @time WHERE assigned = @identifier]]

													MySQL.Async.execute(sql, {
														["@identifier"] = identifier,
														["@time"] = os.time()
													}, function(rowsChanged4)
														if rowsChanged4 > 0 then 
															print("[mp_tokens] El usuario con identifier "..identifier.." ha conseguido una key por llevar un mes en el servidor.")
															updateTokens()
														else
															print("--------------- [mp_tokens] Ha ocurrido un error en la base de datos en: UPDATE TIME 2")
														end
													end)
												else
													print("--------------- [mp_tokens] Ha ocurrido un error en la base de datos en: UPDATE TOKENS")
												end
											end)
										end
									end
								end)
							end
						end
					end
				end
			end
		else
			skr("Debes tener Steam abierto para acceder al servidor.")
			print("Debes tener Steam abierto para acceder al servidor.")
			CancelEvent()
		end
	end
end)

card = function(d, identifier, playerName, license)
	d.presentCard([==[{
    "type": "AdaptiveCard",
    "body": [
        {
            "type": "Image",
            "altText": "",
            "url": "https://i.imgur.com/mPd7UrW.png",
            "horizontalAlignment": "Center"
        },
        {
            "type": "TextBlock",
            "size": "Medium",
            "weight": "Bolder",
            "text": "[MP] Sistema de invitación",
            "horizontalAlignment": "Center"
        },
        {
            "type": "ColumnSet",
            "columns": [
                {
                    "type": "Column",
                    "items": [
                        {
                            "type": "Image",
                            "style": "Person",
                            "url": "https://i.gyazo.com/8db8cc5084e84a72bfcd929b3e2b64e4.png",
                            "size": "Small"
                        }
                    ],
                    "width": "auto"
                },
                {
                    "type": "Column",
                    "items": [
                        {
				            "type": "Input.Text",
				            "placeholder": "Invitación / Key / Token",
				            "inlineAction": {
				                "type": "Action.Submit",
				                "id": "",
				                "title": "Entrar"
				            },
				            "id": "key"
				        }],
                    "width": "stretch"
                }
            ],
            "horizontalAlignment": "Center",
            "separator": true
        },
        {
            "type": "ActionSet",
            "actions": [
                {
                    "type": "Action.Submit",
                    "title": "Verificar",
                    "iconUrl": "https://i.imgur.com/fx372jp.gif",
                    "id": "verify"
                }
            ],
            "horizontalAlignment": "Center"
        },
        {
            "type": "ActionSet",
            "actions": [
                {
                    "type": "Action.OpenUrl",
                    "title": "Discord de ARKEANOS LOS SANTOS",
                    "url": "https://discord.gg/G3avpQf",
                    "iconUrl": "https://i.imgur.com/af7i4xz.png",
                    "style": "positive"
                }
            ],
            "horizontalAlignment": "Center",
            "separator": true
        },
        {
            "type": "ActionSet",
            "actions": [
                {
                    "type": "Action.OpenUrl",
                    "title": "Discord de ARKEANOS PALETO BAY",
                    "url": "https://discord.gg/WCDbF78",
                    "iconUrl": "https://i.gyazo.com/8db8cc5084e84a72bfcd929b3e2b64e4.png"
                }
            ],
            "horizontalAlignment": "Center"
        },
        {
            "type": "ActionSet",
            "actions": [
                {
                    "type": "Action.OpenUrl",
                    "title": "FORO",
                    "url": "https://www.arkeanos.com"
                }
            ],
            "horizontalAlignment": "Center"
        }
    ],
    "verticalContentAlignment": "Center",
    "version": "1.0",
    "$schema": "http://adaptivecards.io/schemas/adaptive-card.json"
}]==],
        function(data, rawData)
        	if data.key and not data.submitId or data.submitId ~= 'verify' then  

        		for k,v in pairs(tokens) do 
        			if not(v.assigned == identifier) then
			        	local sql = [[SELECT * from mp_tokens WHERE token = @token]]

						MySQL.Async.fetchAll(sql, {
					    	["@token"] = data.key
					    }, function(response)
					    	if response[1] then 
					    		if response[1].assigned == nil and response[1].identifier ~= identifier then
					    			local a,b = Find(identifier, 'steam')
									if b ~= 0 then
										local sql = [[UPDATE mp_tokens SET assigned = @identifier WHERE token = @token]]

										MySQL.Async.execute(sql, {
											["@identifier"] = identifier,
											["@token"] = data.key
										}, function(rowsChanged)
											if rowsChanged > 0 then 
												updateTokens()
												Citizen.Wait(500)
												local id = Slice(identifier, 7)
												local id64 = tonumber(id, 16)
												if not isWhitelisted(id64) then
													d.update("Se te ha asignado la key, pero no estás en la whitelist. Licencia : "..id64)
												    Citizen.Wait(5000)
												    card(d, identifier, playerName, license)
												else
													for k,v in pairs(tokens) do 
														if v.assigned == identifier then 
															if v.time == nil then 
																local sql = [[UPDATE mp_tokens SET time = @time WHERE assigned = @identifier]]

																MySQL.Async.execute(sql, {
																	["@identifier"] = identifier,
																	["@time"] = os.time()
																}, function(rowsChanged2)
																	if rowsChanged2 > 0 then 
																		updateTokens()
																		d.done()
																	else
																		print("--------------- [mp_tokens] Ha ocurrido un error en la base de datos en: UPDATE ASSIGNED")
																		d.update("Error. Vuelva a intentarlo.")
														        		Citizen.Wait(2000)
														        		card(d, identifier, playerName, license)
																	end
																end)
															else
																local month = 30*24*60*60
																if ((os.time() - mont) - v.time) > 0 then 
																	local sql = [[SELECT * from users WHERE identifier = @identifier]]

																	MySQL.Async.fetchAll(sql, {
																    	["@identifier"] = identifier
																    }, function(response2)
																    	if response2 and response2[1] then 
																			if response2[1].identifier == identifier then
																				local playerTokens = response2[1].tokens

																				local sql = [[UPDATE users SET tokens = @tokens WHERE identifier = @identifier]]

																				MySQL.Async.execute(sql, {
																					["@identifier"] = identifier,
																					["@tokens"] = (playerTokens + 1)
																				}, function(rowsChanged3)
																					if rowsChanged3 > 0 then 
																						local sql = [[UPDATE mp_tokens SET time = @time WHERE assigned = @identifier]]

																						MySQL.Async.execute(sql, {
																							["@identifier"] = identifier,
																							["@time"] = os.time()
																						}, function(rowsChanged4)
																							if rowsChanged4 > 0 then 
																								print("[mp_tokens] El usuario con identifier "..identifier.." ha conseguido una key por llevar un mes en el servidor.")
																								updateTokens()
																								d.done()
																							else
																								print("--------------- [mp_tokens] Ha ocurrido un error en la base de datos en: UPDATE ASSIGNED")
																								d.update("Error. Vuelva a intentarlo.")
																				        		Citizen.Wait(2000)
																				        		card(d, identifier, playerName, license)
																							end
																						end)
																					else
																						print("--------------- [mp_tokens] Ha ocurrido un error en la base de datos en: UPDATE ASSIGNED")
																						d.update("Error. Vuelva a intentarlo.")
																		        		Citizen.Wait(2000)
																		        		card(d, identifier, playerName, license)
																					end
																				end)
																			end
																		end
																	end)
																else
																	d.done()
																end
															end
														end
													end
												end
											else
												print("--------------- [mp_tokens] Ha ocurrido un error en la base de datos en: UPDATE ASSIGNED")
												d.update("Error. Vuelva a intentarlo.")
											    Citizen.Wait(2000)
											    card(d, identifier, playerName, license)
											end
										end)
									else
										d.update("Debes tener Steam abierto para acceder al servidor.")
										print("Debes tener Steam abierto para acceder al servidor.")
										Citizen.Wait(2000)
										card(d, identifier, playerName, license)
									end
					    		else
					    			d.update("Key no válida.")
						        	Citizen.Wait(2000)
						        	card(d, identifier, playerName, license)
					    		end
							else
								d.update("Key incorrecta.")
						        Citizen.Wait(2000)
						        card(d, identifier, playerName, license)
							end
						end)
					else
						d.update("Ya tienes una key asignada.")
						Citizen.Wait(2000)
						card(d, identifier, playerName, license)
						break
					end
				end
			elseif data.submitId == 'verify' then 
				local inWhitelist = 'No'
				local haveKey = 'No'
				local sql = [[SELECT * from mp_tokens WHERE assigned = @identifier]] 

				MySQL.Async.fetchAll(sql, {
			    	["@identifier"] = identifier
			    }, function(response)
			    	if response[1] then 
			    		if response[1].identifier ~= identifier then
			    			haveKey =  response[1].token..' --> '..identifier
			    		end
					end
					local id64 
					local a,b = Find(identifier, 'steam')
					if b ~= 0 then
						local id = Slice(identifier, 7)
						id64 = tonumber(id, 16)
						if isWhitelisted(id64) then
							inWhitelist = 'Sí'
						end
					end
					d.update("\n\nUSUARIO: "..playerName.."\nSTEAM: "..identifier.."\nLICENCIA: "..license.."\nID64: "..id64.."\n\nKEY: "..haveKey.."\nWHITELIST: "..inWhitelist)
			        Citizen.Wait(15000)
			        card(d, identifier, playerName, license)
				end)
			else
				d.update("No has introducido ninguna key.")
		        Citizen.Wait(2000)
		        card(d, identifier, playerName, license)
			end
        end)
end

RegisterCommand("refreshMP", function(source, args, rawCommand)
    if not (source > 0) then
    	updateTokens()
    end
end, false)

TriggerEvent('es:addCommand', 'addwhitelist',  function(source, args, user)
	local source = source
	local license = args[1]
	local xPlayer = ESX.GetPlayerFromId(source)
	local permission = xPlayer.getPermissions()
	if permission >= 1 then
		if string.match(license, "7") then
			if #license == 17 then
				MySQL.Async.execute("INSERT INTO user_whitelist (`identifier`) VALUES (@identifier)",
							{identifier = license})
				print("Excelente bro")
			else
				print("Lo siento pero la longitud no es la correta :v")
			end
		else
			print("Ese no es el formato correcto.")
		end
	end
end, {help = "Añadir a la whitelist", params = {{name = "ID", help = "ID del jugador"}}})