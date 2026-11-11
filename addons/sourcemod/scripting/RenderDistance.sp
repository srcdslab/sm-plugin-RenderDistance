#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <multicolors>

#pragma newdecls required

// SolidType_t and SolidFlags_t values from the SDK (public/const.h)
#define SOLID_NONE 0
#define SOLID_BBOX 2
#define FSOLID_FORCE_WORLD_ALIGNED 0x0040

static const char entityList[][] = { "env_entity_igniter", "env_explosion", "env_fade", "env_fire", "env_hudhint", \
									"env_physexplosion", "env_sprite", "env_sun", \
									"func_breakable", "func_brush", "func_bomb_target", "func_button", "func_door", \
									"func_dustmotes", "func_physbox_multiplayer", "info_overlay", "info_particle_system", \
									"info_player_counterterrorist", "info_player_terrorist", "infodecal", \
									"item_assaultsuit", "item_defuser", "item_kevlar", \
									"light", "light_environment", "light_spot", "move_rope", "path_track", "planted_c4", \
									"point_viewcontrol", "shadow_control", "vgui_screen", "worldspawn"};

bool bEnabled[MAXPLAYERS + 1],
	bBind[MAXPLAYERS + 1],
	bHolding[MAXPLAYERS + 1],
	bDontRenderFire[MAXPLAYERS + 1];
	
int iDistance[MAXPLAYERS + 1],
	iFlameEntity = -1;
	
Cookie hCookieEnabled,
	hCookieBind,
	hCookieDistance,
	hCookieRenderFire;

// entityList as a set, filled once: OnEntityCreated runs for every entity
StringMap g_smEntityList;

public Plugin myinfo = 
{
	name = "Render Distance Control",
	author = "null138 & (ty ZombieFeyk)",
	description = "Sets entities render distance and etc for players",
	version = "3.0.6",
	url = "https://steamcommunity.com/id/null138/"
}

public void OnPluginStart()
{
	LoadTranslations("renderdistance.phrases.txt");
	LoadTranslations("clientprefs.phrases.txt");

	g_smEntityList = new StringMap();
	for (int i = 0; i < sizeof(entityList); i++)
		g_smEntityList.SetValue(entityList[i], true);

	RegConsoleCmd("sm_renderdistance", cmdRenderDistance);
	RegConsoleCmd("sm_render", cmdRenderDistance);
	RegConsoleCmd("+renderdistance", cmdBind);
	RegConsoleCmd("-renderdistance", cmdBind);

	hCookieEnabled = new Cookie("rendist_enabled", "Render Enable", CookieAccess_Public);
	hCookieBind = new Cookie("rendist_bind", "Render Bind Mode", CookieAccess_Public);
	hCookieDistance = new Cookie("rendist_distance", "Render Distance", CookieAccess_Public);
	hCookieRenderFire = new Cookie("rendist_renderfire", "Render Fire", CookieAccess_Public);

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

	hCookieEnabled.Get(client, buffer, 4);
	bEnabled[client] = view_as<bool>(StringToInt(buffer));

	hCookieBind.Get(client, buffer, 4);
	bBind[client] = view_as<bool>(StringToInt(buffer));

	hCookieDistance.Get(client, buffer, 4);
	iDistance[client] = StringToInt(buffer) < 800 ? 800 : StringToInt(buffer);

	hCookieRenderFire.Get(client, buffer, 4);
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

	char sEnabled[64], sDisabled[64];
	FormatEx(sEnabled, sizeof(sEnabled), "{green}%T{default}", "Enabled", client);
	FormatEx(sDisabled, sizeof(sDisabled), "{red}%T{default}", "Disabled", client);
	CPrintToChat(client, "[%T] %s", "Render Distance", client, bHolding[client] ? sEnabled : sDisabled);
	
	return Plugin_Handled;
}
	
void ShowRenderMenu(int client)
{
	Menu menu = new Menu(MenuHandlerRender);

	menu.SetTitle("[%T] %T", "Render Distance", client, "Client Settings", client);
	
	char buffer[64];

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

	char buffer[64];
	FormatEx(buffer, sizeof(buffer), "%T: %d", "Distance", client, iDistance[client]);
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
		char sEnabled[64], sDisabled[64];
		FormatEx(sEnabled, sizeof(sEnabled), "{green}%T{default}", "Enabled", client);
		FormatEx(sDisabled, sizeof(sDisabled), "{red}%T{default}", "Disabled", client);
		
		switch(choice)
		{
			case 1:
			{
				bEnabled[client] = !bEnabled[client];
				CPrintToChat(client, "%T %s", "Render Distance", client, bEnabled[client] ? sEnabled : sDisabled);
				hCookieEnabled.Set(client, bEnabled[client] ? "1" : "0");
			}
			case 2:
			{
				bBind[client] = !bBind[client];
				char sBindUsage[64], sUsageText[96];
				FormatEx(sBindUsage, sizeof(sBindUsage), "%T", "Bind Usage", client);
				FormatEx(sUsageText, sizeof(sUsageText), "%s %s", sEnabled, sBindUsage);
				CPrintToChat(client, "%T: %s", "Bind Mode", client, bBind[client] ? sUsageText : sDisabled);
				hCookieBind.Set(client, bBind[client] ? "1" : "0");
			}
			case 3:
			{
				bDontRenderFire[client] = !bDontRenderFire[client];
				CPrintToChat(client, "%T: %s", "Dont Render Fire", client, bDontRenderFire[client] ? sEnabled : sDisabled);
				hCookieRenderFire.Set(client, bDontRenderFire[client] ? "1" : "0");
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
			hCookieDistance.Set(client, value);
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
		bool bListed;
		hook = g_smEntityList.GetValue(classname, bListed);
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

	return IsEntityInSphere(entity, vec, float(iDistance[client])) ? Plugin_Continue : Plugin_Handled;
}

// The test CGlobalEntityList::FindEntityInSphere() runs on each entity, run on this entity only.
// Looping over FindEntityInSphere() until it returned this entity walked the whole entity list
// for every entity and every client, on every tick.
// The sphere center goes into the entity collision space (CCollisionProperty::WorldToCollisionSpace),
// then gets tested against the entity bounds (IsBoxIntersectingSphere).
static bool IsEntityInSphere(int entity, const float vecCenter[3], float radius)
{
	float vecOrigin[3], vecMins[3], vecMaxs[3], vecRel[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecOrigin);
	GetEntPropVector(entity, Prop_Send, "m_vecMins", vecMins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vecMaxs);
	SubtractVectors(vecCenter, vecOrigin, vecRel);

	// The bounds turn with the entity, unless they are world aligned (CCollisionProperty::IsBoundsDefinedInEntitySpace)
	int iSolidType = GetEntProp(entity, Prop_Send, "m_nSolidType");
	if (iSolidType != SOLID_NONE && iSolidType != SOLID_BBOX && !(GetEntProp(entity, Prop_Send, "m_usSolidFlags") & FSOLID_FORCE_WORLD_ALIGNED))
	{
		float vecAngles[3];
		GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", vecAngles);

		if (vecAngles[0] != 0.0 || vecAngles[1] != 0.0 || vecAngles[2] != 0.0)
		{
			float vecFwd[3], vecRight[3], vecUp[3], vecWorld[3];
			GetAngleVectors(vecAngles, vecFwd, vecRight, vecUp);
			vecWorld = vecRel;

			// Inverse rotation: the matrix columns are forward, left (-right) and up
			vecRel[0] = GetVectorDotProduct(vecWorld, vecFwd);
			vecRel[1] = -GetVectorDotProduct(vecWorld, vecRight);
			vecRel[2] = GetVectorDotProduct(vecWorld, vecUp);
		}
	}

	float fDistSq = 0.0;
	for (int i = 0; i < 3; i++)
	{
		float fDelta;
		if (vecRel[i] < vecMins[i])
			fDelta = vecRel[i] - vecMins[i];
		else if (vecRel[i] > vecMaxs[i])
			fDelta = vecMaxs[i] - vecRel[i];
		else
			continue;

		fDistSq += fDelta * fDelta;
	}

	return fDistSq < radius * radius;
}
