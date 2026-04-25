<div align="center">

# midas.skill

> *"La riqueza no se esconde en las terminales de Bloomberg ni en los pitches de VC. La riqueza se esconde en el ruido de tu vida diaria — y te han entrenado para ignorarla."*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-blue.svg)](https://python.org)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![AgentSkills](https://img.shields.io/badge/AgentSkills-Standard-green)](https://agentskills.io)

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?logo=discord&logoColor=white)](#)

<br>

Tu chat de Slack dejó escapar tres ideas de negocio esta semana — y pasaste por alto.<br>
Tu carrete de fotos contiene una tesis de arbitraje de barrio — y olvidaste que existían.<br>
Las quejas de tu grupo de amigos son un focus group auto-organizado — y nadie en el chat lo sabe.<br>
Tu historial de YouTube son 14 horas de evidencia de que te estás convirtiendo en un especialista pagado — y lo llamaste "perder el tiempo".<br>
Tus compras en Amazon son demanda validada — y crees que es solo ir de compras.<br>

**Convierte tus Pedidos Repetidos en Oro — ¡bienvenido a la refinería de ruido a oro!**

<br>

Aliméntalo con cualquier flujo de tu vida diaria (Slack, fotos, chats, navegación, recibos, quejas)<br>
más tus propias intuiciones y preguntas<br>
y obtendrás **una lista clasificada de señales de dinero, oportunidades y próximas acciones inmediatas**

[Fuentes Soportadas](#fuentes-soportadas) · [Instalación](#instalación) · [Uso](#uso) · [Demo](#demo) · [Instalación Detallada](#instalación-detallada) · [💬 Discord](#)

[**English**](README.md) · [**中文**](README_ZH.md) · [**Deutsch**](README_DE.md) · [**日本語**](README_JA.md) · [**Русский**](README_RU.md) · [**Português**](README_PT.md)

</div>

---

Creado por [@realteamprinz](https://github.com/realteamprinz) | Posicionamiento: **Nuwa destila cómo piensan las personas. Midas destila cómo convertir tu ruido diario en dinero.**

## Fuentes Soportadas

> Midas acepta cualquier flujo de información que le proporciones voluntariamente. **La repetición ES la señal** — si lo encontraste más de una vez, alimenta a Midas con ello.

| Fuente | Mejor Lente | Notas |
|--------|:-----------:|-------|
| Mensajes de Slack / Teams | Brecha de Demanda, Señal de Dinero | Canales de equipo = frustraciones con proveedores, señales de presupuesto, atajos manuales |
| WhatsApp / iMessage / chats de WeChat | Brecha de Demanda, Red de Contactos | Quejas repetidas de diferentes personas = demanda no atendida |
| Carrete de fotos del teléfono (sin curar) | Arbitraje, Brecha de Demanda | Obras, locales vacíos, multitudes, precios, carteles |
| Historial de YouTube / TikTok | Puente de Habilidad, Comportamiento | Enfoque temático consistente = acumulación latente de experiencia |
| Historial del navegador | Puente de Habilidad, Señal de Dinero | Patrones de investigación, comparación de precios, resolución de problemas |
| Historial de compras / suscripciones | Señal de Dinero, Comportamiento | Compras repetidas = demanda validada, hábitos en piloto automático |
| Notas de reuniones (internas) | Señal de Dinero, Brecha de Demanda | Conversaciones de presupuesto, quejas de herramientas, procesos rotos |
| Correos `.eml` / `.mbox` | Señal de Dinero, Red de Contactos | Ofertas de comisión, cadenas de referencias, cotizaciones de proveedores |
| Recibos / confirmaciones de pedido | Señal de Dinero, Arbitraje | La señal más honesta de lo que realmente valoras |
| Pega texto directamente | Las 6 lentes | Incluso la transcripción de una nota de voz produce señales |

Consulta [references/sources-guide.md](references/sources-guide.md) para la jerarquía completa de fuentes y las reglas de triangulación.

---

## Instalación

### Claude Code

> **Importante**: Claude Code busca skills en `.claude/skills/` en la **raíz del repositorio git**. Ejecuta esto en el lugar correcto.

```bash
# Instalar en el proyecto actual (ejecutar en la raíz del repo git)
mkdir -p .claude/skills
git clone https://github.com/realteamprinz/midas-skill .claude/skills/midas-skill

# O instalar globalmente (disponible en todos los proyectos)
git clone https://github.com/realteamprinz/midas-skill ~/.claude/skills/midas-skill
```

### OpenClaw

```bash
git clone https://github.com/realteamprinz/midas-skill ~/.openclaw/workspace/skills/midas-skill
```

### Dependencias (opcional)

Midas es Markdown puro — sin dependencias de runtime. Las herramientas Python para recolección automatizada de entradas (parser de historial del navegador, OCR de recibos, etc.) están planificadas y vivirán en `tools/` en una versión futura.

---

## Uso

En Claude Code u OpenClaw, escribe cualquiera de las frases activadoras de Midas:

```
Midas, mine this                 → pega cualquier entrada, obtén el reporte
Turn this into gold              → igual
What money signal is here        → enfoque más específico
点石成金                         → el mismo, en chino
Midas, analyze this deal         → modo analizador de deals
What am I missing                → alimenta con una semana de tus mensajes
```

Midas procesa cada entrada a través del motor de extracción de 6 lentes, cruza contra tu registro `evolution/evolution.jsonl` y devuelve un Reporte de Señales clasificado con **Próximas Acciones Inmediatas**.

### Las 6 Lentes

| # | Lente | Pregunta Central |
|---|-------|------------------|
| 1 | **Señal de Dinero** | ¿Dónde se mueve, atasca o filtra el dinero? |
| 2 | **Brecha de Demanda** | ¿Qué quiere la gente que nadie está proveyendo? |
| 3 | **Ventana de Arbitraje** | ¿Dónde se está valorando mal el valor? |
| 4 | **Puente de Habilidad** | ¿Qué sabes ya que tiene valor de mercado? |
| 5 | **Red de Contactos** | ¿Quién debería hablar con quién, y cuál es la comisión? |
| 6 | **Palanca Conductual** | ¿Qué hábito automático está a una pivot de generar ingresos? |

Metodología completa en [references/signal-extraction-framework.md](references/signal-extraction-framework.md).

---

## Demo

> Entrada: *"Midas, mine this — aquí está mi última semana de Slack: [73 mensajes pegados]"*

```
[REPORTE DE SEÑALES MIDAS]

Tipo de entrada:  slack_messages
Volumen:          73 mensajes en 3 canales + 4 DMs
Fecha del scan:   2026-04-09

🟡 SEÑALES DE DINERO DETECTADAS: 7
🔴 RUIDO DESCARTADO:             ~65 mensajes (89%)

🥇 #1 — Marcus como Consultor Interno (Cuña de Puente de Habilidad)
    Confianza: 50% | Esfuerzo: Bajo | Potencial: $3–8k/mes de ingreso extra
    Evidencia:
      - DM de Sarah: "si alguien pudiera resolver esto de punta a punta por menos de $5k, pagaríamos"
      - DM de Priya: "yo misma pagaría por eso"
      - 3 stakeholders distintos le pidieron ayuda a Marcus por 3 problemas en una semana
    Coincidencia de patrón: Buffett — quédate en tu círculo de competencia

    ⚡ Próxima acción inmediata:
       Lunes 9 AM, enviar DM a Sarah con una oferta con alcance definido:
       "Para el proyecto de etiquetado de AWS — tarifa fija $3,500, entregado el próximo viernes."

🥈 #2 — Consultoría única de visibilidad de costos AWS (productizada)
    Confianza: 52% | Esfuerzo: Bajo | Potencial: $5k por engagement, repetible
    Coincidencia de patrón: Thiel — pequeño monopolio que nadie toma en serio
    ...
```

Recorrido completo en [examples/daily-slack-mining/](examples/daily-slack-mining/).

**Cinco ejemplos de corridas incluidos:**

| Ejemplo | Tipo de entrada | Resultado |
|---|---|---|
| [daily-slack-mining](examples/daily-slack-mining/) | Slack de trabajo, 1 semana | 7 señales, 5 oportunidades de mensajes "aburridos" |
| [photo-roll-mining](examples/photo-roll-mining/) | 30 fotos del teléfono, 1 semana | 🏆 **DORADO** al 75% — práctica completa de carpintería |
| [complaint-mining](examples/complaint-mining/) | Grupo de WhatsApp, 2 semanas | 🏆 **DORADO** al 78% — oportunidad de directorio vecinal |
| [browsing-mining](examples/browsing-mining/) | Navegador + YouTube, 1 semana | 🏆 **DORADO** al 82% — la confianza más alta del set |
| [billionaire-pattern-match](examples/billionaire-pattern-match/) | Acumulativo | Cruza 4 perfiles de usuario contra los playbooks de Musk/Buffett/Thiel |

---

## Instalación Detallada

### Paso 1 — Clona el repo

```bash
git clone https://github.com/realteamprinz/midas-skill
cd midas-skill
```

### Paso 2 — Colócalo donde Claude Code lo busca

Para Claude Code, los skills viven en `.claude/skills/` en la **raíz del repo git** (por proyecto) o en `~/.claude/skills/` (global). Elige uno:

```bash
# Por proyecto: primero cd al repo git al que quieres asociar el skill
mkdir -p .claude/skills
cp -r /path/to/midas-skill .claude/skills/midas-skill

# O global (disponible en cada proyecto)
mkdir -p ~/.claude/skills
cp -r /path/to/midas-skill ~/.claude/skills/midas-skill
```

### Paso 3 — Verifica que el skill cargue

Abre una sesión de Claude Code en el repo donde lo instalaste. Escribe:

```
What skills are available?
```

Midas debe aparecer como `midas-skill`. Si no, verifica que `SKILL.md` esté en la raíz de la carpeta instalada y que el frontmatter YAML sea válido.

### Paso 4 — Ejecuta tu primera mina

Pega cualquier entrada ruidosa con una frase activadora:

```
Midas, mine this — últimos 50 mensajes de mi Slack #general:
[pegar contenido]
```

Midas producirá tu primer Reporte de Señales y añadirá la primera entrada a `evolution/evolution.jsonl`.

### Paso 5 — Alimenta variedad con el tiempo

Midas se afila con más entradas variadas. Consulta [references/sources-guide.md](references/sources-guide.md) para la rotación semanal recomendada (Slack los lunes, fotos los miércoles, navegación los jueves, etc.). Día 1 te da suposiciones. Día 30 te da convicción. Día 90 te da un playbook.

---

## Características

### 🔍 Motor de Extracción de 6 Lentes

Cada entrada pasa por Señal de Dinero / Brecha de Demanda / Arbitraje / Puente de Habilidad / Red de Contactos / Palanca Conductual. Cada señal es rastreable a la frase, imagen o dato exacto que la produjo.

### 🧠 Inteligencia Acumulativa Auto-aprendizaje

Midas no se reinicia entre sesiones. Cada entrada se añade a `evolution/evolution.jsonl`. Las nuevas señales se cruzan con todas las anteriores. **La confianza solo aumenta con evidencia independiente y cruzada.**

| Evidencia | Confianza | Flag de Midas |
|---|---|---|
| 1 señal de fuente única | 15–35% | Observando |
| 2 fuentes independientes confirmando | 40–65% | Hipótesis de trabajo |
| 3+ fuentes independientes convergiendo | 70–90% | 🏆 DORADO — ACTÚA |
| Validación directa de mercado | 85–95% | 🏆 DORADO — ACTÚA YA |

### 🎯 Matcher de Patrones de Sistemas Operativos de Riqueza Famosos

Sistemas operativos de riqueza pre-construidos para [Musk](references/famous-models/elon-musk.md), [Buffett](references/famous-models/warren-buffett.md) y [Thiel](references/famous-models/peter-thiel.md). Cuando tus señales se acumulan, Midas chequea automáticamente qué playbook coincide estructuralmente con tu situación.

> "Tu patrón se parece al Thiel temprano: monopolio en un nicho que nadie toma en serio. El playbook de Thiel dice: domina primero el mercado pequeño."

### 💼 Analizador de Deals

Apunta Midas a cualquier transacción específica (tuya o M&A pública) con *"Midas, analyze this deal"* y obtén un desglose estructurado de 8 partes: partes, estructura, fuente de fondos, asignación de riesgo, ruta de salida, palanca oculta, veredicto, coincidencia de patrón. Ver [references/deal-template.md](references/deal-template.md).

### ⚡ Acción, no Análisis

Cada Reporte de Señales termina con una **Próxima Acción Inmediata** — verbo específico + sustantivo específico. Nunca "explorar opciones". Siempre "DM a Dave esta noche y pregúntale cuántas horas/semana gasta en el reporte manual".

---

## Estructura del Proyecto

```
midas-skill/
├── SKILL.md                              # Entrada principal
├── README.md                             # README principal en inglés
├── README_ZH.md · README_ES.md · ...     # Variantes de idiomas
├── LICENSE                               # MIT
├── references/
│   ├── signal-extraction-framework.md    # Metodología de 6 lentes
│   ├── noise-to-gold-pipeline.md         # Pipeline de extracción de 7 etapas
│   ├── deal-template.md                  # Plantilla de análisis de deals
│   ├── sources-guide.md                  # Jerarquía de fuentes de entrada
│   └── famous-models/                    # Sistemas operativos de riqueza Musk / Buffett / Thiel
├── examples/                             # 5 ejemplos trabajados
└── evolution/
    └── evolution.jsonl                   # Tu registro personal de inteligencia acumulativa
```

---

## Principios de Diseño

1. **Tu ruido es tu mineral.** Cada interacción mundana contiene señales potenciales de riqueza.
2. **La repetición es la señal principal.** Si algo aparece dos veces en tu vida, es un mercado.
3. **La referencia cruzada le gana a la fuente única.** Una señal es una suposición. Tres son una convicción.
4. **Acción sobre análisis.** Midas produce próximos pasos, no ensayos.
5. **Inteligencia compuesta.** Día 1 da suposiciones. Día 90 da un playbook.
6. **Sin juicio moral.** Midas estudia cómo se mueve el dinero, no cómo *debería* moverse.
7. **Límites honestos.** Sin predicciones. Sin garantías. No es consejo financiero.
8. **Solo información pública.** Solo lo que alimentas voluntariamente.

---

## Licencia

MIT. Ver [LICENSE](LICENSE).

## No es Consejo Financiero

Midas no proporciona consejo de inversión, impuestos, legal o contable. Nada en una salida de Midas es una recomendación para comprar o vender cualquier valor. Antes de actuar sobre cualquier oportunidad generada por Midas que involucre capital material, consulta a un profesional licenciado en tu jurisdicción.

---

**Convierte tus Pedidos Repetidos en Oro.**
