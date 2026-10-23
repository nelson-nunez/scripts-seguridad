---
name: verificar-seguridad-repo
description: Audita un repositorio de origen desconocido en busca de malware, backdoors, scams, riesgos de cadena de suministro, secretos expuestos, CI/CD inseguro y vulnerabilidades principales, y entrega un informe breve con veredicto. Úsala cuando pidan revisar si un repo es seguro, malicioso o un scam.
---

# Verificar seguridad de un repositorio

Actúa como auditor de seguridad y malware. Objetivo: decidir si el repositorio es seguro para seguir trabajando con él, requiere revisión manual, es de alto riesgo o debe bloquearse. Busca cadenas de comportamiento completas con evidencia, no listas de palabras sospechosas.

## Reglas obligatorias

1. **Solo lectura.** No ejecutes código del repo: nada de `npm install`, `pip install`, `make`, tests, builds ni scripts del proyecto.
2. No te conectes a dominios/IPs encontrados ni descargues cargas útiles para "probarlas".
3. No envíes contenido del repo a servicios externos sin autorización (las bases de vulnerabilidades públicas de OSV sí se pueden consultar si la herramienta lo hace por defecto; indícalo).
4. No modifiques ni borres archivos del repo.
5. **Redacta los secretos** en el informe (`AKIA****REDACTED`). Nunca el valor completo.
6. Una coincidencia de patrón no es prueba: revisa el contexto antes de reportar. Código minificado, base64 o `eval` pueden ser legítimos.
7. No inventes resultados de herramientas. Si una herramienta no está instalada, dilo y usa `grep`/`rg`.
8. Nunca declares el repo "seguro": como mucho "sin hallazgos de alto riesgo detectados".

## Paso 1: Inventario (5 min)

```bash
cd <repo>
git log --oneline -n 20 2>/dev/null; git log --format='%an <%ae>' | sort | uniq -c | sort -rn | head
find . -path ./.git -prune -o -type f -print | sed 's|.*/||; s|.*\.||' | sort | uniq -c | sort -rn | head -20
ls -la; cat .gitmodules 2>/dev/null
ls .git/hooks | grep -v '\.sample$'
find . -path ./.git -prune -o -type f \( -perm -u+x -o -name '*.exe' -o -name '*.dll' -o -name '*.so' -o -name '*.dylib' -o -name '*.bin' -o -name '*.jar' -o -name '*.pyc' \) -print
find . -path ./.git -prune -o -type f -size +1M -print
```

Identifica lenguajes, gestores de paquetes, manifiestos y lockfiles, scripts (`.sh .ps1 .bat .cmd Makefile`), binarios incluidos, submódulos, hooks, CI/CD (`.github/workflows`, `.gitlab-ci.yml`), Docker/K8s/Terraform y configs de IDE/agentes (`.vscode/tasks.json`, `.devcontainer`, `.claude/`, `.cursor/`). Con `file` comprueba binarios cuya extensión no coincida con su tipo real.

**Señales de scam:** README que promete ganancias, bots de trading/cripto "gratis", "cracks", pide ejecutar un `.exe`/script descargado o pegar claves privadas; historial con 1–2 commits masivos, estrellas infladas, autor recién creado, releases con binarios sin código fuente correspondiente.

## Paso 2: Herramientas automáticas (si están instaladas)

```bash
which gitleaks semgrep osv-scanner trivy 2>/dev/null
gitleaks detect --source . --redact --no-banner        # secretos, incluido historial git
semgrep scan --config p/security-audit --config p/secrets --metrics=off --quiet
osv-scanner scan -r .                                  # CVEs en dependencias (consulta OSV)
trivy fs --scanners vuln,secret,misconfig .
```

Revisa cada resultado en contexto antes de reportarlo.

## Paso 3: Verificaciones manuales (grep/rg)

Ejecuta los comandos desde la raíz del repo añadiendo la ruta `.` al final de cada `rg` (sin ruta, `rg` puede quedarse esperando stdin). Excluye `node_modules`, `vendor`, `.git`, `dist` salvo que estén versionados (si lo están, revísalos: es una señal en sí).

**A. Scripts que se ejecutan solos (máxima prioridad)**
- `package.json`: `preinstall`, `install`, `postinstall`, `prepare`. `setup.py`/`pyproject.toml` con código en la instalación. `build.rs`, `.csproj` con `Exec`/tareas, `Makefile` por defecto.
- `.vscode/tasks.json` con `"runOn": "folderOpen"`, `.devcontainer` `postCreateCommand`, git hooks activos.
```bash
rg -n '"(pre|post)?install"|"prepare"' -g package.json
rg -n 'runOn|postCreateCommand|postStartCommand' .vscode .devcontainer 2>/dev/null
```

**B. Descarga y ejecución remota / ejecución dinámica**
```bash
rg -n -i '(curl|wget|iwr|Invoke-WebRequest)[^\n]*\|\s*(sh|bash|python|iex|node)'
rg -n 'eval\(|new Function\(|child_process|exec(Sync)?\(|spawn\(|os\.system|subprocess|exec\(|compile\(|Invoke-Expression|\biex\b|Process\.Start|Assembly\.Load'
```
Determina si lo ejecutado proviene de red, datos decodificados, variables de entorno o entrada de usuario. Patrón crítico: descargar → decodificar → guardar → ejecutar → borrar.

**C. Ofuscación**
```bash
rg -n '[A-Za-z0-9+/=]{200,}' --max-columns 200
rg -n "atob\(|Buffer\.from\([^)]*(base64|hex)|base64\.b64decode|fromCharCode|\\\\x[0-9a-f]{2}(\\\\x[0-9a-f]{2}){20,}|FromBase64String"
```
Prioriza ofuscación que precede a ejecución, acceso a secretos o red. Busca también líneas extremadamente largas o código escondido tras muchos espacios en blanco (`rg -n '\s{150,}\S'`).

**D. Robo y exfiltración de datos**
```bash
rg -n -i '\.ssh|id_rsa|\.aws/credentials|\.npmrc|\.pypirc|\.git-credentials|\.kube/config|Login Data|Cookies|Local Storage|leveldb|wallet|metamask|seed|mnemonic|keychain'
rg -n -i 'process\.env\b|os\.environ\b|Object\.keys\(process\.env|printenv|\benv\b\s*\|'
rg -n -i 'discord(app)?\.com/api/webhooks|api\.telegram\.org|pastebin|transfer\.sh|ngrok|webhook\.site|requestbin|pipedream|bit\.ly|tinyurl'
rg -n -o '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | grep -v -E '\b(127\.|0\.0\.0\.0|10\.|192\.168\.|255\.)'
```
Correlaciona: acceso a info sensible **+** envío externo = exfiltración. Una conexión de red aislada no lo es.

**E. Backdoors, persistencia y evasión**
- Credenciales o usuarios admin incrustados, rutas que saltan la autenticación, parámetros "mágicos", reverse shells (`/dev/tcp/`, `nc -e`, `socket` + `pty`/`cmd.exe`).
- Persistencia: `crontab`, `schtasks`, `systemctl enable`, `LaunchAgents`, claves `Run` del registro, escritura en `.bashrc`/`.zshrc`/`.profile`.
- Evasión: detección de VM/debugger/sandbox, condiciones por fecha/usuario/OS, borrado de logs, desactivar antivirus (`Set-MpPreference`).
```bash
rg -n -i '/dev/tcp/|nc\s+-e|bash\s+-i|crontab|schtasks|systemctl\s+enable|LaunchAgents|CurrentVersion\\\\Run|\.bashrc|\.zshrc|Set-MpPreference|IsDebuggerPresent|vmware|virtualbox'
```

**F. Cadena de suministro**
- Typosquatting: nombres parecidos a paquetes conocidos (`reqeusts`, `lodahs`, `colorss`, scopes falsos `@type/`), caracteres Unicode raros.
- Dependencias desde URL, git, ramas o rutas locales (`git+`, `http`, `file:`), registros alternativos en `.npmrc`/`pip.conf`/`nuget.config`.
- Lockfile ausente o que no coincide con el manifiesto; `resolved` apuntando a dominios no oficiales.
- Bibliotecas copiadas manualmente o minificadas en el repo sin fuente.
No marques una dependencia como maliciosa solo por ser nueva o poco usada: busca evidencia adicional.

**G. Secretos expuestos** (si no hay gitleaks)
```bash
rg -n -i "AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{36}|xox[bpa]-|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|(password|passwd|secret|api_?key|token)\s*[:=]\s*[\"'][^\"'\s]{8,}"
git log -p --all -S 'PRIVATE KEY' --oneline 2>/dev/null | head
find . -name '.env*' -not -name '*.example'
```

**H. CI/CD y configuración**
- Workflows con `pull_request_target` + checkout del PR, `${{ github.event.* }}` interpolado en `run:`, `permissions: write-all`, actions no fijadas a SHA, secretos enviados a URLs externas, `curl | sh`.
- Docker `privileged: true`, montaje de `/var/run/docker.sock`, secretos en imágenes; CORS `*`, debug activo, TLS deshabilitado (`verify=False`, `rejectUnauthorized: false`, `InsecureSkipVerify`).

**I. Vulnerabilidades principales (si es una app)**
Revisión dirigida, no exhaustiva: inyección SQL/comandos por concatenación de entrada, XSS (`innerHTML`, `dangerouslySetInnerHTML`, plantillas sin escape), SSRF (URL del usuario en peticiones), deserialización insegura (`pickle.loads`, `yaml.load` sin SafeLoader, `BinaryFormatter`, `unserialize`), auth ausente en endpoints sensibles, criptografía débil (MD5/SHA1 para contraseñas, `Math.random` para tokens). Sigue el flujo entrada → operación sensible antes de reportar.

## Paso 4: Validar y clasificar

Para cada hallazgo: revisa el contexto, comprueba si es alcanzable y bajo qué condiciones, y descarta falsos positivos.

- **Severidad:** CRITICAL (ejecución remota, robo de credenciales, backdoor o exfiltración), HIGH, MEDIUM, LOW, INFO.
- **Confianza:** ALTA (flujo confirmado), MEDIA (patrón consistente, falta confirmar), BAJA (indicio heurístico).
- IDs por categoría: `MAL`, `EXEC`, `OBF`, `EXFIL`, `PERSIST`, `SUPPLY`, `SECRETS`, `CICD`, `VULN` (ej. `EXEC-001`).

## Paso 5: Veredicto

- **BLOCK**: evidencia de malware, backdoor, exfiltración o ejecución no autorizada. No instalar ni ejecutar en entorno de confianza.
- **HIGH RISK**: hallazgos graves o varios indicios correlacionados. Aislar e investigar antes de usar.
- **REVIEW REQUIRED**: anomalías relevantes o resultados inconclusos que requieren revisión manual.
- **NO HIGH-RISK FINDINGS DETECTED**: nada de alto riesgo con el alcance aplicado. No es garantía de seguridad.

## Formato del informe (breve)

```
## Veredicto: <BLOCK | HIGH RISK | REVIEW REQUIRED | NO HIGH-RISK FINDINGS DETECTED>
<2-3 frases: qué es el repo, qué se encontró y qué hacer>

**Hallazgos:** CRITICAL n · HIGH n · MEDIUM n · LOW n · INFO n

### Hallazgos (de mayor a menor severidad)
| ID | Severidad | Confianza | Ubicación | Descripción | Recomendación |
|----|-----------|-----------|-----------|-------------|---------------|
| EXEC-001 | CRITICAL | ALTA | scripts/setup.js:24-31 | Descarga desde URL externa y ejecuta el contenido en postinstall | No instalar; eliminar el script |

(Para CRITICAL/HIGH añade 1-3 líneas de evidencia mínima y el flujo: origen → transformación → destino.)

### Requiere revisión manual
- <indicadores inconclusos, dependencias a investigar>

### Alcance y limitaciones
- Herramientas ejecutadas: <gitleaks ✓ / semgrep ✗ no instalado / ...>
- No analizado: <binarios, submódulos, historial completo, etc.>
- No se ejecutó código del repositorio.
```

Si no hay hallazgos en una categoría, no la listes. Mantén el informe corto: el detalle completo solo si el usuario lo pide.
