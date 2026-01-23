# Documentación Técnica del Proyecto Low Scope RPG

Este documento detalla la estructura de clases, funciones y comportamiento del sistema.

## 1. Global: GameManager (Singleton)
**Archivo:** `scripts/globals/GameManager.gd`
**Descripción:** Maneja el estado global del juego, la persistencia de datos (guardado/carga) y la configuración de la party. Está configurado como Autoload.

### Variables
*   `party`: Array de diccionarios. Almacena el estado de los personajes (HP, XP, Nivel, Equipamiento, Stats Base).
*   `inventory`: Array de Strings. IDs de items en posesión.
*   `gold`: Entero. Dinero actual.
*   `completed_levels`: Array de enteros. Registra los índices de los niveles superados.
*   `selected_level`: Entero. Almacena el nivel seleccionado para la escena de combate.
*   `enemy_database`: Diccionario. Datos cargados desde `res://data/enemies.json`.
*   `level_database`: Diccionario. Datos cargados desde `res://data/levels.json`.
*   `item_database`: Diccionario. Datos cargados desde `res://data/items.json`.
*   `growth_database`: Diccionario. Datos cargados desde `res://data/growth.json`.

### Funciones Principales
*   `new_game()`: Inicializa una nueva partida.
*   `save_game()` / `load_game()`: Persistencia en `user://savegame.json`. Guarda party, inventario, oro y niveles completados.
*   `buy_item(item_id)`: Resta oro y añade item al inventario si es posible.
*   `equip_item(member_idx, item_id)`: Equipa un item a un personaje.
*   `mark_level_complete(level_idx)`: Marca un nivel como completado y guarda el juego.
*   `gain_rewards(xp_amount, gold_amount)`: Añade Oro globalmente y XP a cada miembro de la party, verificando Level Up.

---

## 2. Modo Animado (MVC)

El juego incluye un modo "Animado" que utiliza una arquitectura Modelo-Vista-Controlador.

### Level Selector Animated
*   **Controller:** `scripts/scenes/LevelSelectorController.gd`
*   **View:** `scripts/scenes/LevelSelectorAnimated.gd`
*   Muestra la interfaz usando nodos gráficos (`TextureRect`) en lugar de controles básicos.

### Combat Animated
*   **Controller:** `scripts/scenes/CombatController.gd`. Maneja toda la lógica de combate (ATB, Inputs, AI). Emite señales para actualizar la vista.
*   **View:** `scripts/scenes/CombatAnimated.gd`. Escucha señales y actualiza sprites, barras y textos.

---

## 3. Escena: Combat (Clásica & Animada)
**Descripción:** Sistema de combate ATB con combos, estadísticas dinámicas y compañeros controlados por IA.

### Mecánicas
*   **Player (Hero 1):** Controlado por el usuario.
    1.  **Input Combo:** Introduce secuencia Q/W/E (3 teclas). Existe un **Cooldown de 0.5s** entre cada input.
    2.  **Targeting:** Una vez completada la secuencia, el juego espera a que el jugador **clickee un enemigo**.
    3.  **Ejecución:** Al clickear, se dispara el ataque (Daño/Cura) y se reinicia el combo.
*   **Buffs y Debuffs:**
    *   **Bleed (Debuff):** Stackeable. Pierde 1 HP por stack cada segundo. Duración 4s. Aplicado por inputs **Q**.
    *   **Slowed (Debuff):** Reduce regeneración de stamina a la mitad. Duración 5s. Aplicado por inputs **E**.
    *   **Attack Boost (Buff):** Aumenta el daño del jugador en un 20%. Duración 10s. Aplicado por inputs **W**.
*   **Compañeros (AI):** Actúan automáticamente (Curar/Atacar) cuando su Stamina llega a 30.
*   **Stats Dinámicos:** HP, Daño y Stamina calculados en base a Nivel y Equipo.
*   **Recompensas:** Al ganar, se entrega XP y Oro basado en enemigos derrotados.
*   **IA Enemiga:**
    *   `random`: Aleatorio.
    *   `focus_weak`: Ataca al más débil.
    *   `aggressive`: Ataca al más fuerte.
    *   `twin_attack`: Patrón alternado (Aleatorio -> Repetir Mismo Objetivo -> Aleatorio...).
    *   `last_attacker`: Ataca al personaje que lo atacó por última vez (o Random si nadie lo atacó).
