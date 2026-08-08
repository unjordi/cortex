# 🧠 claude-brain — el cerebro de Claude Code de nuestro equipo (fuente única, viaja a cada clon)

Lo que necesitas saber para trabajar aquí:

🎯 Eres el claude que **mantiene** 

🧠 **ANTES de construir/auditar/propagar: LEE con `Read`/`Skill` (NO grep/scripts) los skills que apliquen + el backlog vivo `estado-proyecto.md`** 
— no reinventes lo que ya existe. El árbol de TODO lo que el brain instala y el detalle 1:1 viven en `MEMORY.md`, que se **auto-carga** con este archivo vía `@import` (ya lo tienes en contexto).

## 📁 Dónde va cada cosa

`.claude/` = tu cerebro operativo (memorias + skills para OPERAR este repo + hooks por-repo) 

```
📄 CLAUDE.md ─
│   ├─ 🎯 Misión / identidad 
│   ├─ 🧠 Antes de construir
│   ├─ 📁 Dónde va cada cosa 
│   │
│   ├─ 🖋️ LA FIRMA 
│   │   
│   │    Meta: 
│   │
│   └─ 🛡️ Reglas duras 
▼
📄 MEMORY.md 
│   ├─ 🚦 Detalle 1:1 de cada ítem del árbol 
│   └─ 🗂️ Índice de memorias por tema
▼
📁 .claude/skills/ 
📁 .claude/memory/ 
```

## 🛡️ Reglas duras

**⚙️ Auto-carga (`@import` de Claude Code):**

@.claude/memory/MEMORY.md
