<#
.SYNOPSIS
  Endurece Windows 10/11 contra USBs no confiables (version 2).
.PARAMETER DenyWrite
  Ademas impide ESCRIBIR en discos extraibles (solo lectura).
.PARAMETER Undo
  Revierte las politicas aplicadas por este script.
.NOTES
  - Se auto-eleva a administrador (acepta el aviso UAC).
  - La ventana NO se cierra sola: al final pide pulsar Enter.
  - Guarda un registro completo en Secure-USB-resultado.txt (misma carpeta del script).
  - Archivo en ASCII puro a proposito (evita errores de codificacion en PowerShell 5.1).
#>
[CmdletBinding()]
param(
    [switch]$DenyWrite,
    [switch]$Undo
)

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
    if ($Undo)      { $argList += ' -Undo' }
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    } catch {
        Write-Host "No se pudo elevar: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Pulsa Enter para cerrar"
    }
    exit
}

# ---------------------------------------------------------------
#  Registro de resultados
# ---------------------------------------------------------------
$LogResult = Join-Path $here 'Secure-USB-resultado.txt'
try { Start-Transcript -Path $LogResult -Force | Out-Null } catch { $LogResult = '(no se pudo crear el registro)' }

$script:ok = 0
$script:fail = 0
$script:failed = New-Object System.Collections.ArrayList

function Report($label, $pass, $detail = '') {
    if ($pass) {
        Write-Host "  [ OK ]  $label" -ForegroundColor Green
        $script:ok++
    } else {
        Write-Host "  [FAIL]  $label  $detail" -ForegroundColor Red
        $script:fail++
        [void]$script:failed.Add($label)
    }
}
function Section($t) { Write-Host "`n== $t ==" -ForegroundColor Cyan }

# Escribe un valor de registro y lo vuelve a leer para confirmar
function Apply-Reg($label, $path, $name, $value, $type = 'DWord') {
    try {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -ErrorAction Stop
        $read = (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name
        Report $label ($read -eq $value) "(leido: $read, esperado: $value)"
    } catch {
        Report $label $false "($($_.Exception.Message))"
    }
}
# Ejecuta un bloque y reporta OK/FAIL
function Apply-Cmd($label, [scriptblock]$sb) {
    try {
        & $sb
        Report $label $true
    } catch {
        Report $label $false "($($_.Exception.Message))"
    }
}

$ScriptDir    = 'C:\Scripts'
$ScanScript   = Join-Path $ScriptDir 'UsbScan.ps1'
$LogFile      = Join-Path $ScriptDir 'usbscan.log'
$TaskName     = 'UsbScan'
$ExplorerPol  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Policies\Explorer'
$ExplorerPol2 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
$RemovablePol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}'
$AsrUsbRule   = 'b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4'
$user         = "$env:USERDOMAIN\$env:USERNAME"

try {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  SECURIZAR USB - $(if($Undo){'REVERTIR'}else{'APLICAR'})" -ForegroundColor Cyan
    Write-Host "  Usuario: $user   Equipo: $env:COMPUTERNAME" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # ===========================================================
    #  UNDO
    # ===========================================================
    if ($Undo) {
        Section "Revirtiendo cambios"
        Apply-Cmd "Quitar NoDriveTypeAutoRun" {
            Remove-ItemProperty $ExplorerPol2 -Name NoDriveTypeAutoRun -ErrorAction SilentlyContinue
            Remove-ItemProperty $ExplorerPol  -Name NoDriveTypeAutoRun -ErrorAction SilentlyContinue
            Remove-ItemProperty $ExplorerPol2 -Name NoAutoplayfornonVolume -ErrorAction SilentlyContinue
        }
        Apply-Cmd "Quitar bloqueo de ejecucion/escritura en extraibles" {
            Remove-Item $RemovablePol -Recurse -ErrorAction SilentlyContinue
        }
        Apply-Cmd "Quitar regla ASR de USB" {
            Remove-MpPreference -AttackSurfaceReductionRules_Ids $AsrUsbRule -ErrorAction Stop
        }
        Apply-Cmd "Quitar panel de vista previa desactivado" {
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name NoPreviewPane -ErrorAction SilentlyContinue
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name NoReadingPane -ErrorAction SilentlyContinue
        }
        Apply-Cmd "Eliminar tarea programada $TaskName" {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        }
        Write-Host "`nRevertido. Reinicia el equipo para aplicar todo." -ForegroundColor Green
        return
    }

    # ===========================================================
    #  1. AutoRun / AutoPlay
    # ===========================================================
    Section "1. AutoRun y AutoPlay"
    Apply-Reg "NoDriveTypeAutoRun = 255 (HKLM Policies)"  $ExplorerPol2 'NoDriveTypeAutoRun' 255
    Apply-Reg "NoDriveTypeAutoRun = 255 (directiva grupo)" $ExplorerPol  'NoDriveTypeAutoRun' 255
    Apply-Reg "NoAutoplayfornonVolume = 1"                $ExplorerPol2 'NoAutoplayfornonVolume' 1
    Apply-Reg "Servicio cdrom AutoRun = 0" 'HKLM:\SYSTEM\CurrentControlSet\Services\cdrom' 'AutoRun' 0
    Apply-Reg "AutoPlay desactivado (usuario actual)" 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' 'DisableAutoplay' 1

    # ===========================================================
    #  2. Bloqueo de ejecucion en discos extraibles
    # ===========================================================
    Section "2. Bloqueo de ejecucion en discos extraibles"
    Apply-Reg "Deny_Execute = 1" $RemovablePol 'Deny_Execute' 1
    if ($DenyWrite) {
        Apply-Reg "Deny_Write = 1 (solo lectura)" $RemovablePol 'Deny_Write' 1
    } else {
        Apply-Cmd "Escritura en USB permitida (Deny_Write eliminado)" {
            Remove-ItemProperty $RemovablePol -Name Deny_Write -ErrorAction SilentlyContinue
        }
    }

    # ===========================================================
    #  3. Microsoft Defender
    # ===========================================================
    Section "3. Microsoft Defender"
    $mp = Get-Command Set-MpPreference -ErrorAction SilentlyContinue
    if (-not $mp) {
        Report "Modulo de Defender disponible" $false "(Set-MpPreference no existe; hay otro antivirus?)"
    } else {
        Apply-Cmd "Proteccion en tiempo real"          { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop }
        Apply-Cmd "Proteccion en la nube (MAPS)"       { Set-MpPreference -MAPSReporting Advanced -ErrorAction Stop }
        Apply-Cmd "Envio de muestras seguras"          { Set-MpPreference -SubmitSamplesConsent SendSafeSamples -ErrorAction Stop }
        Apply-Cmd "Bloqueo en la nube = High"          { Set-MpPreference -CloudBlockLevel High -ErrorAction Stop }
        Apply-Cmd "Tiempo extra de nube = 30 s"        { Set-MpPreference -CloudExtendedTimeout 30 -ErrorAction Stop }
        Apply-Cmd "PUA Protection"                     { Set-MpPreference -PUAProtection Enabled -ErrorAction Stop }
        Apply-Cmd "Escaneo de unidades extraibles"     { Set-MpPreference -DisableRemovableDriveScanning $false -ErrorAction Stop }
        Apply-Cmd "Network Protection"                 { Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction Stop }
        Apply-Cmd "Regla ASR USB (agregar en modo Block)" {
            Add-MpPreference -AttackSurfaceReductionRules_Ids $AsrUsbRule -AttackSurfaceReductionRules_Actions Enabled -ErrorAction Stop
        }
        # Comprobacion real de la regla ASR
        try {
            $pref = Get-MpPreference
            $ids = @($pref.AttackSurfaceReductionRules_Ids | ForEach-Object { "$_".ToLower() })
            $i = [array]::IndexOf($ids, $AsrUsbRule)
            $act = if ($i -ge 0) { @($pref.AttackSurfaceReductionRules_Actions)[$i] } else { $null }
            Report "Verificacion: regla ASR USB en modo Block" ($act -eq 1) "(valor actual: $act)"
        } catch {
            Report "Verificacion de regla ASR" $false "($($_.Exception.Message))"
        }
    }
    Apply-Reg "SmartScreen habilitado" 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 1
    Apply-Reg "SmartScreen nivel Block" 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'ShellSmartScreenLevel' 'Block' 'String'
    Write-Host "  [INFO]  Tamper Protection: activala a mano en Seguridad de Windows > Proteccion antivirus > Configuracion." -ForegroundColor Yellow

    # ===========================================================
    #  4. Escaneo automatico al conectar USB
    # ===========================================================
    Section "4. Escaneo automatico al conectar USB"
    Apply-Cmd "Crear carpeta $ScriptDir" { New-Item -ItemType Directory -Path $ScriptDir -Force -ErrorAction Stop | Out-Null }

    $scanCode = @'
$log = 'C:\Scripts\usbscan.log'
Get-EventSubscriber -SourceIdentifier USBInsert -ErrorAction SilentlyContinue | Unregister-Event -ErrorAction SilentlyContinue
$q = "SELECT * FROM Win32_VolumeChangeEvent WHERE EventType = 2"
Register-WmiEvent -Query $q -SourceIdentifier USBInsert -Action {
    $log = 'C:\Scripts\usbscan.log'
    function Notify($t) {
        try {
            $s = $t -replace "'", "''"
            Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -Command `"Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show('$s','Escaneo USB')`""
        } catch {}
    }
    try {
        $d = $Event.SourceEventArgs.NewEvent.DriveName          # ej. "E:"
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$d'"
        $isUsb = ($disk.DriveType -eq 2)
        if (-not $isUsb) {
            $bus = (Get-Partition -DriveLetter $d[0] -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue).BusType
            $isUsb = ($bus -eq 'USB')
        }
        if (-not $isUsb) { return }

        $start = Get-Date
        Add-Content $log "$(Get-Date -f s) $d conectado, escaneando..."
        Notify "USB $d detectado. Escaneando... NO abras archivos hasta el siguiente aviso."
        Update-MpSignature -ErrorAction SilentlyContinue
        Start-MpScan -ScanType CustomScan -ScanPath "$d\"

        $threats = Get-MpThreatDetection | Where-Object {
            $_.InitialDetectionTime -ge $start -and (($_.Resources -join ' ') -like "*$d*")
        }
        if ($threats) {
            $names = ($threats | ForEach-Object { (Get-MpThreat -ThreatID $_.ThreatID -ErrorAction SilentlyContinue).ThreatName } | Sort-Object -Unique) -join ', '
            $msg = "AMENAZA detectada en ${d}: $names. NO abras archivos. Revisa Seguridad de Windows."
        } else {
            $msg = "Escaneo de $d terminado: sin amenazas detectadas."
        }
        Add-Content $log "$(Get-Date -f s) $d $msg"
        Notify $msg
    } catch {
        Add-Content $log "$(Get-Date -f s) ERROR: $($_.Exception.Message)"
    }
} | Out-Null
Add-Content $log "$(Get-Date -f s) Vigilante USB iniciado"
while ($true) { Start-Sleep -Seconds 3600 }
'@
    Apply-Cmd "Escribir $ScanScript" { Set-Content -Path $ScanScript -Value $scanCode -Encoding ASCII -ErrorAction Stop }
    Apply-Cmd "Crear archivo de log" {
        if (-not (Test-Path $LogFile)) { New-Item -ItemType File -Path $LogFile -Force | Out-Null }
    }

    Apply-Cmd "Crear tarea programada '$TaskName' (al iniciar sesion, privilegios altos)" {
        $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
                        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScanScript`""
        $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                        -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
            -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
    }
    Apply-Cmd "Iniciar la tarea ahora" { Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop }
    Start-Sleep -Seconds 3
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Report "Verificacion: tarea '$TaskName' en ejecucion" ($t -and $t.State -eq 'Running') "(estado: $(if($t){$t.State}else{'no existe'}))"

    Apply-Cmd "Proteger carpeta $ScriptDir (usuarios sin escritura)" {
        icacls $ScriptDir /inheritance:r /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "${user}:(OI)(CI)RX" | Out-Null
        icacls $LogFile /grant "${user}:M" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "icacls devolvio codigo $LASTEXITCODE" }
    }

    # ===========================================================
    #  5. Explorador y Office
    # ===========================================================
    Section "5. Explorador y Office"
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $expPol = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    Apply-Reg "Mostrar extensiones de archivo"      $adv 'HideFileExt' 0
    Apply-Reg "Mostrar archivos ocultos"            $adv 'Hidden' 1
    Apply-Reg "Panel de vista previa desactivado"   $expPol 'NoPreviewPane' 1
    Apply-Reg "Panel de lectura desactivado"        $expPol 'NoReadingPane' 1
    foreach ($app in 'word', 'excel', 'powerpoint') {
        $p = "HKCU:\Software\Policies\Microsoft\Office\16.0\$app\security"
        Apply-Reg "Office ${app}: bloquear contenido de internet" $p 'blockcontentexecutionfrominternet' 1
        Apply-Reg "Office ${app}: macros deshabilitadas"          $p 'vbawarnings' 4
    }

    Section "Aplicando politicas"
    Apply-Cmd "gpupdate /force" { gpupdate /force | Out-Null }

} catch {
    Write-Host "`nERROR INESPERADO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    $script:fail++
} finally {
    Write-Host "`n================== RESUMEN ==================" -ForegroundColor Cyan
    Write-Host "  Correctos: $script:ok     Fallos: $script:fail" -ForegroundColor $(if ($script:fail) { 'Red' } else { 'Green' })
    if ($script:failed.Count -gt 0) {
        Write-Host "  Pasos con fallo:" -ForegroundColor Red
        $script:failed | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    }
    if (-not $Undo) {
        Write-Host @"

  PENDIENTE MANUAL:
   - Activar Tamper Protection (Seguridad de Windows).
   - REINICIAR el equipo.
   - Despues ejecuta Verify-USB.ps1 para comprobar todo.
   - BadUSB (teclados falsos) NO se frena con esto: usa un equipo o VM aislado
     para USBs de clientes.
"@ -ForegroundColor Yellow
    }
    Write-Host "  Registro completo: $LogResult" -ForegroundColor DarkGray
    try { Stop-Transcript | Out-Null } catch {}
    Write-Host ""
    Read-Host "Pulsa Enter para cerrar esta ventana"
}
