#include <sourcemod>
#include <clientprefs>
#include <adt>

#include "csgo_music_kit_mapping.sp"

#define BASE_STR_LEN 128
#define DEFAULT_MUSIC_KIT "valve_csgo"

public Plugin myinfo = {
    name = "CSGO Music Kit",
    author = "Eric Zhang",
    description = "Select your CSGO music kit",
    version = "1.0.1",
    url = "https://ericaftereric.top"
};

StringMap musicKitMapping;
ArrayList musicKitList;

ConVar cvarShowHintByDefault;

Cookie cookieShowHintWhenEnter;
Cookie cookieClientMusicKit;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    char game[PLATFORM_MAX_PATH];
    GetGameFolderName(game, sizeof(game));
    if (!StrEqual(game, "csgo")) {
        strcopy(error, err_max, "This plugin only works on Counter-Strike: Global Offensive");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart() {
    LoadTranslations("csgo-music-kit.phrases");
    LoadTranslations("csgo-music-kit-kits.phrases");

    musicKitMapping = new StringMap();
    musicKitList = new ArrayList(ByteCountToCells(BASE_STR_LEN));
    MakeMusicKitMapping(musicKitMapping);
    MakeMusicKitList(musicKitList);

    cvarShowHintByDefault = CreateConVar("sm_music_kit_select_hint_default", "1", "Tell clients they can select music kits by default.");

    cookieShowHintWhenEnter = new Cookie("Show music kit hint", "Toggle the music kit hint when you enter the server.", CookieAccess_Public);
    cookieClientMusicKit = new Cookie("Client music kit", "Music kit for clients", CookieAccess_Private);

    cookieShowHintWhenEnter.SetPrefabMenu(CookieMenu_OnOff_Int, "Show music kit hint", OnHintCookieMenu);

    RegConsoleCmd("sm_musickit", Cmd_MusicKit, "Select your music kit.");
    RegConsoleCmd("sm_music", Cmd_MusicKit, "Select your music kit.");

    HookEvent("player_spawn", Event_PlayerSpawn);

    AutoExecConfig();
}

public void OnHintCookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen) {
    if (action == CookieMenuAction_DisplayOption) {
        Format(buffer, maxlen, "%t", "CSGO_MUSIC_KIT_PREF_MENU_TITLE", client);
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client)) {
        return;
    }
    if (cookieShowHintWhenEnter.GetInt(client, cvarShowHintByDefault.BoolValue ? 1 : 0)) {
        PrintToChat(client, "%t", "CSGO_MUSIC_KIT_CHAT_HINT");
    }
}

public void OnClientCookiesCached(int client) {
    if (IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client)) {
        return;
    }
    // give clients a default music kit
    char clientMusicKit[BASE_STR_LEN];
    cookieClientMusicKit.Get(client, clientMusicKit, sizeof(clientMusicKit));
    if (!strlen(clientMusicKit)) {
        cookieClientMusicKit.Set(client, DEFAULT_MUSIC_KIT);
    }
    SetClientMusicKit(client);
}

public Action Cmd_MusicKit(int client, int args) {
    if (!IsValidClient(client)) {
        return Plugin_Continue;
    }

    char menuTitle[BASE_STR_LEN], clientMusicKit[BASE_STR_LEN];
    Format(menuTitle, sizeof(menuTitle), "%T", "CSGO_MUSIC_KIT_MENU_TITLE", client);
    cookieClientMusicKit.Get(client, clientMusicKit, sizeof(clientMusicKit));

    Menu menu = new Menu(Menu_MusicKitMenu);
    menu.SetTitle(menuTitle);

    for (int i = 0; i < musicKitList.Length; i++) {
        int drawStyle = ITEMDRAW_DEFAULT;
        char musicKitKey[BASE_STR_LEN], musicKitLocStr[BASE_STR_LEN], musicKitDispStr[BASE_STR_LEN];
        musicKitList.GetString(i, musicKitKey, sizeof(musicKitKey));
        Format(musicKitLocStr, sizeof(musicKitLocStr), "%T", musicKitKey, client);
        if (StrEqual(clientMusicKit, musicKitKey)) {
            Format(musicKitDispStr, sizeof(musicKitDispStr), "%T", "CSGO_MUSIC_KIT_SELECTED", client, musicKitLocStr);
            drawStyle = ITEMDRAW_DISABLED;
        } else {
            strcopy(musicKitDispStr, sizeof(musicKitDispStr), musicKitLocStr);
        }
        menu.AddItem(musicKitKey, musicKitDispStr, drawStyle);
    }
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public void Menu_MusicKitMenu(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_Select: {
            char info[BASE_STR_LEN];
            menu.GetItem(param2, info, sizeof(info));
            cookieClientMusicKit.Set(param1, info);
            SetClientMusicKit(param1);
        }
        case MenuAction_End: {
            delete menu;
        }
    }
}

bool IsValidClient(int client) {
    return IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client) && !IsClientReplay(client);
}

void SetClientMusicKit(int client) {
    if (!GetEntProp(client, Prop_Send, "m_unMusicID")) {
        return;
    }
    char clientMusicKit[BASE_STR_LEN];
    cookieClientMusicKit.Get(client, clientMusicKit, sizeof(clientMusicKit));
    if (!strlen(clientMusicKit)) {
        return;
    }
    int musicKitId;
    if (!musicKitMapping.GetValue(clientMusicKit, musicKitId)) {
        return;
    }
    SetEntProp(client, Prop_Send, "m_unMusicID", musicKitId);
}
