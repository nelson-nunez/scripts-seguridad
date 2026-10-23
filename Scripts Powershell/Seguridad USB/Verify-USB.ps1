<#
.SYNOPSIS
  Verifica que Secure-USB.ps1 haya aplicado todos los cambios (version 2).
.PARAMETER DenyWrite
  Comprueba tambien que la escritura en USB este bloqueada (usa si aplicaste -DenyWrite).
.NOTES
  - Se auto-eleva a administrador (acepta el aviso UAC).
  - La ventana NO se cierra sola: al final pide pulsar Enter.
  - Guarda el informe en Verify-USB-resultado.txt (misma carpeta del script).
  - Archivo en ASCII puro a proposito (evita errores de codificacion en PowerShell 5.1).
#>
[CmdletBinding()]
param([switch]$DenyWrite)

$ErrorActionPreference = 'Continue'
$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# ---------------------------------------------------------------
#  Auto-elevacion
# ---------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Se necesitan permisos de administrador. Solicitando elevacion (UAC)..." -ForegroundColor Yellow
    if (-not $PSCommandPath) {
        Write-Host "No puedo auto-elevarme. Abre PowerShell como administrador y ejecuta el script de nuevo." -ForegroundColor Red
        Read-Host "Pulsa Enter para cerrar"
        exit 1
    }
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($DenyWrite) { $argList += ' -DenyWrite' }
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    } catch {
        Write-Host "No se pudo elevar: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Pulsa Enter para cerrar"
    }
    exit
}

$LogResult = Join-Path $here 'Verify-USB-resultado.txt'
try { Start-Transcript -Path $LogResult -Force | Out-Null } catch { $LogResult = '(no se pudo crear el informe)' }

$script:ok = 0; $script:fail = 0; $script:warn = 0
$script:failed = New-Object System.Collections.ArrayList

function Result($name, $pass, $detail = '', $isWarn = $false) {
    if ($pass) {
        Write-Host "  [ OK ]  $name" -ForegroundColor Green
        $script:ok++
    } elseif ($isWarn) {
        Write-Host "  [WARN]  $name  $detail" -ForegroundColor Yellow
        $script:warn++
    } else {
        Write-Host "  [FAIL]  $name  $detail" -ForegroundColor Red
        $script:fail++
        [void]$script:failed.Add($name)
    }
}
function Section($t) { Write-Host "`n== $t ==" -ForegroundColor Cyan }
function Get-Reg($path, $name) {
    try { (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name } catch { $null }
}
function Check-Reg($label, $path, $name, $expected, $isWarn = $false) {
    $v = Get-Reg $path $name
    $shown = if ($null -eq $v) { 'no definido' } else { $v }
    Result $label ($v -eq $expected) "(actual: $shown, esperado: $expected)" $isWarn
}

$ExplorerPol  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Policies\Explorer'
$ExplorerPol2 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
$RemovablePol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}'
$AsrUsbRule   = 'b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4'

try {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  VERIFICACION DE SEGURIDAD USB" -ForegroundColor Cyan
    Write-Host "  Usuario: $env:USERDOMAIN\$env:USERNAME   Equipo: $env:COMPUTERNAME" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # -----------------------------------------------------------
    Section "1. AutoRun / AutoPlay"
    Check-Reg "NoDriveTypeAutoRun = 255 (HKLM Policies)"   $ExplorerPol2 'NoDriveTypeAutoRun' 255
    Check-Reg "NoDriveTypeAutoRun = 255 (directiva grupo)" $ExplorerPol  'NoDriveTypeAutoRun' 255
    Check-Reg "NoAutoplayfornonVolume = 1"                 $ExplorerPol2 'NoAutoplayfornonVolume' 1
    Check-Reg "Servicio cdrom AutoRun = 0" 'HKLM:\SYSTEM\CurrentControlSet\Services\cdrom' 'AutoRun' 0
    Check-Reg "AutoPlay desactivado (usuario actual)" 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' 'DisableAutoplay' 1

    # -----------------------------------------------------------
    Section "2. Bloqueo de ejecucion en discos extraibles"
    Check-Reg "Deny_Execute = 1" $RemovablePol 'Deny_Execute' 1
    $dw = Get-Reg $RemovablePol 'Deny_Write'
    if ($DenyWrite) {
        Result "Deny_Write = 1 (solo lectura)" ($dw -eq 1) "(actual: $(if($null -eq $dw){'no definido'}else{$dw}))"
    } else {
        Result "Escritura en USB permitida (Deny_Write no activo)" ($dw -ne 1) "(Deny_Write esta activo; usa -DenyWrite si es intencionado)" $true
    }

    # -----------------------------------------------------------
    Section "3. Microsoft Defender"
    if (-not (Get-Command Get-MpPreference -ErrorAction SilentlyContinue)) {
        Result "Modulo de Defender disponible" $false "(Get-MpPreference no existe; hay otro antivirus?)"
    } else {
        try {
            $pref   = Get-MpPreference -ErrorAction Stop
            $status = Get-MpComputerStatus -ErrorAction Stop

            Result "Antivirus de Defender activo"               ($status.AntivirusEnabled)
            Result "Proteccion en tiempo real"                  ($status.RealTimeProtectionEnabled)
            Result "Proteccion en la nube (MAPS = Advanced)"    ($pref.MAPSReporting -eq 2) "(actual: $($pref.MAPSReporting))"
            Result "Bloqueo en la nube = High"                  ($pref.CloudBlockLevel -eq 2) "(actual: $($pref.CloudBlockLevel))"
            Result "PUA Protection activada"                    ($pref.PUAProtection -eq 1) "(actual: $($pref.PUAProtection))"
            Result "Escaneo de unidades extraibles habilitado"  (-not $pref.DisableRemovableDriveScanning)
            Result "Network Protection activada"                ($pref.EnableNetworkProtection -eq 1) "(actual: $($pref.EnableNetworkProtection))"

            $ids = @($pref.AttackSurfaceReductionRules_Ids | ForEach-Object { "$_".ToLower() })
            $i = [array]::IndexOf($ids, $AsrUsbRule)
            $act = if ($i -ge 0) { @($pref.AttackSurfaceReductionRules_Actions)[$i] } else { $null }
            Result "Regla ASR USB en modo Block" ($act -eq 1) "(actual: $(if($null -eq $act){'no configurada'}else{$act}))"

            Result "Tamper Protection activada" ($status.IsTamperProtected) "(activala a mano en Seguridad de Windows)" $true

            $sigAge = (New-TimeSpan -Start $status.AntivirusSignatureLastUpdated -End (Get-Date)).TotalDays
            Result "Firmas actualizadas (menos de 3 dias)" ($sigAge -lt 3) "(ultima actualizacion hace $([math]::Round($sigAge,1)) dias)" $true
        } catch {
            Result "Lectura de Defender" $false "($($_.Exception.Message))"
        }
    }
    Check-Reg "SmartScreen habilitado" 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 1
    Check-Reg "SmartScreen nivel Block" 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'ShellSmartScreenLevel' 'Block'

    # -----------------------------------------------------------
    Section "4. Escaneo automatico al conectar USB"
    Result "Existe C:\Scripts\UsbScan.ps1" (Test-Path 'C:\Scripts\UsbScan.ps1')

    $task = Get-ScheduledTask -TaskName 'UsbScan' -ErrorAction SilentlyContinue
    Result "Tarea programada 'UsbScan' registrada" ($null -ne $task)
    if ($task) {
        Result "Tarea con privilegios altos" ($task.Principal.RunLevel -eq 'Highest')
        $logon = $task.Triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger' }
        Result "Disparador: al iniciar sesion" ([bool]$logon)
        Result "Vigilante en ejecucion ahora" ($task.State -eq 'Running') "(estado: $($task.State); se iniciara al proximo inicio de sesion)" $true
    }
    if (Test-Path 'C:\Scripts\usbscan.log') {
        $last = Get-Content 'C:\Scripts\usbscan.log' -Tail 1
        Write-Host "         Ultima linea del log: $last" -ForegroundColor DarkGray
    } else {
        Result "Existe el log C:\Scripts\usbscan.log" $false "(se crea al iniciar el vigilante)" $true
    }
    if (Test-Path 'C:\Scripts') {
        $acl = (icacls 'C:\Scripts') -join ' '
        $weak = ($acl -match 'BUILTIN\\Users:\(.*(F|M|W)\)') -or ($acl -match 'Everyone')
        Result "Carpeta C:\Scripts sin escritura para usuarios normales" (-not $weak)
    }

    # -----------------------------------------------------------
    Section "5. Explorador y Office"
    $adv    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $expPol = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    Check-Reg "Extensiones de archivo visibles"      $adv 'HideFileExt' 0
    Check-Reg "Archivos ocultos visibles"            $adv 'Hidden' 1
    Check-Reg "Panel de vista previa desactivado"    $expPol 'NoPreviewPane' 1
    Check-Reg "Panel de lectura desactivado"         $expPol 'NoReadingPane' 1
    foreach ($app in 'word', 'excel', 'powerpoint') {
        $p = "HKCU:\Software\Policies\Microsoft\Office\16.0\$app\security"
        Check-Reg "Office ${app}: bloquear contenido de internet" $p 'blockcontentexecutionfrominternet' 1 $true
        Check-Reg "Office ${app}: macros deshabilitadas"          $p 'vbawarnings' 4 $true
    }

    # -----------------------------------------------------------
    Section "6. Informacion adicional"
    $usb = Get-Disk -ErrorAction SilentlyContinue | Where-Object BusType -eq 'USB'
    if ($usb) {
        Write-Host "  Discos USB conectados ahora:" -ForegroundColor DarkGray
        $usb | ForEach-Object { Write-Host "    - $($_.FriendlyName) ($([math]::Round($_.Size/1GB,1)) GB)" -ForegroundColor DarkGray }
    } else {
        Write-Host "  No hay discos USB conectados." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "`nERROR INESPERADO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    $script:fail++
} finally {
    Write-Host "`n================== RESUMEN ==================" -ForegroundColor Cyan
    $color = if ($script:fail) { 'Red' } elseif ($script:warn) { 'Yellow' } else { 'Green' }
    Write-Host "  OK: $script:ok    Avisos: $script:warn    Fallos: $script:fail" -ForegroundColor $color
    if ($script:failed.Count -gt 0) {
        Write-Host "  Pasos con fallo:" -ForegroundColor Red
        $script:failed | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        Write-Host "  Ejecuta de nuevo Secure-USB.ps1 y reinicia el equipo." -ForegroundColor Red
    } elseif ($script:warn -gt 0) {
        Write-Host "  Lo esencial esta aplicado; revisa los avisos (Tamper Protection es manual)." -ForegroundColor Yellow
    } else {
        Write-Host "  Todo aplicado correctamente." -ForegroundColor Green
    }
    Write-Host @"

  PRUEBA FINAL (manual):
   1. Conecta un USB de prueba: debes recibir aviso de 'Escaneando...' y luego el resultado.
   2. Copia un .exe inofensivo al USB e intenta abrirlo: debe dar 'Acceso denegado'.
   3. (Opcional) Guarda el archivo de prueba EICAR en el USB: Defender debe detectarlo.
"@
    Write-Host "  Informe guardado en: $LogResult" -ForegroundColor DarkGray
    try { Stop-Transcript | Out-Null } catch {}
    Write-Host ""
    Read-Host "Pulsa Enter para cerrar esta ventana"
}
