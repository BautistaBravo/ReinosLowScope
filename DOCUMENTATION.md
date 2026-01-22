# Documentación Técnica del Proyecto Low Scope RPG

Este documento detalla la estructura de clases, funciones y comportamiento del sistema.

## 1. Global: GameManager (Singleton)
**Archivo:** `scripts/globals/GameManager.gd`
**Descripción:** Maneja el estado global del juego, la persistencia de datos (guardado/carga) y la configuración de la party. Está configurado como Autoload.

### Variables
*   `party`: Array de diccionarios. Almacena el estado de los personajes (HP, XP, Nivel, Equipamiento, Stats Base).
*   `inventory`: Array de Strings. IDs de items en posesión.
*   `gold`: Entero. Dinero actual.
*   `selected_level`: Entero. Almacena el nivel seleccionado para la escena de combate.
*   `enemy_database`: Diccionario. Datos cargados desde `res://data/enemies.json`.
*   `level_database`: Diccionario. Datos cargados desde `res://data/levels.json`.
*   `item_database`: Diccionario. Datos cargados desde `res://data/items.json`.
*   `growth_database`: Diccionario. Datos cargados desde `res://data/growth.json`.

### Funciones Principales
*   `new_game()`: Inicializa una nueva partida.
*   `save_game()` / `load_game()`: Persistencia en `user://savegame.json`. Guarda party, inventario y oro.
*   `buy_item(item_id)`: Resta oro y añade item al inventario si es posible.
*   `equip_item(member_idx, item_id)`: Equipa un item a un personaje.
*   `unequip_item(member_idx, slot)`: Desequipa item.
*   `gain_party_xp(amount)`: Otorga XP y verifica Level Up usando `growth.json`.

---

## 2. Datos (Data Driven)
El juego carga configuración desde archivos JSON en `res://data/`.

*   `items.json`: Define items, slots (weapon, helmet, chest, pants, boots), precio y estadísticas.
*   `enemies.json`: Define atributos de enemigos y tipo de IA.
*   `levels.json`: Define composición de enemigos por nivel.
*   `growth.json`: Define estadísticas base (HP, Daño, Stamina, Regen, XP Requerida) por Nivel.

---

## 3. Escena: LevelSelector
**Archivo:** `scripts/scenes/LevelSelector.gd`
**Descripción:** Hub principal del juego con selección de nivel, tienda e inventario.

---

## 4. Escena: Combat
**Archivo:** `scripts/scenes/Combat.gd`
**Descripción:** Sistema de combate ATB con combos, estadísticas dinámicas y compañeros controlados por IA.

### Mecánicas
*   **Player (Hero 1):** Controlado por el usuario. Input Q/W/E consume stamina del Player.
*   **Compañeros (AI):** Actúan automáticamente (Curar/Atacar) cuando su Stamina llega a 30.
*   **Stats Dinámicos:**
    *   **HP / Max HP:** Base por Nivel + Bonus Equipamiento.
    *   **Daño:** Base por Nivel + Bonus Equipamiento + Multiplicador de Combo.
    *   **Stamina:** Base por Nivel + Bonus Equipamiento.
*   **Progresión:**
    *   Al ganar combate, se obtiene XP.
    *   Si XP > Exp Requerida (según `growth.json`), el personaje sube de nivel, incrementando sus stats base y curándose completamente.
