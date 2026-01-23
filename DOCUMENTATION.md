# Documentación Técnica del Proyecto Low Scope RPG

Este documento detalla la estructura de clases, funciones y comportamiento del sistema.

## 1. Global: GameManager & SoundManager
*   **GameManager:** Singleton de estado (Party, Inventario, Progreso).
*   **SoundManager:** Singleton de Audio.
    *   Genera efectos de sonido procedurales (`AudioStreamWAV`) para evitar dependencias externas.
    *   `play_sfx(name)`: Reproduce 'click', 'hit', 'buy', 'victory', 'win_game'.
    *   `play_music(name)`: Reproduce música (placeholder/log).

---

## 2. Modos de Juego (Clásico vs Animado)
El proyecto soporta dos modos visuales con la misma lógica subyacente.

### Clásico (Prototipo UI)
*   **Escenas:** `LevelSelector.tscn`, `Combat.tscn`.
*   **Implementación:** Lógica y Vista acopladas en un solo script GDScript.

### Animado (MVC)
*   **Escenas:** `LevelSelectorAnimated.tscn`, `CombatAnimated.tscn`.
*   **Implementación:** Separación en Controlador (`CombatController.gd`) y Vista (`CombatAnimated.gd`).
*   **Gráficos:** Uso de `TextureRect` y placeholders visuales.

---

## 3. Escena: Combat (Clásica & Animada)
**Descripción:** Sistema de combate ATB con combos, estadísticas dinámicas y compañeros controlados por IA.

### Mecánicas
*   **Inicio:** Delay de 2 segundos antes de comenzar.
*   **Player (Hero 1):**
    1.  **Input Combo:** Secuencia Q/W/E (Cooldown 0.5s).
    2.  **Targeting:** Selección de enemigo con **Flechas** y confirmación con **0**.
    3.  **Feedback Sonoro:** Sonidos al confirmar, atacar y recibir daño.
*   **Buffs y Debuffs:** Bleed (Q), Slowed (E), Attack Boost (W).
*   **Compañeros (AI):** Actúan automáticamente (Curar/Atacar) cuando su Stamina llega a 30.
*   **Recompensas:** XP y Oro. Level Up cura totalmente al personaje.
