# Documentación Técnica del Proyecto Low Scope RPG

Este documento detalla la estructura de clases, funciones y comportamiento del sistema.

## 1. Global: GameManager & SoundManager
*   **GameManager:** Singleton de estado (Party, Inventario, Progreso).
*   **SoundManager:** Singleton de Audio.

---

## 2. Sistema de Héroes y Selección
El juego comienza con una party vacía.
*   **Archivo:** `data/heroes.json`. Define el roster (Guerrero, Hada, Mago, etc.) con sus estadísticas base y habilidades.
*   **Selección de Héroe:**
    *   Al iniciar `New Game` y tras vencer los niveles 2 y 4 (si es la primera vez), se muestra la escena `HeroSelection`.
    *   Muestra 3 opciones aleatorias con sus sprites y rareza (Color de fondo).
    *   Al elegir, el héroe se une a la party.

---

## 3. Escena: Combat (Clásica & Animada)
**Descripción:** Sistema de combate ATB con combos, estadísticas dinámicas y compañeros controlados por IA.

### Mecánicas
*   **Player (Hero 1):** Controlado por el usuario.
    1.  **Input Combo:** Secuencia Q/W/E (Cooldown 0.5s).
    2.  **Targeting:** Selección de enemigo con **Flechas** y confirmación con **0**.
    3.  **Ejecución:** Al confirmar, se dispara la habilidad correspondiente a la tecla.
*   **Habilidades Modulares:**
    *   Cada héroe define qué efecto tienen Q, W y E en `heroes.json` (ej: `damage_bleed`, `heal_party`).
    *   Ya no es fijo (Q=Bleed, W=Heal, E=Slow), sino que depende del héroe líder.
*   **Buffs y Debuffs:** Bleed, Slowed, Attack Boost.
*   **Compañeros (AI):** Actúan automáticamente cuando su Stamina llega a 30.
