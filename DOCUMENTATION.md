# Documentación Técnica del Proyecto Low Scope RPG

Este documento detalla la estructura de clases, funciones y comportamiento del sistema.

## 1. Global: GameManager & SoundManager
*   **GameManager:** Singleton de estado (Party, Inventario, Progreso).
*   **SoundManager:** Singleton de Audio.

---

## 2. Sistema de Héroes y Selección
*   **Archivo:** `data/heroes.json`. Define el roster con sus estadísticas y habilidades (Q, W, E).
*   **Selección:** Al iniciar `New Game` y tras vencer niveles 2 y 4, se eligen héroes.

## 3. Escena: LevelSelector (Animated)
*   **Stats Tab:** Muestra stats detallados y permite **Configurar Combo AI**.
    *   **Combo AI:** El jugador puede grabar una secuencia de 3 teclas (Q/W/E) que el héroe usará automáticamente cuando sea controlado por la IA. Por defecto es aleatorio.

---

## 4. Escena: Combat (Animated)
**Descripción:** Sistema de combate ATB con combos, estadísticas dinámicas y compañeros controlados por IA.

### Mecánicas
*   **Control de Héroe:**
    *   El jugador controla a un héroe a la vez.
    *   **TAB:** Alterna el control entre los héroes vivos.
    *   El héroe controlado se resalta visualmente ("[CTRL]").
    *   La barra de Stamina principal refleja la del héroe controlado.
*   **Player (Hero Controlado):**
    1.  **Input Combo:** Secuencia Q/W/E (Cooldown 0.225s).
    2.  **Targeting:** Selección de enemigo con **Flechas** (Up, Down) y confirmación con **0**.
    3.  **Ejecución:** Se dispara la habilidad mapeada en `heroes.json`.
*   **Compañeros (AI):**
    *   Actúan automáticamente cuando su Stamina llega a 30.
    *   Si tienen un **Combo AI** configurado, ejecutan esa secuencia específica.
    *   Si no, eligen acciones al azar.
*   **Buffs y Debuffs:** Bleed, Slowed, Attack Boost.
*   **IA Enemiga:** Random, Twin Attack, Last Attacker, Focus Weak, Aggressive.
