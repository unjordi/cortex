# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-send-keys.ps1  -  Envia TECLAS a la sesion interactiva del usuario, POR SSH.
  ==================================================================================================
  Complemento de entrada (junto con win-ssh-send-click.ps1). La sesion SSH corre en otra logon-session
  que la consola -> se despacha el tecleo a la SESION INTERACTIVA con `schtasks /IT`, via WScript.Shell
  SendKeys. Opcionalmente enfoca una ventana por titulo (AppActivate) antes de teclear.
  VERIFICADO 2026-08-27 (estacion de prueba real): una tecla enviada disparo el OSD del sistema "Bloq numerico".

  SINTAXIS DE -Keys (WScript.Shell SendKeys):
    texto normal se teclea literal;  {ENTER} {TAB} {ESC} {BACKSPACE} {DEL} {F5} {UP}{DOWN}{LEFT}{RIGHT}
    modificadores: + = Shift, ^ = Ctrl, % = Alt  (ej. "^a" = Ctrl+A ; "%{F4}" = Alt+F4)
    caracteres reservados a escapar con llaves: {+}{^}{%}{~}{(}{)}{[}{]}{{}{}}

  USO (por SSH; correr COMO admin, con un usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-send-keys.ps1 -Keys "usuario{TAB}clave{ENTER}"
    ... -File win-ssh-send-keys.ps1 -Keys "N" -Window "MiApp - Herramienta"
    ... -File win-ssh-send-keys.ps1 -Keys "%{F4}"                                 # Alt+F4 (cerrar ventana activa)
    ... -Keys "^a{DEL}\\servidor\Recurso" -ClickX 701 -ClickY 451                          # CLIC (foco) + teclea, MISMO proceso

  -ClickX/-ClickY (coords de PANTALLA de Windows, las que da `win-ssh-read-uia -WithRect`): hace un clic
  izquierdo AHI y LUEGO teclea, TODO en el mismo proceso -> el foco NO se pierde (un click y un send-keys
  en schtasks /IT SEPARADOS pierden el foco entre uno y otro; por eso campos custom no recibian el tecleo).

  EXIT: 0 si despacho las teclas; 1 si no hay sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Keys,
    [string]$Window,                       # titulo de ventana a enfocar antes de teclear (AppActivate)
    [int]$ClickX = -1,                     # si >=0: clic izquierdo en (ClickX,ClickY) ANTES de teclear, mismo proceso
    [int]$ClickY = -1,
    [string]$User,                         # dominio\usuario de consola; default = el logueado
    [string]$WorkDir = 'C:\GuiSshWork',         # carpeta de trabajo SIN espacios (para el .ps1 temporal)
    [int]$WaitMs = 1200
)
if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }

function Get-ConsoleUser {
    if ($User) { return $User }
    foreach ($l in (quser 2>$null)) {
        if ($l -match '^\s*>?(\S+)\s+console\s') { return "$env:COMPUTERNAME\$($Matches[1])" }
    }
    $ex = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -EA SilentlyContinue | Select-Object -First 1
    if ($ex) { $o = Invoke-CimMethod -InputObject $ex -MethodName GetOwner; return "$($o.Domain)\$($o.User)" }
    return $null
}

$ru = Get-ConsoleUser
if (-not $ru) { Write-Host "SIN sesion de consola activa -> no hay donde teclear"; exit 1 }

# pasamos texto y titulo por base64 para no pelear con comillas/acentos a traves de SSH+schtasks
$kb = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Keys))
$focus = ''
if ($Window) {
    $wb = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Window))
    $focus = "[void]`$ws.AppActivate([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))); Start-Sleep -Milliseconds 400"
}

$clickCode = ''
if ($ClickX -ge 0 -and $ClickY -ge 0) {
    $clickCode = @"
Add-Type -Name Mou -Namespace Cur -MemberDefinition '[DllImport(\"user32.dll\")] public static extern bool SetCursorPos(int x,int y); [DllImport(\"user32.dll\")] public static extern void mouse_event(uint f,uint x,uint y,uint d,int e);'
[Cur.Mou]::SetCursorPos($ClickX,$ClickY); Start-Sleep -Milliseconds 200
[Cur.Mou]::mouse_event(2,0,0,0,0); [Cur.Mou]::mouse_event(4,0,0,0,0); Start-Sleep -Milliseconds 400
"@
}
$body = @"
`$ws = New-Object -ComObject WScript.Shell
$focus
$clickCode
`$k = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$kb'))
`$ws.SendKeys(`$k)
"@

$f = Join-Path $WorkDir 'sk-keys.ps1'
$body | Set-Content $f -Encoding UTF8

$tn = 'SK_KEYS'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null

Write-Host ("OK teclas enviadas (usuario {0})" -f $ru)
exit 0
