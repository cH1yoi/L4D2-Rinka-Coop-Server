#define PLUGIN_CONFIG						 "Neko_Specials_binhooks"

#define CSpecial_Fast_Response				 1
#define CSpecial_Spawn_Time					 2
#define CSpecial_Random_Mode				 3
#define CSpecial_Default_Mode				 4
#define CSpecial_Show_Tips					 5
#define CSpecial_Spawn_Tank_Alive			 6
#define CSpecial_Num						 7
#define CSpecial_AddNum						 8
#define CSpecial_PlayerAdd					 9
#define CSpecial_PlayerNum					 10
#define CSpecial_Spawn_Mode					 11
#define CSpecial_Boomer_Num					 12
#define CSpecial_Smoker_Num					 13
#define CSpecial_Charger_Num				 14
#define CSpecial_Hunter_Num					 15
#define CSpecial_Spitter_Num				 16
#define CSpecial_Jockey_Num					 17
#define CSpecial_AutoKill_StuckTank			 18
#define CSpecial_LeftPoint_SpawnTime		 19
#define CSpecial_PluginStatus				 20
#define CSpecial_Show_Tips_Chat				 21
#define CSpecial_PlayerCountSpec			 22
#define CSpecial_CanCloseDirector			 23
#define CGame_Difficulty					 24
#define CSpecial_Spawn_Time_DifficultyChange 25
#define CSpecial_Spawn_Time_Easy			 26
#define CSpecial_Spawn_Time_Normal			 27
#define CSpecial_Spawn_Time_Hard			 28
#define CSpecial_Spawn_Time_Impossible		 29
#define CSpecial_IsModeInNormal				 30
#define CSpecial_Boomer_Spawn_Weight		 31
#define CSpecial_Smoker_Spawn_Weight		 32
#define CSpecial_Charger_Spawn_Weight		 33
#define CSpecial_Hunter_Spawn_Weight		 34
#define CSpecial_Spitter_Spawn_Weight		 35
#define CSpecial_Jockey_Spawn_Weight		 36
#define CSpecial_Boomer_Spawn_DirChance		 37
#define CSpecial_Smoker_Spawn_DirChance		 38
#define CSpecial_Charger_Spawn_DirChance	 39
#define CSpecial_Hunter_Spawn_DirChance		 40
#define CSpecial_Spitter_Spawn_DirChance	 41
#define CSpecial_Jockey_Spawn_DirChance		 42
#define CSpecial_Boomer_Spawn_Area			 43
#define CSpecial_Smoker_Spawn_Area			 44
#define CSpecial_Charger_Spawn_Area			 45
#define CSpecial_Hunter_Spawn_Area			 46
#define CSpecial_Spitter_Spawn_Area			 47
#define CSpecial_Jockey_Spawn_Area			 48
#define CSpecial_Boomer_Spawn_MaxDis		 49
#define CSpecial_Smoker_Spawn_MaxDis		 50
#define CSpecial_Charger_Spawn_MaxDis		 51
#define CSpecial_Hunter_Spawn_MaxDis		 52
#define CSpecial_Spitter_Spawn_MaxDis		 53
#define CSpecial_Jockey_Spawn_MaxDis		 54
#define CSpecial_Boomer_Spawn_MinDis		 55
#define CSpecial_Smoker_Spawn_MinDis		 56
#define CSpecial_Charger_Spawn_MinDis		 57
#define CSpecial_Hunter_Spawn_MinDis		 58
#define CSpecial_Spitter_Spawn_MinDis		 59
#define CSpecial_Jockey_Spawn_MinDis		 60
#define CSpecial_Spawn_MaxDis				 61
#define CSpecial_Spawn_MinDis				 62
#define CSpecial_Num_NotCul_Death			 63
#define CSpecial_Spawn_Tank_Alive_Pro		 64
#define CSpecial_AutoKill_StuckSpecials		 65
#define Cvar_Max							 66

ConVar NCvar[Cvar_Max];

int	   MENU_TIME = 60;

int	   ModeValue;

enum struct ClientItem
{
	bool WaitingForTgtime;
	bool WaitingForTgnum;
	bool WaitingForTgadd;
	bool WaitingForTgCustom;
	bool WaitingForTgCustomWeight;
	bool WaitingForTgCustomDirChance;
	bool WaitingForPadd;
	bool WaitingForPnum;
	bool WaitingForTgCustomMaxDis;
	bool WaitingForTgCustomMinDis;
	bool WaitingForTgCustomMaxDisNor;
	bool WaitingForTgCustomMinDisNor;

	char WaitingForTgCustomItem[50];
	char WaitingForTgTimeType[50];
	char WaitingForTgCustomWeightItem[50];
	char WaitingForTgCustomDirChanceItem[50];
	char WaitingForTgCustomMinDisItem[50];
	char WaitingForTgCustomMaxDisItem[50];

    bool InWait(){
		if (this.WaitingForTgtime || this.WaitingForTgnum || this.WaitingForTgadd || this.WaitingForPnum || this.WaitingForPadd || this.WaitingForTgCustom || this.WaitingForTgCustomWeight || this.WaitingForTgCustomDirChance || this.WaitingForTgCustomMaxDis || this.WaitingForTgCustomMinDis || this.WaitingForTgCustomMaxDisNor || this.WaitingForTgCustomMinDisNor)
			return true;
		return false;
	}

	void Reset(){
		this.WaitingForTgtime				 = false;
		this.WaitingForTgnum				 = false;
		this.WaitingForTgadd				 = false;
		this.WaitingForTgCustom				 = false;
		this.WaitingForTgCustomWeight		 = false;
		this.WaitingForTgCustomDirChance	 = false;
		this.WaitingForPadd					 = false;
		this.WaitingForPnum					 = false;
		this.WaitingForTgCustomMaxDis		 = false;
		this.WaitingForTgCustomMinDis		 = false;
		this.WaitingForTgCustomMaxDisNor	 = false;
		this.WaitingForTgCustomMinDisNor	 = false;
		this.WaitingForTgCustomItem			 = NULL_STRING;
		this.WaitingForTgTimeType			 = NULL_STRING;
		this.WaitingForTgCustomWeightItem	 = NULL_STRING;
		this.WaitingForTgCustomDirChanceItem = NULL_STRING;
		this.WaitingForTgCustomMinDisItem	 = NULL_STRING;
		this.WaitingForTgCustomMaxDisItem	 = NULL_STRING;
    }
}

ClientItem N_ClientItem[MAXPLAYERS + 1];

enum struct ClientMenu
{
	Menu N_MenuSpecialMenu;
	Menu N_SpecialMenuCustom;
	Menu N_SpecialMenuCustomWeight;
	Menu N_SpecialMenuCustomDirChance;
	Menu N_SpecialMenuCustomSpawnArea;
	Menu N_SpecialMenuCustomMaxDis;
	Menu N_SpecialMenuCustomMinDis;

	int	 MenuPageItem;

	void Reset(bool CleanPage = false){
		this.N_MenuSpecialMenu			  = null;
		this.N_SpecialMenuCustom		  = null;
		this.N_SpecialMenuCustomWeight	  = null;
		this.N_SpecialMenuCustomDirChance = null;
		this.N_SpecialMenuCustomSpawnArea = null;
		this.N_SpecialMenuCustomMaxDis	  = null;
		this.N_SpecialMenuCustomMinDis	  = null;
		if (CleanPage) this.MenuPageItem  = 0;
    }
}

ClientMenu	  N_ClientMenu[MAXPLAYERS + 1];

bool		  IsPlayerLeftCP;

char		  SpecialName[8][50]   = { "NULL", "牛子", "胖子", "口水", "舌头", "猴子", "猎人", "默认" };

char		  SpawnModeName[4][50] = { "引擎", "普通", "噩梦", "地狱" };

GlobalForward N_Forward_OnSetSpecialsNum, N_Forward_OnSetSpecialsTime, N_Forward_OnStartFirstSpawn;