MP = {}
ESX = nil
ESXLoaded = false

Citizen.CreateThread(function ()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end

    while ESX.GetPlayerData().job == nil do
		Citizen.Wait(10)
	end

    ESXLoaded = true
end)

Citizen.CreateThread(function()
	TriggerEvent('chat:addSuggestion', '/invitar', 'Abrir el menú de invitaciones.')
end)

RegisterCommand("invitar", function(source, args, rawCommand)
    MP.OpenMenu()
end, false)

MP.OpenMenu = function()
	local elements = {}

	table.insert(elements, {
		label = "Crear invitación",
		value = "invite"
	})

	table.insert(elements, {
		label = "Invitaciones creadas",
		value = "others"
	})

	ESX.UI.Menu.CloseAll()
	MP.checkTokens(function(tokens)
		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'invitation_menu',
			{
				title  = 'Invitaciones - '..tokens..' restantes',
				align    = 'right',
				elements = elements
			},
			function(data, menu)	
				if data.current.value == "invite" then 
					if tokens > 0 then 
						TriggerServerEvent('mp:invite')
						Citizen.Wait(500)
						MP.OpenMenu()
					else
						ESX.ShowNotification('No te quedan más invitaciones.')
						MP.OpenMenu()
					end
				elseif data.current.value == "others" then 
					local elements = {}

					ESX.TriggerServerCallback('mp:checkInvite', function(hasInvite, token)
						if hasInvite == true then 

							if type(token) == "table" then
								for i=1, #token do 
									table.insert(elements, {
										label = token[i].." - <span style='color: red;'>ELIMINAR</span>",
										value = "token",
										token = token[i],
									})
								end
							else
								table.insert(elements, {
									label = token.." - <span style='color: red;'>ELIMINAR</span>",
									value = "token",
									token = token,
								})
							end

							ESX.UI.Menu.Open(
								'default', GetCurrentResourceName(), 'tokens',
								{
									title  = 'Invitaciones',
									align    = 'right',
									elements = elements
								},
								function(data2, menu2)	

									if data2.current.value == "token" then
										elements = {}

										table.insert(elements, {
											label = "<span style='color: green;'>SÍ</span>",
											value = "yes",
										})

										table.insert(elements, {
											label = "<span style='color: red;'>NO</span>",
											value = "no",
										})

										ESX.UI.Menu.Open(
											'default', GetCurrentResourceName(), 'sure',
											{
												title  = '¿Estás segur@? Si revocas esta invitación le quitarás acceso a la persona que la esté usando.',
												align    = 'right',
												elements = elements
											},
											function(data3, menu3)	

												if data3.current.value == "yes" then 
													TriggerServerEvent('mp:delete', data2.current.token)
													Citizen.Wait(500)
													MP.OpenMenu()
												elseif data3.current.value == "no" then 
													MP.OpenMenu()
												end

												menu3.close()
											end,
											function(data3, menu3)
												MP.OpenMenu()
											end
										)
									end

									menu2.close()
								end,
								function(data2, menu2)
									MP.OpenMenu()
								end
							)
						else
							ESX.ShowNotification('No tienes ninguna invitación creada.')
							MP.OpenMenu()
						end
					end)
				end

				menu.close()
			end,
			function(data, menu)
				menu.close()
			end
		)
	end)
end

MP.checkTokens = function(cb)
	ESX.TriggerServerCallback('mp:checkTokens', function(tokens)
		if tokens > 0 then 
			cb(tokens)
		else
			cb(0)
		end
	end)
end

--[[ 
MP.OpenDialog = function()
	ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'getSteamDialog',
	{
		title = "Ingrese un perfil de Steam",
	}, function(data, menu)
		local parameter = data.value

		TriggerServerEvent('mp:invite', parameter)

		menu.close()
	end, function(data, menu)
		menu.close()
	end)
end
]]