# Documentación Técnica del Proyecto Low Scope RPG

Este documento detalla la estructura de clases, funciones y comportamiento del sistema.

## 1. Global: GameManager (Singleton)
**Archivo:** `scripts/globals/GameManager.gd`
**Descripción:** Maneja el estado global del juego, la persistencia de datos (guardado/carga) y la configuración de la party. Está configurado como Autoload.

### Variables
*   `party`: Array de diccionarios. Almacena el estado de los personajes (HP, XP, Nivel, Equipamiento).
*   `inventory`: Array de Strings. IDs de items en posesión.
*   `gold`: Entero. Dinero actual.
*   `selected_level`: Entero. Almacena el nivel seleccionado para la escena de combate.
*   `enemy_database`: Diccionario. Datos cargados desde `res://data/enemies.json`.
*   `level_database`: Diccionario. Datos cargados desde `res://data/levels.json`.
*   `item_database`: Diccionario. Datos cargados desde `res://data/items.json`.

### Funciones Principales
*   `new_game()`: Inicializa una nueva partida.
*   `save_game()` / `load_game()`: Persistencia en `user://savegame.json`. Guarda party, inventario y oro.
*   `buy_item(item_id)`: Resta oro y añade item al inventario si es posible.
*   `equip_item(member_idx, item_id)`: Equipa un item a un personaje, intercambiando si ya tiene algo en el slot.
*   `unequip_item(member_idx, slot)`: Desequipa item y lo devuelve al inventario.
*   `get_party_total_stat_bonus(stat_name)`: Calcula bonos totales de equipamiento de toda la party.

---

## 2. Datos (Data Driven)
El juego carga configuración desde archivos JSON en `res://data/`.

*   `items.json`: Define items, slots (weapon, helmet, chest, pants, boots), precio y estadísticas (damage, hp, stamina, stamina_regen).
*   `enemies.json`: Define atributos de enemigos y tipo de IA.
*   `levels.json`: Define composición de enemigos por nivel.

---

## 3. Escena: LevelSelector
**Archivo:** `scripts/scenes/LevelSelector.gd`
**Descripción:** Hub principal del juego. Utiliza un sistema de pestañas (Tabs).

### Pestañas
1.  **Levels:** Selección de dificultad (Niveles 1-5), Guardar Partida, Volver al Menú.
2.  **Shop:** Lista de items disponibles para comprar con Oro.
3.  **Inventory:** Gestión de equipo. Permite seleccionar un Héroe, ver su equipo actual, desequipar items y equipar items desde el inventario.

---

## 4. Escena: Combat
**Archivo:** `scripts/scenes/Combat.gd`
**Descripción:** Sistema de combate ATB con combos, estadísticas dinámicas y compañeros controlados por IA.

### Mecánicas
*   **Player (Hero 1):** Controlado por el usuario.
    *   **Input:** Combos Q/W/E (Heal, Damage, Heavy Damage).
    *   **Stamina:** Barra superior grande. Se consume al presionar teclas.
*   **Compañeros (AI):**
    *   **Stamina:** Barras independientes debajo de cada héroe. Regeneran automáticamente.
    *   **IA:** Cuando la stamina llega a 30, ejecutan una acción automáticamente.
        *   **Heal:** 30% de probabilidad si algún aliado tiene < 50% HP.
        *   **Attack:** Ataca a un enemigo aleatorio con su daño base + equipo.
*   **Stats Dinámicos:**
    *   **Max Stamina y Regen:** Individual para cada miembro, basado en su equipo.
    *   **Daño:** El daño del Player usa solo sus stats. El daño de la IA usa sus propios stats.
*   **IA Enemiga:**
    *   `random`: Aleatorio.
    *   `focus_weak`: Ataca al más débil.
    *   `aggressive`: Ataca al más fuerte.
