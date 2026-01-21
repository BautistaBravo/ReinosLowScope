# Documentación Técnica del Proyecto Low Scope RPG

Este documento detalla la estructura de clases, funciones y comportamiento del sistema.

## 1. Global: GameManager (Singleton)
**Archivo:** `scripts/globals/GameManager.gd`
**Descripción:** Maneja el estado global del juego, la persistencia de datos (guardado/carga) y la configuración de la party. Está configurado como Autoload.

### Variables
*   `party`: Array de diccionarios. Almacena el estado de los personajes (HP, XP, Nivel).
*   `selected_level`: Entero. Almacena el nivel seleccionado para la escena de combate.
*   `SAVE_PATH`: Constante. Ruta del archivo de guardado (`user://savegame.json`).
*   `enemy_database`: Diccionario. Datos cargados desde `res://data/enemies.json`.
*   `level_database`: Diccionario. Datos cargados desde `res://data/levels.json`.

### Funciones
*   `_ready()`
    *   **Comportamiento:** Carga los archivos JSON de enemigos y niveles en memoria.
*   `new_game()`
    *   **Comportamiento:** Inicializa una nueva partida creando una party por defecto y guarda el juego.
    *   **Llamado por:** Botón "New Game" en `MainMenu`.
*   `_init_default_party()`
    *   **Comportamiento:** Crea 3 personajes con estadísticas base (Nivel 1, 20 HP).
    *   **Llamado por:** `new_game()`.
*   `save_game()`
    *   **Comportamiento:** Serializa el estado de la `party` a formato JSON y lo escribe en disco.
    *   **Llamado por:** `new_game()` y al finalizar un combate con victoria en `Combat`.
*   `load_game() -> bool`
    *   **Comportamiento:** Lee el archivo JSON del disco y restaura el estado de la `party`. Retorna `true` si tuvo éxito.
    *   **Llamado por:** Botón "Load Game" en `MainMenu`.
*   `get_level_data(level_index)`
    *   **Comportamiento:** Retorna una lista de enemigos basada en la configuración del archivo `levels.json`. Si el nivel no existe, usa un enemigo por defecto ("Fallback Slime").
    *   **Llamado por:** Escena `Combat` al iniciar (`_ready`).
*   `heal_party(amount)`
    *   **Comportamiento:** Suma puntos de vida a todos los miembros de la party (hasta su máx HP).
    *   **Llamado por:** Escena `Combat` al ejecutar un combo con inputs "W".
*   `damage_party_member(index, amount)`
    *   **Comportamiento:** Reduce la vida de un miembro específico de la party.
    *   **Llamado por:** Lógica de ataque enemigo en `Combat`.
*   `gain_party_xp(amount)`
    *   **Comportamiento:** Otorga experiencia a la party y maneja la subida de nivel (incremento de Max HP y curación completa).
    *   **Llamado por:** Escena `Combat` tras la victoria.

---

## 2. Datos (Data Driven)
El juego carga la configuración de enemigos y niveles desde archivos JSON.

### Archivo: `data/enemies.json`
Define los tipos de enemigos.
Ejemplo:
```json
"goblin": {
    "name": "Goblin",
    "hp": 40,
    "damage": 5,
    "speed": 15.0,
    "ai_type": "focus_weak"
}
```

### Archivo: `data/levels.json`
Define qué enemigos aparecen en cada nivel.
Ejemplo:
```json
"2": ["slime", "goblin"]
```

---

## 3. Escena: MainMenu
**Archivo:** `scripts/scenes/MainMenu.gd`
**Descripción:** Pantalla de inicio con opciones para comenzar o cargar juego.

### Funciones
*   `_ready()`
    *   **Comportamiento:** Construye la interfaz de usuario (Título, Botones) programáticamente.
*   `_on_new_game_pressed()`
    *   **Comportamiento:** Llama a `GameManager.new_game()` y cambia a la escena `LevelSelector`.
    *   **Llamado por:** Señal `pressed` del botón "New Game".
*   `_on_load_game_pressed()`
    *   **Comportamiento:** Intenta cargar con `GameManager.load_game()`. Si es exitoso, cambia a `LevelSelector`.
    *   **Llamado por:** Señal `pressed` del botón "Load Game".

---

## 4. Escena: LevelSelector
**Archivo:** `scripts/scenes/LevelSelector.gd`
**Descripción:** Permite al jugador elegir el nivel de dificultad.

### Funciones
*   `_ready()`
    *   **Comportamiento:** Genera botones para los niveles 1 al 5.
*   `_on_level_selected(level_idx)`
    *   **Comportamiento:** Actualiza `GameManager.selected_level` con el nivel elegido y cambia a la escena `Combat`.
    *   **Llamado por:** Señal `pressed` de los botones de nivel.
*   `_on_back_pressed()`
    *   **Comportamiento:** Regresa a `MainMenu`.
    *   **Llamado por:** Señal `pressed` del botón "Back".

---

## 5. Escena: Combat
**Archivo:** `scripts/scenes/Combat.gd`
**Descripción:** Maneja la lógica de combate, sistema de inputs, stamina y turnos de enemigos (ATB). Incluye lógica de IA.

### Variables
*   `current_stamina`: Float. Stamina actual del jugador.
*   `input_buffer`: Array. Almacena la secuencia de teclas Q, W, E.
*   `enemies_data`: Copia local de los enemigos cargados para el nivel.
*   `enemy_atb_gauges`: Array de progreso (0-100) para el ataque enemigo.

### Funciones
*   `_ready()`
    *   **Comportamiento:** Inicializa UI, carga datos de la party desde `GameManager` y enemigos según el nivel.
*   `_process(delta)`
    *   **Comportamiento:**
        1. Regenera stamina del jugador.
        2. Incrementa las barras ATB de los enemigos basándose en su `speed`. Si una barra llena, llama a `_enemy_attack()`.
    *   **Llamado por:** Motor de Godot cada frame.
*   `_input(event)`
    *   **Comportamiento:** Detecta teclas Q, W, E. Consume stamina y añade al buffer. Si el buffer llega a 3, llama a `_execute_combo()`.
    *   **Llamado por:** Motor de Godot al recibir input.
*   `_execute_combo()`
    *   **Comportamiento:** Interpreta el buffer de 3 teclas:
        *   **W:** Cura 1 HP a la party por cada W.
        *   **Q:** 1 daño al enemigo seleccionado por cada Q.
        *   **E:** 2 daño al enemigo seleccionado por cada E.
        *   Verifica condiciones de victoria tras el daño.
    *   **Llamado por:** `_input` al completar 3 teclas.
*   `_enemy_attack(enemy_idx)`
    *   **Comportamiento:** Ejecuta el ataque enemigo según su `ai_type`:
        *   `random`: Ataca a un objetivo aleatorio.
        *   `focus_weak`: Ataca al miembro con menos HP.
        *   `aggressive`: Ataca al miembro con más HP.
    *   **Llamado por:** `_process` cuando la barra ATB del enemigo se llena.
*   `_check_win_condition()`
    *   **Comportamiento:** Verifica si todos los enemigos murieron. Si sí, otorga XP, guarda el juego y regresa al selector de nivel.
    *   **Llamado por:** `_execute_combo`.
*   `_check_loss_condition()`
    *   **Comportamiento:** Verifica si toda la party murió. Si sí, regresa al menú principal.
    *   **Llamado por:** `_enemy_attack`.
