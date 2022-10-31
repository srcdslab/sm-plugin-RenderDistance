#pragma semicolon 1

#define PLUGIN_AUTHOR "null138 & (ty ZombieFeyk)"
#define PLUGIN_VERSION "3.00"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#pragma newdecls required

static const char entityList[][] = { "ambient_generic", "color_correction", "env_entity_igniter", "env_fade", "point_viewcontrol", \
									"env_hudhint", "env_physexplosion", "env_shake", "filter_activator_name", "filter_activator_team", \
									"filter_damage_type", "func_buyzone", "func_button", "game_score", "info_player_counterterrorist", \
									"info_player_terrorist", "info_teleport_destination", "path_track", "player_speedmod", "soundent", \
									"point_clientcommand", "point_servercommand", "point_teleport", "worldspawn", "ai_network", "light", \
									"simple_bot", "holiday_gift", "vgui_screen", "info_target", "infodecal", "move_rope", "env_sun", \
									"spraycan", "light_spot", "shadow_control", "item_assaultsuit", "func_bomb_target", "env_fire", \
									"point_viewcontrol", "func_dustmotes", "env_soundscape_triggerable", "trigger_soundscape", \
									"func_physbox_multiplayer", "env_tonemap_controller", "logic_auto", "_firesmoke", "item_kevlar", \
									"planted_c4", "item_defuser", "env_sprite", "func_breakable", "light_environment", "func_brush", \
									"env_explosion", "func_door", "info_overlay", "info_particle_system"};

bool 
	bEnabled[MAXPLAYERS + 1],
	bBind[MAXPLAYERS + 1],
	bHolding[MAXPLAYERS + 1],
	bDontRenderFire[MAXPLAYERS + 1];
	
int 
	iDistance[MAXPLAYERS + 1],
	iFlameEntity = -1;
	
Handle 
	hCookieEnabled,
	hCookieBind,
	hCookieDistance,
	hCookieRenderFire,
	hSDkCall;

public Plugin myinfo = 
{
	name = "Render Distance Control",
	author = PLUGIN_AUTHOR,
	description = "Sets entities render distance and etc for players",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
}

public void OnPluginStart()
{
	Handle gameData = LoadGameConfigFile("render_distance.games");
	if(!gameData) 
	{
		SetFailState("Failed to load gamedata \"render_distance.games.txt\"");
	}
	
	StartPrepSDKCall(SDKCall_EntityList);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CGlobalEntityList::FindEntityInSphere()");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	hSDkCall = EndPrepSDKCall();
	delete gameData;
	
	RegConsoleCmd("sm_renderdistance", cmdRenderDistance);
	RegConsoleCmd("+renderdistance", cmdBind);
	RegConsoleCmd("-renderdistance", cmdBind);
	
	hCookieEnabled = RegClientCookie("rendist_enabled", "Render Enable", CookieAccess_Public);
	hCookieBind = RegClientCookie("rendist_bind", "Render Bind Mode", CookieAccess_Public);
	hCookieDistance = RegClientCookie("rendist_distance", "Render Distance", CookieAccess_Public);
	hCookieRenderFire = RegClientCookie("rendist_renderfire", "Render Fire", CookieAccess_Public);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	bEnabled[client] = false;
	bBind[client] = false;
	bHolding[client] = false;
	bDontRenderFire[client] = false;
	iDistance[client] = 800;
}

public void OnClientCookiesCached(int client)
{
	char buffer[4];
	
	GetClientCookie(client, hCookieEnabled, buffer, 4);
	bEnabled[client] = view_as<bool>(StringToInt(buffer));
	
	GetClientCookie(client, hCookieBind, buffer, 4);
	bBind[client] = view_as<bool>(StringToInt(buffer));
	
	GetClientCookie(client, hCookieDistance, buffer, 4);
	iDistance[client] = StringToInt(buffer) < 800 ? 800 : StringToInt(buffer);
	
	GetClientCookie(client, hCookieRenderFire, buffer, 4);
	bDontRenderFire[client] = view_as<bool>(StringToInt(buffer));
}

public Action cmdRenderDistance(int client, int args)
{
	ShowRenderMenu(client);
	
	return Plugin_Handled;
}

public Action cmdBind(int client, int args)
{
	char prefix[4];
	GetCmdArg(0, prefix, 4);
	bHolding[client] = prefix[0] == '+';
	
	return Plugin_Handled;
}
	
void ShowRenderMenu(int client)
{
	Menu menu = new Menu(MenuHandlerRender);

	menu.SetTitle("Render Distance Control");
	
	char buffer[24];
	bEnabled[client] ? Format(buffer, 24, "Enable [X]") : Format(buffer, 24, "Enable [-]");
	menu.AddItem("1", buffer);
	bBind[client] ? Format(buffer, 24, "Bind Mode [X]") : Format(buffer, 24, "Bind Mode [-]");
	menu.AddItem("2", buffer);
	bDontRenderFire[client] ? Format(buffer, 24, "Dont Render Fire [X]") : Format(buffer, 24, "Dont Render Fire [-]");
	menu.AddItem("3", buffer);
	Format(buffer, 24, "Distance: %d", iDistance[client]);
	menu.AddItem("4", buffer);

	menu.Display(client, 15);
}

void ShowDistanceMenu(int client)
{
	Menu menu = new Menu(MenuHandlerDistance);

	char buffer[24];
	Format(buffer, 24, "Distance: %d", iDistance[client]);
	menu.SetTitle(buffer);

	menu.AddItem("800", "800");
	menu.AddItem("1200", "1200");
	menu.AddItem("1600", "1600");
	menu.AddItem("2000", "2000");
	menu.AddItem("2400", "2400");
	menu.AddItem("2800", "2800");
	menu.AddItem("3200", "3200");
	menu.AddItem("3600", "3600");
	menu.AddItem("4000", "4000");

	menu.Display(client, 15);
}

int MenuHandlerRender(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Select)
	{
		choice++;
		switch(choice)
		{
			case 1:
			{
				bEnabled[client] = !bEnabled[client];
				PrintToChat(client, "\x03 Render Distance %sabled", bEnabled[client] ? "en" : "dis");
				SetClientCookie(client, hCookieEnabled, bEnabled[client] ? "1" : "0");
			}
			case 2:
			{
				bBind[client] = !bBind[client];
				PrintToChat(client, "\x03 Bind Mode %s", bBind[client] ? "enabled\n Do \"bind <command> +renderdistance\"" : "disabled");
				SetClientCookie(client, hCookieBind, bBind[client] ? "1" : "0");
			}
			case 3:
			{
				bDontRenderFire[client] = !bDontRenderFire[client];
				PrintToChat(client, "\x03 Rendering Fire %sabled", bDontRenderFire[client] ? "en" : "dis");
				SetClientCookie(client, hCookieRenderFire, bDontRenderFire[client] ? "1" : "0");
			}
			case 4:
			{
				ShowDistanceMenu(client);
			}
		}
		if(choice != 4) ShowRenderMenu(client);
	}
	if(action == MenuAction_End)
	{
		menu.Close();
	}
}

int MenuHandlerDistance(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char menuItem[6];
			menu.GetItem(choice, menuItem, sizeof(menuItem));
		
			iDistance[client] = StringToInt(menuItem);
			ShowDistanceMenu(client);
			char value[6];
			FormatEx(value, sizeof(value), "%d", iDistance[client]);
			SetClientCookie(client, hCookieDistance, value);
		}
		case MenuAction_Cancel:
		{
			ShowRenderMenu(client);
		}
		case MenuAction_End:
		{
			menu.Close();
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	bool hook;
	if(!strcmp(classname, "entityflame"))
	{
		iFlameEntity = EntIndexToEntRef(entity);
		hook = true;
	}
	else if(!strncmp(classname, "prop_", 5)) hook = true;
	else for(int i; i < sizeof(entityList); i++) if(!strcmp(classname, entityList[i]))
	{
		hook = true;
		break;
	}

	if(hook) SDKHook(entity, SDKHook_SetTransmit, DoTransmit);
}

public Action DoTransmit(int entity, int client)
{
	if(bDontRenderFire[client] && entity == EntRefToEntIndex(iFlameEntity)) return Plugin_Handled;
	
	if(IsFakeClient(client) || !bEnabled[client] || (bBind[client] && !bHolding[client])) return Plugin_Continue;
	
	if(GetEdictFlags(entity) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(entity, (GetEdictFlags(entity) ^ FL_EDICT_ALWAYS));
	}
	
	static float vec[3];
	GetClientAbsOrigin(client, vec);
	
	int i = -1;
	while((i = FindEntityInSphere(i, vec, float(iDistance[client]))) != -1) 
	{
		if(entity == i)
		{
			return Plugin_Continue;
		}
	}

	return Plugin_Handled;
}

static int FindEntityInSphere(int entity, const float vecCenter[3], float radius)
{
	return SDKCall(hSDkCall, entity, vecCenter, radius);
}