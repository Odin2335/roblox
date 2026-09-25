# RIFTBOUND – MVP Asset Pack v2

19 originale, prozedural modellierte Low-Poly-Assets. Die Vorschau wurde aus der tatsächlichen Mesh-Geometrie gerendert.

## Inhalt
- Werkzeuge/Waffen: Steinspitzhacke, Kupferspitzhacke, Steinschwert, Kupferbogen mit Pfeil, Seilwerfer.
- Gegner: Riftling, Rootstalker, Hollow Warden, Lantern Wraith, Rift Crawler und Burrow Mimic.
- Ressourcen: Steinvorkommen, Kupfervorkommen, Rift-Kristallvorkommen, Holzstapel.
- Strukturen: Werkbank mit Amboss, Schmelzofen, Rückkehrportal, Lagertruhe.

Jedes Asset hat einen eigenen Ordner mit .gltf + .bin sowie .obj + .mtl. Diese Dateien gehören jeweils zusammen. Die Materialien sind einfache Farbmaterialien, ohne externe Texturen oder UV-Maps. Die glTF-Version enthält zusätzlich schwache Emissionswerte für Kristalle und Feuer.

## Roblox Studio
1. Das gesamte ZIP entpacken.
2. Über den 3D-Importer eine .gltf-Datei aus dem gewünschten Modellordner wählen. Die gleichnamige .bin-Datei muss daneben liegen. Alternativ die .obj-Datei verwenden; .mtl im selben Ordner belassen.
3. In der Import-Vorschau Ausrichtung, Größe und Materialien prüfen. Die Modelle haben bewusst keine verbindliche Umrechnung in Roblox-Studs. Als Referenz beispielsweise den Warden ungefähr doppelt so hoch wie einen Spieler skalieren und die übrigen Modelle passend zur Szene einstellen.
4. Für unbewegliche Dekorationen die importierten Teile verankern. Kollisionen möglichst über einfache separate Kollisionskörper lösen; kleine Dekorationen brauchen keine eigenen Kollisionen.
5. Falls Farben/Emission beim Import nicht übernommen werden: die benannten Materialien/Teile anhand der Vorschau einfärben. Rift-Teile können in Studio ein Neon-Material erhalten.

Offizielle Import-Dokumentation: https://create.roblox.com/docs/studio/importer

## Blender
File > Import > glTF 2.0 und die jeweilige .gltf wählen. Materialien und getrennte Komponenten sind enthalten. OBJ ist als geometrisches Austauschformat beigefügt (Z nach oben); glTF verwendet Y nach oben.

## Fertigstellungsstand
Die sechs Gegner bestehen aus benannten, getrennten Meshgruppen. Ihre glTF-Dateien enthalten eine hierarchische Pivotstruktur mit Drehpunkten für Kopf, Rumpf, Arme, Beine und bei Spezialgegnern Maul, Kiefer oder Beinsegmente. Die Pivotkoordinaten stehen zusätzlich in rigs.json. Damit lassen sich Posen in Blender anlegen oder die Gegner in einem eigenen Animationsworkflow weiterverwenden.

Es gibt weiterhin kein Skinning, keine Animationsclips, keine Roblox-Motor6D-Verbindungen, NPC-KI, Werkzeugfunktionen, Hitboxen, Partikeleffekte oder fertige Roblox-Tools. Es sind vorbereitete starre Gelenkgruppen, keine importfertigen Roblox-Charakter-Rigs und keine R15-Avatare. OBJ enthält die Geometrie, aber keine Gelenkhierarchie; für die Pivotstruktur die jeweilige glTF-Datei verwenden.

Die Werkzeuge sind noch als Tool-Instanzen mit Handle, Grip und Verbindungen einzurichten. Der Pfeil ist beim Bogen separat modelliert, aber nicht als Geschoss programmiert. Das Portal hat einen offenen Innenraum; Portalfläche, Effekte und Teleport müssen ergänzt werden.

## Technische Qualität
112–4860 Dreiecke pro vollständigem Modell. Getrennte Komponenten erleichtern die Bearbeitung, erzeugen aber mehr MeshParts; unbewegliche Teile können vor dem Import passend zusammengeführt werden. Einzelne geschlossene Komponenten überlappen absichtlich. Das Paket ist für Spielgrafik, nicht für 3D-Druck gedacht.

Geprüft: Dateistruktur, Buffer/Accessor-Verweise, endliche Koordinaten, Normalen, nicht entartete Dreiecke, OBJ-Flächen und gerenderte Vorschau. Kein tatsächlicher Importtest in Roblox Studio oder Blender durchgeführt.

manifest.json enthält Dreieckszahlen, Komponenten und Abmessungen.
source/generate.py und source/enemies_v2.py sind die bearbeitbaren Erzeugungsquellen. source/render_preview.py rendert die Vorschau. Benötigt Python, numpy, scipy und Pillow. Der Vorschau-Renderer verwendet DejaVu-Fonts unter Linux; bei anderen Systemen die Fontpfade anpassen. Das Skript erstellt die Modelldateien und die Vorschau erneut.

## Gegner und Animation
Jede Gegnerdatei enthält im glTF eine Szene mit einem Root, hierarchischen Pivotknoten und getrennten Meshteilen. Die Arme sind an Schulter, Ellenbogen und Hand getrennt; Beine an Hüfte und Fuß. Kopf und Rumpf haben eigene Drehpunkte. Die Pivotknoten sind leere Transformationsknoten. Studio-Import und Animation müssen im konkreten Projekt eingerichtet und getestet werden.

## Änderungen in Version 2
- Seilwerfer neu modelliert: Griff, Abzugsbügel, Seilwicklung, Achskappen und drei Greifhaken.
- Holzstapel neu modelliert: getrennte Rinde und Schnittflächen, Jahresringe, feine Risse und außen geführte Seile.
- Werkbank neu modelliert: gefaste Bretter, Holzverbindungen, Amboss mit Fuß und Taille, Schraubstock, Hammer und Zange.
- Beide Spitzhacken: schmal zulaufende gebogene Spitzen.
- Kupfervorkommen: kompakte Erzstücke im Gestein, optisch vom Riftkristall getrennt.
- Truhe: Oberflächenbänder, Bretter und Nieten.
- Vorschau: pixelgenauer Tiefentest beseitigt falsche Überlagerungen der bisherigen Darstellung.
- Gegner, Schwert, Bogen, Stein-/Riftvorkommen, Ofen und Portal behalten ihre bisherige Geometrie.
- Der zusätzliche Detailaufwand liegt vor allem in Holz-Jahresringen und Seilwicklungen. Für viele gleichzeitig sichtbare Exemplare können diese später als Textur oder LOD vereinfacht werden.

Die Vorschauerzeugung liegt jetzt in source/render_preview.py. Beide Python-Dateien zusammen behalten.
