import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time.Gregorian;
import Toybox.Math;

class EventHorizonView extends WatchUi.WatchFace {

    private var _centerX as Number = 0;
    private var _centerY as Number = 0;
    private var _radius as Number = 0;
    private var _dialX as Number = 0; // Pivot des aiguilles (décalé = asymétrie)
    private var _dialY as Number = 0;
    private var _shadowWidth as Number = 0; // Largeur en pixels de la zone d'ombre (effet lune)
    private var _electricBlue as Number = 0x00FFFF; // Cyan/Electric Blue
    private var _shieldColor as Number = 0x000000; // Black
    private var _handColor as Number = 0xFFFFFF; // White
    private var _secondHandColor as Number = 0x00FFFF; // Electric Blue tip? Or just silver. Let's go with silver/grey for main, blue tip maybe.
    private var _isInSleepMode as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _centerX = dc.getWidth() / 2;
        _centerY = dc.getHeight() / 2;
        _radius = (_centerX < _centerY ? _centerX : _centerY) - 20;
        // Pivot décalé vers 7h30 pour l'asymétrie (Option B)
        _dialX = _centerX - 38;
        _dialY = _centerY + 32;
        // Ombre lunaire : décalage proportionnel au décentrage du pivot
        _shadowWidth = 55; // Largeur exacte en pixels de la zone d'ombre sur le bord droit
    }

    function onUpdate(dc as Dc) as Void {
        // Clear screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_isInSleepMode) {
            // In sleep mode, draw markers and hands (no seconds)
            drawMarkers(dc);
            drawHands(dc, true); // true = in sleep mode = no seconds
            return;
        }

        //Other Background
        drawConcentricBackground(dc);
        drawStarField(dc);


        // Draw the Shield Shape
        drawShieldBackground(dc);

        // Draw Moon Shadow (sous le circuit et les marqueurs pour qu'ils restent visibles)
        drawMoonShadow(dc);

        // Draw Singularity Rings — anneaux de l'horizon des événements dans la zone noire
        drawSingularityRings(dc);

        // Draw the Electric Blue Circuit Lines + Markers (par-dessus l'ombre)
        drawCircuitLines(dc);

        // Draw the Logo
        drawLogo(dc);

        // Draw Hands
        drawHands(dc, false);
    }


    private function drawConcentricBackground(dc as Dc) as Void {
        var numRings = 40; // Increased for smoother gradient
        var maxRadius = _radius + 20;

        // Opalin : centre plus clair, bords plus sombres
        var startR = 0;      // centre
        var startG = 0x40;
        var startB = 0x60;

        var endR = 0;        // bord extérieur
        var endG = 0x05;
        var endB = 0x10;

        // Draw concentric circles from largest (outer) to smallest (inner)
        for (var i = numRings - 1; i >= 0; i--) {
            var ratio = i.toFloat() / (numRings - 1);
            
            // Interpolate colors
            var r = startR + (endR - startR) * ratio;
            var g = startG + (endG - startG) * ratio;
            var b = startB + (endB - startB) * ratio;
            
            var color = (r.toLong() << 16) | (g.toLong() << 8) | b.toLong();
            
            var ringRadius = maxRadius * (i + 1) / numRings;
            
            dc.setColor(color.toNumber(), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_centerX, _centerY, ringRadius);
        }
    }


    private function drawStarField(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // Vous pouvez ajuster le nombre d'étoiles ici
        var numStars = 200;
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Utilise une graine (seed) constante pour que le champ d'étoiles soit
        // identique à chaque appel. C'est un simple générateur pseudo-aléatoire.
        var seed = 1;

        for (var i = 0; i < numStars; i++) {
            // Génère une coordonnée X pseudo-aléatoire
            seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
            var x = seed % width;

            // Génère une coordonnée Y pseudo-aléatoire
            seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
            var y = seed % height;

            // Fait varier la taille des étoiles pour un effet plus naturel
            // 30% des étoiles seront un peu plus grandes.
            seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
            var size = (seed % 10 > 7) ? 2 : 1;

            dc.fillCircle(x, y, size);
        }
    }


    private function drawSingularityRings(dc as Dc) as Void {
        // Singularité décentrée : tension asymétrique dans la zone noire
        var sw = _shadowWidth.toFloat();
        var sx = (_centerX + _radius).toFloat() - sw * 0.45;
        var sy = _centerY.toFloat() - sw * 0.35;

        // Étape 2 — Radii adaptatifs proportionnels à _shadowWidth
        // [0.08, 0.17, 0.27, 0.38, 0.52, 0.68] × _shadowWidth
        var r1 = (sw * 0.08).toNumber();
        var r2 = (sw * 0.17).toNumber();
        var r3 = (sw * 0.27).toNumber(); // disque d'accrétion
        var r4 = (sw * 0.38).toNumber();
        var r5 = (sw * 0.52).toNumber(); // arc partiel
        var r6 = (sw * 0.68).toNumber(); // arc partiel

        var sxi = sx.toNumber();
        var syi = sy.toNumber();

        // Étape 4 — Anneaux intérieurs complets avec épaisseur variable
        dc.setPenWidth(1);
        dc.setColor(0x009999, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sxi, syi, r1);

        dc.setColor(0x007777, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sxi, syi, r2);

        // Étape 3 — Disque d'accrétion lumineux (~27% du rayon max)
        dc.setColor(0x00DDDD, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawCircle(sxi, syi, r3);

        dc.setPenWidth(2);
        dc.setColor(0x009999, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sxi, syi, r3 + 2);

        // Anneau intermédiaire complet
        dc.setPenWidth(1);
        dc.setColor(0x004444, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sxi, syi, r4);

        // Étape 5 — Anneaux partiels : seule la moitié droite tracée
        // Simule la lumière qui disparaît derrière le terminateur (côté gauche coupé)
        dc.setColor(0x002828, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(sxi, syi, r5, Graphics.ARC_CLOCKWISE, 300, 60);

        dc.setColor(0x001818, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(sxi, syi, r6, Graphics.ARC_CLOCKWISE, 320, 40);

        // Singularité centrale : point noir absolu
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sxi, syi, (sw * 0.05).toNumber());
    }

    private function drawMoonShadow(dc as Dc) as Void {
        // Ombre lunaire pixel-exact + effet de flou au terminateur.
        // Formule : offset = 2 * (_radius - width) place le terminateur à exactement 'width' px du bord.
        var r = _radius;
        var blurSpan = 30; // largeur de la zone de transition en pixels

        // --- ORDRE CORRECT : pénombre EN PREMIER, ombre noire PAR-DESSUS ---

        // Pénombre : 8 passes du fond bleu vers le noir.
        // Colors : partent proches du fond (~0x003050) et descendent vers le noir.
        // Dessinées AVANT le noir pour être visibles dans la zone bleue.
        var blurColors = [
            0x003050, 0x002840, 0x002030, 0x001828,
            0x001020, 0x000818, 0x000410, 0x000208
        ];

        for (var i = 0; i < 8; i++) {
            // blurW : de _shadowWidth+blurSpan (loin dans le bleu) → _shadowWidth (terminateur)
            var blurW = _shadowWidth + blurSpan - (i * blurSpan / 7);
            dc.setColor(blurColors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_centerX + 2 * (r - blurW), _centerY, r);
        }

        // Zone noire principale (dessinée APRÈS le flou, par-dessus)
        dc.setColor(0x000810, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_centerX + 2 * (r - _shadowWidth),            _centerY, r);

        dc.setColor(0x000408, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_centerX + 2 * (r - _shadowWidth * 65 / 100), _centerY, r);

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_centerX + 2 * (r - _shadowWidth * 35 / 100), _centerY, r);
    }

    private function drawShieldBackground(dc as Dc) as Void {
        // The Ventura shape is a triangle with curved sides.
        // Since the screen is round, we want to maximize the size but keep the shape visible.
        // We'll draw a polygon or fill the background black (already done).
        // To make it look like the watch, we might want to draw a dark grey outline of the shield if the background is black.
        // But the user asked for the watch face.
        // Let's assume the whole screen is the "face" but we draw the shield contour to define the active area.
        
        // Actually, looking at the image, the face IS the shield. The rest is the strap/case.
        // On a round watch, we can't change the physical shape.
        // So we will draw the shield shape in the center.
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Coordinates for a shield shape
        // Top Left, Top Right, Bottom Center (roughly)
        // It's an asymmetric triangle? No, Ventura is usually symmetric or slightly asymmetric depending on model.
        // The image shows a symmetric shield rotated 90 degrees? No, it's a triangle pointing down/right?
        // Wait, the image shows the Ventura Elvis80 or similar. It's a triangle pointing roughly 3 o'clock?
        // No, the crown is on the right. The point is on the left?
        // Let's look at the image again.
        // The top is wide, the bottom is a point. It's a triangle pointing down.
        // But it's rotated. The 12 is at the top.
        // The shape is: Top edge is curved. Sides are curved to a point at the bottom.
        // Actually, the Ventura is often "shield" shaped on its side.
        // In the image provided:
        // The 12 o'clock marker is at the top.
        // The shape is roughly a triangle with the base at the top-left to bottom-left?
        // No, let's look at the markers.
        // There is a marker at 12 (top), 6 (bottom), 9 (left).
        // The "point" seems to be at the 3 o'clock position (right) or 9 o'clock?
        // The Hamilton Ventura is unique.
        // Let's assume a standard orientation where 12 is up.
        // The image shows the case is triangular.
        // The dial inside follows the case.
        // I will draw a "Shield" shape that fits within the circle.
        
        // Let's define points for a polygon that approximates the shield.
        // Top-Left, Top-Right, Bottom.
        // Top edge is convex.
        // Side edges are convex.
        
        // For simplicity and "best effort" on a round screen:
        // I will draw the "Electric Blue" pattern which DEFINES the look more than the black background on black.
        
    }

    private function drawCircuitLines(dc as Dc) as Void {
        dc.setColor(0x007799, Graphics.COLOR_TRANSPARENT); // Teal foncé (différencié du cyan des aiguilles)
        dc.setPenWidth(3);

        // The pattern in the image:
        // A central circle/arc structure on the left (9 o'clock).
        // Lines radiating out or forming a grid.
        // "Hamilton" text on the right.
        
        // Let's approximate the "pulse" design.
        // It looks like a zig-zag or frequency wave on the left, scaling from 9 o'clock towards the center.
        
        // Left side (9 o'clock) - The "Generator" look
        // Concentric arcs or a spiral?
        // Image shows: A circle at 9 o'clock.
        // Then lines extending to the right.
        
        var r = _centerX; // radius (taille de référence, pas une position)

        // 1. The Circle at 9 o'clock — décalé avec le pivot
        var circleX = _dialX - r * 0.5;
        var circleY = _dialY;
        var circleRadius = r * 0.15;

        dc.setPenWidth(3);
        dc.drawCircle(circleX, circleY, circleRadius);
        dc.fillCircle(circleX, circleY, circleRadius * 0.4); // Inner dot

        // 2. Arcs around it
        dc.drawArc(circleX, circleY, circleRadius * 1.5, Graphics.ARC_COUNTER_CLOCKWISE, 270, 90);
        dc.drawArc(circleX, circleY, circleRadius * 2.0, Graphics.ARC_COUNTER_CLOCKWISE, 250, 110);

        // 3. Top Blue Loop — décalé avec le pivot
        dc.drawLine(_dialX - 50, _dialY - 15, _dialX - 40, _dialY - 60); // Left up
        dc.drawLine(_dialX - 40, _dialY - 60, _dialX + 60, _dialY - 50); // Top across
        dc.drawLine(_dialX + 60, _dialY - 50, _dialX + 50, _dialY - 15); // Right down
        dc.drawLine(_dialX + 50, _dialY - 15, _dialX - 50, _dialY - 15); // Bottom across (close loop)

        // Bottom Blue Loop (Mirrored)
        dc.drawLine(_dialX - 50, _dialY + 15, _dialX - 40, _dialY + 60);
        dc.drawLine(_dialX - 40, _dialY + 60, _dialX + 60, _dialY + 50);
        dc.drawLine(_dialX + 60, _dialY + 50, _dialX + 50, _dialY + 15);
        dc.drawLine(_dialX + 50, _dialY + 15, _dialX - 50, _dialY + 15);

        // Connecting lines to the circle on the left
        dc.drawLine(_dialX - 50, _dialY - 15, circleX + circleRadius, _dialY - 5);
        dc.drawLine(_dialX - 50, _dialY + 15, circleX + circleRadius, _dialY + 5);

        drawMarkers(dc);
    }

    private function drawMarkers(dc as Dc) as Void {
        // Marqueurs répartis en cercle autour du pivot décalé (_dialX/_dialY),
        // cohérent avec le centre de rotation des aiguilles.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var markerRadius = _radius.toFloat() * 0.88;
        var markerLen    = 15;

        for (var i = 0; i < 12; i++) {
            if (i == 3 || i == 9) { continue; } // 3h et 9h supprimés

            var angle = (i / 12.0) * Math.PI * 2 - Math.PI / 2;
            var cosA  = Math.cos(angle);
            var sinA  = Math.sin(angle);

            dc.drawLine(
                _dialX + markerRadius * cosA,              _dialY + markerRadius * sinA,
                _dialX + (markerRadius - markerLen) * cosA, _dialY + (markerRadius - markerLen) * sinA
            );
        }
    }

    private function drawLogo(dc as Dc) as Void {
        // Placé dans l'espace haut-droite libéré par l'asymétrie du pivot
        dc.setColor(_electricBlue, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _centerX + 24,
            _centerY - 30,
            Graphics.FONT_XTINY,
            "EVENT",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _centerX + 24,
            _centerY - 16,
            Graphics.FONT_XTINY,
            "HORIZON",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawHands(dc as Dc, inSleep as Boolean) as Void {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var min = clockTime.min;
        var sec = clockTime.sec;

        // Adjust for 12-hour format if needed, but math works with 24h too for angle
        var hourAngle = ((hour % 12) * 60 + min) / (12 * 60.0) * Math.PI * 2 - Math.PI / 2;
        var minAngle = min / 60.0 * Math.PI * 2 - Math.PI / 2;
        var secAngle = sec / 60.0 * Math.PI * 2 - Math.PI / 2;

        // Draw Hour Hand
        // Dauphine style hands (triangular)
        // drawDauphineHand(dc, hourAngle, 60, 6, _handColor); // ORIGINAL
        drawDauphineHand(dc, hourAngle, 90, 10, _handColor); // MODIFIED: Increased size

        // Draw Minute Hand
        // drawDauphineHand(dc, minAngle, 90, 4, _handColor); // ORIGINAL
        drawDauphineHand(dc, minAngle, 120, 8, _handColor); // MODIFIED: Increased size

        // Chaton de pivot — cercle en bleu électrique sur le point de pivot décalé
        dc.setColor(0x001830, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_dialX, _dialY, 7);
        dc.setColor(_electricBlue, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_dialX, _dialY, 5);
        dc.setColor(0x000A18, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_dialX, _dialY, 2);

        // Draw Second Hand
        // Thin line with a tip
        if (!inSleep) {
            var secRadius = 130; // MODIFIED: Increased size
            var x = _dialX + secRadius * Math.cos(secAngle);
            var y = _dialY + secRadius * Math.sin(secAngle);

            // Outline for relief effect
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(5);
            dc.drawLine(_dialX, _dialY, x, y);
            dc.fillCircle(x, y, 5);

            // Inner line
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3); // MODIFIED: Increased size
            dc.drawLine(_dialX, _dialY, x, y);
            dc.fillCircle(x, y, 4); // Tip // MODIFIED: Increased size
        }
    }

    private function drawDauphineHand(dc as Dc, angle as Float, length as Number, width as Number, color as Number) as Void {
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);
        var backLen = 15;
        var glowMargin = 4;
        var sepMargin = 8;

        // --- Option C : Anneau sombre isolant (sépare l'aiguille du fond cyan) ---
        dc.setColor(0x000A18, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [_dialX + (length + sepMargin) * cos,          _dialY + (length + sepMargin) * sin],
            [_dialX + (width  + sepMargin) * Math.sin(angle), _dialY - (width  + sepMargin) * Math.cos(angle)],
            [_dialX - (backLen + sepMargin) * cos,         _dialY - (backLen + sepMargin) * sin],
            [_dialX - (width  + sepMargin) * Math.sin(angle), _dialY + (width  + sepMargin) * Math.cos(angle)]
        ]);

        // --- Idée B : Halo bleu électrique (polygone agrandi) ---
        var xTipG  = _dialX + (length + glowMargin) * cos;
        var yTipG  = _dialY + (length + glowMargin) * sin;
        var xBackG = _dialX - (backLen + glowMargin) * cos;
        var yBackG = _dialY - (backLen + glowMargin) * sin;
        var xS1G   = _dialX + (width + glowMargin) * Math.sin(angle);
        var yS1G   = _dialY - (width + glowMargin) * Math.cos(angle);
        var xS2G   = _dialX - (width + glowMargin) * Math.sin(angle);
        var yS2G   = _dialY + (width + glowMargin) * Math.cos(angle);

        dc.setColor(_electricBlue, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[xTipG, yTipG], [xS1G, yS1G], [xBackG, yBackG], [xS2G, yS2G]]);

        // --- Idée A : Corps principal blanc ---
        var xTip  = _dialX + length * cos;
        var yTip  = _dialY + length * sin;
        var xBack = _dialX - backLen * cos;
        var yBack = _dialY - backLen * sin;
        var xS1   = _dialX + width * Math.sin(angle);
        var yS1   = _dialY - width * Math.cos(angle);
        var xS2   = _dialX - width * Math.sin(angle);
        var yS2   = _dialY + width * Math.cos(angle);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[xTip, yTip], [xS1, yS1], [xBack, yBack], [xS2, yS2]]);

        // --- Contour bleu nuit (profondeur, remplace le noir) ---
        dc.setColor(0x001830, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(xTip, yTip, xS1, yS1);
        dc.drawLine(xS1, yS1, xBack, yBack);
        dc.drawLine(xBack, yBack, xS2, yS2);
        dc.drawLine(xS2, yS2, xTip, yTip);

        // --- Idée A : Arête centrale en bleu électrique (effet prisme lumineux) ---
        dc.setColor(_electricBlue, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(xBack, yBack, xTip, yTip);
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
