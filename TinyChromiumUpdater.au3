#include <GUIConstantsEx.au3>
#include <SendMessage.au3>

#AutoIt3Wrapper_Icon=logo.ico
#AutoIt3Wrapper_Outfile=TinyChromiumUpdater.exe
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Description=TinyChromiumUpdater par mGeek
#AutoIt3Wrapper_Res_Fileversion=1.0
#AutoIt3Wrapper_Res_Language=1036
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker

#cs -----------------------------------------------------------------

	TinyChromiumUpdater 1.0
	par @mGeek_ - web: mgeek.fr
	(version Debian/Ubuntu codée par @_Drav disponible sur dravinux.legtux.org)

	changelog-
	1.0
	Nettoyage du code / Nouveau design
	Mode silencieux fonctionnel
	Puis voilà.
	0.4
	Mode silencieux
	Correction d'une autre faute d'orthographe (merci @ThePoivron) *_*
	0.31
	Correction d'une faute d'orthographe (merci @ThePoivron)
	0.3 - VERSION STABLE
	Ajout de commentaires
	Optimisation de AITray.dll (x32 et x64)
	0.2
	Correction de l'intégration des backgrounds
	Problème de fermeture réglé / Ajout d'un singleTon pour prévenir les multi-ouvertures
	Fonctionnel sur x64
	Rangement du code
	0.11
	Correction d'un problème lié au Tooltip (x32)
	Recherche de mise à jour des le lancement
	0.1

#ce -----------------------------------------------------------------

Global $checkbox_discret
;_Singleton("TinyChromiumUpdater") ;Permet d'empécher de lancer plusieurs fois le logiciel

Opt("TrayMenuMode", 1)
Opt("TrayAutoPause", 0)
Opt('WinTitleMatchMode', 3) ;Pour AITray.dll
Opt('WinWaitDelay', 0) ;Pour AITray.dll

$lastChangeURL = "http://commondatastorage.googleapis.com/chromium-browser-continuous/Win/LAST_CHANGE"
$downloadURL = "http://commondatastorage.googleapis.com/chromium-browser-continuous/Win/%id/mini_installer.exe"

DirCreate(@AppDataDir & "\TinyChromiumUpdater")
If Not FileExists(@AppDataDir & "\TinyChromiumUpdater\config") Then

	GUICreate("TinyChromiumUpdater", 300, 135)
	GUISetBkColor(0xFFFFFF)
	GUISetFont(9, 400, 0, "Segoe UI")

	GUICtrlCreateLabel("Bienvenue !", 10, 10, 300, 25)
	GUICtrlSetFont(-1, 13)
	GUICtrlSetColor(-1, 0x338CE0)

	GUICtrlCreateLabel("Pour le premier lancement, il faut obligatoirement effectuer une première mise à jour de Chromium.", 15, 40, 300, 30)

	GUICtrlCreateLabel("", 0, 90, 300, 45)
	GUICtrlSetBkColor(-1, 0xF0F0F0)
	GUICtrlSetState(-1, $GUI_DISABLE)

	GUICtrlCreateLabel("", 0, 90, 300, 1)
	GUICtrlSetBkColor(-1, 0xB9B9B9)

	$button_start = GUICtrlCreateButton("Commencer", 190, 100, 100, 25)
	GUISetState(@SW_SHOW)

	While 1
		Switch GUIGetMsg()
			Case -3
				Exit
			Case $button_start
				GUIDelete()
				_Update()
				ExitLoop
		EndSwitch
	WEnd
EndIf

#region == Création de la fenêtre

$gui = GUICreate("TinyChromiumUpdater", 245, 200)
GUISetBkColor(0xFFFFFF)
GUISetFont(9, 400, 0, "Segoe UI")

GUICtrlCreateLabel("TinyChromiumUpdater", 10, 5, 245, 30)
GUICtrlSetFont(-1, 15)
GUICtrlSetColor(-1, 0x338CE0)

GUICtrlCreateLabel("Dernière version installée :", 40 - 1, 48, 140, 17)
$installed_build = GUICtrlCreateLabel("150032", 180, 48, 45, 20)
GUICtrlSetFont(-1, 9, 800)

GUICtrlCreateLabel("Version disponible sur internet :", 10, 72, 167, 17)
$internet_build = GUICtrlCreateLabel("150034", 180, 72, 45, 20)
GUICtrlSetFont(-1, 9, 800)

$button_forceupdate = GUICtrlCreateButton("Forcer la mise à jour", 40, 96, 163, 25)

$checkbox_startwindows = GUICtrlCreateCheckbox("Lancer au démarrage de Windows", 16, 136, 201, 17)
$checkbox_discret = GUICtrlCreateCheckbox("Faire la mise à jour sans demander", 16, 160, 201, 17)
If IniRead(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "silent", "false") = "true" Then GUICtrlSetState(-1, $GUI_CHECKED)

_UpdateGUI()

If $CmdLine[0] <> 0 And $CmdLine[1] = "-s" Then
Else
	GUISetState(@SW_SHOW, $gui)
EndIf

$tShow = TrayCreateItem("Afficher / Cacher")
$tExit = TrayCreateItem("Quitter")
TraySetState()
TraySetToolTip("TinyChromiumUpdater")

_CheckVersion()
$timerCheckVersion = TimerInit()

While 1

	Switch GUIGetMsg()
		Case -3
			GUISetState(@SW_HIDE, $gui)

		Case $checkbox_startwindows
			If IsAdmin() Then
				RegWrite("HKLM\Software\Microsoft\Windows\CurrentVersion\Run\", "TinyChromiumUpdater", "REG_SZ", @ScriptFullPath & " -s")
				_UpdateGUI()
			Else
				MsgBox(48, "Erreur", "Relancez TinyChromiumUpdater en mode administrateur pour pouvoir activer cette option")
			EndIf

		Case $button_forceupdate
			_ForceUpdate()

		Case $checkbox_discret
			If GUICtrlRead($checkbox_discret) = $GUI_CHECKED Then
				IniWrite(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "silent", "true")
			Else
				IniWrite(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "silent", "false")
			EndIf
	EndSwitch

	Switch TrayGetMsg()
		Case $tShow
			If WinGetState($gui) <> 5 Then
				GUISetState(@SW_HIDE, $gui)
			Else
				GUISetState(@SW_SHOW, $gui)
			EndIf
			TrayItemSetState($tShow, $GUI_UNCHECKED)
		Case $tExit
			If MsgBox(36, "Quitter", "Êtes-vous sur de vouloir quitter TinyChromiumUpdater ?") = 6 Then Exit

	EndSwitch

	If TimerDiff($timerCheckVersion) > 300000 Then ;5 minutes
	;If TimerDiff($timerCheckVersion) > 5000 Then ;10 secondes (pour le debug)
		ConsoleWrite("lol")
		_CheckVersion()
		$timerCheckVersion = TimerInit()
	EndIf

	Sleep(10)
WEnd
#endregion == Création de la fenêtre

#region == Fonctions liées à TinyChromiumUpdater
Func _CheckVersion()
	$build = BinaryToString(InetRead($lastChangeURL))
	If $build > IniRead(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "version", $build) Then
		If GUICtrlRead($checkbox_discret) = $GUI_CHECKED Then
			_forceUpdate()
		Else
			If MsgBox(36, "TinyChromiumUpdater", "Une mise à jour de Chromium est disponible ! Voulez-vous l'installer ?") = 6 Then _forceUpdate()
		EndIf
	EndIf
	Return $build
EndFunc   ;==>_CheckVersion

Func _UpdateGUI()
	If Not RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\Run\", "TinyChromiumUpdater") = @ScriptFullPath & " -s" Then
	Else
		GUICtrlSetState($checkbox_startwindows, $GUI_CHECKED)
		GUICtrlSetState($checkbox_startwindows, $GUI_DISABLE)
	EndIf

	$build = BinaryToString(InetRead($lastChangeURL))
	GUICtrlSetData($installed_build, IniRead(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "version", $build))
	GUICtrlSetData($internet_build, $build)
EndFunc   ;==>_UpdateGUI

Func _forceupdate()
	GUISetState(@SW_HIDE, $gui)
	_Update()
	GUISetState(@SW_SHOW, $gui)
	_UpdateGUI()
EndFunc   ;==>_forceupdate

Func _Update()

	$build = BinaryToString(InetRead($lastChangeURL))

	GUICreate("TinyChromiumUpdater", 300 - 10, 145)
	GUISetBkColor(0xFFFFFF)
	GUISetFont(9, 400, 0, "Segoe UI")

	GUICtrlCreateLabel("Mise à jour de Chromium", 10, 10, 300, 25)
	GUICtrlSetFont(-1, 13)
	GUICtrlSetColor(-1, 0x338CE0)

	$state = GUICtrlCreateLabel("Téléchargement de", 25, 40, 200, 20)
	$gras = GUICtrlCreateLabel("Chromium (build " & $build & ")", 135, 40, 200, 20)
	GUICtrlSetFont(-1, 9, 800)

	$progress = GUICtrlCreateProgress(25, 65, 220, 17)
	$label_percent = GUICtrlCreateLabel("0%", 250, 65, 30, 20)

	GUICtrlCreateLabel("", 15, 40, 1, 45)
	GUICtrlSetBkColor(-1, 0xB9B9B9)

	GUICtrlCreateLabel("", 0, 100, 300, 45)
	GUICtrlSetBkColor(-1, 0xF0F0F0)
	GUICtrlSetState(-1, $GUI_DISABLE)

	GUICtrlCreateLabel("", 0, 100, 300, 1)
	GUICtrlSetBkColor(-1, 0xB9B9B9)

	$button_finish = GUICtrlCreateButton("Terminé", 210, 110, 70, 25)
	GUICtrlSetState(-1, $GUI_DISABLE)
	If GUICtrlRead($checkbox_discret) = $GUI_CHECKED Then
		GUISetState()
		GUISetState(@SW_MINIMIZE)
	Else
		GUISetState()
	EndIf
	$URL = StringReplace($downloadURL, "%id", $build)

	$iget_size = InetGetSize($URL)
	$iget = InetGet($URL, @AppDataDir & "\TinyChromiumUpdater\mini_installer.exe", 1, 1)

	Do
		$percent = Round(InetGetInfo($iget, 0) * 100 / $iget_size)
		GUICtrlSetData($label_percent, $percent & "%")
		GUICtrlSetData($progress, $percent)
		Sleep(50)
	Until InetGetInfo($iget, 2)

	GUICtrlSetStyle($progress, 0x040A)
	_SendMessage(GUICtrlGetHandle($progress), 0x040A, True, 20)

	If GUICtrlRead($checkbox_discret) = $GUI_CHECKED Then
		GUICtrlDelete($gras)
		GUICtrlSetData($state, "Attente de la fermeture de Chromium")
		While ProcessExists("chrome.exe")
			Sleep(100)
		WEnd
	Else
		GUICtrlDelete($gras)
		GUICtrlSetData($state, "Installation de Chromium")
		If ProcessExists("chrome.exe") Then MsgBox(64, "TinyChromiumUpdater", "Fermez Chromium, et cliquez sur OK pour continuer la mise à jour")
		While ProcessExists("chrome.exe")
			ProcessClose("chrome.exe")
		WEnd
	EndIf

	GUICtrlSetData($state, "Attente de la fermeture de Chromium")
	RunWait(@AppDataDir & "\TinyChromiumUpdater\mini_installer.exe")

	IniWrite(@AppDataDir & "\TinyChromiumUpdater\config", "Chromium", "version", $build)
	GUIDelete()

	MsgBox(64, "Mise à jour terminée", "Chromium à été mis à jour avec succès.")

EndFunc   ;==>_Update
#endregion == Fonctions liées à TinyChromiumUpdater
