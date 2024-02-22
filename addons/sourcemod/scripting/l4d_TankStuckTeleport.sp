#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define CVAR_FLAGS FCVAR_NOTIFY
#define PLUGIN_VERSION "2.3"

public Plugin myinfo = {
	name = "Tank Anti-Stuck",
	author = "Dragokas, X光",
	description = "Teleport tank if he was stuck within collision and can't move",
	version = PLUGIN_VERSION,
	url = "https://github.com/dragokas"
}

/*
	ChangeLog:

	2.3 (06-December-2023)
	 插件作者只维护到2.2版本,2.3版本全新修改.
	 1. 坦克卡住传送为设置目标附近视野盲区有效位置,惩罚传送为最前方超过设置值距离附近.
	 2. 新增目标选择最前方的幸存者.
	 3. 精简代码,增加插件指令开关功能.

	2.2 (03-Sep-2019)
	 - Returned to the previous stuck detection method (radius position-based)
	 with removing false positives when tank finishes off incapped player nearby or attacking in place.
	 - Some code optimizations, comments, removed some unused.
	 - "On ladder" logic is changed.

	2.1 (09-Aug-2019)
	 - Prevent rush punishment when tank count is 1 elapsed
	 - Tank is react faster when he is blocked on the ladder

	2.0 (05-May-2019)
	 - Collision with another clients (include other tanks) is now not considered as stuck.
	 - Fixed case when TR_DidHit() could return wrong result due to extracting info from global trace.
	 - Added "l4d_TankAntiStuck_dest_object" ConVar to control the destination, 
	 where you want to teleport tank to:
	 (0 - next to current tank, 1 - next to another tank, 2 - next to player). By default: 1 (previously, it was: 2).

	 - Added new violations (punishment is teleporting tank directly to player):
	 1. Punish the player who doesn't move (tank stucker / inactive player)
	 2. Punish the player who rush too far from the nearest tank (and thus, from the team, including team rush).

	 Punishments are enabled by default. To disable, use below ConVars:
	 - l4d_TankAntiStuck_idler_punish
	 - l4d_TankAntiStuck_rusher_punish

	 For detail adjustments, see more new ConVars in the thread.

	 - Code optimization
	 - Tank angry detection is improved
	 - Tank stuck detection is improved to avoid false positives

	1.3 
	 - Added some missing ConVar hooks.

	1.2 (05-Mar-2019)
	 - Added all user's ConVars.
	 - Added late loading code.
	 - Included anti-losing tank control ConVar (thanks to cravenge)

	1.1 (01-Mar-2019)
	 - Added more reliable logic

	1.0 (05-Jan-2019)
	 - Initial release

==========================================================================================

	Credits:

*	Peace-Maker - for some examples on TraceHull filter.

*	stinkyfax - for examples of teleporting in direction math.

*	cravenge - for some ConVar, possibly, preventing tank from losing control when getting stuck.

* 	midnight9, PatriotGames - who tried to help me with another ConVars against losing tank control.

==========================================================================================

	Related topics:
	https://forums.alliedmods.net/showthread.php?t=313696
	https://forums.alliedmods.net/showthread.php?p=2133193
	https://forums.alliedmods.net/showthread.php?t=101998

*/

#define DEBUG 0

ConVar
	g_hCvarEnable,
	g_hCvarNonAngryTime,
	g_hCvarTankDistanceMax,
	g_hCvarStuckInterval,
	g_hCvarNonStuckRadius,
	g_hCvarAllIntellect,
	g_hCvarApplyConVar,
	g_hCvarStuckFailsafe,
	g_hCvarTankClawRangeDown,
	g_hCvarTankClawRange,
	g_hCvarDestObject,
	g_hCvarRusherPunish,
	g_hCvarRusherDist,
	g_hCvarRusherCheckTimes,
	g_hCvarRusherCheckInterv,
	g_hCvarRusherMinPlayers,
	g_hCvarRusherEnable;

Handle g_hTimerRusher;

float F_LocationsPos[3];
float g_pos[MAXPLAYERS+1][3];
float g_fMaxNonAngryDist, g_fNonAngryTime, g_fTankClawRange;

bool g_bAtLeastOneTankAngry, g_bMapStarted;
bool g_bAngry[MAXPLAYERS+1];

int g_bEnabled;
int g_iTimes[MAXPLAYERS+1], g_iStuckTimes[MAXPLAYERS+1], g_iRushTimes[MAXPLAYERS+1];

public void OnPluginStart() {
	CreateConVar("l4d_TankAntiStuck_version", PLUGIN_VERSION, "插件版本", FCVAR_DONTRECORD);

	g_hCvarEnable = CreateConVar("l4d_TankAntiStuck_enable",							"1",		"是否开启插件(0=关闭, 1=开启).", CVAR_FLAGS);
	g_hCvarNonAngryTime = CreateConVar("l4d_TankAntiStuck_non_angry_time",				"30.0",		"如果在指定的多少秒坦克出现但没有行动(响起BGM)则自动传送坦克(0=禁用).", CVAR_FLAGS);
	g_hCvarTankDistanceMax = CreateConVar("l4d_TankAntiStuck_tank_distance_max",		"2000.0",	"坦克与最近的幸存者允许的最远距离(BGM响起时),如果超过这个距离则传送坦克(0=禁用).", CVAR_FLAGS);
	g_hCvarStuckInterval = CreateConVar("l4d_TankAntiStuck_check_interval",				"5.0",		"多少秒检测一次坦克是否被卡住.", CVAR_FLAGS);
	g_hCvarNonStuckRadius = CreateConVar("l4d_TankAntiStuck_non_stuck_radius",			"50.0",		"在指定秒内未移动时,坦克被判定为未卡住的最大半径.", CVAR_FLAGS);
	g_hCvarDestObject = CreateConVar("l4d_TankAntiStuck_dest_object",					"3",		"坦克传送到什么物体旁边(0=当前坦克附近, 1=别的坦克附近, 2=随机幸存者附近, 3=最前方幸存者附近).", CVAR_FLAGS);
	g_hCvarAllIntellect = CreateConVar("l4d_TankAntiStuck_all_intellect",				"1",		"防卡死应用的目标(0=只有BOT, 1=玩家和BOT).", CVAR_FLAGS);
	g_hCvarApplyConVar = CreateConVar("l4d_TankAntiStuck_apply_convar",					"1",		"防止坦克因为卡住而自杀(0=关闭, 1=开启).", CVAR_FLAGS);
	g_hCvarRusherPunish = CreateConVar("l4d_TankAntiStuck_rusher_punish",				"1",		"是否惩罚(把坦克传送到他附近)跑图(出了坦克不打,一个人跑)的玩家(0=关闭, 1=开启).", CVAR_FLAGS);
	g_hCvarRusherDist = CreateConVar("l4d_TankAntiStuck_rusher_dist",					"2000.0",	"离坦克这么远被认为是在跑图.", CVAR_FLAGS);
	g_hCvarRusherCheckTimes = CreateConVar("l4d_TankAntiStuck_rusher_check_times",		"1",		"检测多少次玩家如果在跑图,下一次达到设置检测时间后就执行惩罚传送.", CVAR_FLAGS);
	g_hCvarRusherCheckInterv = CreateConVar("l4d_TankAntiStuck_rusher_check_interval",	"5.0",		"多少秒检测一次玩家是否跑图.", CVAR_FLAGS);
	g_hCvarRusherMinPlayers = CreateConVar("l4d_TankAntiStuck_rusher_minplayers",		"2",		"至少要这么多玩家才考虑检查是否有人跑图.", CVAR_FLAGS);
	g_hCvarRusherEnable = CreateConVar("l4d_TankAntiStuck_rusher_Enable",				"1",		"救援关是否检测跑图(0=关闭, 1=开启).", CVAR_FLAGS);

	//AutoExecConfig(true, "l4d_tank_antistuck");

	g_hCvarStuckFailsafe = FindConVar("tank_stuck_failsafe");
	g_hCvarTankClawRange = FindConVar("claw_range");
	g_hCvarTankClawRangeDown = FindConVar("claw_range_down");

	RegAdminCmd("sm_tkfk", Cmd_TankAntiStuck, ADMFLAG_ROOT, "插件开关指令");

	HookConVarChange(g_hCvarEnable,				ConVarChanged);
	HookConVarChange(g_hCvarTankDistanceMax,	ConVarChanged);
	HookConVarChange(g_hCvarNonAngryTime,		ConVarChanged);
	HookConVarChange(g_hCvarRusherPunish,		ConVarChanged);
	HookConVarChange(g_hCvarRusherEnable,		ConVarChanged);

	GetCvars();

	if (g_bEnabled) {
		for (int i = 1; i <= MaxClients; i++) {
			if (i != 0 && IsClientInGame(i) && CheckTankIntellect(i)) {
				if (IsTank(i))
					BeginTankTracing(i);
			}
		}
	}
}

bool CheckTankIntellect(int tank) {
	if (g_hCvarAllIntellect.BoolValue)
		return true;
	else
		if (IsFakeClient(tank))
			return true;

	return false;
}

public void OnConfigsExecuted() {
	if (g_hCvarApplyConVar.BoolValue) {
		if (g_hCvarStuckFailsafe != null)
			g_hCvarStuckFailsafe.SetInt(0);
	}
	g_fTankClawRange = g_hCvarTankClawRangeDown.FloatValue;

	if (g_hCvarTankClawRange.FloatValue > g_fTankClawRange)
		g_fTankClawRange = g_hCvarTankClawRange.FloatValue;
	
	g_fTankClawRange *= 2; // to be sure
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bEnabled = g_hCvarEnable.BoolValue;
	g_fMaxNonAngryDist = g_hCvarTankDistanceMax.FloatValue;
	g_fNonAngryTime = g_hCvarNonAngryTime.FloatValue;

	InitHook();
}

void InitHook() {
	static bool bHooked;

	if (g_bEnabled) {
		if (!bHooked) {
			HookEvent("tank_spawn",				Event_TankSpawn,		EventHookMode_Post);
			HookEvent("player_death",			Event_PlayerDeath,		EventHookMode_Pre);
			HookEvent("round_start",			Event_RoundStart,		EventHookMode_PostNoCopy);
			HookEvent("round_end",				Event_RoundEnd,			EventHookMode_PostNoCopy);
			HookEvent("finale_win",				Event_RoundEnd,			EventHookMode_PostNoCopy);
			HookEvent("mission_lost",			Event_RoundEnd,			EventHookMode_PostNoCopy);
			HookEvent("map_transition",			Event_RoundEnd,			EventHookMode_PostNoCopy);
			bHooked = true;
		}
	} else {
		if (bHooked) {
			UnhookEvent("tank_spawn",			Event_TankSpawn,		EventHookMode_Post);
			UnhookEvent("player_death",			Event_PlayerDeath,		EventHookMode_Pre);
			UnhookEvent("round_start",			Event_RoundStart,		EventHookMode_PostNoCopy);
			UnhookEvent("round_end",			Event_RoundEnd,			EventHookMode_PostNoCopy);
			UnhookEvent("finale_win",			Event_RoundEnd,			EventHookMode_PostNoCopy);
			UnhookEvent("mission_lost",			Event_RoundEnd,			EventHookMode_PostNoCopy);
			UnhookEvent("map_transition",		Event_RoundEnd,			EventHookMode_PostNoCopy);
			bHooked = false;
		}
	}
}

public Action Cmd_TankAntiStuck(int client, int args) {
	g_hCvarEnable.BoolValue = !g_bEnabled;

	PrintToChat(client, "\x04[提示]\x05坦克传送功能已\x03%s\x05.", g_bEnabled ? "开启" : "关闭");

	return Plugin_Handled;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	OnMapStart();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

public void OnMapStart() {
	g_bMapStarted = true;
	g_bAtLeastOneTankAngry = false;

	for (int i = 1; i < MaxClients; i++)
		g_iTimes[i] = 0;
}

public void OnMapEnd() {
	delete g_hTimerRusher;
	g_bMapStarted = false;
}

public void OnClientDisconnect(int client) {
	ResetClientStat(client);
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bEnabled || !g_bMapStarted) return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (CheckTankIntellect(client)) {
		BeginTankTracing(client);
		BeginIdlerRusherTracing();
		#if (DEBUG)
			PrintToChatAll("%N (id: %i) 出现了.", client, client);
		#endif
	}
}

void BeginIdlerRusherTracing() {
	if (g_hCvarRusherPunish.BoolValue) {
		if (g_hCvarRusherEnable.BoolValue && IsFinalMap() || !IsFinalMap())
		{
			delete g_hTimerRusher;
			g_hTimerRusher = CreateTimer(g_hCvarRusherCheckInterv.FloatValue, Timer_CheckRusher, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_CheckRusher(Handle timer) {
	static float pos[3], postank[3], distance;
	static int tank, i;

	if (!g_bMapStarted)
		return Plugin_Stop;

	if (!g_bEnabled || !g_bAtLeastOneTankAngry)
		return Plugin_Continue;

	i = GetAheadSurvivor(); //获取最前方的幸存者.

	if (i > 0) {
		GetClientAbsOrigin(i, pos);
		if (GetSurvivorCountAlive() >= g_hCvarRusherMinPlayers.IntValue) {
			tank = GetNearestTank(i);
			if (tank > 0) {
				GetClientAbsOrigin(tank, postank);
				distance = GetVectorDistance(pos, postank, false);
				if (distance > g_hCvarRusherDist.FloatValue) {
					if (g_iRushTimes[i] >= g_hCvarRusherCheckTimes.IntValue) {
						pos[0] -= 20.0;
						pos[2] += 20.0;
						if (!IsPos_StuckTank(postank, tank)) {
							SetEntProp(tank, Prop_Send, "m_bDucked", 1);
							SetEntityFlags(tank, GetEntityFlags(tank) | FL_DUCKING);
							TeleportEntity(tank, pos, NULL_VECTOR, NULL_VECTOR);
							g_iRushTimes[i] = 0;
							PrintToChatAll("\x04[提示]\x05惩罚启动\x03坦克%s\x05传送到跑图玩家\x03%s\x05身边.", GetPlayerName(tank), GetTrueName(i));
						}
						pos[0] += 20.0;
						pos[2] -= 20.0;
					}
					else 
						g_iRushTimes[i]++;
				}
				else
					g_iRushTimes[i] = 0;
			}
		}
	}

	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bEnabled || !g_bMapStarted) return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client != 0) {
		if (IsTank(client)) {
			CreateTimer(1.0, Timer_UpdateTankCount, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		else {
			if (GetClientTeam(client) == 2) {
				ResetClientStat(client);
			}
		}
	}
}

void ResetClientStat(int client) {
	g_pos[client][0] = 0.0;
	g_pos[client][1] = 0.0;
	g_pos[client][2] = 0.0;
	g_iRushTimes[client] = 0;
}

public Action Timer_UpdateTankCount(Handle timer) {
	UpdateTankCount();

	return Plugin_Handled;
}

void UpdateTankCount() {
	int count = 0;

	for (int i = 1; i <= MaxClients; i++)
		if (IsTank(i))
			count++;
	
	if (count == 0) {
		g_bAtLeastOneTankAngry = false;
	}
}

void BeginTankTracing(int client) {
	g_iStuckTimes[client] = 0;
	g_bAngry[client] = false;
	GetClientAbsOrigin(client, g_pos[client]);

	// wait until somebody make tank angry to begin check for stuck
	CreateTimer(2.0, Timer_CheckAngry, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	if (g_fNonAngryTime != 0 && IsPlayerAlive(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
		// check if tank didnt't become angry within 30 sec
		CreateTimer(g_fNonAngryTime, Timer_CheckAngryTimeout, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_CheckAngry(Handle timer, int UserId) {
	int client = GetClientOfUserId(UserId);

	if (client != 0 && IsClientInGame(client) && IsPlayerAlive(client) && g_bMapStarted) {
		// became angry?
		if (IsAngry(client) || g_bAngry[client]) {
			#if (DEBUG)
				PrintToChatAll("%N 发起了进攻.", client);
			#endif

			g_bAtLeastOneTankAngry = true;
			// check if he is not moving within X sec.
			CreateTimer(g_hCvarStuckInterval.FloatValue, Timer_CheckPos, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Stop;
		}
	}
	else
		return Plugin_Stop;
	
	return Plugin_Continue;
}

bool IsAngry(int tank) {
	if (GetEntProp(tank, Prop_Send, "m_zombieState") != 0)
		return true;
	
	if (GetEntProp(tank, Prop_Send, "m_hasVisibleThreats") != 0)
		return true;
		
	return false;
}

bool IsIncappedNearBy(float vOrigin[3]) {
	static float vOriginPlayer[3];
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsPlayerState(i) && IsPlayerAlive(i)) {
			GetClientAbsOrigin(i, vOriginPlayer);
			if (GetVectorDistance(vOriginPlayer, vOrigin) <= g_fTankClawRange)
				return true;
		}
	}

	return false;
}

bool IsTankAttacking(int tank) {
	return GetEntProp(tank, Prop_Send, "m_fireLayerSequence") > 0;
}

public Action Timer_CheckPos(Handle timer, int UserId) {
	int tank = GetClientOfUserId(UserId);

	if (tank != 0 && IsClientInGame(tank) && IsPlayerAlive(tank) && g_bMapStarted) {
		static float pos[3];
		GetClientAbsOrigin(tank, pos);
		pos[2] += 20.0;
		L4D_WarpToValidPositionIfStuck(tank);
		pos[2] -= 20.0;
		static float distance;
		distance = GetVectorDistance(pos, g_pos[tank], false);
		if (distance < g_hCvarNonStuckRadius.FloatValue && !IsIncappedNearBy(pos) && !IsTankAttacking(tank)) {
			static bool bOnLadder;
			bOnLadder = IsOnLadder(tank);
			if (g_fMaxNonAngryDist != 0.0 && (GetDistanceToNearestClient(tank) > g_fMaxNonAngryDist || g_iStuckTimes[tank] > 2)) {
				// object selectable by ConVar => teleport only when tank looks like completely stuck
				TeleportToObject(tank);
			}
			else if (g_iStuckTimes[tank] > 1 || bOnLadder) {
				#if (DEBUG)
					int anim = GetEntProp(tank, Prop_Send, "m_nSequence");
					PrintToChatAll("%N stucked => micro-teleport, dist: %f, anim: %i", tank, distance, anim);
				#endif
			}
			g_iStuckTimes[tank]++;

			#if (DEBUG)
				PrintToChatAll("%N stuck ++: %i", tank, g_iStuckTimes[tank]);
			#endif
		}
		else {
			g_iStuckTimes[tank] = 0;
		}
		g_pos[tank] = pos;
	}
	else
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public Action Timer_CheckAngryTimeout(Handle timer, int UserId) {
	int client = GetClientOfUserId(UserId);

	if (client != 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
		if (GetEntProp(client, Prop_Send, "m_zombieState") == 0) {
			TeleportToObject(client);
		}
		// force angry flag to allow timer to begin check for position even if tank became angry but still not moving
		SetEntProp(client, Prop_Send, "m_zombieState", 1);
		g_bAngry[client] = true; // just in case
		g_bAtLeastOneTankAngry = true;

		#if (DEBUG)
			PrintToChatAll("%N 进攻超时.", client);
		#endif
	}

	return Plugin_Handled;
}

void TeleportToObject(int client) {
	if (!g_bEnabled || !g_bMapStarted)
		return;

	static int target;

	switch(g_hCvarDestObject.IntValue) {
		case 0: {
			//当前坦克附近.
			target = client;
		}
		case 1: {
			//别的坦克附近,如果没有多余坦克则随机获取一个幸存者附近.
			target = GetNearestTank(client) > 0 ? GetNearestTank(client) : GetAnyRandomSurvivor();
		}
		case 2: {
			//随机幸存者附近.
			target = GetAnyRandomSurvivor();
		}
		case 3: {
			//最前方幸存者附近,如果获取不到方向时则随机获取一个幸存者附近.
			target = GetAheadSurvivor() > 0 ? GetAheadSurvivor() : GetAnyRandomSurvivor();
		}
	}

	if (target > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
		if (FindValidLocations(client, target))
			GetClientAbsOrigin(target, F_LocationsPos);

		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntityFlags(client, GetEntityFlags(client) | FL_DUCKING);
		TeleportEntity(client, F_LocationsPos, NULL_VECTOR, NULL_VECTOR);
		PrintToChatAll("\x04[提示]\x05防卡启动\x03坦克%s\x05%s传送到%s%s\x03%s\x05附近.", 
		GetPlayerName(client), target != GetAheadSurvivor() ? "随机" : "", target == GetAheadSurvivor() ? "前方" : "", g_hCvarDestObject.IntValue >= 2 ? "玩家" : "", GetTrueName(target));
	}
}

void FindValidLocations(int client, int target) {
	L4D_GetRandomPZSpawnPosition(target, GetEntProp(client, Prop_Send, "m_zombieClass") == 8, 8, F_LocationsPos);
}

char[] GetPlayerName(int client) {
	char sName[32];

	if (!IsFakeClient(client))
		FormatEx(sName, sizeof(sName), "\x04%N", client);
	else {
		GetClientName(client, sName, sizeof(sName));
		SplitString(sName, "Tank", sName, sizeof(sName));
	}

	return sName;
}

char[] GetTrueName(int client) {
	char sName[32];
	int Bot = IsClientIdle(client);

	if (Bot != 0)
		FormatEx(sName, sizeof(sName), "闲置:%N", Bot);
	else
		GetClientName(client, sName, sizeof(sName));

	return sName;
}

int IsClientIdle(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

float GetDistanceToNearestClient(int client) {
	static float tpos[3], spos[3], dist, mindist;
	mindist = 0.0;
	GetClientAbsOrigin(client, tpos);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			GetClientAbsOrigin(i, spos);
			dist = GetVectorDistance(tpos, spos, false);
			if (dist < mindist || mindist < 0.1)
				mindist = dist;
		}
	}

	return mindist;
}

stock int GetAnyRandomSurvivor() {
	int client;
	ArrayList aClients = new ArrayList();

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerState(i) && IsPlayerAlive(i))
			aClients.Push(i);
	}

	if (aClients.Length > 0) {
		SetRandomSeed(GetGameTickCount());
		client = aClients.Get(GetRandomInt(0, aClients.Length - 1));
	}
	delete aClients;

	return client;
}

static int GetAheadSurvivor() {
	static int i;
	static float flow;
	static ArrayList flowList;
	flowList = new ArrayList(2);

	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerState(i) || !IsPlayerAlive(i))
			continue;

		flow = L4D2Direct_GetFlowDistance(i);
		if (flow)
			flowList.Set(flowList.Push(flow), i, 1);
	}
	if (flowList.Length == 0) {
		delete flowList;
		return -1;
	}

	RoundToCeil(flow / L4D2Direct_GetMapMaxFlowDistance() * 100) > 0 ? flowList.Sort(Sort_Descending, Sort_Float) : flowList.Sort(Sort_Ascending, Sort_Float);

	i = flowList.Get(0, 1);
	delete flowList;

	return i;
}

int GetNearestTank(int client) {
	static float tpos[3], spos[3], dist, mindist;
	static int iNearClient;
	iNearClient = 0;
	mindist = 0.0;
	GetClientAbsOrigin(client, tpos);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsTank(i)) {
			GetClientAbsOrigin(i, spos);
			dist = GetVectorDistance(tpos, spos, false);
			if (dist < mindist || mindist < 0.1) {
				mindist = dist;
				iNearClient = i;
			}
		}
	}

	return iNearClient;
}

bool TR_EntityFilter(int entity, int mask) {
	if (entity <= MaxClients)
		return false;

	else if (entity > MaxClients) {
		char classname[16] = {'\0'};
		GetEdictClassname(entity, classname, sizeof(classname));
		if (strcmp(classname, "infected") == 0 || strcmp(classname, "witch") == 0 || strcmp(classname, "prop_physics") == 0 || strcmp(classname, "tank_rock") == 0)
			return false;
	}

	return true;
}

stock void CopyVectors(float origin[3], float result[3]) {
	result[0] = origin[0];
	result[1] = origin[1];
	result[2] = origin[2];
}

bool IsPos_StuckTank(float refpos[3], int client) {
	bool stuck = false;
	float client_mins[3] = {0.0}, client_maxs[3] = {0.0}, up_hull_endpos[3] = {0.0};
	GetClientMins(client, client_mins);
	GetClientMaxs(client, client_maxs);
	CopyVectors(refpos, up_hull_endpos);
	up_hull_endpos[2] += 72.0;
	TR_TraceHullFilter(refpos, up_hull_endpos, client_mins, client_maxs, MASK_NPCSOLID_BRUSHONLY, TR_EntityFilter);
	stuck = TR_DidHit();

	return stuck;
}

stock bool IsTank(int client) {
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(client))
		return true;

	return false;
}

int GetSurvivorCountAlive() {
	int count = 0;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i) && IsPlayerAlive(i))
			count++;
	}

	return count;
}

public bool TraceRay_DontHitSelf(int iEntity, int iMask, any data) {
	return (iEntity != data);
}

stock bool IsOnLadder(int entity) {
	return GetEntityMoveType(entity) == MOVETYPE_LADDER;
}

bool IsPlayerState(int client) {
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

stock bool IsFinalMap() {
	return FindEntityByClassname(-1, "info_changelevel") == -1 && FindEntityByClassname(-1, "trigger_changelevel") == -1;
}