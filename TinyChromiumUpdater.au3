#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=logo.ico
#AutoIt3Wrapper_Outfile=TinyChromiumUpdater.exe
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Description=TinyChromiumUpdater par mGeek
#AutoIt3Wrapper_Res_Fileversion=0.3.0.0
#AutoIt3Wrapper_Res_Language=1036
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Res_File_Add=res\bg-body.jpg, rt_rcdata, bg_body
#AutoIt3Wrapper_Res_File_Add=res\bg-mini.jpg, rt_rcdata, bg_mini
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#cs -----------------------------------------------------------------

	TinyChromiumUpdater 0.3
	par mGeek - web: mgeek.legtux.org
	(version Debian/Ubuntu codée par Drav disponible sur dravinux.legtux.org)

	changelog-
	0.3 - VERSION STABLE
	Ajout de commentaires
	Optimisation de AITray.dll (x32 et x64)
	0.2
	Correction de l'intégration des backgrounds
	Problème de fermeture réglé / Ajout d'un singleTon pour prévenir les multi-ouvertures
	Fonctionnel sur x64
	Rangement du code
	0.1 (.1)
	Correction d'un problème lié au Tooltip (x32)
	Recherche de mise à jour des le lancement
	0.1
	Init

#ce -----------------------------------------------------------------

#region Initialisation de TinyChromiumUpdater
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <Constants.au3>
#include <Misc.au3>
#include "res\Resources.au3"

_Singleton("TinyChromiumUpdater") ;Permet d'empécher de lancer plusieurs fois le logiciel

Opt("TrayMenuMode", 1)
Opt("TrayAutoPause", 0)
Opt('WinTitleMatchMode', 3) ;Pour AITray.dll
Opt('WinWaitDelay', 0) ;Pour AITray.dll

$lastChangeURL = "http://commondatastorage.googleapis.com/chromium-browser-continuous/Win/LAST_CHANGE"
$downloadURL = "http://commondatastorage.googleapis.com/chromium-browser-continuous/Win/%id/mini_installer.exe"
$version = "0.3"

DirCreate(@AppDataDir & "\TinyChromiumUpdater")
If Not FileExists(@AppDataDir & "\TinyChromiumUpdater\config") Then IniWrite(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "version", "0")
#endregion Initialisation de TinyChromiumUpdater

#region == Initialisation d'AITray.dll
Global Const $NIN_BALLOONUSERCLICK = $WM_USER + 5
$hForm = GUICreate('')

If @AutoItX64 Then
	FileInstall("res\AITray_x64.dll", @TempDir & "\*", 1)
	$hDll = DllOpen(@TempDir & '\AITray_x64.dll')
Else
	FileInstall("res\AITray.dll", @TempDir & "\*", 1)
	$hDll = DllOpen(@TempDir & '\AITray.dll')
EndIf

If $hDll <> -1 Then
	$Ret = DllCall($hDll, 'int', 'AISetTrayRedirection', 'hwnd', WinGetHandle(AutoItWinGetTitle()), 'hwnd', $hForm)
	If (@error) Or (Not $Ret[0]) Then
		DllClose($hDll)
		Exit
	EndIf
Else
	MsgBox(16, "Erreur", "Erreur fatale liée à la DLL AITray.dll")
	Exit
EndIf

GUIRegisterMsg($WM_USER + 1, 'WM_TRAYNOTIFY')
#endregion == Initialisation d'AITray.dll

#region == Création de la fenêtre
$guiMain = GUICreate("TinyChromiumUpdater", 300, 250)
$pic_ = GUICtrlCreatePic("", 0, 0, 300, 250)
_ResourceSetImageToCtrl($pic_, "bg_body")
GUICtrlSetState(-1, 128)

GUICtrlCreateLabel("version " & $version, 150, 235, 145, 20, $SS_RIGHT)
GUICtrlSetBkColor(-1, -2)
GUICtrlSetColor(-1, 0xFFFFFF)

$labelCredit = GUICtrlCreateLabel("Créé par mGeek", 5, 235, 85, 20)
GUICtrlSetBkColor(-1, -2)
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlSetCursor(-1, 0)

$labelStartState = GUICtrlCreateLabel("", 10, 50, 280, 30, $SS_CENTER)
GUICtrlSetBkColor(-1, -2)

$buttonStartState = GUICtrlCreateButton("Lancer au démmarage de Windows", 30, 85, 240, 23)
GUICtrlSetBkColor(-1, -2)
GUICtrlSetState(-1, 128)

;Séparateur
GUICtrlCreateLabel("", 10, 120, 280, 1)
GUICtrlSetBkColor(-1, 0xCCCCCC)

$labelVersion = GUICtrlCreateLabel("", 10, 130, 280, 20, $SS_CENTER)
GUICtrlSetBkColor(-1, -2)

$labelVersionState = GUICtrlCreateLabel("", 10, 150, 280, 20, $SS_CENTER)
GUICtrlSetBkColor(-1, -2)

$buttonUpdate = GUICtrlCreateButton("", 30, 175, 240, 23)
#endregion == Création de la fenêtre


;Mise à jour du status (registre - version de chromium)
_UpdateGUI()

;Si le programme à été lancé en mode "silentieux" (param. -s) la fenêtre ne s'affiche pas
If $CmdLine[0] <> 0 And $CmdLine[1] = "-s" Then
Else
	GUISetState(@SW_SHOW)
EndIf

#region == Création du menu Tray
$tShow = TrayCreateItem("Afficher / Cacher")
$tExit = TrayCreateItem("Quitter")
TraySetState()
TraySetToolTip("TinyChromiumUpdater " & $version)
#endregion == Création du menu Tray


;Première recherche de version
_CheckVersion()
$timerCheckVersion = TimerInit()

#region == Boucle principale (fenêtre - tray - gestion du temps de recherche de mises à jour)
While 1
	Switch GUIGetMsg()
		Case -3
			MsgBox(64, "Bon de réduction", "Je vais me réduire dans la barre des taches, comme ça, je reste actif pour vous signaler l'arrivée d'une nouvelle version")
			GUISetState(@SW_HIDE, $guiMain)
		Case $buttonStartState
			If IsAdmin() Then
				RegWrite("HKLM\Software\Microsoft\Windows\CurrentVersion\Run\", "TinyChromiumUpdater", "REG_SZ", @ScriptFullPath & " -s")
				_UpdateGUI()
			Else
				MsgBox(48, "Erreur", "Relancez moi en mode administrateur pour m'assigner au lancement de Windows, je ne peux rien faire sans..")
			EndIf
		Case $buttonUpdate
			_ForceUpdate()
		Case $labelCredit
			ShellExecute("http://mgeek.legtux.org")
	EndSwitch

	Switch TrayGetMsg()
		Case $tShow
			If WinGetState($guiMain) <> 5 Then
				GUISetState(@SW_HIDE, $guiMain)
			Else
				GUISetState(@SW_SHOW, $guiMain)
			EndIf
			TrayItemSetState($tShow, $GUI_UNCHECKED)
		Case $tExit
			If MsgBox(36, "Quitter TinyChromiumUpdater", "Êtes vous sur de vouloir me désactiver ?" & @CRLF & "Vous ne receverez plus les mises à jours de Chromium tant que vous ne me relancerez pas..") = 6 Then
				DllClose($hDll)
				Exit
			EndIf
			TrayItemSetState($tExit, $GUI_UNCHECKED)
	EndSwitch

	If TimerDiff($timerCheckVersion) > 300000 Then ;5 minutes
		;If TimerDiff($timerCheckVersion) > 10000 Then ;10 secondes (pour le debug)
		_CheckVersion()
		$timerCheckVersion = TimerInit()
	EndIf

	Sleep(10)
WEnd
#endregion == Boucle principale (fenêtre - tray - gestion du temps de recherche de mises à jour)


#region == Fonctions liées à TinyChromiumUpdater
Func _CheckVersion()
	$lastChange = BinaryToString(InetRead($lastChangeURL, 1))
	If $lastChange > IniRead(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "version", $lastChange) Then
		;Une mise à jour est requise
		TrayTip("Tiny Chromium Updater", "Une mise à jour de Chromium est disponible !" & @CRLF & "Cliquez sur ce message pour l'installer.", 1)
		_UpdateGUI()
	EndIf
	Return $lastChange
EndFunc   ;==>_CheckVersion

Func _UpdateGUI()
	If Not RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\Run\", "TinyChromiumUpdater") = @ScriptFullPath & " -s" Then
		GUICtrlSetData($labelStartState, "Je ne suis pas assigné au démmarage de Windows, cliquez sur le bouton ci-dessous pour m'associer :")
		GUICtrlSetColor($labelStartState, 0xBF0000)
		GUICtrlSetState($buttonStartState, $GUI_ENABLE)
	Else
		GUICtrlSetData($labelStartState, "Je suis correctement prévu pour me lancer au démmarage de Windows")
		GUICtrlSetColor($labelStartState, 0x00BF00)
		GUICtrlSetState($buttonStartState, $GUI_DISABLE)
	EndIf

	$lastChange = BinaryToString(InetRead($lastChangeURL, 1))
	GUICtrlSetData($labelVersion, "Version installée: " & IniRead(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "version", $lastChange) & " | Version disponible: " & $lastChange)
	If $lastChange > IniRead(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "version", $lastChange) Then
		GUICtrlSetData($labelVersionState, "Une mise à jour est disponible !")
		GUICtrlSetColor($labelVersionState, 0x00BF00)
		GUICtrlSetFont($labelVersionState, -1, 800)
		GUICtrlSetData($buttonUpdate, "Effectuer une mise à jour de Chromium")
	Else
		GUICtrlSetData($labelVersionState, "Aucune mise à jour n'est disponible")
		GUICtrlSetColor($labelVersionState, 0x000000)
		GUICtrlSetFont($labelVersionState, -1, 400)
		GUICtrlSetData($buttonUpdate, "Ré-installer la dernière mise à jour de Chromium")
	EndIf
EndFunc   ;==>_UpdateGUI

Func _ForceUpdate()

	$guiMainVisible = False
	If WinGetState($guiMain) = 5 Then $guiMainVisible = True
	GUISetState(@SW_HIDE, $guiMain)

	$guiProgression = GUICreate("", 300, 30, @DesktopWidth - 320, @DesktopHeight - 80, BitOR($WS_POPUP, $WS_BORDER), $WS_EX_TOPMOST)
	$pic_ = GUICtrlCreatePic("", 0, 0, 300, 30)
	_ResourceSetImageToCtrl($pic_, "bg_mini")
	GUICtrlSetState(-1, 128)
	$progressBar = GUICtrlCreateProgress(40, 5, 205, 19)
	$labelProgress = GUICtrlCreateLabel("0%", 255, 8, 40, 20, $SS_CENTER)
	GUICtrlSetBkColor(-1, -2)
	GUISetState(@SW_SHOW)

	$lastChange = BinaryToString(InetRead($lastChangeURL, 1))
	$downloadURL_ = StringReplace($downloadURL, "%id", $lastChange)

	$iget_size = InetGetSize($downloadURL_)
	$iget = InetGet($downloadURL_, @AppDataDir & "\TinyChromiumUpdater\mini_installer.exe", 1, 1)

	Do
		$percent = Round(InetGetInfo($iget, 0) * 100 / $iget_size)
		GUICtrlSetData($labelProgress, $percent & "%")
		GUICtrlSetData($progressBar, $percent)
		Sleep(50)
	Until InetGetInfo($iget, 2)

	GUICtrlSetStyle($progressBar, 0x040A)
	_SendMessage(GUICtrlGetHandle($progressBar), 0x040A, True, 20)

	While ProcessExists("chrome.exe")
		ProcessClose("chrome.exe")
	WEnd
	RunWait(@AppDataDir & "\TinyChromiumUpdater\mini_installer.exe")

	IniWrite(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "version", $lastChange)
	GUIDelete($guiProgression)
	MsgBox(64, "Mise à jour terminée", "Chromium à été mis à jour avec succès")

	If $guiMainVisible Then GUISetState(@SW_SHOW, $guiMain)
	_UpdateGUI()

EndFunc   ;==>_ForceUpdate
#endregion == Fonctions liées à TinyChromiumUpdater

#region Fonction liée à AITray.dll
Func WM_TRAYNOTIFY($hWnd, $iMsg, $wParam, $lParam)
	Switch $hWnd
		Case $hForm
			If $lParam = $NIN_BALLOONUSERCLICK Then _ForceUpdate()
	EndSwitch
EndFunc   ;==>WM_TRAYNOTIFY
#endregion Fonction liée à AITray.dll
