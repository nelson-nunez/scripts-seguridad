<#
.SYNOPSIS
  Hace que un disco SATA interno (por defecto D:) deje de aparecer como "extraible".
.DESCRIPTION
  Windows marca como extraible un disco conectado a un puerto SATA con "hot plug" o
  "eSATA" activo. La solucion oficial es listar ese puerto en
  HKLM\SYSTEM\CurrentControlSet\Services\storahci\Parameters\Device\TreatAsInternalPort
  (valor REG_MULTI_SZ). Requiere reiniciar.
.PARAMETER DriveLetter
  Letra del disco a corregir. Por defecto D.
.PARAMETER Port
  Numero de puerto SATA. Si se omite se detecta solo (SCSITargetId del disco).
.PARAMETER Undo
  Quita el valor TreatAsInternalPort (o solo el puerto indicado con -Port).
.PARAMETER Yes
  No pregunta confirmacion antes de aplicar.
.PARAMETER Force
  Continua aunque el diagnostico indique que no es necesario o que no aplica.
.PARAMETER NoRestart
  No ofrece reiniciar al final.
.NOTES
  - Se auto-eleva a administrador. La ventana no se cierra sola.
  - Registro en Fix-DiscoD-resultado.txt (misma carpeta del script).
  - ASCII puro a proposito.
#>
[CmdletBinding()]
param(
    [string]$DriveLetter = 'D',
    [int]$Port = -1,
    [switch]$Undo,
    [switch]$Yes,
    [switch]$Force,
    [switch]$NoRestart
)

$ErrorActionPreference = 'Continue'
$here = if ($PSScriptRoot) { $PSScriptRoot } else { [Environment]::GetFolderPath('Desktop') }
$DriveLetter = $DriveLetter.Trim().TrimEnd(':').Substring(0, 1).ToUpper()

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
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -DriveLetter $DriveLetter"
    if ($Port -ge 0)  { $argList += " -Port $Port" }
    if ($Undo)        { $argList += ' -Undo' }
    if ($Yes)         { $argList += ' -Yes' }
    if ($Force)       { $argList += ' -Force' }
    if ($NoRestart)   { $argList += ' -NoRestart' }
    try { Start-Process powershell.exe -Verb RunAs -ArgumentList $argList }
    catch {
        Write-Host "No se pudo elevar: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Pulsa Enter para cerrar"
    }
    exit
}

$LogResult = Join-Path $here 'Fix-DiscoD-resultado.txt'
try { Start-Transcript -Path $LogResult -Force | Out-Null } catch { $LogResult = '(no se pudo crear el registro)' }

$script:needReboot = $false
$script:fail = 0

function Info($t)  { Write-Host "  $t" -ForegroundColor Gray }
function Good($t)  { Write-Host "  [ OK ]  $t" -ForegroundColor Green }
function Warn($t)  { Write-Host "  [WARN]  $t" -ForegroundColor Yellow }
function Bad($t)   { Write-Host "  [FAIL]  $t" -ForegroundColor Red; $script:fail++ }
function Section($t) { Write-Host "`n== $t ==" -ForegroundColor Cyan }

$KeyPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\storahci\Parameters\Device'
$ValName = 'TreatAsInternalPort'
$Backup  = Join-Path $here 'TreatAsInternalPort-backup.txt'

function Get-Ports {
    try { @((Get-ItemProperty -Path $KeyPath -Name $ValName -ErrorAction Stop).$ValName) | Where-Object { $_ -ne $null -and "$_" -ne '' } }
    catch { @() }
}
function Save-Backup {
    $cur = (Get-Ports) -join ','
    Add-Content -Path $Backup -Value "$(Get-Date -f s)  valor previo de $ValName : [$cur]" -ErrorAction SilentlyContinue
}

try {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  DISCO ${DriveLetter}: -> INTERNO (no extraible)" -ForegroundColor Cyan
    Write-Host "  Usuario: $env:USERDOMAIN\$env:USERNAME   Equipo: $env:COMPUTERNAME" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # ===========================================================
    #  UNDO
    # ===========================================================
    if ($Undo) {
        Section "Revirtiendo"
        $cur = @(Get-Ports)
        if ($cur.Count -eq 0) {
            Info "No hay valor $ValName configurado. Nada que revertir."
            return
        }
        Save-Backup
        if ($Port -ge 0) {
            $new = @($cur | Where-Object { "$_" -ne "$Port" })
            if ($new.Count -gt 0) {
                Set-ItemProperty -Path $KeyPath -Name $ValName -Value ([string[]]$new) -Type MultiString
            } else {
                Remove-ItemProperty -Path $KeyPath -Name $ValName -ErrorAction SilentlyContinue
            }
            Good "Puerto $Port quitado de $ValName"
        } else {
            Remove-ItemProperty -Path $KeyPath -Name $ValName -ErrorAction SilentlyContinue
            Good "Valor $ValName eliminado"
        }
        $script:needReboot = $true
        return
    }

    # ===========================================================
    #  1. Diagnostico
    # ===========================================================
    Section "1. Diagnostico del disco ${DriveLetter}:"
    $part = Get-Partition -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
    if (-not $part) {
        Bad "No existe la unidad ${DriveLetter}: (conectada y con letra asignada?)"
        return
    }
    $disk = Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue
    $vol  = Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
    $wmi  = Get-CimInstance Win32_DiskDrive -Filter "Index=$($part.DiskNumber)" -ErrorAction SilentlyContinue

    Info "Modelo ............ $($disk.FriendlyName)"
    Info "Tamano ............ $([math]::Round($disk.Size/1GB,1)) GB"
    Info "Disco numero ...... $($disk.Number)   (sistema: $($disk.IsSystem))"
    Info "Tipo de bus ....... $($disk.BusType)"
    Info "Tipo de unidad .... $($vol.DriveType)"
    if ($wmi) {
        Info "MediaType ......... $($wmi.MediaType)"
        Info "Interfaz .......... $($wmi.InterfaceType)"
        Info "SCSI Port/Bus/Target: $($wmi.SCSIPort) / $($wmi.SCSIBus) / $($wmi.SCSITargetId)"
    }

    # Capacidades PnP del disco: es lo que hace aparecer "Expulsar ..." en la bandeja.
    # (DriveType puede decir 'Fixed' y aun asi el puerto SATA declarar el disco como extraible.)
    $caps = $null
    $policy = $null
    if ($wmi -and $wmi.PNPDeviceID) {
        try { $caps = [uint32](Get-PnpDeviceProperty -InstanceId $wmi.PNPDeviceID -KeyName 'DEVPKEY_Device_Capabilities' -ErrorAction Stop).Data } catch {}
        try { $policy = [int](Get-PnpDeviceProperty -InstanceId $wmi.PNPDeviceID -KeyName 'DEVPKEY_Device_RemovalPolicy' -ErrorAction Stop).Data } catch {}
    }
    $capRemovable = $false
    if ($null -ne $caps) {
        $hasRemovable = (($caps -band 4) -ne 0)
        $hasEject     = (($caps -band 2) -ne 0)
        $capRemovable = ($hasRemovable -or $hasEject)
        Info ("Capacidades PnP ... 0x{0:X}  (Removable: {1}, EjectSupported: {2})" -f $caps, $hasRemovable, $hasEject)
    } else {
        Info "Capacidades PnP ... no se pudieron leer"
    }
    if ($null -ne $policy) {
        Info "RemovalPolicy ..... $policy  (1 = no extraible, 2 = ordenada, 3 = sorpresa)"
        if ($policy -ne 1) { $capRemovable = $true }
    }

    if ($vol.DriveType -eq 'Fixed' -and $null -ne $caps -and -not $capRemovable -and -not $Force) {
        Good "La unidad ${DriveLetter}: es disco fijo y sin capacidad de expulsion. No hace falta cambiar nada."
        $cur = @(Get-Ports)
        if ($cur.Count -gt 0) { Info "TreatAsInternalPort actual: $($cur -join ', ')" }
        return
    }
    if ($vol.DriveType -eq 'Fixed') {
        Warn "Windows la clasifica como 'Fixed', pero el puerto SATA la declara extraible/expulsable"
        Warn "(por eso aparece 'Expulsar ...' en la bandeja). Se aplica el ajuste."
    }

    # Bus compatible
    $okBus = @('SATA', 'ATA', 'RAID', 'SAS', 'SCSI')
    if ($disk.BusType -eq 'USB' -and -not $Force) {
        Bad "El disco esta conectado por USB (caja o adaptador). Windows lo trata como extraible"
        Info "con razon; este ajuste solo sirve para discos en puertos SATA internos."
        Info "Si es un SSD en una caja USB, ese disco debe seguir considerandose externo."
        return
    }
    if (($okBus -notcontains "$($disk.BusType)") -and $disk.BusType -ne 'USB' -and -not $Force) {
        Bad "Bus '$($disk.BusType)' no soportado por este metodo (se esperaba SATA). Usa -Force para forzar."
        return
    }

    # Controlador
    $ctrls = @(Get-CimInstance Win32_IDEController -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    $svc = Get-Service -Name storahci -ErrorAction SilentlyContinue
    Info "Controladores SATA: $($ctrls -join ' | ')"
    Info "Servicio storahci : $(if($svc){'presente'}else{'NO presente'})"
    $ahci = ($ctrls -match 'AHCI') -and $svc
    if (-not $ahci) {
        Warn "No se detecto 'Standard SATA AHCI Controller' (storahci)."
        Warn "Con Intel RST/RAID u otro driver, TreatAsInternalPort puede no tener efecto."
        Warn "Alternativa: en BIOS/UEFI desactiva 'Hot Plug' del puerto SATA de este disco."
    }

    # ===========================================================
    #  2. Puerto
    # ===========================================================
    Section "2. Puerto SATA a marcar como interno"
    if ($Port -ge 0) {
        $p = $Port
        Info "Puerto indicado manualmente: $p"
    } elseif ($wmi -and $wmi.SCSITargetId -ne $null) {
        $p = [int]$wmi.SCSITargetId
        Info "Puerto detectado (SCSITargetId): $p"
    } else {
        Bad "No se pudo detectar el puerto. Ejecuta de nuevo con -Port N (0, 1, 2...)."
        return
    }
    $current = @(Get-Ports)
    Info "TreatAsInternalPort actual: $(if($current.Count){$current -join ', '}else{'(vacio)'})"

    if (-not $Yes) {
        $ans = Read-Host "  Marcar el puerto $p como INTERNO? (S/N)"
        if ($ans -notmatch '^[sSyY]') { Warn "Cancelado por el usuario."; return }
    }

    # ===========================================================
    #  3. Aplicar
    # ===========================================================
    Section "3. Aplicando"
    Save-Backup
    if (-not (Test-Path $KeyPath)) {
        New-Item -Path $KeyPath -Force | Out-Null
        Info "Clave creada: $KeyPath"
    }
    $new = @($current + "$p" | ForEach-Object { "$_" } | Sort-Object -Unique)
    Set-ItemProperty -Path $KeyPath -Name $ValName -Value ([string[]]$new) -Type MultiString -ErrorAction Stop
    $read = @(Get-Ports) | ForEach-Object { "$_" }
    if ($read -contains "$p") {
        Good "TreatAsInternalPort = $($read -join ', ')  (verificado)"
        $script:needReboot = $true
    } else {
        Bad "No se pudo verificar el valor escrito (leido: $($read -join ', '))"
    }

} catch {
    Write-Host "`nERROR INESPERADO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    $script:fail++
} finally {
    Write-Host "`n================== RESUMEN ==================" -ForegroundColor Cyan
    if ($script:fail) {
        Write-Host "  Hubo fallos: revisa los mensajes anteriores." -ForegroundColor Red
    } elseif ($script:needReboot) {
        Write-Host "  Cambio aplicado. REINICIA el equipo para que surta efecto." -ForegroundColor Green
        Write-Host @"

  Despues del reinicio:
   1. Ejecuta este script otra vez: debe decir que la unidad ya es disco fijo.
   2. (Opcional) Ejecuta Verify-USB.ps1 y haz la prueba con un USB real.

  Si tras reiniciar sigue como extraible:
   - Entra al BIOS/UEFI y desactiva 'Hot Plug' / 'eSATA' en el puerto SATA de ese disco.
   - Si el puerto detectado no era el correcto, usa:  -Port N  (prueba 0, 1, 2...).
   - Para revertir:  .\Fix-DiscoD-NoExtraible.ps1 -Undo
"@ -ForegroundColor Yellow
    } else {
        Write-Host "  Sin cambios." -ForegroundColor Gray
    }
    Write-Host "  Registro: $LogResult" -ForegroundColor DarkGray
    try { Stop-Transcript | Out-Null } catch {}
    Write-Host ""
    if ($script:needReboot -and -not $NoRestart -and -not $script:fail) {
        $r = Read-Host "Reiniciar ahora? (S/N)"
        if ($r -match '^[sSyY]') { Restart-Computer -Force }
    } else {
        Read-Host "Pulsa Enter para cerrar esta ventana"
    }
}
