#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <multicolors>

#pragma newdecls required

static const char entityList[][] = { "_firesmoke", "ai_network", "color_correction", "env_entity_igniter", "env_explosion", "env_fade", \
									"env_fire", "env_hudhint", "env_physexplosion", "env_shake", "env_sound", "env_soundscape_triggerable", \
									"env_sprite", "env_sun", "env_tonemap_controller", "filter_activator_name", "filter_activator_team", \
									"filter_damage_type", "func_breakable", "func_brush", "func_bomb_target", "func_button", "func_door", \
									"func_dustmotes", "func_physbox_multiplayer", "func_buyzone", "holiday_gift", "info_overlay", \
									"info_particle_system", "info_player_counterterrorist", "info_player_terrorist", "info_target", \
									"info_teleport_destination", "infodecal", "item_assaultsuit", "item_defuser", "item_kevlar", \
									"light", "light_environment", "light_spot", "move_rope", "path_track", "planted_c4", \
									"point_viewcontrol", "shadow_control", "simple_bot", "soundent", "spraycan", \
									"trigger_soundscape", "vgui_screen", "worldspawn"};

bool bEnabled[MAXPLAYERS + 1],
	bBind[MAXPLAYERS + 1],
	bHolding[MAXPLAYERS + 1],
	bDontRenderFire[MAXPLAYERS + 1];
	
int iDistance[MAXPLAYERS + 1],
	iFlameEntity = -1;
	
Handle hCookieEnabled,
	hCookieBind,
	hCookieDistance,
	hCookieRenderFire,
	hSDkCall;

public Plugin myinfo = 
{
	name = "Render Distance Control",
	author = "null138 & (ty ZombieFeyk)",
	description = "Sets entities render distance and etc for players",
	version = "3.0.1",
	url = "https://steamcommunity.com/id/null138/"
}

public void OnPluginStart()
{
	Handle gameData = LoadGameConfigFile("render_distance.games");
	if(!gameData) 
	{
		SetFailState("Failed to load gamedata \"render_distance.games.txt\"");
	}

	LoadTranslations("renderdistance.phrases.txt");
	LoadTranslations("clientprefs.phrases.txt");
	
	StartPrepSDKCall(SDKCall_EntityList);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CGlobalEntityList::FindEntityInSphere()");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	hSDkCall = EndPrepSDKCall();
	delete gameData;

	RegConsoleCmd("sm_renderdistance", cmdRenderDistance);
	RegConsoleCmd("sm_render", cmdRenderDistance);
	RegConsoleCmd("+renderdistance", cmdBind);
	RegConsoleCmd("-renderdistance", cmdBind);

	hCookieEnabled = RegClientCookie("rendist_enabled", "Render Enable", CookieAccess_Public);
	hCookieBind = RegClientCookie("rendist_bind", "Render Bind Mode", CookieAccess_Public);
	hCookieDistance = RegClientCookie("rendist_distance", "Render Distance", CookieAccess_Public);
	hCookieRenderFire = RegClientCookie("rendist_renderfire", "Render Fire", CookieAccess_Public);

	SetCookieMenuItem(ShowRenderCookieHandler, 0, "Show Render Distance Settings");
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

public void ShowRenderCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
			ShowRenderMenu(client);
	}
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

	// Auto enable/disable if using bind
	if (bHolding[client] != bEnabled[client])
		bEnabled[client] = bHolding[client];

	char sEnabled[32], sDisabled[32];
	FormatEx(sEnabled, sizeof(sEnabled), "{green}%T{default}", "Enabled", client);
	FormatEx(sDisabled, sizeof(sDisabled), "{red}%T{default}", "Disabled", client);
	CPrintToChat(client, "[%T] %s", "Render Distance", client, bHolding[client] ? sEnabled : sDisabled);
	
	return Plugin_Handled;
}
	
void ShowRenderMenu(int client)
{
	Menu menu = new Menu(MenuHandlerRender);

	menu.SetTitle("Render Distance Control");
	menu.SetTitle("[%T] %T", "Render Distance", client, "Client Settings", client);
	
	char buffer[24];

	FormatEx(buffer, sizeof(buffer), "%T [%s]", "Enabled", client, bEnabled[client] ? "X" : "-");
	menu.AddItem("1", buffer);

	FormatEx(buffer, sizeof(buffer), "%T [%s]", "Bind Mode", client, bBind[client] ? "X" : "-");
	menu.AddItem("2", buffer);

	FormatEx(buffer, sizeof(buffer), "%T [%s]", "Dont Render Fire", client, bDontRenderFire[client] ? "X" : "-");
	menu.AddItem("3", buffer);

	FormatEx(buffer, sizeof(buffer), "%T: %d", "Distance", client, iDistance[client]);
	menu.AddItem("4", buffer);

	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowDistanceMenu(int client)
{
	Menu menu = new Menu(MenuHandlerDistance);

	char buffer[24];
	FormatEx(buffer, 24, "Distance: %d", iDistance[client]);
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

	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandlerRender(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Select)
	{
		choice++;
		char sEnabled[32], sDisabled[32];
		FormatEx(sEnabled, sizeof(sEnabled), "{green}%T{default}", "Enabled", client);
		FormatEx(sDisabled, sizeof(sDisabled), "{red}%T{default}", "Disabled", client);
		
		switch(choice)
		{
			case 1:
			{
				bEnabled[client] = !bEnabled[client];
				CPrintToChat(client, "%T %s", "Render Distance", client, bEnabled[client] ? sEnabled : sDisabled);
				SetClientCookie(client, hCookieEnabled, bEnabled[client] ? "1" : "0");
			}
			case 2:
			{
				bBind[client] = !bBind[client];
				char sBindUsage[64], sUsageText[96];
				FormatEx(sBindUsage, sizeof(sBindUsage), "%T", "Bind Usage", client);
				FormatEx(sUsageText, sizeof(sUsageText), "%s %s", sEnabled, sBindUsage);
				CPrintToChat(client, "%T: %s", "Bind Mode", client, bBind[client] ? sUsageText : sDisabled);
				SetClientCookie(client, hCookieBind, bBind[client] ? "1" : "0");
			}
			case 3:
			{
				bDontRenderFire[client] = !bDontRenderFire[client];
				CPrintToChat(client, "%T: %s", "Dont Render Fire", client, bDontRenderFire[client] ? sEnabled : sDisabled);
				SetClientCookie(client, hCookieRenderFire, bDontRenderFire[client] ? "1" : "0");
			}
			case 4:
			{
				ShowDistanceMenu(client);
			}
		}
		if (choice != 4)
			ShowRenderMenu(client);
	}
	if (action == MenuAction_End)
	{
		menu.Close();
	}

	return 0;
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

	return 0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	bool hook = false;

	if (!strcmp(classname, "entityflame"))
	{
		iFlameEntity = EntIndexToEntRef(entity);
		hook = true;
	}
	else if (!strncmp(classname, "prop_", 5))
	{
		hook = true;
	}
	else
	{
		for(int i; i < sizeof(entityList); i++)
		{
			if(!strcmp(classname, entityList[i]))
			{
				hook = true;
				break;
			}
		}
	}

	if (hook)
		SDKHook(entity, SDKHook_SetTransmit, DoTransmit);
}

public Action DoTransmit(int entity, int client)
{
	if (bDontRenderFire[client] && entity == EntRefToEntIndex(iFlameEntity))
		return Plugin_Handled;
	
	if (IsFakeClient(client) || !bEnabled[client] || (bBind[client] && !bHolding[client]))
		return Plugin_Continue;
	
	if (GetEdictFlags(entity) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(entity, (GetEdictFlags(entity) ^ FL_EDICT_ALWAYS));
	}
	
	static float vec[3];
	GetClientAbsOrigin(client, vec);
	
	int i = -1;
	while ((i = FindEntityInSphere(i, vec, float(iDistance[client]))) != -1) 
	{
		if (entity == i)
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