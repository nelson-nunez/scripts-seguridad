# Seguridad USB

Scripts para endurecer Windows 10/11 frente a dispositivos USB no confiables.

| Script | Funcion |
|--------|---------|
| `Secure-USB.ps1` | Aplica las politicas de seguridad para USB. Se auto-eleva a administrador. |
| `Verify-USB.ps1` | Comprueba que `Secure-USB.ps1` aplico todos los cambios. |

## Uso

```powershell
# 1. Aplicar
.\Secure-USB.ps1

#    Ademas bloquear la escritura en discos extraibles (solo lectura)
.\Secure-USB.ps1 -DenyWrite

# 2. Verificar (usar -DenyWrite si se aplico en el paso 1)
.\Verify-USB.ps1
.\Verify-USB.ps1 -DenyWrite

# Revertir los cambios
.\Secure-USB.ps1 -Undo
```

## Notas

- Piden elevacion UAC y la ventana no se cierra sola (esperan Enter).
- Guardan un registro junto al script: `Secure-USB-resultado.txt` y `Verify-USB-resultado.txt`.
- Tras aplicar, reiniciar el equipo y ejecutar `Verify-USB.ps1`.
- Archivos en ASCII puro a proposito, para evitar problemas de codificacion en PowerShell 5.1.