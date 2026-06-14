# bezier — éditeur vectoriel iPhone

App d'illustration vectorielle, iPhone au doigt d'abord. **Pas de dessin à main
levée** : on pose des **primitives** (carré, cercle, triangle) toujours
**aimantées à une grille de points**, puis on les édite librement par poignées
(sommets, tangentes de Bézier). Objectif : géométrie nette « papier à points »,
publiable App Store.

> Une première approche par reconnaissance de forme (tracé au doigt → classif
> droite/cercle/rectangle) a été abandonnée : trop floue côté UX. Tout le
> pipeline associé (Schneider fitting, RDP, PCA/calipers, capture UIKit) a été
> retiré.

## Langue & conventions
- **Communiquer en français, coder en anglais** (identifiants, commits).
- **Pas de commentaires dans le code.** Jamais en français. Les rares
  indispensables (constante « magique », invariant non évident) : en anglais,
  courts. Le code doit se lire seul (noms explicites).
- Commits conventionnels : `type: description` (`feat`, `fix`, `refactor`…).
- Avant toute édition SwiftUI/iOS : invoquer les skills `all-ios-skills:*`
  pertinents (cf. config globale). Le core géométrique (dossier
  `bezier/Geometry/`) est du Swift pur, hors de cette règle.

## Architecture (couches découplées)

| Couche | Rôle | Où |
|---|---|---|
| **Géométrie** | `VectorShape` (modèle éditable), `BezierPath` (rendu), `Grid`, `Viewport` | `bezier/Geometry/` — Swift pur, **zéro UIKit** (n'importe que `CoreGraphics`/`Foundation`) |
| **État** | caméra, outil, formes, sélection | `CanvasStore` (`@Observable`, `@MainActor`) |
| **UI / interaction** | rendu Canvas, gestes, toolbar | `InfiniteCanvasView` (SwiftUI) |

### Modèle clé : `VectorShape` est centré sur les nœuds
Un `VectorShape` est une suite de `Node` (ancre + deux poignées de tangente
absolues optionnelles + type `corner`/`smooth`), optionnellement fermé. Bouger un
sommet, courber un côté, aimanter sont des opérations **locales** (pas de
duplication d'ancre entre segments). Le rendu passe par `VectorShape.bezierPath()`
qui aplatit en
`CubicSegment` → `cgPath()`. Une poignée à `nil` = côté droit (contrôle implicite
au tiers, exposé par `effectiveHandleIn/Out`), donc **tout côté est courbable**,
même sur un polygone à coins francs.

### Fichiers
Tout est dans une seule cible app (`bezier`). Pas de package séparé.
- `bezier/Geometry/` (Swift pur) : `VectorShape.swift` (cœur), `BezierPath.swift`
  (conteneur de rendu), `Grid.swift` (aimantation), `Viewport.swift`
  (monde↔écran), `CGPoint+Math.swift` (`+ - *` sur `CGPoint`).
- `bezier/` : `CanvasStore.swift`, `InfiniteCanvasView.swift`, `ContentView.swift`,
  `bezierApp.swift`.

## Interaction actuelle (mode Sélectionner)
- **Poser** : un tap sur une icône de primitive la dépose au centre, aimantée.
- **Tap corps** d'une forme → sélection (ancres visibles).
- **Tap/drag d'un nœud** → l'active (révèle ses tangentes, ancre en accent) *et*
  le déplace dans le même geste. Aimanté au lâcher.
- **Drag d'une tangente** (du nœud actif) → courbe le côté. Bout aimanté à la
  grille au lâcher. Nœud `smooth` : poignée opposée en miroir ; `corner` :
  côtés indépendants.
- **Mode Naviguer** : pan (drag) + zoom (pinch centré sur les doigts).

Priorité de saisie : tangente du nœud actif → n'importe quel nœud → corps → vide.

## Build
```sh
xcodebuild -project bezier.xcodeproj -scheme bezier \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```
Le projet Xcode utilise des **groupes synchronisés** : ajouter/retirer un fichier
sous `bezier/` (y compris `bezier/Geometry/`) ne nécessite pas d'éditer le
`.pbxproj`. Pas de suite de tests (choix assumé : vélocité solo).

## Suite envisagée
- Poignées d'**arête** (pousser un segment = agrandir H/L) et de **bounding-box**
  (scale global).
- Édition de nœuds : ajouter/supprimer un point, bascule `corner`↔`smooth`.
- Document multi-formes : z-order, style (remplissage/contour), **undo/redo**.
- Persistance (galerie + `Codable`), export PNG/PDF.
- Plus tard : opérations booléennes (union/diff/intersection) via lib tierce
  (iOverlay envisagé) sur formes aplaties.
