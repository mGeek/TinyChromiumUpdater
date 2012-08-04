#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=logo.ico
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Description=TinyChromiumUpdater par mGeek
#AutoIt3Wrapper_Res_Fileversion=0.1.0.0
#AutoIt3Wrapper_Res_Language=1036
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Res_File_Add=res\bg-body.jpg, rt_rcdata, bg_body
#AutoIt3Wrapper_Res_File_Add=res\bg-mini.jpg, rt_rcdata, bg_mini
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <Constants.au3>
#include <WinAPI.au3>
#include "res\Resources.au3"

Opt("TrayMenuMode", 1)
Opt("TrayAutoPause", 0)
Opt('WinTitleMatchMode', 3)
Opt('WinWaitDelay', 0)

$lastChangeURL = "http://commondatastorage.googleapis.com/chromium-browser-continuous/Win/LAST_CHANGE"
$downloadURL = "http://commondatastorage.googleapis.com/chromium-browser-continuous/Win/%id/mini_installer.exe"
Global $trayTest = 0, $handleProc, $handleProcOld, $handle, $trayClicked

Global Const $NIN_BALLOONSHOW = $WM_USER + 2
Global Const $NIN_BALLOONHIDE = $WM_USER + 3
Global Const $NIN_BALLOONUSERCLICK = $WM_USER + 5
Global Const $NIN_BALLOONTIMEOUT = $WM_USER + 4

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
	MsgBox(16, "Erreur", "Erreur fatale li�e � la DLL AITray.dll")
	Exit
EndIf

GUIRegisterMsg($WM_USER + 1, 'WM_TRAYNOTIFY')

If Not FileExists("cfg") Then IniWrite("cfg", "Chromium", "version", "0")

;Fen�tre
$guiMain = GUICreate("TinyChromiumUpdater", 300, 250)
$pic_ = GUICtrlCreatePic("", 0, 0, 300, 250)
_ResourceSetImageToCtrl($pic_, "bg_body")
GUICtrlSetState(-1, 128)

GUICtrlCreateLabel("version 0.1", 150, 235, 145, 20, $SS_RIGHT)
GUICtrlSetBkColor(-1, -2)
GUICtrlSetColor(-1, 0xFFFFFF)

GUICtrlCreateLabel("Cr�� par mGeek", 5, 235, 85, 20)
GUICtrlSetBkColor(-1, -2)
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlSetCursor(-1, 0)

$labelStartState = GUICtrlCreateLabel("", 10, 50, 280, 30, $SS_CENTER)
GUICtrlSetBkColor(-1, -2)

$buttonStartState = GUICtrlCreateButton("Lancer au d�mmarage de Windows", 30, 85, 240, 23)
GUICtrlSetBkColor(-1, -2)
GUICtrlSetState(-1, 128)

;S�parateur
GUICtrlCreateLabel("", 10, 120, 280, 1)
GUICtrlSetBkColor(-1, 0xCCCCCC)

$labelVersion = GUICtrlCreateLabel("", 10, 130, 280, 20, $SS_CENTER)
GUICtrlSetBkColor(-1, -2)

$labelVersionState = GUICtrlCreateLabel("", 10, 150, 280, 20, $SS_CENTER)
GUICtrlSetBkColor(-1, -2)

$buttonUpdate = GUICtrlCreateButton("", 30, 175, 240, 23)

_UpdateGUI()

If $CmdLine[0] <> 0 And $CmdLine[1] = "-s" Then
Else
	GUISetState(@SW_SHOW)
EndIf

$tShow = TrayCreateItem("Afficher / Cacher")
$tExit = TrayCreateItem("Quitter")
TraySetState()
TraySetToolTip("TinyChromiumUpdater 0.1")

_CheckVersion()
$timerCheckVersion = TimerInit()
While 1
	Switch GUIGetMsg()
		Case -3
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
			If MsgBox(36, "Quitter TinyChromiumUpdater", "�tes vous sur de vouloir me d�sactiver ?" & @CRLF & "Vous ne receverez plus les mises � jours de Chromium tant que vous ne me relancerez pas..") = 6 Then
				DllCall($hDll, 'int', 'AIRemoveTrayRedirection')
				DllClose($hDll)
				Exit
			EndIf
			TrayItemSetState($tExit, $GUI_UNCHECKED)
	EndSwitch

	;If TimerDiff($timerCheckVersion) > 300000 Then ;5 minutes
	If TimerDiff($timerCheckVersion) > 10000 Then ;10 secondes
		_CheckVersion()
		$timerCheckVersion = TimerInit()
	EndIf

	Sleep(10)
WEnd

Func _CheckVersion()
	$lastChange = BinaryToString(InetRead($lastChangeURL, 1))
	If $lastChange > IniRead("cfg", "Chromium", "version", $lastChange) Then
		;Une mise � jour est requise
		TrayTip("Tiny Chromium Updater", "Une mise � jour de Chromium est disponible !" & @CRLF & "Cliquez sur ce message pour l'installer.", 1)
		_UpdateGUI()
	EndIf
	Return $lastChange
EndFunc   ;==>_CheckVersion

Func _UpdateGUI()
	If Not RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\Run\", "TinyChromiumUpdater") = @ScriptFullPath & " -s" Then
		GUICtrlSetData($labelStartState, "Je ne suis pas assign� au d�mmarage de Windows, cliquez sur le bouton ci-dessous pour m'associer :")
		GUICtrlSetColor($labelStartState, 0xBF0000)
		GUICtrlSetState($buttonStartState, $GUI_ENABLE)
	Else
		GUICtrlSetData($labelStartState, "Je suis correctement pr�vu pour me lancer au d�mmarage de Windows")
		GUICtrlSetColor($labelStartState, 0x00BF00)
		GUICtrlSetState($buttonStartState, $GUI_DISABLE)
	EndIf

	$lastChange = BinaryToString(InetRead($lastChangeURL, 1))
	GUICtrlSetData($labelVersion, "Version install�e: " & IniRead("cfg", "Chromium", "version", $lastChange) & " | Version disponible: " & $lastChange)
	If $lastChange > IniRead("cfg", "Chromium", "version", $lastChange) Then
		GUICtrlSetData($labelVersionState, "Une mise � jour est disponible !")
		GUICtrlSetColor($labelVersionState, 0x00BF00)
		GUICtrlSetFont($labelVersionState, -1, 800)
		GUICtrlSetData($buttonUpdate, "Effectuer une mise � jour de Chromium")
	Else
		GUICtrlSetData($labelVersionState, "Aucune mise � jour n'est disponible")
		GUICtrlSetColor($labelVersionState, 0x000000)
		GUICtrlSetFont($labelVersionState, -1, 400)
		GUICtrlSetData($buttonUpdate, "R�-installer la derni�re mise � jour de Chromium")
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
	$iget = InetGet($downloadURL_, "mini_installer.exe", 1, 1)

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
	RunWait("mini_installer.exe")

	IniWrite("cfg", "Chromium", "version", $lastChange)
	GUIDelete($guiProgression)
	MsgBox(64, "Mise � jour termin�e", "Chromium � �t� mis � jour avec succ�s")

	If $guiMainVisible Then GUISetState(@SW_SHOW, $guiMain)
	_UpdateGUI()

EndFunc   ;==>_ForceUpdate

Func WM_TRAYNOTIFY($hWnd, $iMsg, $wParam, $lParam)
	Switch $hWnd
		Case $hForm
			Switch $lParam
				Case $NIN_BALLOONSHOW
					ConsoleWrite('Balloon tip show.' & @CR)
				Case $NIN_BALLOONHIDE
					ConsoleWrite('Balloon tip hide.' & @CR)
				Case $NIN_BALLOONUSERCLICK
					_ForceUpdate()
				Case $NIN_BALLOONTIMEOUT
					ConsoleWrite('Balloon tip close.' & @CR)
			EndSwitch
	EndSwitch
EndFunc   ;==>WM_TRAYNOTIFY
