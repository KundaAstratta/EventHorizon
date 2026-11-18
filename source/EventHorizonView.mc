import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! Event Horizon — Asymmetric Space Watch Face.
//!
//! Référence de design : écran rond 454 px (FR965, Epix 2, ...), rayon de
//! cadran _radius = 207 px après marge de 20 px. **Aucune taille codée en
//! dur en pixels** : toutes les dimensions du rendu sont des fractions de
//! _radius, de sorte que le cadran s'adapte à toutes les cibles du
//! manifest.xml (260 px → 454 px).
//!
//! Conventions géométriques :
//! - Repère écran Connect IQ : origine en haut à gauche, **y vers le bas** ;
//! - Angles des aiguilles en radians, 0 = 12 h, sens horaire, avec
//!   `x = x0 + L·cos(θ)`, `y = y0 + L·sin(θ)` (correct dans un repère y
//!   inversé, cf. suite de tests Python `tests/test_eventhorizon_math.py`) ;
//! - `drawArc` suit la convention du SDK (doc officielle) : **0° = 3 h**,
//!   **90° = 12 h**, angles croissants en sens trigonométrique ;
//!   `ARC_CLOCKWISE` dessine de degreeStart à degreeEnd dans le sens horaire
//!   visuel.
class EventHorizonView extends WatchUi.WatchFace {

    // Pivot des aiguilles (asymétrie "7h30"), en fraction du rayon
    private const PIVOT_DX = -0.1836;
    private const PIVOT_DY =  0.1546;

    // Aiguilles Dauphine : longueurs / largeurs en fraction du rayon
    private const HOUR_LEN   = 0.4348; // 90 px sur 454
    private const MIN_LEN    = 0.5797; // 120 px
    private const SEC_LEN    = 0.6280; // 130 px
    private const HOUR_WIDTH = 0.0483; // 10 px (demi-largeur)
    private const MIN_WIDTH  = 0.0386; // 8 px (demi-largeur)
    private const HAND_BACK  = 0.0725; // 15 px (queue)
    private const GLOW_MARGIN = 0.0193; // 4 px de halo
    private const SEPARATOR_MARGIN = 0.0386; // 8 px d'anneau isolant

    // Ombre lunaire (terminateur) : fractions du rayon
    private const SHADOW_FRAC = 0.2657; // profondeur visée : 55 px / 207
    private const BLUR_FRAC   = 0.1449; // pénombre : 30 px / 207

    // Marqueurs horaires
    private const MARKER_FRAC   = 0.88;   // rayon du cercle des marqueurs
    private const MARKER_LEN_FRAC = 0.0725;

    // Chaton de pivot (fraction du rayon)
    private const PIVOT_R_OUT  = 0.0338; // 7 px
    private const PIVOT_R_MID  = 0.0242; // 5 px
    private const PIVOT_R_IN   = 0.0097; // 2 px

    private var _centerX as Number = 0;
    private var _centerY as Number = 0;
    private var _radius as Number = 0;
    private var _dialX as Float = 0.0;      // Pivot des aiguilles (décalé = asymétrie)
    private var _dialY as Float = 0.0;
    private var _shadowWidth as Float = 0.0; // Profondeur du terminateur (fraction × rayon)
    private var _blurSpan as Float = 0.0;
    private var _markerRadius as Float = 0.0;
    private var _markerLen as Float = 0.0;

    private var _electricBlue as Number = 0x00FFFF; // Cyan / Electric Blue
    private var _handColor as Number = 0xFFFFFF;
    private var _isInSleepMode as Boolean = false;

    // Champ d'étoiles précalculé (x, y, taille), identique à chaque frame
    private var _starX as Array = [0];
    private var _starY as Array = [0];
    private var _starS as Array = [1];

    // Fond statique rasterisé (dégradé + étoiles), null si l'allocation échoue
    private var _bgBitmap as Graphics.BufferedBitmap or Null = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        _centerX = w / 2;
        _centerY = h / 2;
        // Garde-fou : jamais de rayon négatif ou déraisonnablement petit
        // (Toybox.Math n'expose pas min/max : ternaires)
        var halfScreen = (_centerX < _centerY) ? _centerX : _centerY;
        _radius = (halfScreen - 20 > 40) ? halfScreen - 20 : 40;

        // Pivot décalé en fraction du rayon : l'asymétrie est conservée
        // quelle que soit la taille de l'écran.
        _dialX = _centerX.toFloat() + PIVOT_DX * _radius;
        _dialY = _centerY.toFloat() + PIVOT_DY * _radius;

        _shadowWidth = SHADOW_FRAC * _radius;
        _blurSpan = BLUR_FRAC * _radius;

        // Marqueurs : rayon visé 0.88 × r, mais borné pour rester à l'écran.
        // Distance max d'un marqueur au centre-écran = |pivot| + _markerRadius ;
        // on la limite au rayon écran, sinon les marqueurs voisins de 7h30
        // sont tronqués par la lunette.
        var pivotDist = Math.sqrt(PIVOT_DX * PIVOT_DX + PIVOT_DY * PIVOT_DY) * _radius;
        var screenRadius = ((w < h) ? w : h).toFloat() / 2.0 - 1.0;
        var markerAim = _radius.toFloat() * MARKER_FRAC;
        var markerMax = screenRadius - pivotDist;
        _markerRadius = (markerAim < markerMax) ? markerAim : markerMax;
        _markerLen = MARKER_LEN_FRAC * _radius;

        _initStars(w, h);
        _buildBackground(w, h);
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_isInSleepMode) {
            drawMarkers(dc);
            drawHands(dc, true);
            return;
        }

        // Fond statique (dégradé + étoiles) pré-rasterisé UNE fois dans un
        // BufferedBitmap 8 bits : un blit par seconde au lieu de ~240
        // primitives. Repli sur le tracé direct si l'allocation a échoué
        // (mémoire insuffisante sur certaines cibles).
        if (_bgBitmap == null) {
            drawConcentricBackground(dc);
            drawStarField(dc);
        } else {
            dc.drawBitmap(0, 0, _bgBitmap);
        }

        // Ombre lunaire (sous le circuit et les marqueurs pour rester lisibles)
        drawMoonShadow(dc);

        drawSingularityRings(dc);
        drawCircuitLines(dc);
        drawHands(dc, false);
    }

    //! Rasterise le fond statique (dégradé radial + champ d'étoiles) dans un
    //! BufferedBitmap palette 8 bits (≈ w·h octets, ex. 206 Ko sur 454 px).
    //! En cas d'échec d'allocation, le rendu bascule sur le tracé direct.
    private function _buildBackground(w as Number, h as Number) as Void {
        try {
            if (! (Toybox.Graphics has :createBufferedBitmap)) {
                return;
            }
            // Palette exacte du dégradé (40 pas) + blanc des étoiles :
            // le 8 bits reste sans banding car chaque couleur tracée
            // existe littéralement dans la palette.
            var palette = [];
            var startG = 0x40;
            var startB = 0x60;
            var endG   = 0x05;
            var endB   = 0x10;
            var n1 = 39.0;
            for (var i = 0; i < 40; i++) {
                var ratio = i / n1;
                var g = startG + (endG - startG) * ratio;
                var b = startB + (endB - startB) * ratio;
                palette.add((g.toLong() << 8 | b.toLong()).toNumber());
            }
            palette.add(0xFFFFFF);

            // createBufferedBitmap (API 4.0.0) renvoie une référence allouée
            // dans le pool graphique ; get() matérialise le bitmap et peut
            // lever OutOfGraphicsMemoryException (attrapé ci-dessous).
            var reference = Graphics.createBufferedBitmap({
                :width => w,
                :height => h,
                :palette => palette
            });
            // get() renvoie Null en cas d'échec ; le cast alors levera une
            // InvalidCastException, capturée par le catch ci-dessous.
            var bitmap = reference.get() as Graphics.BufferedBitmap;
            var bdc = bitmap.getDc();
            bdc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
            bdc.clear();
            drawConcentricBackground(bdc);
            drawStarField(bdc);
            _bgBitmap = bitmap;
        } catch (ex) {
            _bgBitmap = null;
        }
    }

    //! Fond dégradé radial : C(r) interpolé linéairement entre start (centre)
    //! et end (bord), sur `numRings` cercles concentriques (du plus grand au
    //! plus petit). ratio=0 exactement au centre pour i = 0.
    private function drawConcentricBackground(dc as Dc) as Void {
        var numRings = 40;
        var maxRadius = _radius + 20;

        var startG = 0x40;  // centre : opalin sombre
        var startB = 0x60;
        var endG   = 0x05;  // bord : quasi noir
        var endB   = 0x10;

        var n1 = (numRings - 1).toFloat();
        var iF = numRings.toFloat();
        for (var i = numRings - 1; i >= 0; i--) {
            var ratio = i.toFloat() / n1;

            var g = startG + (endG - startG) * ratio;
            var b = startB + (endB - startB) * ratio;
            var color = (g.toLong() << 8) | b.toLong();

            // Flottant explicite : évite la division entière qui produit
            // des rayons inégaux (espacement irrégulier des anneaux).
            var ringRadius = maxRadius.toFloat() * (i + 1).toFloat() / iF;

            dc.setColor(color.toNumber(), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_centerX, _centerY, ringRadius);
        }
    }

    //! xorshift 31 bits : uniquement des shifts et des XOR, donc aucun
    //  dépassement de capacity de `Number` (32 bits signés), contrairement
    //  au LCG précédent (1664525 mod 2^31) dont le produit intermédiaire
    //  dépasse 2^32. Injection de bits moyens (>> 8) : les bits bas d'un
    //  PRNG multiplicatif ont une période courte.
    private function _xorshift31(x as Number) as Number {
        x = x ^ ((x << 13) & 0x7FFFFFFF);
        x = x ^ (x >> 17);
        x = x ^ ((x << 5) & 0x7FFFFFFF);
        return x; // 0 <= x < 2^31, jamais 0 si la graine est non nulle
    }

    //! Position des étoiles calculée UNE fois (graine fixe → champ stable),
    //! stockée en tableaux : plus aucun PRNG ni allocation dans le chemin
    //! de rendu par seconde.
    private function _initStars(width as Number, height as Number) as Void {
        var count = 200;
        _starX = new [count];
        _starY = new [count];
        _starS = new [count];

        var x = 42; // graine arbitraire non nulle
        for (var i = 0; i < count; i++) {
            x = _xorshift31(x);
            _starX[i] = (x >> 8) % width;

            x = _xorshift31(x);
            _starY[i] = (x >> 8) % height;

            x = _xorshift31(x);
            // 20 % d'étoiles plus grandes (x % 10 ∈ {8, 9})
            _starS[i] = ((x >> 8) % 10 > 7) ? 2 : 1;
        }
    }

    private function drawStarField(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var n = _starX.size();
        for (var i = 0; i < n; i++) {
            dc.fillCircle(_starX[i], _starY[i], _starS[i]);
        }
    }

    private function drawSingularityRings(dc as Dc) as Void {
        var sw = _shadowWidth; // profondeur du terminateur
        var sxi = ((_centerX + _radius).toFloat() - sw * 0.45).toNumber();
        var syi = (_centerY.toFloat() - sw * 0.35).toNumber();

        var r1 = sw * 0.08;
        var r2 = sw * 0.17;
        var r3 = sw * 0.27; // disque d'accrétion
        var r4 = sw * 0.38;
        var r5 = sw * 0.52; // arc partiel
        var r6 = sw * 0.68; // arc partiel

        dc.setPenWidth(1);
        dc.setColor(0x009999, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sxi, syi, r1);

        dc.setColor(0x007777, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sxi, syi, r2);

        dc.setPenWidth(3);
        dc.setColor(0x00DDDD, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sxi, syi, r3);

        dc.setPenWidth(2);
        dc.setColor(0x009999, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sxi, syi, r3 + 2);

        dc.setPenWidth(1);
        dc.setColor(0x004444, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sxi, syi, r4);

        // Arcs partiels : moitié droite du cadran uniquement.
        // Convention SDK (doc officielle Dc.drawArc) : 0° = 3 h, 90° = 12 h,
        // angles croissants en sens trigonométrique ; ARC_CLOCKWISE dessine
        // visuellement dans le sens horaire de degreeStart à degreeEnd.
        // Le demi-arc droit s'écrit donc [90° → 270°] horaire (passe par 0° = 3 h).
        dc.setColor(0x002828, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(sxi, syi, r5, Graphics.ARC_CLOCKWISE, 90, 270);

        dc.setColor(0x001818, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(sxi, syi, r6, Graphics.ARC_CLOCKWISE, 100, 260);

        // Singularité centrale : point noir absolu
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sxi, syi, sw * 0.05);
    }

    //! Ombre lunaire + pénombre.
    //!
    //! Géométrie corrigée : deux disques de même rayon r, dont l'ombre est
    //! décalée de Δ par rapport au centre-écran. Sur l'axe horizontal, le
    //! disque d'ombre couvre [rim − (2r − Δ), rim] ; la profondeur visible
    //! vaut donc 2r − Δ. Le code d'origine utilisait Δ = 2(r − w), soit une
    //! profondeur réelle de 2w (le double de la valeur documentée) ;
    //! **Δ = 2r − w** place le terminateur à exactement w px du bord.
    private function drawMoonShadow(dc as Dc) as Void {
        var r = _radius.toFloat();

        // Pénombre : 8 passes, du disque le plus large (léger) au plus étroit
        // (sombre), du fond bleu vers le noir.
        var blurColors = [
            0x003050, 0x002840, 0x002030, 0x001828,
            0x001020, 0x000818, 0x000410, 0x000208
        ];

        for (var i = 0; i < 8; i++) {
            // w décroît de _shadowWidth + _blurSpan → _shadowWidth
            var w = _shadowWidth + _blurSpan - i.toFloat() * _blurSpan / 7.0;
            dc.setColor(blurColors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_centerX.toFloat() + 2.0 * r - w, _centerY.toFloat(), r);
        }

        // Ombre noire principale, par-dessus la pénombre.
        dc.setColor(0x000810, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_centerX.toFloat() + 2.0 * r - _shadowWidth, _centerY.toFloat(), r);

        dc.setColor(0x000408, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_centerX.toFloat() + 2.0 * r - 0.65 * _shadowWidth, _centerY.toFloat(), r);

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_centerX.toFloat() + 2.0 * r - 0.35 * _shadowWidth, _centerY.toFloat(), r);
    }

    private function drawCircuitLines(dc as Dc) as Void {
        var r = _radius.toFloat();

        dc.setColor(0x007799, Graphics.COLOR_TRANSPARENT); // Teal foncé

        // 1. Le cercle "générateur" à 9 h, aligné sur le pivot
        var circleRadius = r * 0.15;
        var circleX = _dialX - r * 0.5;
        var circleY = _dialY;

        dc.setPenWidth(3);
        dc.drawCircle(circleX, circleY, circleRadius);
        dc.fillCircle(circleX, circleY, circleRadius * 0.4);

        // 2. Arcs en dessous
        dc.drawArc(circleX, circleY, circleRadius * 1.5, Graphics.ARC_COUNTER_CLOCKWISE, 270, 90);
        dc.drawArc(circleX, circleY, circleRadius * 2.0, Graphics.ARC_COUNTER_CLOCKWISE, 250, 110);

        // 3. Boucles supérieure/inférieure, à l'échelle du rayon
        var lx = r * 0.2415; // 50 px
        var ly = r * 0.0725; // 15 px
        var tx = r * 0.1932; // 40 px
        var ty = r * 0.2899; // 60 px
        var rx = r * 0.2899; // 60 px
        var ry = r * 0.2415; // 50 px

        dc.drawLine(_dialX - lx, _dialY - ly, _dialX - tx, _dialY - ty);
        dc.drawLine(_dialX - tx, _dialY - ty, _dialX + rx, _dialY - ry);
        dc.drawLine(_dialX + rx, _dialY - ry, _dialX + lx, _dialY - ly);
        dc.drawLine(_dialX + lx, _dialY - ly, _dialX - lx, _dialY - ly);

        dc.drawLine(_dialX - lx, _dialY + ly, _dialX - tx, _dialY + ty);
        dc.drawLine(_dialX - tx, _dialY + ty, _dialX + rx, _dialY + ry);
        dc.drawLine(_dialX + rx, _dialY + ry, _dialX + lx, _dialY + ly);
        dc.drawLine(_dialX + lx, _dialY + ly, _dialX - lx, _dialY + ly);

        // 4. Raccords vers le cercle de 9 h
        var cy = r * 0.0242; // 5 px
        dc.drawLine(_dialX - lx, _dialY - ly, circleX + circleRadius, _dialY - cy);
        dc.drawLine(_dialX - lx, _dialY + ly, circleX + circleRadius, _dialY + cy);

        drawMarkers(dc);
    }

    private function drawMarkers(dc as Dc) as Void {
        // Marqueurs en cercle autour du pivot décalé, cohérents avec le
        // centre de rotation des aiguilles. Sens horaire, 0 en haut :
        // θ_i = 2π·i/12 − π/2, x = x0 + R·cos(θ), y = y0 + R·sin(θ)
        // (repère écran y inversé ⇒ ordre horaire correct, cf. tests).
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        for (var i = 0; i < 12; i++) {
            if (i == 3 || i == 9) { continue; } // 3 h et 9 h supprimés

            var angle = (i.toFloat() / 12.0) * Math.PI * 2 - Math.PI / 2;
            var cosA = Math.cos(angle);
            var sinA = Math.sin(angle);

            dc.drawLine(
                _dialX + _markerRadius * cosA,               _dialY + _markerRadius * sinA,
                _dialX + (_markerRadius - _markerLen) * cosA, _dialY + (_markerRadius - _markerLen) * sinA
            );
        }
    }

    private function drawHands(dc as Dc, inSleep as Boolean) as Void {
        var clockTime = System.getClockTime();
        var r = _radius.toFloat();

        // Angles (rad) : 0 = 12 h, sens horaire. Heure : 720 min / tour,
        // minutes et secondes : 60 / tour. La fraction t/T ∈ [0,1[ est
        // multipliée par 2π puis décalée de −π/2 (0 = haut).
        var hourAngle = ((clockTime.hour % 12) * 60 + clockTime.min) / (12 * 60.0) * Math.PI * 2 - Math.PI / 2;
        var minAngle  = clockTime.min / 60.0 * Math.PI * 2 - Math.PI / 2;
        var secAngle  = clockTime.sec / 60.0 * Math.PI * 2 - Math.PI / 2;

        var hourLen  = r * HOUR_LEN;
        var minLen   = r * MIN_LEN;
        var hourHalf = r * HOUR_WIDTH;
        var minHalf  = r * MIN_WIDTH;

        drawDauphineHand(dc, hourAngle, hourLen, hourHalf, _handColor);
        drawDauphineHand(dc, minAngle, minLen, minHalf, _handColor);

        // Chaton de pivot — cercle en bleu électrique sur le point de pivot
        dc.setColor(0x001830, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_dialX, _dialY, r * PIVOT_R_OUT);
        dc.setColor(_electricBlue, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_dialX, _dialY, r * PIVOT_R_MID);
        dc.setColor(0x000A18, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_dialX, _dialY, r * PIVOT_R_IN);

        // Trotteuse après le chaton : la ligne part du pivot sans masquer
        // le chaton plus longtemps qu'une seconde.
        if (!inSleep) {
            var secLen = r * SEC_LEN;
            var x = _dialX + secLen * Math.cos(secAngle);
            var y = _dialY + secLen * Math.sin(secAngle);

            // Liseré noir pour le relief
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(5);
            dc.drawLine(_dialX, _dialY, x, y);
            dc.fillCircle(x, y, r * PIVOT_R_MID);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(_dialX, _dialY, x, y);
            dc.fillCircle(x, y, r * PIVOT_R_OUT);
        }
    }

    //! Aiguille Dauphine : losange orienté selon `angle` (rad), longueur
    //! `length` avant du pivot, `backLen` derrière, demi-largeur `width`
    //! perpendiculaire. Direction unitaire u = (cosθ, sinθ) ; normale
    //! n = (sinθ, −cosθ). Dessin en 4 couches : anneau isolant, halo,
    //! corps, arête centrale.
    private function drawDauphineHand(dc as Dc, angle as Float, length as Float, width as Float, color as Number) as Void {
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);
        var backLen = _radius.toFloat() * HAND_BACK;
        var glowM = _radius.toFloat() * GLOW_MARGIN; // 4 px de halo autour du corps
        var sepM = _radius.toFloat() * SEPARATOR_MARGIN; // 8 px d'anneau isolant

        // --- Anneau sombre isolant (sépare l'aiguille du fond cyan) ---
        dc.setColor(0x000A18, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [_dialX + (length + sepM) * cos,   _dialY + (length + sepM) * sin],
            [_dialX + (width + sepM) * sin,    _dialY - (width + sepM) * cos],
            [_dialX - (backLen + sepM) * cos,  _dialY - (backLen + sepM) * sin],
            [_dialX - (width + sepM) * sin,    _dialY + (width + sepM) * cos]
        ]);

        // --- Halo bleu électrique (polygone agrandi) ---
        dc.setColor(_electricBlue, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [_dialX + (length + glowM) * cos,  _dialY + (length + glowM) * sin],
            [_dialX + (width + glowM) * sin,   _dialY - (width + glowM) * cos],
            [_dialX - (backLen + glowM) * cos, _dialY - (backLen + glowM) * sin],
            [_dialX - (width + glowM) * sin,   _dialY + (width + glowM) * cos]
        ]);

        // --- Corps principal ---
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [_dialX + length * cos,    _dialY + length * sin],
            [_dialX + width * sin,     _dialY - width * cos],
            [_dialX - backLen * cos,   _dialY - backLen * sin],
            [_dialX - width * sin,     _dialY + width * cos]
        ]);

        // --- Contour bleu nuit (profondeur) ---
        dc.setColor(0x001830, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(_dialX + length * cos,   _dialY + length * sin,
                    _dialX + width * sin,    _dialY - width * cos);
        dc.drawLine(_dialX + width * sin,    _dialY - width * cos,
                    _dialX - backLen * cos,  _dialY - backLen * sin);
        dc.drawLine(_dialX - backLen * cos,  _dialY - backLen * sin,
                    _dialX - width * sin,    _dialY + width * cos);
        dc.drawLine(_dialX - width * sin,    _dialY + width * cos,
                    _dialX + length * cos,   _dialY + length * sin);

        // --- Arête centrale en bleu électrique (effet prisme) ---
        dc.setColor(_electricBlue, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(_dialX - backLen * cos, _dialY - backLen * sin,
                    _dialX + length * cos,   _dialY + length * sin);
    }

    function onHide() as Void {
    }

    function onEnterSleep() as Void {
        _isInSleepMode = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isInSleepMode = false;
        WatchUi.requestUpdate();
    }

}
