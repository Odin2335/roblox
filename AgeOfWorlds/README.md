# Age of Worlds – Gameplay-Architektur (Unity 6)

Echtzeit-Strategie mit Zivilisationsfortschritt: Steinzeit → Mittelalter → Moderne → Zukunft.
Die Architektur ist so gebaut, dass weitere Epochen (bis 10–12), Einheiten, Gebäude und Technologien
hauptsächlich über **ScriptableObjects** hinzukommen, ohne dass Core-Code umgeschrieben werden muss.

**Stand: Fundament + Phase 1 (Core Prototype) + Phase 2 (Economy).** Alles Weitere folgt Phase für Phase.

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
  Economy/        ResourceManager, PopulationManager, ResourceNode, ResourceDropOff, ResourceLocator, IdleWorkerTracker
    Workers/      Worker (ein System für alle Ressourcentypen) + States/
  Commands/       CommandManager, Formationen
  Selection/      SelectionManager, SelectionMarker
  CameraSystem/   RTSCameraController
  Input/          RTSControls.inputactions, InputReader
  UI/             SelectionBoxUI, SelectionPanelUI, ResourceBarUI
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

## Hotkeys (Standardbelegung)

Alle Tasten stehen in `Assets/Game/Input/RTSControls.inputactions` und können dort geändert werden.
Im Code steht keine Taste. WASD bewegt **immer nur** die Kamera.

| Aktion | Taste | Status |
| --- | --- | --- |
| Kamera | WASD + Pfeiltasten | aktiv |
| Kamera drehen | Bild ↑ / Bild ↓ | aktiv |
| Formation wechseln | F | aktiv |
| Stop | X | aktiv (seit Phase 2) |
| Pause | F10 | aktiv |
| Abbrechen / Menüs / Placement Cancel | Escape | Action angelegt, Funktion ab Phase 3 |
| Attack Move | Q | Action angelegt, Funktion in Phase 5 |
| Hold Position | H | Action angelegt, Funktion in Phase 10 |
| Patrol | P | Action angelegt, Funktion in Phase 10 |
| Build Menu | B | Action angelegt, Funktion in Phase 3 |
| Repair | R | Action angelegt, Funktion später |
| Control Group speichern | Strg + 1–9 | Actions angelegt (`ControlGroupAssignModifier` + `ControlGroup1..9`), Funktion in Phase 10 |
| Control Group abrufen | 1–9 | wie oben |

---

## Phase 2 – Economy

### Neue und geänderte Skripte

| Datei | Zweck |
| --- | --- |
| `Economy/ResourceManager.cs` | Einzige Stelle, die Vorräte ändert: `GetAmount`, `CanAfford`, `TrySpend`, `Add`. Sendet `ResourceChangedEvent`. |
| `Economy/PopulationManager.cs` | Aktuelle Bevölkerung = Summe der `PopulationCost` aller Einheiten (über Unit-Events). Max = Startkapazität + `AddCapacity` (Häuser in Phase 3), begrenzt durch Hard Cap. `HasRoomFor` für die Produktion. |
| `Economy/ResourceNode.cs` | ResourceType, MaxAmount, RemainingAmount, GatherRateModifier. Food/Tree/Metal/Energy-Knoten sind **Prefabs derselben Komponente**. Auswählbar (zeigt die Restmenge). |
| `Economy/IResourceDropOff.cs`, `ResourceDropOff.cs` | Abgabestelle. Welche Ressourcen angenommen werden, steht nur in der Liste **Accepted Resource Types** (Standard: alle vier). |
| `Economy/IResourceGatherer.cs` | CarryCapacity, GatherRate, CurrentCarryAmount, CarriedResourceType, CurrentResourceNode, CurrentDropOff |
| `Economy/ResourceLocator.cs` | Register für Knoten und Abgabestellen. Sucht den nächsten Knoten eines Typs bzw. die nächste passende Abgabestelle. |
| `Economy/IdleWorkerTracker.cs` | Liste untätiger Worker pro Spieler, `GetNextIdleWorker()` für den späteren Button |
| `Economy/Workers/Worker.cs` | Worker-Fähigkeit für jede Einheit. Der Ressourcentyp kommt vom Knoten und ist nicht im Worker festgelegt. |
| `Economy/Workers/States/*` | `WorkerMoveToResourceState`, `WorkerGatherState`, `WorkerReturnResourceState`, `WorkerBuildState` und `WorkerRepairState` (beide vorbereitet) |
| `UI/ResourceBarUI.cs` | Obere Leiste: Food, Wood, Metal, Energy, Population `47 / 80`, Idle Workers |
| geändert: `UnitData` | neu: **Carry Capacity**, **Gather Rate** |
| geändert: `MatchConfig` | neu: **Starting Resources**, **Starting Population Capacity**, **Population Hard Cap** |
| geändert: `PlayerState` | hält `Resources` und `Population` (serialisierbar für Saves) |
| geändert: `Unit`, `UnitCommand`, `UnitStateMachine`, `UnitStateId`, `UnitMovement` | Befehle Gather und ReturnResource, `StateChanged`-Event, Zustand MovingToResource, Blickrichtung beim Arbeiten |
| geändert: `CommandManager` | Rechtsklick auf Knoten oder Abgabestelle, Stop (X) |
| geändert: `SelectionManager`, `SelectionPanelUI` | leere Knoten werden abgewählt, das Panel zeigt Ladung bzw. Restmenge |
| geändert: `InputReader`, `RTSControls.inputactions` | neue Hotkeys, siehe oben |

**Worker-Zustände:** Idle, Moving (`UnitMoveState`), MovingToResource, Gathering, ReturningResource, Building, Repairing.
Alle laufen über dieselbe Unit-State-Machine mit 10 Hz. Gesammelt wird pro Tick (`GatherRate × GatherRateModifier × Tickdauer`), nie pro Frame.

### Einrichtung in Unity

1. **Layer:** zusätzlich **Resource** und **Building** anlegen.
2. **Systems-Objekt** um diese Komponenten erweitern: `ResourceManager`, `PopulationManager`, `ResourceLocator`, `IdleWorkerTracker`. Im Inspector gibt es bei ihnen nichts einzustellen.
3. **CommandManager:** **Interactable Mask** = `Resource` + `Building`.
   **SelectionManager:** **Selectable Mask** = `Unit` + `Resource`. Mit `Building` zusammen ist das in Phase 3 schon vorbereitet.
4. **MatchConfig:** Starting Resources (Standard 200 / 200 / 100 / 0), Starting Population Capacity (Standard 10), Hard Cap 200.
5. **Worker-Einheit:**
   - Lege ein neues `UnitData`-Asset `Villager` an (ID `stone_villager`, Unit Type **Worker**, Population Cost 1, Carry Capacity 10, Gather Rate 1).
   - Lege ein Prefab wie den Clubman aus Phase 1 an, zusätzlich mit der Komponente **Worker** (Defaults: Interaction Reach 0.8, Node Search Radius 25, Max Approach Attempts 3).
   - Setze **Unit → Data** = `Villager`.
6. **Ressourcenknoten** (je ein Prefab in `Assets/Prefabs/Resources`):
   | Prefab | Form (Vorschlag) | Resource Type | Max Amount | Gather Rate Modifier |
   | --- | --- | --- | --- | --- |
   | `TreeNode` | Zylinder, grün | Wood | 150 | 1 |
   | `FoodNode` | Kugel, rot (Beerenbusch) | Food | 200 | 1 |
   | `MetalNode` | Würfel, grau | Metal | 400 | 0.7 |
   | `EnergyNode` | Kapsel, cyan | Energy | 500 | 0.5 |

   Jeder Knoten braucht: Layer **Resource** (auch an den Kindern), einen **Collider**, die Komponente `ResourceNode` und eine **NavMeshObstacle** mit **Carve** = an. So laufen Einheiten drumherum, und nach dem Abbau wird der Weg frei.
7. **Platzhalter-Abgabestelle** (bis das Town Center in Phase 3 kommt):
   - Würfel `DropOff_TC`, Scale `(4, 2, 4)`, Layer **Building**.
   - Komponenten: `ResourceDropOff` (**Owner Id** 0, **Accepted Resource Types** = alle vier) und **NavMeshObstacle** (Carve).
   - Für einen Test ohne Energy-Annahme: zweiter Würfel `DropOff_LumberCamp` mit **Accepted Resource Types** = nur Wood.
8. **UI:** Im Canvas oben ein Objekt `ResourceBar` mit `ResourceBarUI`, darin 6 Texte (TextMeshPro) für Food, Wood, Metal, Energy, Population und Idle Workers. Ziehe sie in die gleichnamigen Felder.
   Optional kannst du im Auswahlpanel einen weiteren Text als **Detail Text** zuweisen.
9. NavMesh **neu baken**.

### Phase 2 testen

| Test | Erwartung |
| --- | --- |
| Play drücken | Leiste zeigt `Food: 200  Wood: 200  Metal: 100  Energy: 0`, dazu `Population: <Anzahl Einheiten> / 10` und `Idle workers: <Anzahl>` |
| Villager wählen, Rechtsklick auf Baum | Er läuft hin, dreht sich zum Baum und sammelt. Das Detail-Panel zeigt `Carrying 3 / 10 Wood (Gather)`. |
| Ladung voll | Er läuft zur nächsten Abgabestelle, gibt ab (Wood +10), läuft zum **selben** Baum zurück, und das wiederholt sich |
| Baum anklicken | Das Panel zeigt `Wood: 120 / 150` und die Menge sinkt |
| Baum leer | Der Baum verschwindet, der Villager sucht selbst den nächsten Baum im Umkreis von 25 m |
| Kein weiterer Baum in der Nähe | Er bringt die Restladung weg und wird idle, der Idle-Zähler steigt |
| Derselbe Villager: Holz → Erz → Beeren | Er wechselt ohne Umbau. Wechselt er mitten in der Ladung den Typ, verfällt die alte Ladung. |
| Energy sammeln, nur `DropOff_LumberCamp` vorhanden | Warnung „found no drop-off accepting Energy“, Worker wird idle |
| Rechtsklick mit vollem Worker auf eigene Abgabestelle | Er liefert sofort dort ab |
| Rechtsklick auf Boden, danach X | Er bewegt sich bzw. stoppt, die Ladung bleibt erhalten |
| Viele Villager auf einen Baum | Wer keinen Platz bekommt, wählt nach ein paar Versuchen einen Nachbarbaum |
| Einheit im Editor löschen | Population sinkt sofort |
| Ressourcen erscheinen auf der Leiste | Nur per Event, es gibt kein Polling |

### Bekannte Einschränkungen (Phase 2)

- **Abgabestelle ist ein Platzhalter:** `ResourceDropOff` sitzt auf einem Würfel. Das Town Center (Phase 3) nutzt dieselbe Komponente.
- **Maximale Bevölkerung** kommt nur aus der Startkapazität der `MatchConfig`. Häuser rufen ab Phase 3 `AddCapacity` auf.
- **Kein Limit an Workern pro Knoten**, aber unerreichbare Plätze werden nach 3 Versuchen aufgegeben.
- Die Suche nach der nächsten Abgabestelle misst **Luftlinie**, nicht Pfadlänge.
- **Tragen wird nicht angezeigt:** Es gibt kein Tragemodell und keine Sammel-Animation.
- **Keine Tech-Modifikatoren:** Carry Capacity und Gather Rate lesen direkt aus `UnitData`. Die Modifikatoren kommen in Phase 6.
- **Kein Idle-Worker-Button:** Es gibt nur den Zähler, Button und Hotkey kommen in Phase 10.
- **Building und Repairing** laufen nur zum Ziel und warten dort.
- **Hotkeys ohne Funktion:** Escape, Q, H, P, B, R und die Control-Group-Tasten sind als Actions angelegt, tun aber noch nichts.

## Nächster Schritt: Phase 3 – Buildings

Gebäudeplatzierung mit Ghost (grün/rot), Bau durch Worker mit abnehmendem Zusatznutzen, Town Center, Houses, Barracks.
