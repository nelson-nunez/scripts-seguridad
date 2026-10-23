---
name: readme-github-atractivo
description: Lee un repositorio, redacta su descripción y genera un README de GitHub atractivo combinando Markdown, HTML permitido por GitHub y recursos SVG con CSS interno. Úsala cuando el usuario pida crear, mejorar, embellecer, rediseñar o auditar un README, o generar solo el hero, encabezados de sección, diagramas o badges. Si no está claro si quiere el README completo o solo recursos visuales, pregunta el alcance.
---

# README atractivo para GitHub

Convierte un repositorio en una portada clara y con identidad propia. Markdown es la capa de contenido, el HTML permitido por GitHub es la capa de maquetación, y los SVG con CSS interno son la capa visual.

> Regla clave: GitHub **elimina** `<style>`, atributos `style=""`, `class`, scripts y fuentes remotas del README. El CSS solo vive **dentro de los archivos SVG** (que GitHub muestra como imagen) y en la **vista previa local HTML**. Lee [references/html-css-github.md](references/html-css-github.md) antes de escribir cualquier HTML o CSS.

## Flujo de trabajo

### 1. Confirmar el modo antes de editar

Usa exactamente un modo:

- **Modo README** — crea o mejora el README completo: descripción, orden de la información, jerarquía de textos, pruebas, Markdown/HTML y sistema visual.
- **Modo solo recursos** — crea únicamente los SVG pedidos (hero, encabezados, diagrama, badge). No modifiques el README salvo autorización explícita.

Si el modo no está claro, haz una sola pregunta corta:

> ¿Quieres que cree/mejore el README completo o solo los recursos visuales? Si son solo recursos, dime si necesitas hero, encabezados de sección, diagrama, badges o un set coordinado.

No interpretes “usa esta skill”, una ruta o “ponlo bonito” como permiso para reescribir todo. Si el usuario pide solo una auditoría, audita sin editar y no hagas la pregunta de modo.

### 2. Leer el proyecto (solo lectura)

Antes de diseñar, inspecciona:

- `README` actual, árbol del repositorio (2–3 niveles), licencia.
- Metadatos: `package.json`, `pyproject.toml`, `setup.cfg`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, `composer.json`, `*.csproj`, `Dockerfile`, `docker-compose.yml`, `Makefile`.
- Punto de entrada y scripts (`main`, `bin`, `scripts`, `cli`), carpeta `examples/`, `docs/`, tests.
- Recursos reales: logo, capturas, GIFs, salidas de ejemplo, colores/tokens de diseño ya existentes.
- Para una URL de GitHub: la página remota, rama por defecto, topics y descripción del repo.

Identifica: público, problema que resuelve, la prueba más clara, el camino más corto al primer uso y cualquier afirmación sin evidencia. No hagas commit, push ni publiques nada sin autorización.

### 3. Redactar la descripción del proyecto

Escribe esta ficha antes de dibujar nada y muéstrala al usuario si el proyecto es ambiguo:

```text
Nombre:
Público:
Descripción en una frase (≤ 120 caracteres, sin adjetivos vacíos):
Descripción corta (2–3 frases: qué es, para quién, qué lo hace distinto):
Prueba principal (captura, salida, demo, ejemplo real):
Primera acción exitosa (comando o paso):
Stack detectado:
Tema visual:
```

Reglas de redacción:

- Di qué hace en lenguaje llano, no en eslóganes (“Convierte CSV en dashboards” > “La solución definitiva para tus datos”).
- Deriva cada afirmación de evidencia del repositorio. **No inventes** usuarios, benchmarks, compatibilidades, testimonios ni funciones.
- Si algo es incierto, márcalo como `TODO:` y pregúntalo; no lo rellenes.
- Escribe en el idioma del README existente; si no hay, en el idioma del usuario. Ofrece versión bilingüe solo si se pide.

La descripción en una frase sirve además como “About” del repositorio en GitHub; ofrécela por separado.

### 4. Definir el sistema visual del proyecto

Lee [references/direccion-visual.md](references/direccion-visual.md) y congela una especificación compacta:

```text
Paleta: fondo / texto / primario / acento / atenuado (+ variante oscura)
Tipografía: pila de fuentes del sistema / escala / contraste de peso
Forma: radio / trazo / retícula / espaciado
Motivo: una pista visual recurrente propia del proyecto
Composición: sobria / editorial / técnica / lúdica
```

El motivo sale del proyecto: una CLI usa prompt y cursor; una base de datos, tablas y relaciones; una API, endpoints y flechas; una librería de UI, componentes y retícula. Si el repo ya tiene colores o logo, úsalos. Nunca apliques la misma plantilla a todos los repositorios.

### 5. Ejecutar solo el modo elegido

#### Modo README

Elige la profundidad:

- **Rediseño completo** — reestructura la historia y crea el sistema visual.
- **Refresco visual** — conserva la arquitectura de información y mejora la presentación.

Orden recomendado (detalles en [references/arquitectura-contenido.md](references/arquitectura-contenido.md)):

1. Hero: nombre + valor en lenguaje llano (SVG) + badges reales.
2. Prueba: captura, salida o demo.
3. Qué es: explicación breve.
4. Por qué es distinto: mecanismo, no eslóganes.
5. Cómo funciona: proceso corto o arquitectura.
6. Instalación + primer comando.
7. Uso / configuración (en `<details>` si es largo).
8. Límites, compatibilidad, contribución y licencia.

Parte de [templates/README.template.md](templates/README.template.md). Pon el ejemplo antes de la explicación larga. Elimina promesas repetidas y detalles internos que no ayudan a adoptar el proyecto.

#### Modo solo recursos

- Confirma qué recursos y si es uno o un set coordinado.
- Créalos en `assets/readme/` (u otra ruta aprobada) partiendo de [templates/hero.svg](templates/hero.svg) y [templates/section.svg](templates/section.svg).
- No cambies el README. Ofrece el fragmento para incrustarlos aparte.

### 6. Construir las capas

**Markdown (contenido):** textos, comandos en bloques de código con lenguaje, tablas, enlaces, listas. Todo lo que se deba poder buscar o copiar va aquí, nunca dentro de una imagen.

**HTML permitido por GitHub (maquetación):**

- Centrado: `<p align="center">` / `<div align="center">`.
- Imágenes: `<img src="..." alt="..." width="100%">`.
- Modo claro/oscuro: `<picture>` con `<source media="(prefers-color-scheme: dark)" srcset="...">`.
- Plegables: `<details><summary>`; teclas: `<kbd>`; notas: `<sub>`, `<sup>`.
- Rejillas de tarjetas: `<table>` con `<td width="33%">` (sin `style`).
- Avisos nativos: `> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`.

**SVG + CSS (visual):** lee [references/html-css-github.md](references/html-css-github.md).

- `viewBox` de 1200 unidades de ancho, incrustado con `width="100%"`.
- CSS dentro de `<style>` del propio SVG: variables, clases, `@media (prefers-color-scheme: dark)` para adaptar colores.
- Fuentes del sistema, sin `@import` ni fuentes remotas, sin `<script>`, sin `foreignObject`.
- `<title>` y `<desc>` con `role="img"` para accesibilidad, y `alt` descriptivo en el `<img>`.
- Texto esencial ≥ 20 unidades, etiquetas de apoyo ≥ 18 (legibles a ~900 px y en móvil a 360 px).
- Animación CSS solo decorativa y no esencial (GitHub puede no reproducirla en todos los clientes).
- Badges: usa shields.io solo con datos verdaderos (licencia, versión publicada, CI existente).

No rasterices el README entero ni pongas párrafos de texto dentro de imágenes.

### 7. Vista previa y verificación

- Genera la vista previa local con CSS similar a GitHub (claro y oscuro):

```bash
python3 scripts/preview_readme.py /ruta/al/repositorio/README.md
```

  Abre el `README.preview.html` generado y revisa ancho completo y móvil.
- Audita el README:

```bash
python3 scripts/auditar_readme.py /ruta/al/repositorio/README.md
```

- Revisa: imágenes rotas, texto SVG recortado, contraste en ambos temas, `alt` en todas las imágenes, tamaño de los SVG (< 100 KB idealmente), enlaces relativos correctos.
- En modo solo recursos, verifica que el README quedó intacto.
- Informa qué cambió, qué quedó intencionadamente simple y qué archivos no se tocaron.

### 8. Entrega segura

Muestra la vista previa y el diff primero. Solo haz commit, push, PR o publica cuando el usuario lo pida explícitamente.

## Criterios de calidad

- La primera pantalla explica el proyecto sin conocimiento previo.
- La descripción es verificable con el propio repositorio.
- El diseño parece nativo de este proyecto, no de esta skill: si quitas el nombre, el hero no sirve para otro repo.
- Cada módulo visual tiene una función de comunicación.
- La prueba real aparece antes que las afirmaciones abstractas.
- El README queda más claro, no solo más decorado.
- Funciona aunque fallen las imágenes: `alt`, encabezados, comandos y enlaces siguen siendo útiles.
- Nada de CSS fuera de los SVG o de la vista previa local.

## Ejemplos de invocación

```text
Usa $readme-github-atractivo para crear el README de este repositorio desde cero.
```

```text
Usa $readme-github-atractivo para crear solo un hero SVG y tres encabezados de sección, sin tocar el README.
```

```text
Usa $readme-github-atractivo para auditar el README de https://github.com/usuario/proyecto sin editarlo.
```

```text
Usa $readme-github-atractivo para refrescar visualmente el README manteniendo su estructura.
```
