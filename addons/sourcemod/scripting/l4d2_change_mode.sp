#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>

#define PLUGIN_VERSION	"1.2.1"
#define CVAR_FLAGS		FCVAR_NOTIFY

char g_sModeName[][32] = 
{
	"重载章节", 
	"战役模式", 
	"血流不止", 
	"写实模式", 
	"特感速递", 
	"死亡之门", 
	"绝境求生", 
	"枪枪爆头", 
	"猎人派对", 
	"无法近身", 
	"感染季节", 
	"侏儒卫队", 
	"铁人意志"
};

char g_sModeCode[][32] = 
{
	"重载章节", 
	"coop", 
	"mutation3", 
	"realism", 
	"community1", 
	"community5", 
	"mutation4", 
	"mutation2", 
	"mutation16", 
	"mutation14", 
	"community2", 
	"mutation9", 
	"mutation8"
};

int    g_iChangeMode;
float  g_fChangeTime;
ConVar g_hChangeMode, g_hChangeTime;

Handle g_hGameMode;

TopMenu hTopMenu;
TopMenuObject hAddToTopMenu = INVALID_TOPMENUOBJECT;

public Plugin myinfo =
{
	name = "l4d2_change_mode", 
	author = "l4d2_change_mode", 
	description = "管理员指令!mode更改游戏模式.", 
	version = PLUGIN_VERSION, 
	url = "N/A"
};

public void OnPluginStart()
{
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
	
	RegConsoleCmd("sm_mode", MenuMode, "管理员更换游戏模式.");
	
	g_hChangeMode	= CreateConVar("l4d2_change_mode","1","启用管理员指令!mode更换游戏模式(指令!mode空格+模式代码更换其它模式)? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hChangeTime	= CreateConVar("l4d2_change_time","6.0","管理员更换模式后延迟几秒重启当前章节?", CVAR_FLAGS);

	g_hChangeMode.AddChangeHook(CvarChanged);
	g_hChangeTime.AddChangeHook(CvarChanged);

	AutoExecConfig(true, "l4d2_change_mode");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		hTopMenu = null;
}
 
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == hTopMenu)
		return;
	
	hTopMenu = topmenu;
	
	TopMenuObject objDifficultyMenu = FindTopMenuCategory(hTopMenu, "OtherFeatures");
	if (objDifficultyMenu == INVALID_TOPMENUOBJECT)
		objDifficultyMenu = AddToTopMenu(hTopMenu, "OtherFeatures", TopMenuObject_Category, AdminMenuHandler, INVALID_TOPMENUOBJECT);
	
	hAddToTopMenu= AddToTopMenu(hTopMenu,"sm_mode",TopMenuObject_Item,InfectedMenuHandler,objDifficultyMenu,"sm_mode",ADMFLAG_ROOT);
}

public void AdminMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "选择功能:", param);
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "其它功能", param);
	}
}

public void InfectedMenuHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == hAddToTopMenu)
			Format(buffer, maxlength, "更改模式", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == hAddToTopMenu)
			SetModeMenu(param, 0);
	}
}

//地图开始.
public void OnMapStart()
{
	GetCvars();
	StopTimer();
}

//地图结束.
public void OnMapEnd()
{
	StopTimer();
}

void StopTimer()
{
	delete g_hGameMode;
}

public void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iChangeMode = g_hChangeMode.IntValue;
	g_fChangeTime = g_hChangeTime.FloatValue;
}

public Action MenuMode(int client, int args)
{
	if(bCheckClientAccess(client))
		GetModeMenu(client, args);
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

void GetModeMenu(int client, int args)
{
	char gmode1[256];
	GetConVarString(FindConVar("mp_gamemode"), gmode1, sizeof(gmode1));
	
	switch (g_iChangeMode)
	{
		case 0:
		{
			PrintToChat(client, "\x05[提示]\x03更换游戏模式已禁用,请在CFG中设为1启用.");
		}
		case 1:
		{
			ShowModeMenu(client, args);
		}
	}
}

void ShowModeMenu(int client, int args)
{
	switch (args)
	{
		case 0:
		{
			SetModeMenu(client, 0);
		}
		case 1:
		{
			char g_sMode[32];
			GetCmdArgString(g_sMode, sizeof(g_sMode));

			if(strcmp(g_sMode, GetGameMode(), false) == 0)
				PrintToChat(client, "\x04[提示]\x05当前已是\x04(\x03%s\x04)\x05模式.", GetModeName());
			else
			{
				SetConVarString(FindConVar("mp_gamemode"), g_sMode);
				
				if (!StrEqual(g_sMode, GetGameMode(), false) == true)
				{
					PrintToChat(client, "\x04[模式]\x05请确认你输入的模式代码\x04[\x03%s\x04]\x05是否正确.", g_sMode);
				}
				else
				{
					if(g_hGameMode == null)
					{
						PrintToChatAll("\x04[模式]\x05游戏模式更改为\x04(\x03%s\x04)\x04,\x05将在\x03%.1f秒\x05后重启当前章节.", GetModeName(), g_fChangeTime);
						PrintHintTextToAll("[模式] 游戏模式更改为(%s),期间可能出现黑屏,请等待数秒.", GetModeName());
						g_hGameMode = CreateTimer(g_fChangeTime, DelaySetGameMode);//延迟重启当前章节
					}
					else
						PrintToChat(client, "\x04[提示]\x05当前正在更改为\x04(\x03%s\x04)\x05模式,请勿重复设置游戏模式.", GetModeName());
				}
			}
		}
	}
}

void SetModeMenu(int client, int index)
{
	char line[128], sInfo[32], sData[2][32];
	Menu menu = new Menu(Menu_HandlerMode);
	Format(line, sizeof(line), "其它模式!mode空格+模式代码.\n选择模式:(当前模式为:%s)", GetModeName());
	SetMenuTitle(menu, "%s", 	line);
	strcopy(sData[0], sizeof(sData[]), g_sModeCode[0]);
	strcopy(sData[1], sizeof(sData[]), g_sModeName[0]);
	ImplodeStrings(sData, 2, "|", sInfo, sizeof(sInfo));//打包字符串.
	menu.AddItem(sInfo, g_sModeName[0]);
	for (int i = 1; i < sizeof(g_sModeCode); i++)
	{
		strcopy(sData[0], sizeof(sData[]), g_sModeCode[i]);
		strcopy(sData[1], sizeof(sData[]), g_sModeName[i]);
		ImplodeStrings(sData, 2, "|", sInfo, sizeof(sInfo));//打包字符串.
		menu.AddItem(sInfo, g_sModeName[i]);
	}

	menu.ExitButton = true;//默认值:true,设置为:false,则不显示退出选项.
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

int Menu_HandlerMode(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		case MenuAction_Select:
		{
			char sItem[32], g_sMode[32];
			GetConVarString(FindConVar("mp_gamemode"), g_sMode, sizeof(g_sMode));
			
			if(menu.GetItem(itemNum, sItem, sizeof(sItem)))
			{
				char sInfo[2][32];
				ExplodeString(sItem, "|", sInfo, sizeof(sInfo), sizeof(sInfo[]));//拆分字符串.
				
				if(strcmp(sInfo[0], sInfo[1], false) == 0)
				{
					g_hGameMode = CreateTimer(g_fChangeTime, DelaySetGameMode);//延迟重启当前章节
					PrintHintTextToAll("[提示] 服务器将在 %.1f秒 后重启当前章节.", g_fChangeTime);
					PrintToChatAll("\x04[提示]\x05服务器将在\x03%.1f秒\x05后重启当前章节.", g_fChangeTime);
				}
				else
				{
					if(strcmp(sInfo[0], g_sMode, false) == 0)
					{
						SetModeMenu(client, menu.Selection);//重新打开游戏模式选择菜单.
						PrintToChat(client, "\x04[提示]\x05当前已是\x04(\x03%s\x04)\x05模式.", sInfo[1]);
					}
					else
					{
						if(g_hGameMode == null)
						{
							g_hGameMode = CreateTimer(g_fChangeTime, DelaySetGameMode);//延迟重启当前章节
							SetConVarString(FindConVar("mp_gamemode"), sInfo[0]);//设置游戏模式.
							PrintHintTextToAll("[模式] 游戏模式更改为(%s),期间可能出现黑屏,请等待数秒.", sInfo[1]);
							PrintToChatAll("\x04[模式]\x05游戏模式更改为\x04(\x03%s\x04)\x04,\x05将在\x03%.1f秒\x05后重启当前章节.", sInfo[1], g_fChangeTime);
						}
						else
							PrintToChat(client, "\x04[提示]\x05当前正在更改为\x04(\x03%s\x04)\x05模式,请勿重复设置游戏模式.", sInfo[1]);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack && hTopMenu != null)
				hTopMenu.Display(client, TopMenuPosition_LastCategory);
		}
	}
	return 0;
}

public Action DelaySetGameMode(Handle timer)
{
	ForceChangeLevel(GetMapCode(), "sm_map Command");
	g_hGameMode = null;
	return Plugin_Stop;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

char[] GetMapCode()
{
	char sMapCode[32];
	GetCurrentMap(sMapCode, sizeof(sMapCode));
	return sMapCode;
}

char[] GetModeName()
{
	for (int i = 1; i < sizeof(g_sModeCode); i++)
	{
		if(strcmp(g_sModeCode[i], GetGameMode(), false) == 0)
			return g_sModeName[i];
	}
	return GetGameMode();
}

char[] GetGameMode()
{
	char g_sMode[32];
	GetConVarString(FindConVar("mp_gamemode"), g_sMode, sizeof(g_sMode));
	return g_sMode;
}
