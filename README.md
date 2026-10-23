<p align="center">
  <img src="assets/readme/hero.svg" alt="Skills y Scripts varios: skills para Claude Code y scripts de PowerShell" width="100%">
</p>

<p align="center">
  <img alt="Skills" src="https://img.shields.io/badge/skills-4-0969da">
  <img alt="Scripts PowerShell" src="https://img.shields.io/badge/scripts-2-1a7f37">
  <img alt="Plataforma" src="https://img.shields.io/badge/PowerShell-5.1%2B-5391fe">
</p>

> Colección personal de **skills para Claude Code** y **scripts de PowerShell para Windows**. Cada pieza es autónoma: copia la carpeta que necesites y úsala.

## Contenido

| | Qué hay | Para qué |
|---|---|---|
| 🧠 [`skills/`](skills) | 4 skills con su `SKILL.md` | Dar a Claude Code flujos de trabajo repetibles |
| ⚙️ [`Scripts Powershell/`](<Scripts Powershell>) | Scripts agrupados por tema, con un `README.md` por grupo | Automatizar tareas de Windows |

```text
.
├── .claude-plugin/plugin.json      # Manifiesto del plugin (expone ./skills)
├── skills/
│   ├── code-simplification/
│   ├── readme-github-atractivo/
│   ├── spec-funcional-sdd/
│   └── verificar-seguridad-repo/
└── Scripts Powershell/
    └── Seguridad USB/
```

## Skills

| Skill | Úsala cuando… |
|-------|---------------|
| [`code-simplification`](skills/code-simplification/SKILL.md) | El código funciona pero es difícil de leer o mantener y quieres refactorizar sin cambiar su comportamiento |
| [`readme-github-atractivo`](skills/readme-github-atractivo/SKILL.md) | Quieres crear, mejorar o auditar un README de GitHub |
| [`spec-funcional-sdd`](skills/spec-funcional-sdd/SKILL.md) | Tienes requerimientos, un BRD o un RFP y necesitas una especificación funcional (Spec-Driven Development) |
| [`verificar-seguridad-repo`](skills/verificar-seguridad-repo/SKILL.md) | Debes decidir si un repositorio desconocido es seguro, malicioso o un scam |

### Instalación

Copia la carpeta de la skill a tu directorio de skills de Claude Code:

```powershell
# Global (todos tus proyectos)
Copy-Item -Recurse skills\verificar-seguridad-repo "$HOME\.claude\skills\"

# Solo un proyecto
Copy-Item -Recurse skills\verificar-seguridad-repo .\.claude\skills\
```

Después Claude la invoca por su `description`, o puedes llamarla por nombre (por ejemplo `/verificar-seguridad-repo`).

## Scripts PowerShell

| Grupo | Descripción |
|-------|-------------|
| [`Seguridad USB`](<Scripts Powershell/Seguridad USB/README.md>) | Endurece Windows 10/11 frente a USBs no confiables y verifica el resultado |

```powershell
cd "Scripts Powershell\Seguridad USB"
.\Secure-USB.ps1      # aplica (pide elevación UAC)
.\Verify-USB.ps1      # comprueba que todo quedó aplicado
```

<details>
<summary>Más opciones de Seguridad USB</summary>

```powershell
.\Secure-USB.ps1 -DenyWrite   # además bloquea la escritura en discos extraíbles
.\Verify-USB.ps1 -DenyWrite   # verificar incluyendo el bloqueo de escritura
.\Secure-USB.ps1 -Undo        # revertir los cambios
```

</details>

> [!WARNING]
> Los scripts modifican políticas del sistema. Léelos antes de ejecutarlos y reinicia el equipo tras aplicarlos.

## Convenciones

- Una skill = una carpeta en `skills/` con un `SKILL.md` (frontmatter `name` + `description`).
- Un tema de scripts = una carpeta en `Scripts Powershell/` con su propio `README.md`.