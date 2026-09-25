# RIFTBOUND – MVP v2: Die Elementarschmiede

Koop-Action-RPG für Roblox (1–4 Spieler). Du erkundest das Rift, sammelst Erz, Elementkerne und Monsterteile und schmiedest daraus deine eigene Waffe.

**Kreislauf:** Vorbereiten → Expedition starten → erkunden und sammeln → Risiko abwägen → zurückkehren → craften und schmieden → weiter vordringen.

> *„Geh weiter, sammle seltene Beute und komm rechtzeitig zurück, um daraus Ausrüstung zu bauen, die dir neue Wege öffnet.“*

---

## In Place 1 bringen

### Variante A – Rojo (empfohlen, bleibt synchron)

1. Rojo installieren: [rojo.space](https://rojo.space/docs/v7/getting-started/installation/). Das geht z. B. über [Aftman](https://github.com/LPGhatguy/aftman) oder als Download von GitHub. Dazu das **Rojo-Plugin** in Studio installieren.
2. Dieses Repo klonen und im Ordner ausführen:
   ```bash
   rojo serve
   ```
3. Place 1 in Roblox Studio öffnen → Plugins → **Rojo** → **Connect**.
4. **Play** drücken. Die Welt (Camp + Verdant Scar) baut sich beim Start automatisch auf.

### Variante B – ohne Rojo

`RIFTBOUND.rbxlx` in Studio öffnen (Datei → Öffnen) und testen. Um es in Place 1 zu übernehmen, kopierst du aus der Datei folgende Ordner an dieselben Stellen in Place 1:

- `ReplicatedStorage/Shared`
- `ServerScriptService/Server`
- `StarterPlayer/StarterPlayerScripts/Client`
- `StarterPlayer/StarterCharacterScripts/Health`

Die Datei neu bauen: `rojo build -o RIFTBOUND.rbxlx`

### Speichern aktivieren

Home → Game Settings → Security → **Enable Studio Access to API Services**. Das Spiel muss dafür veröffentlicht sein. Ohne diese Einstellung läuft alles, nur der Fortschritt wird nicht gespeichert.

---

## Assets (Asset-Pack & Creator Store)

Das Spiel ist **sofort spielbar**: Fehlt ein Modell, baut `AssetLoader` ein Low-Poly-Ersatzmodell aus Parts.

So ersetzt du die Ersatzmodelle durch die Modelle aus `assets/` (oder durch Modelle aus dem Creator Store):

1. In Studio: **3D-Importer** (Avatar/Home → Import 3D) → `.gltf` aus `assets/models/...` wählen. Die `.bin` muss daneben liegen.
2. In **ServerStorage** einen Ordner **`RiftboundAssets`** anlegen.
3. Das importierte Modell hineinziehen und **genau so benennen** wie in der Tabelle.
4. Falls es falsch herum steht: am Modell ein Number-Attribut **`Yaw`** (Grad, z. B. `90` oder `180`) setzen.

Die Größe wird automatisch angepasst. Fremde Skripte in Creator-Store-Modellen werden beim Einsetzen entfernt.

| Name im Ordner | Verwendung | Datei im Pack |
|---|---|---|
| `Riftling`, `Rootstalker`, `Lantern_Wraith`, `Rift_Crawler`, `Burrow_Mimic`, `Hollow_Warden` | Gegner & Boss | `models/02_Enemies/...` |
| `Copper_Deposit`, `Stone_Deposit`, `Rift_Deposit`, `Timber_Pile` | Abbaubare Ressourcen | `models/03_Resources/...` |
| `Hard_Copper_Deposit`, `Fiber_Bush`, `Herb_Patch`, `Anvil_Forge` | Harte Ader, Fasern, Kräuter, Schmiede | nicht im Pack → Creator Store oder Ersatzmodell |
| `Workbench`, `Smelting_Furnace`, `Storage_Chest`, `Return_Portal` | Stationen, Truhen, Portale | `models/04_Structures/...` |
| `Research_Table`, `Expedition_Board`, `Training_Dummy` | Stationen | nicht im Pack → Creator Store oder Ersatzmodell |
| `Tree`, `Rock`, `Tent`, `Ruin_Pillar`, `Ruin_Wall`, `Lantern`, `Campfire` | Deko | Creator Store oder Ersatzmodell |

Hinweise:

- **Gegner:** Das Pack-Modell wird als Optik an einen unsichtbaren `HumanoidRootPart` geschweißt. KI, Treffer und Lebensleiste funktionieren sofort. Eigene Animationen sind der nächste Schritt; die Gelenkpunkte stehen in `assets/rigs.json`.
- **Portal:** Die leuchtende Portalfläche heißt `Surface`. Beim Pack-Modell kannst du selbst ein Part mit diesem Namen ergänzen. Ohne dieses Part funktioniert das Portal trotzdem.
- **Waffen** werden je nach Form und Element farbig aus Parts gebaut, weil jede Kombination anders aussieht.

---

## Steuerung

| | PC | Controller | Handy |
|---|---|---|---|
| Leichter Angriff | Linksklick | R2 | ANGRIFF |
| Kupferbogen | T | L2 | BOGEN |
| Heiltrank | 1 | Steuerkreuz ↓ | TRANK |
| Rückruf-Signalgeber | X | Steuerkreuz → | RÜCKRUF |
| Schwerer Angriff | R / kurzer Rechtsklick | R1 | SCHWER |
| Ausweichen (kurz unverwundbar) | Q | B | AUSWEICHEN |
| Elementfähigkeit (Ladung voll) | F | Y | ELEMENT |
| Interagieren | E (Beute sichern: G) | X | Tippen |
| Arsenal / Aufgaben / Hilfe | I / J / H | Select | Knöpfe unten links |

---

## Was im MVP steckt

- **Rift Camp:** Schmiede, Werkbank, Schmelzofen, Forschungstisch, Expeditionstafel, Lagerkiste (Materialien an Mitspieler geben) und ein Trainingsplatz mit Übungspuppen.
- **Werkbank:** Stein- und Kupferspitzhacke, Seilwerfer, Kupferbogen, leichte Rüstung (−20 % Schaden), Rift-Ortungsgerät. Dazu Verbrauchsgüter: Heiltränke (aus Heilkräutern), Pfeile und Rückruf-Signalgeber.
- **Werkzeuge öffnen Wege:** Normale Adern brauchen die Steinspitzhacke, harte Kupferadern die Kupferspitzhacke. Der Seilwerfer überquert den Abgrund am sicheren Pfad zum versteckten Höhlenbereich. Der Bogen ist stark gegen schwebende Wraiths.
- **Ressourcen:** Holz, Stein, Kupfererz, Riftkristall, Fasern und Heilkräuter. Das Waldgebiet rund um den Außenposten ist die sichere Einstiegszone.
- **Baupläne als Beute:** Seilwerfer und Kupferbogen findest du in Truhen, das Rift-Ortungsgerät beim Hollow Warden. Der Forschungstisch entschlüsselt sie.
- **Camp-Ausbau:** Großer Schmelzofen (3 Erz → 2 Barren), Kräuterbeet (doppelte Tränke), Rift-Wachturm (Gefahr steigt später). Die Ausbauten stehen sichtbar im Camp.
- **Rift-Gefahr:** Ab Minute 5 steigt sie alle 2 Minuten um eine Stufe (max. 5), und Gegnerwellen tauchen bei den Spielern auf. Der Signalgeber erlaubt einmal pro Expedition die Notflucht mit Beute.
- **Schmiede:** Waffenform + bis zu zwei Elementkerne + Monsterteil. Die Vorschau zeigt Effekte und Kosten. Danach folgt der Härtungsschritt: 3 Schläge im richtigen Moment ergeben die Qualität *Grob*, *Solide*, *Fein* oder *Meisterhaft*. Das Timing kann die Waffe nie zerstören.
- **3 Waffenformen:** Schwert (lädt schneller auf), Kriegshammer (betäubt, größere Explosionen; erforschen), Speer (Reichweite, Effekte reichen weiter; erforschen).
- **4 Elemente:** Glut (Brand), Frost (Verlangsamen/Einfrieren), Sturm (Ladung springt über), Schatten (Markieren → schwerer Treffer).
- **6 Kombinationen:** Thermobruch, Funkensturm, Brandmal, Kälteschock, Nachhall, Sprungblitz. Jede Waffenform führt sie anders aus.
- **5 Monsterteile:** Warden-Horn, Crawler-Klaue, Wraith-Kern, Rootstalker-Rinde, Mimic-Zahn. Sie lassen sich im Arsenal wieder entfernen.
- **Verdant Scar:** Außenposten (Beute sichern), Ruinen mit Rift-Barriere und Elementschrein, Kupfermine mit sicherem und riskantem Pfad sowie Frostsiegel-Versteck, Rift-Kammer. Gegner, Erze und Truhen wechseln bei jedem Lauf.
- **6 Gegnertypen + Boss:** Der Hollow Warden hat drei Angriffe: Bodenstoß, Wurzelschlag und Rift-Ausbruch (Kristalle zerstören!). Er skaliert mit der Gruppengröße.
- **Risiko:** Rucksack vs. gesichertes Lager, Niederschlag + Wiederbeleben, Teamwipe = 50 % der ungesicherten Grundmaterialien weg. Kerne, Monsterteile und Bossbeute bleiben erhalten. Nach einem Verbindungsabbruch kommst du mit deinem Rucksack in den Lauf zurück.
- **Fortschritt:** 14 Meilensteine (von der Steinspitzhacke bis zum Rift-Ortungsgerät), 4 Aufgaben mit Belohnung, Baupläne speichern und nachbauen. Speichern läuft über DataStore.
- **Sicherheit:** Der Server prüft Schaden, Treffer, Beute, Crafting und Speicherstände. Der Client sendet nur Absichten.

## Projektstruktur

```
src/shared/Config.luau          Alle Werte: Waffen, Elemente, Kombos, Gegner, Aufgaben
src/shared/Net.luau             Remotes
src/server/Main.server.luau     Startreihenfolge
src/server/Services/
  AssetLoader    Modelle aus ServerStorage/RiftboundAssets oder Ersatzmodelle
  WorldBuilder   Camp + Verdant Scar (Terrain, Stationen, Spawnpunkte)
  DataService    Speichern/Laden, Lager
  PlayerState    Leben, Ausdauer, Ladung, Rucksack, Waffe in der Hand
  Combat         Angriffe, Elemente, Kombinationen, Fähigkeiten
  Entities       Gegner-KI, Boss, Statuseffekte, Barrieren, Übungspuppen
  Forge          Schmiede, Härtung, Werkbank, Ofen, Forschung, Camp-Ausbau, Arsenal, Lagerkiste
  Gear           Bogen, Heiltränke, Rückruf, Seilwerfer, sichtbare Camp-Ausbauten
  Expedition     Lobby, Lauf, Beute sichern, Wiederbeleben, Teamwipe
  Progress       Meilensteine und Aufgaben
src/client/     HUD, Menüs, Eingabe (PC/Controller/Handy), Effekte
assets/         RIFTBOUND Asset-Pack (glTF/OBJ, Vorschaubilder, rigs.json)
```

Balancing: fast alles steht in `src/shared/Config.luau`, zum Beispiel Schaden, Kosten, Drop-Chancen, Boss-Werte und Aufgaben.

## Nächste Schritte

- Werkzeuge sichtbar in der Hand (Spitzhacken, Seilwerfer und Bogen aus dem Asset-Pack).
- Animationen für Spieler und Gegner (Gelenkpunkte in `rigs.json`) sowie Sounds.
- Weitere Studio-Deko aus dem Creator Store.
- Zweites Gebiet **Glutadern** mit Gluteisen, Schmiedegolem und Lava-Wegen. Dafür einfach einen neuen Abschnitt in `WorldBuilder.Spawns` und neue Einträge in `Config` anlegen.
