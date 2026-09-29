# Tabby Shaders

Copyright (c) 2026 Avie29 – lizenziert unter [CC BY-NC 4.0](LICENSE) (Namensnennung, nicht kommerziell).

Ein schneller Iris-Shader für **Minecraft 26.x** im Stil von BSL, gebaut für hohe FPS.

## Features

- **BSL-artiger Nebel**: Der Nebel nimmt die Himmelsfarbe in Blickrichtung an. Entferntes Terrain geht nahtlos in den Himmel über und leuchtet bei Sonnenuntergang orange. Dazu kommen Dunst je nach Tageszeit, weniger Nebel in der Höhe, dunkler Höhlennebel, Regennebel und Nebel unter Wasser, in Lava und in Pulverschnee.
- **Sonne & Mond**: runde Sonne mit Leuchten und runder Mond mit echten **Mondphasen**. Das Licht wechselt über den Tag: warmes Morgen- und Abendlicht, weißes Mittagslicht, blaues Mondlicht. Die Helligkeit des Mondlichts hängt von der Mondphase ab.
- **Vanilla-Wolken mit Fade nach oben**: Die Form bleibt Vanilla. Unten sind die Wolken deckend und werden nach oben hin durchsichtig. Ihre Farbe folgt der Tageszeit.
- **Volumetrische Wolken (optional)** in drei Stilen: **Complementary Unbound** (realistische, hohe Haufenwolken mit Blumenkohl-Kuppeln und Silberrand), **BSL** (weiche Haufenwolken) und **Complementary Reimagined** (blockige Wolkenfelder im Vanilla-Raster). Sie werden in halber Auflösung berechnet.
- **Wasser im BSL-Stil**: Landschaft und Himmel spiegeln sich (Screen-Space-Reflections), der Boden wird durch die Wellen verzerrt, und die Sonne glitzert auf dem Wasser. Flaches Wasser ist klar, tiefes Wasser dunkelblau. Als Farbe wählst du die Biomfarbe oder ein einheitliches BSL-Blau. Die Vanilla-Textur blendest du stufenlos ein (0 % = reines Shader-Wasser, 100 % = Vanilla).
- **Wetter**: Bei Regen wird der Boden nass und glänzend, auf flachen Flächen bilden sich spiegelnde Pfützen mit Regentropfen-Ringen, die nach dem Regen langsam trocknen. Gewitter machen den Himmel dunkler, Blitze erhellen kurz die ganze Welt, und nach dem Regen erscheint ein Regenbogen. Das alles gibt es nur in Biomen, in denen es auch regnet.
- **Farbiges Licht**: Seelenfackeln leuchten blau, Redstone rot, Amethyst lila, Kupferfackeln grün, Froschlichter gelb, grün oder pink. Die Farben mischen sich und werden von Wänden aufgehalten. Die Helligkeit kommt weiter aus der Vanilla-Lightmap, deshalb gibt es keine Lichtlecks. Das braucht Iris mit Compute-Shadern, sonst gibt es normales Fackellicht.
- **Leuchtende Erze**: Die farbigen Flecken von Diamant, Smaragd, Lapis, Redstone, Gold, Eisen, Kupfer und den Nether-Erzen leuchten und erhellen mit farbigem Licht schwach ihre Umgebung.
- **PBR (labPBR)**: Mit einem PBR-Ressourcenpaket gibt es Normal Maps, Glanzlichter, Metalle, Spiegelungen und leuchtende Stellen. Die Option ist standardmäßig aus.
- **End**: eigener Himmel mit rotierenden Sturmwolken, Blitzen und einem Wirbel im Zenit. Minecrafts End-Blitze lassen alles aufleuchten. Die Insel bekommt Licht mit Schatten und lila Nebel, der zum Himmel passt.
- **Nether**: leuchtender Lava-Dunst über dem Lavameer und orangenes Lava-Licht von unten.
- **3D-Portale**: Nether- und End-Portal bekommen einen Tiefeneffekt, man schaut in wirbelnde Energie bzw. ein Sternenfeld hinein.
- **Dynamisches Handlicht**: Fackeln, Laternen und andere leuchtende Items in der Hand erhellen die Umgebung, und zwar in ihrer Farbe (Seelenfackel blau, Redstone-Fackel rot ...).
- **Lichtstrahlen**: Sonnenstrahlen durch Bäume und Fenster, besonders schön bei Sonnenauf- und -untergang und unter Wasser.
- Günstige Schatten (optional), wehende Pflanzen und Blätter, leuchtende Blöcke, ACES-Tonemapping.

## Performance

- Forward Rendering: Licht wird direkt beim Zeichnen berechnet, ohne teure Deferred-Lighting-Pässe.
- Wenige Vollbild-Pässe: `deferred` + `deferred1` für volumetrische Wolken (optional, halbe Auflösung, mit zeitlicher Glättung), `deferred2` für den Himmel, `composite` für Wasser und Lichtstrahlen, `final` fürs Tonemapping.
- Farbiges Licht: ein Compute-Shader pro Frame auf einem 128×64×128-Raster und ein zusätzlicher Texturzugriff pro Pixel im Fackellicht. Es braucht den Schatten-Pass, der deshalb auch mit abgeschalteten Schatten weiterläuft.
- Schatten mit Hardware-PCF (1 oder 4 Samples). Der Schatten-Pass rendert nur innerhalb der Schattendistanz und ohne transparente Blöcke.
- Profile: **Kartoffel** (ohne Schatten, farbiges Licht, Lichtstrahlen und Wasser-Effekte), **Niedrig** (ohne Schatten, farbiges Licht, Lichtstrahlen und Landschaftsspiegelung), **Mittel** (Standard), **Hoch**.

## Installation

1. [Iris](https://irisshaders.dev) für deine 26.x-Version installieren.
2. Den Ordner `tabby-shaders` (mit dem Unterordner `shaders`) in `.minecraft/shaderpacks/` kopieren oder als ZIP packen.
3. Im Spiel unter *Optionen → Grafik → Shader-Pakete* auswählen.

## Aufbau

```text
shaders/
  shaders.properties     Menü, Profile, Tageszeit-Uniforms
  block.properties       Block-IDs (Pflanzen, Blätter, Wasser, Lichtquellen)
  lib/                   settings, Himmel, Nebel, Licht, Schatten, Wind
  program/               eigentlicher Shader-Code (einmal für alle Dimensionen)
  *.vsh / *.fsh          Oberwelt  (kleine Wrapper → program/)
  world-1/               Nether    (Wrapper mit #define NETHER)
  world1/                End       (Wrapper mit #define END)
```

Alle Einstellungen stehen in `shaders/lib/settings.glsl` und im Iris-Menü.

Ursprünglich gestartet aus dem Iris Example Shaderpack / XorDev's Default Shaderpack. Lizenz: siehe `LICENSE`. Ausnahme: `shaders/lib/needs_iris.glsl` steht unter der Lizenz im Kopf dieser Datei.
