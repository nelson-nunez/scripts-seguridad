---
name: "commitear"
description: "Crea commits limpios y revisables en repos personales: pregunta en qué rama subirlos (sugiriendo las ramas del proyecto), divide por tema y redacta el mensaje. Úsala cuando pidan commitear o hacer un commit."
---

# Commitear

Crea commits que otra persona pueda leer, revisar y revertir sin sorpresas.

## Cuándo usarla

- La persona pide "commitear", "haz un commit", "sube los cambios" o similar.
- La persona entrega un mensaje o contexto para usar como base del commit.

Nunca commitees por iniciativa propia: solo cuando la persona lo pide.

## Procedimiento

### 1. Leer el estado real

No confíes en la memoria de la sesión. Ejecuta:

```bash
git status
git diff
git diff --staged
git log --oneline -10          # formato, idioma y convenciones del repo
git branch --show-current
```

Si no hay cambios, dilo y termina.

### 2. Preguntar en qué rama subir los cambios

Obtén las ramas del proyecto ordenadas por actividad reciente (locales y remotas, sin duplicados):

```bash
git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads refs/remotes \
  | sed -E 's#^[^/]+/##' | grep -vE '^(HEAD|origin)$' | awk '!seen[$0]++' | head -8
```

Pregunta a la persona (con AskUserQuestion si está disponible) ofreciendo **al menos 5 opciones**:

1. La rama actual, marcada como tal.
2. Las ramas con actividad más reciente de la lista anterior (incluye `main`/`master`/`develop` si existen).
3. Siempre una opción **"Crear rama nueva"**, con un nombre sugerido según la convención (ver abajo) y derivado de los cambios. Ejemplo: `feature/login-con-google`.

Si el repo tiene menos de 4 ramas, completa las 5 opciones con nombres nuevos sugeridos de distintos tipos (`feature/…`, `fix/…`, `docs/…`, `refactor/…`) que encajen con el diff.

Si la persona elige `main` o `master`, recuérdale en una línea que commitea directo sobre la rama principal y sigue si lo confirma.

Cambiar de rama sin perder trabajo:

- Rama nueva: `git switch -c <rama>` (los cambios sin commitear viajan con ella).
- Rama existente: `git switch <rama>`. Si git se niega por conflictos con el árbol de trabajo, detente y pregunta; no uses `stash drop`, `reset` ni `checkout .`.

#### Convención de nombres de rama

Formato: `tipo/descripcion-corta`, opcionalmente con ID de ticket: `tipo/ID-descripcion`.

| Tipo | Uso |
|---|---|
| `feature/` | Nueva funcionalidad |
| `fix/` o `bugfix/` | Corrección de un error |
| `hotfix/` | Arreglo urgente en producción |
| `docs/` | Solo documentación |
| `refactor/` | Reestructurar código sin cambiar comportamiento |
| `test/` | Añadir o modificar pruebas |
| `chore/` | Mantenimiento: dependencias, configuración, tooling |

Reglas:

- Solo minúsculas, números y guiones. Nada de espacios, CamelCase, snake_case ni símbolos.
- Separa palabras con `-` (ej. `feature/login-con-google`).
- Corto y descriptivo: 2 a 5 palabras.
- Si hay ticket (Jira, Trello, GitHub Issues), inclúyelo: `feature/JIRA-1234-login-social`, `fix/42-crash-al-guardar`.
- Sin guiones al inicio o al final, sin `..`, sin terminar en `/` o `.lock`.
- Si el repo ya usa otra convención (se ve en `git branch -a`), síguela.

### 3. Decidir el alcance y dividir si hace falta

- Un commit por unidad lógica: lo que se revierte junto, va junto.
- Divide cuando el árbol mezcla temas: refactor y feature, formateo masivo y lógica, backend y frontend sin relación, o una dependencia nueva y su uso.
- No dividas lo que no compila o no pasa tests por separado. Ante la duda entre dos commits acoplados, deja uno.
- Ordena por dependencia: primero lo que el resto necesita (renombres, utilidades, migraciones), después lo que lo usa.
- Si un archivo mezcla dos temas, usa `git add -p <archivo>` para stagear solo los hunks de uno.
- Deja fuera experimentos, prints de depuración, archivos de scratch y configuración local. Menciona en el reporte lo que quedó fuera.

### 4. Stagear explícitamente

- `git add <ruta>` por archivo o por directorio acotado.
- Evita `git add -A`, `git add .` y `git commit -a`: arrastran archivos que nadie revisó.
- Antes de commitear, relee `git diff --staged`: es lo único que quedará en la historia.

### 5. Escribir el mensaje

- Base del mensaje, en este orden: el mensaje o contexto que dio la persona, la spec o tarea que se desarrolló, y si no hay ninguno, lo que muestra el diff.
- Usa el formato que ya usa el repo. Si usa (o no tiene) convención, usa Conventional Commits: `tipo(scope): descripción`, con tipos `feat`, `fix`, `refactor`, `test`, `docs`, `style`, `chore`, `perf`, `build`, `ci`.
- Alinea el tipo con la rama cuando aplique (`feature/` → `feat`, `fix/` → `fix`, `docs/` → `docs`).
- Primera línea: menos de 72 caracteres, en imperativo y en el idioma del repo (ej. `feat(auth): agrega login con Google`).
- Cuerpo opcional, separado por una línea en blanco: explica el porqué y las decisiones no obvias. El qué ya está en el diff. Viñetas solo si hay varios cambios significativos.
- Si hay ticket, refiérelo al final (`Refs: JIRA-1234`, `Closes #42`).
- Sin atribución de agente ni coautoría, salvo que el repo o la persona lo pidan.

### 6. Commitear

```bash
git commit -m "<titulo>" -m "<cuerpo opcional>"
```

### 7. Subir los cambios

- Si la rama no tiene upstream: `git push -u origin <rama>`.
- Si ya lo tiene: `git push`.
- Si el push es rechazado porque el remoto avanzó, no fuerces: haz `git pull --rebase` solo si la persona lo aprueba, o explica la situación.
- Si no hay remoto configurado, deja el commit local y dilo.

## Errores comunes

- **Hooks.** Si un hook falla, el commit no se creó. Corrige la causa, vuelve a stagear lo que el hook modificó y commitea de nuevo. Nunca `--no-verify`.
- **Secretos y ruido.** No commitees `.env`, credenciales, tokens, claves, dumps, artefactos de build, logs ni archivos temporales. Ante la duda, propone añadirlo a `.gitignore`.
- **Comandos destructivos.** No uses `git reset --hard`, `git checkout .`, `git clean -fd` ni `git stash drop` para ordenar: borran trabajo que no es tuyo.
- **Historia publicada.** No hagas `--amend`, rebase ni `push --force` sobre commits que ya están en el remoto, salvo pedido explícito (y entonces usa `--force-with-lease`).
- **Mensaje inflado.** No describas intención, impacto ni motivación que el diff no respalde.

## Verificación y reporte

- `git log -1 --stat` muestra el mensaje esperado y solo los archivos previstos (repite por cada commit si dividiste).
- `git status` no deja residuos que se pretendía incluir.
- `git status -sb` muestra la rama sincronizada con el remoto tras el push.

Responde a la persona con: rama usada, commits creados (hash corto y título), si se hizo push, y cualquier cosa que quedó sin commitear, test que falló o archivo que un hook modificó.