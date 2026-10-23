---
name: spec-funcional-sdd
description: Analiza un documento de requerimientos, BRD, propuesta o RFP/licitación y genera una definición funcional ordenada del proyecto en un archivo Markdown, aplicando Spec-Driven Development (SDD). Define alcance y fuera de alcance, validaciones y reglas de negocio, pantallas, modelo de datos con diagrama de clases (Mermaid) y criterios de aceptación. Úsala cuando el usuario pida especificación funcional, definición funcional, spec, análisis de requerimientos o convertir un documento/RFP en una especificación para desarrollo.
---

# Spec funcional SDD

Convierte un documento de entrada (BRD, requerimientos, propuesta, RFP, licitación) en una **especificación funcional** en Markdown, que sea la fuente de verdad para planificar e implementar (Spec-Driven Development).

## Principios SDD que debes aplicar

1. **La spec es la fuente de verdad.** Código, plan y tareas derivan de ella; si algo cambia, se cambia primero la spec.
2. **Qué y por qué, no cómo.** La spec es agnóstica de tecnología. No elijas lenguaje, framework, base de datos ni arquitectura. Si el documento impone una tecnología, regístrala solo como *restricción*.
3. **Todo es verificable.** Cada requisito tiene ID único y al menos un criterio de aceptación comprobable (formato Dado/Cuando/Entonces).
4. **Trazabilidad.** Cada requisito referencia su origen en el documento (sección o página) y se vincula con pantallas, entidades y reglas.
5. **Sin ambigüedad oculta.** Lo que no esté claro se resuelve preguntando; lo no crítico se marca `[NECESITA ACLARACIÓN]`. No se inventa.
6. **Preparada para la siguiente fase.** Termina con una sección que guía el plan técnico y la descomposición en tareas.

## Flujo de trabajo

### Paso 1. Leer y analizar el documento
- Lee el documento completo (usa el skill de lectura adecuado según el formato: PDF, DOCX, etc.).
- Extrae: objetivo, actores, procesos, funcionalidades, datos, reglas, restricciones, integraciones, supuestos, exclusiones explícitas.
- Detecta contradicciones, requisitos incompletos, términos ambiguos y cifras sin unidad.

### Paso 2. Puerta de aclaración (obligatoria)
**Si existen vacíos críticos, DETENTE y no generes el archivo.** Un vacío es crítico si impide definir el alcance, una entidad, una regla de negocio o un criterio de aceptación.

- Presenta las dudas agrupadas, numeradas y priorizadas, cada una con: qué falta, por qué importa y una opción por defecto sugerida (para que el usuario pueda responder rápido).
- Usa AskUserQuestion cuando esté disponible (máx. 4 preguntas por ronda); si no, lista las dudas en texto.
- Repite rondas hasta que no queden vacíos críticos. Los vacíos **no críticos** pueden quedar como `[NECESITA ACLARACIÓN]` o registrarse como supuesto explícito.

### Paso 3. Definir el alcance
- **Dentro del alcance:** funcionalidades, procesos y actores cubiertos.
- **Fuera de alcance:** lo excluido explícitamente por el documento **y** lo que razonablemente podría asumirse pero no está pedido (indicando cuál es cuál). Cada exclusión con su motivo.
- **Supuestos, restricciones y dependencias.**

### Paso 4. Definir los requisitos
Redacta requisitos funcionales con ID (`RF-001`…), prioridad (MoSCoW) y origen. Agrúpalos por módulo o proceso.

Luego evalúa **cada uno** de estos componentes. Para cada uno decide si **aplica** y justifícalo; si no aplica, escribe "No aplica" con el motivo (no lo omitas en silencio):

- **Validaciones y reglas de negocio:** por campo (obligatoriedad, formato, rango, unicidad, longitud) y por flujo (precondiciones, cálculos, estados permitidos, transiciones). Con ID (`RN-001`, `VAL-001`) y mensaje de error esperado.
- **Registro / auditoría (logging):** qué eventos se registran, con qué datos, quién puede consultarlos y cuánto tiempo se conservan. Solo si el documento o la naturaleza del sistema lo requiere (datos sensibles, dinero, cambios de estado, trazabilidad legal).
- **Pantallas / interfaces:** listado con ID (`PAN-001`), propósito, actor, campos y controles, acciones, navegación, estados (vacío, error, carga) y requisitos que cubre. Si el sistema no tiene UI (API, batch), define las interfaces equivalentes.
- **Modelo de datos:** entidades, atributos con tipo lógico y obligatoriedad, claves, relaciones y cardinalidades, y estados/ciclo de vida cuando existan.
- **Roles y permisos, integraciones, requisitos no funcionales (rendimiento, seguridad, disponibilidad), reportes:** inclúyelos solo si el documento los menciona o implica; si no, "No aplica".

### Paso 5. Diagrama de clases
- Es el **único diagrama** del entregable. No generes flujos, secuencias ni otros.
- Usa **Mermaid** (`classDiagram`) dentro de un bloque ```mermaid.
- Incluye clases con atributos (con tipo), relaciones (herencia, composición, agregación, asociación) y multiplicidades. Los nombres deben ser consistentes con la sección de modelo de datos.
- Si el modelo es grande (más de 12 clases), divídelo en subdiagramas por módulo, pero siempre diagramas de clases.
- Revisa la sintaxis antes de entregar (llaves cerradas, relaciones válidas, sin caracteres especiales en los nombres).

### Paso 6. Criterios de aceptación
Para cada requisito funcional importante, escribe escenarios verificables:

```
Dado <contexto>
Cuando <acción>
Entonces <resultado observable>
```

Cubre el camino feliz, los errores de validación y los casos límite relevantes.

### Paso 7. Generar el archivo
- Lee `plantilla-spec.md` (en esta misma carpeta) y genera el archivo con Write siguiendo su estructura.
- Nombre: `spec-funcional-<nombre-proyecto-en-kebab-case>.md`.
- **Idioma: siempre español**, sin importar el idioma del documento de entrada. Conserva en el idioma original los nombres propios y términos del dominio cuando traducirlos genere ambigüedad.
- Entrega el archivo con SendUserFile y resume en 2-3 frases: qué se generó, cuántos requisitos contiene y los `[NECESITA ACLARACIÓN]` no críticos que queden pendientes.

## Reglas de calidad (revisa antes de entregar)

- [ ] Todo requisito tiene ID, prioridad, origen y criterio de aceptación.
- [ ] Alcance y fuera de alcance están separados y justificados.
- [ ] Cada validación o regla tiene ID y mensaje de error.
- [ ] Cada pantalla referencia los requisitos que cubre; cada requisito está cubierto por una pantalla, proceso o regla.
- [ ] Las entidades del diagrama coinciden con las del modelo de datos.
- [ ] No hay decisiones tecnológicas dentro de la spec (salvo restricciones citadas del documento).
- [ ] No hay datos inventados: lo supuesto está en la sección de supuestos.
- [ ] Hay un único diagrama: el de clases.
- [ ] La matriz de trazabilidad está completa.

## Qué NO hacer

- No generes la spec si quedan vacíos críticos sin resolver.
- No diseñes arquitectura, base de datos física ni endpoints, ni elijas tecnologías.
- No agregues funcionalidades "útiles" que el documento no pide; si las sugieres, ponlas en "Fuera de alcance / Recomendaciones futuras".
- No uses otros diagramas.
