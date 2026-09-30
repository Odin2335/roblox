# Age of Worlds – Gameplay-Architektur (Unity 6)

Echtzeit-Strategie mit Zivilisationsfortschritt: Steinzeit → Mittelalter → Moderne → Zukunft.
Die Architektur ist so gebaut, dass weitere Epochen (bis 10–12), Einheiten, Gebäude und Technologien
hauptsächlich über **ScriptableObjects** hinzukommen, ohne dass Core-Code umgeschrieben werden muss.

**Stand: Fundament + Phase 1 (Core Prototype).** Alles Weitere folgt Phase für Phase.

---

## Ins Unity-Projekt übernehmen

Kopiere den Ordner `AgeOfWorlds/Assets/Game` nach `<DeinProjekt>/Assets/Game`,
dazu `AgeOfWorlds/Assets/ScriptableObjects` und `AgeOfWorlds/Assets/Prefabs` (bis jetzt nur leere Ordner).
Unity erzeugt die `.meta`-Dateien beim Import selbst.

### Benötigte Pakete (Window → Package Manager)

| Paket | Wofür |
| --- | --- |
| **Input System** (`com.unity.inputsystem`) | alle Eingaben (ist in Unity-6-Vorlagen meist schon installiert) |
| **AI Navigation** (`com.unity.ai.navigation`) | `NavMeshSurface` zum Baken des NavMesh |
| **uGUI / TextMeshPro** | UI-Panel (in Unity 6 im Paket `com.unity.ugui` enthalten) |

Setze unter *Edit → Project Settings → Player → Active Input Handling* den Wert **Input System Package (New)** oder **Both**.
Beim ersten TextMeshPro-Text fragt Unity nach *Import TMP Essentials*. Das bestätigen.

---

## Architektur

```
Assets/Game/
  Core/           GameManager, EventBus, GameServices, MapBounds
    Players/      PlayerManager, PlayerState, MatchConfig
    Spatial/      SpatialHashGrid (Nachbarsuche ohne globale Suchen)
    Interfaces/   ISelectable
  Data/           ScriptableObject-Definitionen: UnitData, BuildingData, TechnologyData, EraData, FactionData, Enums
  Units/          Unit, UnitMovement, UnitManager, UnitCommand
    States/       wiederverwendbare Zustände (Idle, Move, … später Gather, Attack, Chase …)
  Commands/       CommandManager, Formationen
  Selection/      SelectionManager, SelectionMarker
  CameraSystem/   RTSCameraController
  Input/          RTSControls.inputactions, InputReader
  UI/             SelectionBoxUI, SelectionPanelUI
Assets/ScriptableObjects/   Daten-Assets (Units, Buildings, Technologies, Eras, Factions, Match)
Assets/Prefabs/             Units, Buildings, Resources, VFX
```

### Grundprinzipien

- **Kein Gott-GameManager.** `GameManager` kümmert sich nur um Match-Start, Pause, Sieg und Niederlage. Jedes System ist ein eigener Manager.
- **EventBus** (`Core/EventBus.cs`): Events sind Structs, zum Beispiel `UnitCreatedEvent`, `SelectionChangedEvent` oder `GameStateChangedEvent`. Die UI abonniert Events und fragt keinen Zustand ab (kein Polling).
- **GameServices** (`Core/GameServices.cs`): eine kleine Registry. Manager registrieren sich in `Awake`, und gespawnte Objekte wie Einheiten finden sie dort. Es gibt keine `FindObjectOfType`-Aufrufe im Gameplay.
- **Manager-getriebene Ticks:** Einzelne Einheiten haben kein eigenes `Update()`. `UnitManager` tickt alle Einheiten:
  - pro Frame nur Rotation und Separation,
  - die State Machines mit 10 Hz,
  - Nachbarsuchen über ein Spatial Hash Grid.
- **Daten sind unveränderlich:** ScriptableObjects haben nur Getter. Upgrades laufen später über Laufzeit-Modifikatoren pro Spieler (`StatModifier`), nie über das Asset selbst.
- **Eingaben nur über Actions:** Code liest Aktionen wie `Select`, `Command` oder `CameraMove`, nie konkrete Tasten. Alle Bindings liegen in `RTSControls.inputactions` und sind dort änderbar.
- **Pooling:** Auswahlringe laufen über `UnityEngine.Pool.ObjectPool`. Projektile, VFX und Healthbars folgen demselben Muster.

---

## Phase 1 – Szene einrichten (Schritt für Schritt)

### 1. Layer anlegen

*Edit → Project Settings → Tags and Layers*: lege die Layer **Ground** und **Unit** an.

### 2. Boden + NavMesh

1. *GameObject → 3D Object → Plane*, Name `Ground`, Scale `(20, 1, 20)`. Das ergibt eine Fläche von 200 × 200. Setze den Layer auf **Ground**.
2. Optional kannst du ein paar Würfel als Hindernisse daraufstellen.
3. Leeres GameObject `NavMesh`, dazu Komponente **NavMeshSurface** (aus dem AI-Navigation-Paket) → **Bake**.
   Nach jeder Änderung an Boden oder Hindernissen neu baken.

### 3. Systems-Objekt

Lege ein leeres GameObject `Systems` an und füge diese Komponenten hinzu:

| Komponente | Inspector-Einstellungen |
| --- | --- |
| `InputReader` | **Actions** = `Assets/Game/Input/RTSControls.inputactions` |
| `PlayerManager` | – |
| `GameManager` | **Match Config** = Asset aus Schritt 4, **Player Manager** = `Systems`, **Input** = `Systems` |
| `UnitManager` | Defaults passen (Tick 0,1 s, Cell Size 4) |
| `SelectionManager` | **Input** = `Systems`, **World Camera** = Main Camera, **Selection Box** = aus Schritt 6, **Selectable Mask** = `Unit` |
| `CommandManager` | **Input** = `Systems`, **Selection** = `Systems`, **World Camera** = Main Camera, **Ground Mask** = `Ground` |

Lege außerdem ein leeres GameObject `MapBounds` an, Position `(0,0,0)`, Komponente `MapBounds`, Size `(200, 200)`.

### 4. Daten-Assets

1. Rechtsklick in `Assets/ScriptableObjects/Match` → *Create → Age of Worlds → Match Config*.
   Standard: Spieler 0 (du, Team 0) und Spieler 1 (KI, Team 1). **Local Player Id** = 0.
2. Rechtsklick in `Assets/ScriptableObjects/Units` → *Create → Age of Worlds → Unit Data*, Name `Clubman`.
   Trage ein: ID `stone_clubman`, Display Name `Clubman`, Max Health 60, Movement Speed 4, Radius 0.5.

### 5. Einheiten-Prefab

1. Leeres GameObject `Clubman` (Pivot = Boden), Layer **Unit**.
   Darunter als Kind: *3D Object → Capsule* mit lokaler Position `(0, 1, 0)`, ebenfalls Layer **Unit**.
   Der Capsule Collider des Kinds wird zum Anklicken benutzt.
2. Füge am Parent diese Komponenten hinzu: **NavMeshAgent**, `UnitMovement`, `Unit`.
   Die Werte von Speed, Radius und Acceleration setzt `UnitData` zur Laufzeit.
   - `Unit` → **Data** = `Clubman`, **Owner Id** = 0
3. Ziehe das Objekt nach `Assets/Prefabs/Units` (es wird zum Prefab). Platziere 10–20 Instanzen auf dem NavMesh.
   Setze bei 2–3 davon **Owner Id** = 1. Das sind Gegner, die du anklicken, aber nicht steuern kannst.

### 6. UI

1. *GameObject → UI → Canvas* (Render Mode: **Screen Space – Overlay**). Unity legt automatisch ein **EventSystem** an.
   Beim EventSystem: falls Unity danach fragt, *Replace with InputSystemUIInputModule*.
2. Im Canvas: *UI → Image*, Name `SelectionBox`, Farbe z. B. `(0.3, 1, 0.3, 0.2)`, Komponente `SelectionBoxUI`.
   Das Objekt bleibt aktiv, denn das Skript blendet die Box selbst ein und aus.
3. Optionales Info-Panel:
   - Im Canvas ein leeres Objekt `SelectionPanel` mit der Komponente `SelectionPanelUI`.
   - Darin ein Kind `Panel` (UI → Panel, unten mittig), darin ein **Image** (Icon) und zwei **Text – TextMeshPro** (Name, HP).
   - Ziehe `Panel` in **Panel Root**, dazu Icon, Name Text und Health Text.
     **Panel Root** muss das Kind sein, nicht `SelectionPanel` selbst.

### 7. Kamera-Rig

1. Leeres GameObject `CameraRig` bei `(0,0,0)`, Komponente `RTSCameraController`.
2. Ziehe die **Main Camera** als **Kind** unter `CameraRig`. Position und Rotation setzt das Skript.
3. Inspector: **Input** = `Systems`, **Camera Transform** = Main Camera, **Map Bounds** = `MapBounds`.

---

## Phase 1 – Testen

| Aktion | Erwartung |
| --- | --- |
| WASD / Pfeiltasten | Kamera fährt mit weichem Beschleunigen und Abbremsen |
| Maus an den Bildschirmrand | Edge-Scrolling |
| Mittlere Maustaste ziehen | Kamera verschieben |
| Mausrad | Zoom zwischen Kampfansicht (nah, flacher) und Strategieansicht (fern, steiler) |
| Bild ↑ / Bild ↓ | Kamera drehen |
| Kamera über den Kartenrand bewegen | Sie bleibt innerhalb von `MapBounds` |
| Linksklick auf Einheit | Grüner Ring, Info-Panel zeigt Name und HP |
| Linksklick auf Gegner (Owner 1) | Roter Ring, Rechtsklick bewegt ihn **nicht** |
| Linksklick auf Boden | Auswahl wird aufgehoben |
| Linke Maustaste ziehen | Auswahlrechteck, wählt nur eigene Einheiten |
| Shift + Klick | Einheit hinzufügen oder entfernen |
| Shift + Ziehen | Einheiten zur Auswahl hinzufügen |
| Doppelklick auf Einheit | Alle eigenen Einheiten desselben Typs auf dem Bildschirm |
| Rechtsklick auf Boden | Einheiten laufen hin, verteilen sich auf Formationsplätze, drehen sich weich in Laufrichtung, weichen Hindernissen aus |
| F | Formation wechseln: Loose → Line → Box (Konsole zeigt die aktive) |
| Einheiten in einen Engpass schicken | Sie blockieren sich nicht dauerhaft; wer feststeckt, akzeptiert nach kurzer Zeit seine Position |
| F10 / Pause | Spiel pausiert, die Kamera funktioniert weiter |

### Typische Fehler

- **Einheiten bewegen sich nicht, Warnung „could not path“:** Das NavMesh ist nicht gebaked, oder die Einheit steht nicht darauf.
- **Klick wählt nichts aus:** Collider fehlt, falscher Layer, oder die **Selectable Mask** des SelectionManagers passt nicht.
- **Rechtsklick tut nichts:** Die **Ground Mask** des CommandManagers enthält den Layer `Ground` nicht.
- **Magenta-Ring:** Weise im SelectionManager ein eigenes Unlit-Material bei **Marker Material** zu.

---

## Offene Design-Entscheidung vor Phase 5 / 10

Die Vorgabe verlangt **WASD für die Kamera** und zugleich **A = Attack Move, S = Stop**. Diese Tasten kollidieren.
Die Bindings sind frei änderbar. Die Standardbelegung muss aber vor Phase 5 festgelegt werden, zum Beispiel:
Kamera nur auf Pfeiltasten, oder Befehls-Hotkeys nur aktiv, solange Einheiten ausgewählt sind.

## Nächster Schritt: Phase 2 – Economy

Worker, Ressourcenknoten (Food/Tree/Metal/Energy), Sammeln mit Tragekapazität und Drop-off, Ressourcen-UI, Bevölkerung.
Dabei kommen `ResourceManager`, `PopulationManager`, `IResourceGatherer`, `IResourceDropOff` und die Worker-Zustände hinzu.
