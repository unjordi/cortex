# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-read-uia.ps1  -  Lee el texto de una ventana por UI AUTOMATION (dialogos modernos), POR SSH.
  ==================================================================================================
  Complemento de win-ssh-read-text.ps1 (que usa EnumChildWindows clasico). Los dialogos MODERNOS
  (TaskDialog / DirectUIHWND, como los de la app objetivo: "no se encuentra servidor", "limite de usuarios")
  NO exponen su mensaje como control Win32 clasico -> read-text solo ve los botones. UI Automation SI
  lee ese texto (recorre el arbol de AutomationElements y saca la propiedad Name de cada nodo).
  Se despacha a la SESION INTERACTIVA con `schtasks /IT`.

  USO (por SSH; admin + usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-read-uia.ps1 -Window "Error"
    ... -Window "MiApp"            # el titulo que CONTENGA esto
    ... -Window "Error" -WithType      # antepone el ControlType de cada texto (Text/Button/Edit...)
    ... -Window "MiApp" -WithRect      # antepone "cx,cy" (CENTRO del control en coords de PANTALLA de
                                       #   Windows) -> se pasan TAL CUAL a win-ssh-send-click -X -Y.
                                       #   Incluye controles SIN Name (Edit vacios, etc.) para tener sus
                                       #   coords. ASI YA NO SE ADIVINAN coords del noVNC (que no mapea
                                       #   1:1 a la resolucion nativa): pides el rect y clicas exacto.

  Salida: una linea por elemento (Name no vacio; o TODOS con -WithRect). Con -WithRect: "cx,cy<TAB>Type: Name".
  EXIT: 0 hallo la ventana; 1 no la encontro / sin sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Window,
    [switch]$WithType,
    [switch]$WithRect,
    [string]$User,
    [string]$WorkDir = 'C:\GuiSshWork',
    [int]$WaitMs = 2500
)
if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }
function Get-ConsoleUser {
    if ($User) { return $User }
    foreach ($l in (quser 2>$null)) { if ($l -match '^\s*>?(\S+)\s+console\s') { return "$env:COMPUTERNAME\$($Matches[1])" } }
    $ex = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -EA SilentlyContinue | Select-Object -First 1
    if ($ex) { $o = Invoke-CimMethod -InputObject $ex -MethodName GetOwner; return "$($o.Domain)\$($o.User)" }
    return $null
}
$ru = Get-ConsoleUser
if (-not $ru) { Write-Host "SIN sesion de consola activa"; exit 1 }
$wb  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Window))
$res = Join-Path $WorkDir 'uia-result.txt'
$wt  = if ($WithType) { '$true' } else { '$false' }
$wr  = if ($WithRect) { '$true' } else { '$false' }
$body = @"
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
`$needle=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))
`$withType=$wt
`$withRect=$wr
`$root=[System.Windows.Automation.AutomationElement]::RootElement
`$true1=[System.Windows.Automation.Condition]::TrueCondition
`$wins=`$root.FindAll([System.Windows.Automation.TreeScope]::Children,`$true1)
`$target=`$null
foreach(`$w in `$wins){ try { `$nm=`$w.Current.Name } catch { `$nm='' }; if(`$nm -and `$nm.ToLower().Contains(`$needle.ToLower())){ `$target=`$w; break } }
`$out=New-Object System.Collections.ArrayList
if(`$null -eq `$target){ [void]`$out.Add("__NOTFOUND__") }
else {
  [void]`$out.Add("VENTANA: "+`$target.Current.Name)
  `$all=`$target.FindAll([System.Windows.Automation.TreeScope]::Descendants,`$true1)
  foreach(`$e in `$all){
    try { `$n=`$e.Current.Name } catch { `$n='' }
    `$t=''; try { `$t=`$e.Current.ControlType.ProgrammaticName -replace '^ControlType\.','' } catch {}
    if(`$withRect){
      try { `$r=`$e.Current.BoundingRectangle } catch { `$r=`$null }
      if(`$r -and `$r.Width -gt 0 -and `$r.Width -lt 100000){ `$cx=[int](`$r.X+`$r.Width/2); `$cy=[int](`$r.Y+`$r.Height/2); [void]`$out.Add(("{0},{1}`t{2}: {3}" -f `$cx,`$cy,`$t,`$n)) }
    } elseif(`$n){ if(`$withType){ [void]`$out.Add(`$t+": "+`$n) } else { [void]`$out.Add(`$n) } }
  }
}
Set-Content '$res' (`$out -join "`n") -Encoding UTF8
"@
$f = Join-Path $WorkDir 'uia.ps1'; $body | Set-Content $f -Encoding UTF8
if (Test-Path $res) { Remove-Item $res -Force }
$tn = 'WUIA'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -STA -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null
if (-not (Test-Path $res)) { Write-Host "FALLO: sin resultado"; exit 1 }
$c = Get-Content $res
if ($c -contains '__NOTFOUND__') { Write-Host "no encontre ventana (UIA) con titulo que contenga '$Window'"; exit 1 }
$c | ForEach-Object { $_ }
exit 0
